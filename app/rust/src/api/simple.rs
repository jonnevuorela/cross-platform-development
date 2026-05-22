use crate::frb_generated::StreamSink;
use half::f16;
use ort::{
    session::{builder::GraphOptimizationLevel, Session},
    value::{Tensor, TensorElementType, ValueType},
    Error,
};
use rand::Rng;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, PoisonError};
use tokenizers::Tokenizer;

struct ModelConfig {
    num_layers: usize,
    num_kv_heads: i64,
    head_dim: i64,
    vocab_size: i64,
    eos_token_id: i64,
    bos_token_id: i64,
    role_start_id: i64,
    role_end_id: i64,
    turn_end_id: i64,
    fixed_seq_len: Option<i64>,
}

struct AppInner {
    session: Session,
    tokenizer: Tokenizer,
    cfg: ModelConfig,
}

struct KvCache {
    keys: Vec<Vec<f32>>,
    values: Vec<Vec<f32>>,
}

impl KvCache {
    fn new(num_layers: usize) -> Self {
        Self {
            keys: vec![vec![]; num_layers],
            values: vec![vec![]; num_layers],
        }
    }

    fn seq_len(&self, cfg: &ModelConfig) -> i64 {
        if self.keys[0].is_empty() {
            0
        } else {
            self.keys[0].len() as i64 / (cfg.num_kv_heads * cfg.head_dim)
        }
    }
}

static APP: Mutex<Option<AppInner>> = Mutex::new(None);
static CANCEL: AtomicBool = AtomicBool::new(false);

fn lock_app() -> std::sync::MutexGuard<'static, Option<AppInner>> {
    APP.lock().unwrap_or_else(|e: PoisonError<_>| {
        eprintln!("[LLM] mutex poisoned, recovering");
        e.into_inner()
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn cancel_generation() {
    CANCEL.store(true, Ordering::SeqCst);
    eprintln!("[LLM] cancel flag set");
}

pub fn reset_model() {
    let mut guard = lock_app();
    *guard = None;
    CANCEL.store(false, Ordering::SeqCst);
    eprintln!("[LLM] model reset - session dropped");
}

pub fn init_model(
    model_path: String,
    tokenizer_path: String,
    num_layers: i64,
    num_kv_heads: i64,
    head_dim: i64,
    vocab_size: i64,
    eos_token_id: i64,
    bos_token_id: i64,
    role_start_id: i64,
    role_end_id: i64,
    turn_end_id: i64,
) -> Result<(), Error> {
    CANCEL.store(true, Ordering::SeqCst);

    let result = (|| {
        let tokenizer = Tokenizer::from_file(&tokenizer_path)
            .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;

        let path = std::path::Path::new(&model_path);
        let meta = std::fs::metadata(path)
            .map(|m| m.len())
            .unwrap_or(0);
        let data_path = path.with_extension("onnx_data");
        let data_meta = std::fs::metadata(&data_path)
            .map(|m| m.len())
            .unwrap_or(0);
        eprintln!(
            "[LLM] loading model: {} ({:.2} MB), data: {} ({:.2} MB)",
            model_path,
            meta as f64 / 1_048_576.0,
            data_path.display(),
            data_meta as f64 / 1_048_576.0,
        );

        ort::init().with_name("app").commit();

        let session = Session::builder()?
            .with_optimization_level(GraphOptimizationLevel::Level1)?
            .with_intra_threads(1)?
            .with_inter_threads(1)?
            .with_memory_pattern(false)?
            .with_prepacking(false)?
            .commit_from_file(&model_path)?;

        log_model_io(&session);

        let fixed_seq_len = detect_fixed_seq_len(&session);

        let cfg = ModelConfig {
            num_layers: num_layers as usize,
            num_kv_heads,
            head_dim,
            vocab_size,
            eos_token_id,
            bos_token_id,
            role_start_id,
            role_end_id,
            turn_end_id,
            fixed_seq_len,
        };

        let mut guard = lock_app();
        *guard = Some(AppInner { session, tokenizer, cfg });
        CANCEL.store(false, Ordering::SeqCst);
        eprintln!("[LLM] model loaded successfully");
        Ok(())
    })();

    if let Err(ref err) = result {
        CANCEL.store(false, Ordering::SeqCst);
        eprintln!("[LLM] init_model error: {err}");
    }

    result
}

pub fn generate(
    prompt: String,
    max_tokens: u32,
    temperature: f32,
    top_p: f32,
    top_k: i64,
    repetition_penalty: f32,
) -> Result<Vec<String>, Error> {
    match run_generate(&prompt, max_tokens, temperature, top_p, top_k, repetition_penalty, None) {
        Ok(tokens) => Ok(tokens),
        Err(err) => {
            eprintln!("[LLM] generate error: {err}");
            Err(err)
        }
    }
}

pub fn generate_stream(
    prompt: String,
    max_tokens: u32,
    temperature: f32,
    top_p: f32,
    top_k: i64,
    repetition_penalty: f32,
    stream: StreamSink<String>,
) -> Result<(), Error> {
    match run_generate(&prompt, max_tokens, temperature, top_p, top_k, repetition_penalty, Some(&stream)) {
        Ok(_) => Ok(()),
        Err(err) => {
            eprintln!("[LLM] generate_stream error: {err}");
            Err(err)
        }
    }
}

fn encode_text(tokenizer: &Tokenizer, text: &str) -> Result<Vec<i64>, Error> {
    let enc = tokenizer
        .encode(text, false)
        .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;
    Ok(enc.get_ids().iter().map(|&id| id as i64).collect())
}

fn strip_label_prefix(text: &str) -> Option<&str> {
    let text = text.trim_start();
    let col_idx = text.find(':')?;
    let prefix = text[..col_idx].trim();
    if prefix.len() < 60
        && !prefix.is_empty()
        && !prefix.contains('.')
        && !prefix.contains('!')
        && !prefix.contains('?')
        && !prefix.contains('\n')
    {
        let after = text[col_idx + 1..].trim_start();
        if !after.is_empty() {
            return Some(after);
        }
    }
    None
}

fn remove_self_intro(text: &str) -> Option<String> {
    let trimmed = text.trim_start();
    if trimmed.is_empty() {
        return None;
    }
    let head = &trimmed[..trimmed.len().min(200)];
    let intro_patterns: &[&str] = &[
        "I am a helpful",
        "I am an AI",
        "I'm an AI",
        "I'm a helpful",
        "I am SmolLM",
        "I'm SmolLM",
        "I am here to",
        "I'm here to",
        "As an AI",
        "As a language model",
        "I am a large language",
        "I'm a large language",
    ];
    let has_intro = intro_patterns.iter().any(|p| head.starts_with(p));
    if !has_intro {
        return None;
    }
    let boundaries: &[&str] = &[". ", ".\n", "!\n", "?\n", "\n\n"];
    for b in boundaries {
        if let Some(pos) = trimmed.find(b) {
            let rest = trimmed[pos + b.len()..].trim_start();
            if !rest.is_empty() {
                return Some(rest.to_string());
            }
        }
    }
    Some(String::new())
}

fn softmax(logits: &[f32]) -> Vec<f32> {
    let max_val = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
    let exps: Vec<f32> = logits.iter().map(|v| (v - max_val).exp()).collect();
    let sum: f32 = exps.iter().sum();
    exps.iter().map(|v| v / sum).collect()
}

fn sample_top_k_top_p(probs: &[f32], top_k: usize, top_p: f32) -> usize {
    let mut indices: Vec<usize> = (0..probs.len()).collect();
    indices.sort_unstable_by(|&a, &b| probs[b].partial_cmp(&probs[a]).unwrap_or(std::cmp::Ordering::Equal));

    let limit = if top_k > 0 && top_k < indices.len() { top_k } else { indices.len() };
    indices.truncate(limit);

    let mut cumsum = 0.0f32;
    let cutoff = indices.iter().position(|&i| {
        cumsum += probs[i];
        cumsum >= top_p
    });
    let limit2 = cutoff.map(|c| c + 1).unwrap_or(indices.len()).min(indices.len());
    indices.truncate(limit2);

    if indices.is_empty() {
        return 0;
    }

    let sub_probs: Vec<f32> = indices.iter().map(|&i| probs[i]).collect();
    let sub_sum: f32 = sub_probs.iter().sum();
    if sub_sum <= 0.0 {
        return indices[0];
    }

    let mut rng = rand::thread_rng();
    let r: f32 = rng.gen::<f32>() * sub_sum;
    let mut accum = 0.0f32;
    for (idx, &prob) in sub_probs.iter().enumerate() {
        accum += prob;
        if r <= accum {
            return indices[idx];
        }
    }
    indices[indices.len() - 1]
}

fn run_generate(
    prompt: &str,
    max_tokens: u32,
    temperature: f32,
    top_p: f32,
    top_k: i64,
    repetition_penalty: f32,
    sink: Option<&StreamSink<String>>,
) -> Result<Vec<String>, Error> {
    let inner = {
        let guard = lock_app();
        guard.as_ref().ok_or_else(|| Error::new("Model not loaded"))?;
        let inner = guard.as_ref().unwrap();
        let tokenizer = inner.tokenizer.clone();
        let cfg = ModelConfig {
            num_layers: inner.cfg.num_layers,
            num_kv_heads: inner.cfg.num_kv_heads,
            head_dim: inner.cfg.head_dim,
            vocab_size: inner.cfg.vocab_size,
            eos_token_id: inner.cfg.eos_token_id,
            bos_token_id: inner.cfg.bos_token_id,
            role_start_id: inner.cfg.role_start_id,
            role_end_id: inner.cfg.role_end_id,
            turn_end_id: inner.cfg.turn_end_id,
            fixed_seq_len: inner.cfg.fixed_seq_len,
        };
        (tokenizer, cfg)
    };

    let (tokenizer, cfg) = inner;
    let newline_ids = encode_text(&tokenizer, "\n")?;

    let system_prompt = "You are a helpful assistant. Answer concisely and stop when done.";
    let user_message = prompt.trim();

    if user_message.is_empty() {
        return Ok(vec![]);
    }

    let mut all_ids = Vec::new();

    if cfg.bos_token_id >= 0 {
        all_ids.push(cfg.bos_token_id);
    }

    all_ids.push(cfg.role_start_id);
    all_ids.extend(&encode_text(&tokenizer, "system")?);
    if cfg.role_end_id >= 0 {
        all_ids.push(cfg.role_end_id);
    }
    all_ids.extend(&newline_ids);
    all_ids.extend(&encode_text(&tokenizer, system_prompt)?);
    all_ids.push(cfg.turn_end_id);
    all_ids.extend(&newline_ids);

    all_ids.push(cfg.role_start_id);
    all_ids.extend(&encode_text(&tokenizer, "user")?);
    if cfg.role_end_id >= 0 {
        all_ids.push(cfg.role_end_id);
    }
    all_ids.extend(&newline_ids);
    all_ids.extend(&encode_text(&tokenizer, user_message)?);
    all_ids.push(cfg.turn_end_id);
    all_ids.extend(&newline_ids);

    all_ids.push(cfg.role_start_id);
    all_ids.extend(&encode_text(&tokenizer, "assistant")?);
    if cfg.role_end_id >= 0 {
        all_ids.push(cfg.role_end_id);
    }
    all_ids.extend(&newline_ids);

    let mut kv_cache = KvCache::new(cfg.num_layers);
    let mut output_tokens = Vec::new();
    let max_steps = max_tokens as usize;
    let top_k_usize = if top_k > 0 { top_k as usize } else { cfg.vocab_size as usize };
    let temp = if temperature <= 0.0 { 1.0 } else { temperature };

    let mut prefix_buf = String::new();
    let mut prefix_resolved = false;

    // Prefill phase: for models with fixed seq_len (e.g. GPT-2 decoder_with_past_model),
    // feed prompt tokens one at a time to populate the KV cache
    let prefill_done = if cfg.fixed_seq_len == Some(1) && all_ids.len() > 1 {
        eprintln!("[LLM] prefill: {} tokens", all_ids.len());
        for i in 0..all_ids.len() {
            if CANCEL.load(Ordering::SeqCst) {
                CANCEL.store(false, Ordering::SeqCst);
                eprintln!("[LLM] prefill cancelled at token {i}");
                return Ok(vec![]);
            }

            let input_ids = vec![all_ids[i]];
            let past_seq_len = kv_cache.seq_len(&cfg);
            let kv_seq_len = past_seq_len.max(1);

            {
                let mut guard = lock_app();
                let app = guard.as_mut().ok_or_else(|| Error::new("Model unloaded during prefill"))?;
                let session = &mut app.session;
                let input_specs: Vec<(String, ValueType)> = session
                    .inputs()
                    .iter()
                    .map(|input| (input.name().to_string(), input.dtype().clone()))
                    .collect();
                let inputs = build_inputs(&input_specs, &cfg, &input_ids, &kv_cache, kv_seq_len)?;
                let outputs = Session::run(session, inputs)?;
                let _ = extract_logits_and_kv(outputs.iter(), &mut kv_cache, &cfg)?;
            }
        }
        eprintln!("[LLM] prefill done, cache seq_len={}", kv_cache.seq_len(&cfg));
        true
    } else {
        false
    };

    for step in 0..max_steps {
        if CANCEL.load(Ordering::SeqCst) {
            eprintln!("[LLM] generation cancelled at step {step}");
            CANCEL.store(false, Ordering::SeqCst);
            break;
        }

        let is_first_step = step == 0 && !prefill_done;

        let (input_ids, past_seq_len) = if is_first_step {
            (all_ids.clone(), 0i64)
        } else {
            let last = vec![all_ids[all_ids.len() - 1]];
            (last, kv_cache.seq_len(&cfg))
        };

        let kv_seq_len = past_seq_len.max(1);

        let (logits, new_seq_len): (Vec<f32>, usize) = {
            let mut guard = lock_app();
            let app = guard.as_mut().ok_or_else(|| Error::new("Model unloaded during generation"))?;
            let session = &mut app.session;
            let input_specs: Vec<(String, ValueType)> = session
                .inputs()
                .iter()
                .map(|input| (input.name().to_string(), input.dtype().clone()))
                .collect();
            let inputs = build_inputs(&input_specs, &cfg, &input_ids, &kv_cache, kv_seq_len)?;
            let outputs = Session::run(session, inputs)?;
            let (data, new_len) = extract_logits_and_kv(outputs.iter(), &mut kv_cache, &cfg)?;
            (data, new_len)
        };

        let seq_len_for_logits = new_seq_len;

        let total_logits = seq_len_for_logits * cfg.vocab_size as usize;
        if logits.len() < total_logits {
            break;
        }
        let start = (seq_len_for_logits - 1) * cfg.vocab_size as usize;
        let end = start + cfg.vocab_size as usize;
        let slice = &logits[start..end.min(logits.len())];

        let mut logits_vec: Vec<f32> = slice.to_vec();

        if logits_vec.len() > cfg.vocab_size as usize {
            logits_vec.truncate(cfg.vocab_size as usize);
        }

        if cfg.vocab_size as usize > logits_vec.len() {
            logits_vec.resize(cfg.vocab_size as usize, f32::NEG_INFINITY);
        }

        let local_ids = &all_ids[all_ids.len().saturating_sub(50)..];
        for (idx, val) in logits_vec.iter_mut().enumerate() {
            if local_ids.contains(&(idx as i64)) {
                *val /= repetition_penalty;
            }
        }

        for val in logits_vec.iter_mut() {
            *val /= temp;
        }

        let probs = softmax(&logits_vec);
        let token_id = sample_top_k_top_p(&probs, top_k_usize, top_p);

        if token_id as i64 == cfg.eos_token_id || token_id as i64 == cfg.turn_end_id {
            break;
        }
        all_ids.push(token_id as i64);
        let piece = tokenizer
            .decode(std::slice::from_ref(&(token_id as u32)), true)
            .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;

        if let Some(s) = sink {
            if !prefix_resolved {
                prefix_buf.push_str(&piece);
                if let Some(stripped) = strip_label_prefix(&prefix_buf) {
                    prefix_resolved = true;
                    if !stripped.is_empty() {
                        if s.add(stripped.to_string()).is_err() {
                            break;
                        }
                    }
                    continue;
                }
                let has_boundary = prefix_buf.contains('.')
                    || prefix_buf.contains('!')
                    || prefix_buf.contains('?')
                    || prefix_buf.contains('\n');
                if has_boundary || prefix_buf.len() > 80 {
                    prefix_resolved = true;
                    if let Some(stripped) = remove_self_intro(&prefix_buf) {
                        if !stripped.is_empty() {
                            if s.add(stripped).is_err() {
                                break;
                            }
                        }
                    } else if s.add(prefix_buf.clone()).is_err() {
                        break;
                    }
                }
            } else if s.add(piece.clone()).is_err() {
                break;
            }
        }
        output_tokens.push(piece);
    }

    if CANCEL.load(Ordering::SeqCst) {
        CANCEL.store(false, Ordering::SeqCst);
    }

    if let Some(s) = sink {
        if !prefix_resolved && !prefix_buf.is_empty() {
            let _ = s.add(prefix_buf.clone());
        }
    }

    let full_output = output_tokens.join("");
    let mut result = full_output;
    if let Some(stripped) = strip_label_prefix(&result) {
        result = stripped.to_string();
    }
    result = remove_self_intro(&result).unwrap_or(result);
    Ok(vec![result])
}

fn build_inputs(
    input_specs: &[(String, ValueType)],
    cfg: &ModelConfig,
    input_ids: &[i64],
    kv_cache: &KvCache,
    kv_seq_len: i64,
) -> Result<Vec<(std::borrow::Cow<'static, str>, ort::session::SessionInputValue<'static>)>, Error> {
    let mut inputs_vec: Vec<(std::borrow::Cow<'static, str>, ort::session::SessionInputValue<'static>)> = Vec::new();
    let new_len = input_ids.len() as i64;
    let total_len = kv_seq_len + new_len;
    let input_shape = vec![1i64, new_len];
    let total_shape = vec![1i64, total_len];

    let attention_mask: Vec<i64> = vec![1; total_len as usize];
    let position_ids: Vec<i64> = (kv_seq_len..total_len).collect();

    for (name, dtype) in input_specs {
        let value: Option<ort::session::SessionInputValue<'static>> = match name.as_str() {
            "input_ids" | "tokens" => Some(
                Tensor::from_array((input_shape.clone(), input_ids.to_vec()))?.into(),
            ),
            "attention_mask" => Some(
                Tensor::from_array((total_shape.clone(), attention_mask.clone()))?.into(),
            ),
            "position_ids" => Some(
                Tensor::from_array((input_shape.clone(), position_ids.clone()))?.into(),
            ),
            "token_type_ids" => Some(
                Tensor::from_array((input_shape.clone(), vec![0i64; input_ids.len()]))?.into(),
            ),
            _ if name.starts_with("past_key_values") => {
                let parts: Vec<&str> = name.split('.').collect();
                if parts.len() < 3 {
                    return Err(Error::new(format!("Invalid past_key_values name: {name}")));
                }
                let layer: usize = parts[1]
                    .parse()
                    .map_err(|_| Error::new(format!("Invalid layer in {name}")))?;
                let is_key = parts[2] == "key";

                let shape = vec![1i64, cfg.num_kv_heads, kv_seq_len, cfg.head_dim];
                let numel = shape.iter().map(|d| *d as usize).product::<usize>();

                if kv_seq_len > 0 && !kv_cache.keys[layer].is_empty() {
                    let raw_data = if is_key {
                        kv_cache.keys[layer].clone()
                    } else {
                        kv_cache.values[layer].clone()
                    };
                    let elem_type = tensor_elem_type(dtype)?;
                    Some(match elem_type {
                        TensorElementType::Float16 => {
                            let f16_data: Vec<f16> =
                                raw_data.iter().map(|v| f16::from_f32(*v)).collect();
                            Tensor::from_array((shape, f16_data))?.into()
                        }
                        _ => Tensor::from_array((shape, raw_data))?.into(),
                    })
                } else {
                    let elem_type = tensor_elem_type(dtype)?;
                    Some(match elem_type {
                        TensorElementType::Float16 => {
                            Tensor::from_array((shape, vec![f16::from_f32(0.0); numel]))?.into()
                        }
                        _ => Tensor::from_array((shape, vec![0f32; numel]))?.into(),
                    })
                }
            }
            _ => None,
        };
        if let Some(value) = value {
            inputs_vec.push((std::borrow::Cow::Owned(name.clone()), value));
        }
    }

    Ok(inputs_vec)
}

fn extract_tensor_flexible(val: &ort::value::ValueRef) -> Result<(Vec<i64>, Vec<f32>), Error> {
    if let Ok((shape, data)) = val.try_extract_tensor::<f16>() {
        let f32_data: Vec<f32> = data.iter().map(|v| v.to_f32()).collect();
        return Ok((shape.to_vec(), f32_data));
    }
    let (shape, data) = val.try_extract_tensor::<f32>()?;
    Ok((shape.to_vec(), data.to_vec()))
}

fn extract_logits_and_kv<'a>(
    outputs: impl Iterator<Item = (&'a str, ort::value::ValueRef<'a>)>,
    kv_cache: &mut KvCache,
    cfg: &ModelConfig,
) -> Result<(Vec<f32>, usize), Error> {
    let collected: Vec<(&str, ort::value::ValueRef<'_>)> = outputs.collect();

    let mut seq_len = 0usize;

    for (name, val) in &collected {
        if *name == "logits" {
            continue;
        }
        let s = name.to_string();
        if s.starts_with("present.") {
            let (shape, data) = extract_tensor_flexible(val)?;
            if shape.len() >= 2 {
                let current_seq = shape[1] as usize;
                if current_seq > seq_len {
                    seq_len = current_seq;
                }
            }
            let parts: Vec<&str> = name.split('.').collect();
            if parts.len() >= 3 {
                if let Ok(layer) = parts[1].parse::<usize>() {
                    if layer < cfg.num_layers {
                        if parts[2] == "key" {
                            kv_cache.keys[layer] = data.to_vec();
                        } else if parts[2] == "value" {
                            kv_cache.values[layer] = data.to_vec();
                        }
                    }
                }
            }
        }
    }

    let logits_ref = collected
        .iter()
        .find(|(name, _)| *name == "logits")
        .ok_or_else(|| Error::new("No logits output"))?;

    let (shape, data) = logits_ref.1.try_extract_tensor::<f32>()?;
    let sequence_length = if shape.len() >= 2 {
        shape[1] as usize
    } else {
        data.len() / cfg.vocab_size as usize
    };

    Ok((data.to_vec(), sequence_length))
}

fn log_model_io(session: &Session) {
    let inputs = session
        .inputs()
        .iter()
        .map(|input| format!("{}: {}", input.name(), input.dtype()))
        .collect::<Vec<_>>()
        .join(", ");
    let outputs = session
        .outputs()
        .iter()
        .map(|output| format!("{}: {}", output.name(), output.dtype()))
        .collect::<Vec<_>>()
        .join(", ");
    println!("[LLM] inputs: {inputs}");
    println!("[LLM] outputs: {outputs}");
}

fn detect_fixed_seq_len(session: &Session) -> Option<i64> {
    for input in session.inputs() {
        if input.name() != "input_ids" {
            continue;
        }
        if let ValueType::Tensor { shape, .. } = input.dtype() {
            if shape.len() >= 2 {
                let seq_dim = shape[shape.len() - 1];
                if seq_dim == 1 {
                    eprintln!("[LLM] fixed seq_len=1 detected (prefill mode)");
                    return Some(1);
                }
            }
        }
        break;
    }
    None
}

fn tensor_elem_type(dtype: &ValueType) -> Result<TensorElementType, Error> {
    match dtype {
        ValueType::Tensor { ty, .. } => Ok(*ty),
        _ => Err(Error::new("Unsupported past_key_values dtype")),
    }
}
