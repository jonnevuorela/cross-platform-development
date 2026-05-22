use crate::frb_generated::StreamSink;
use half::f16;
use once_cell::sync::OnceCell;
use ort::{
    session::{builder::GraphOptimizationLevel, Session},
    value::{Tensor, TensorElementType, ValueType},
    Error,
};
use tokenizers::Tokenizer;

struct ModelConfig {
    num_layers: usize,
    num_kv_heads: i64,
    head_dim: i64,
    vocab_size: i64,
    eos_token_id: i64,
    im_start_id: i64,
    im_end_id: i64,
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

const REPETITION_PENALTY: f32 = 1.15;

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

static SESSION: std::sync::Mutex<Option<Session>> = std::sync::Mutex::new(None);
static TOKENIZER: OnceCell<Tokenizer> = OnceCell::new();
static CONFIG: OnceCell<ModelConfig> = OnceCell::new();

pub fn init_model(
    model_path: String,
    tokenizer_path: String,
    num_layers: i64,
    num_kv_heads: i64,
    head_dim: i64,
    vocab_size: i64,
    eos_token_id: i64,
    im_start_id: i64,
    im_end_id: i64,
) -> Result<(), Error> {
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

        let cfg = ModelConfig {
            num_layers: num_layers as usize,
            num_kv_heads,
            head_dim,
            vocab_size,
            eos_token_id,
            im_start_id,
            im_end_id,
        };

        let _ = TOKENIZER.set(tokenizer);
        let _ = CONFIG.set(cfg);
        *SESSION.lock().map_err(|e| Error::new(format!("Session lock: {e}")))? = Some(session);
        Ok(())
    })();

    if let Err(ref err) = result {
        eprintln!("[LLM] init_model error: {err}");
    }

    result
}

pub fn generate(prompt: String, max_tokens: u32) -> Result<Vec<String>, Error> {
    match run_generate(&prompt, max_tokens, None) {
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
    stream: StreamSink<String>,
) -> Result<(), Error> {
    match run_generate(&prompt, max_tokens, Some(&stream)) {
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

fn run_generate(prompt: &str, max_tokens: u32, sink: Option<&StreamSink<String>>) -> Result<Vec<String>, Error> {
    let tokenizer = TOKENIZER.get().ok_or_else(|| Error::new("Tokenizer not initialized"))?;
    let cfg = CONFIG.get().ok_or_else(|| Error::new("Config not initialized"))?;
    let newline_ids = encode_text(tokenizer, "\n")?;

    let system_prompt = "You are a helpful assistant. Answer concisely and stop when done.";
    let user_message = prompt.trim();

    if user_message.is_empty() {
        return Ok(vec![]);
    }

    let mut all_ids = Vec::new();

    all_ids.push(cfg.im_start_id);
    all_ids.extend(&encode_text(tokenizer, "system")?);
    all_ids.extend(&newline_ids);
    all_ids.extend(&encode_text(tokenizer, system_prompt)?);
    all_ids.push(cfg.im_end_id);
    all_ids.extend(&newline_ids);

    all_ids.push(cfg.im_start_id);
    all_ids.extend(&encode_text(tokenizer, "user")?);
    all_ids.extend(&newline_ids);
    all_ids.extend(&encode_text(tokenizer, user_message)?);
    all_ids.push(cfg.im_end_id);
    all_ids.extend(&newline_ids);

    all_ids.push(cfg.im_start_id);
    all_ids.extend(&encode_text(tokenizer, "assistant")?);
    all_ids.extend(&newline_ids);

    let mut kv_cache = KvCache::new(cfg.num_layers);
    let mut output_tokens = Vec::new();
    let max_steps = max_tokens as usize;

    let mut prefix_buf = String::new();
    let mut prefix_resolved = false;

    for step in 0..max_steps {
        let (input_ids, past_seq_len) = if step == 0 {
            (all_ids.clone(), 0i64)
        } else {
            let last = vec![all_ids[all_ids.len() - 1]];
            (last, kv_cache.seq_len(cfg))
        };

        let kv_seq_len = past_seq_len.max(1);

        let (logits, new_seq_len): (Vec<f32>, usize) = {
            let mut session_guard = SESSION
                .lock()
                .map_err(|_| Error::new("Session lock poisoned"))?;
            let session = session_guard
                .as_mut()
                .ok_or_else(|| Error::new("Model not initialized"))?;
            let input_specs: Vec<(String, ValueType)> = session
                .inputs()
                .iter()
                .map(|input| (input.name().to_string(), input.dtype().clone()))
                .collect();
            let inputs = build_inputs(&input_specs, cfg, &input_ids, &kv_cache, kv_seq_len)?;
            let outputs = Session::run(session, inputs)?;
            let (data, new_len) = extract_logits_and_kv(outputs.iter(), &mut kv_cache, cfg)?;
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

        let mut logits_vec: Vec<(usize, f32)> = slice.iter().copied().enumerate().collect();
        let local_ids = &all_ids[all_ids.len().saturating_sub(50)..];
        for (idx, val) in logits_vec.iter_mut() {
            if *idx as i64 >= cfg.vocab_size {
                continue;
            }
            if local_ids.contains(&(*idx as i64)) {
                *val /= REPETITION_PENALTY;
            }
        }
        logits_vec.sort_unstable_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        let token_id = logits_vec[0].0;
        if token_id as i64 == cfg.im_end_id || token_id as i64 == cfg.eos_token_id {
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

fn tensor_elem_type(dtype: &ValueType) -> Result<TensorElementType, Error> {
    match dtype {
        ValueType::Tensor { ty, .. } => Ok(*ty),
        _ => Err(Error::new("Unsupported past_key_values dtype")),
    }
}
