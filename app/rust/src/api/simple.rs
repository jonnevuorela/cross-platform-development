use crate::frb_generated::StreamSink;
use half::f16;
use once_cell::sync::OnceCell;
use ort::{
    session::{builder::GraphOptimizationLevel, Session},
    value::{Tensor, TensorElementType, ValueType},
    Error,
};
use tokenizers::Tokenizer;

const NUM_LAYERS: usize = 36;
const NUM_KV_HEADS: i64 = 4;
const HEAD_DIM: i64 = 128;

struct KvCache {
    keys: Vec<Vec<f32>>,
    values: Vec<Vec<f32>>,
}

impl KvCache {
    fn new() -> Self {
        Self {
            keys: vec![vec![]; NUM_LAYERS],
            values: vec![vec![]; NUM_LAYERS],
        }
    }

    fn seq_len(&self) -> i64 {
        if self.keys[0].is_empty() {
            0
        } else {
            self.keys[0].len() as i64 / (NUM_KV_HEADS * HEAD_DIM)
        }
    }
}

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

pub fn init_model(model_path: String, tokenizer_path: String) -> Result<(), Error> {
    let result = (|| {
        let tokenizer = Tokenizer::from_file(tokenizer_path)
            .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;

        let session = Session::builder()?
            .with_optimization_level(GraphOptimizationLevel::Level3)?
            .with_intra_threads(4)?
            .commit_from_file(model_path)?;

        log_model_io(&session);

        let _ = TOKENIZER.set(tokenizer);
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

fn run_generate(prompt: &str, max_tokens: u32, sink: Option<&StreamSink<String>>) -> Result<Vec<String>, Error> {
    let tokenizer = TOKENIZER.get().ok_or_else(|| Error::new("Tokenizer not initialized"))?;

    let encoding = tokenizer
        .encode(prompt.to_string(), true)
        .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;
    let mut all_ids: Vec<i64> = encoding.get_ids().iter().map(|id| *id as i64).collect();
    if all_ids.is_empty() {
        return Ok(vec![]);
    }

    let mut kv_cache = KvCache::new();
    let mut output_tokens = Vec::new();
    let mut generated_tokens: std::collections::HashSet<i64> = std::collections::HashSet::new();
    let max_steps = max_tokens as usize;
    const REPETITION_PENALTY: f32 = 1.15;
    const TOP_K: usize = 40;

    for step in 0..max_steps {
        let (input_ids, past_seq_len) = if step == 0 {
            (all_ids.clone(), 0i64)
        } else {
            let last = vec![all_ids[all_ids.len() - 1]];
            (last, kv_cache.seq_len())
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
            let inputs = build_inputs(&input_specs, &input_ids, &kv_cache, kv_seq_len)?;
            let outputs = Session::run(session, inputs)?;
            let (data, new_len) = extract_logits_and_kv(outputs.iter(), &mut kv_cache)?;
            (data, new_len)
        };

        let seq_len_for_logits = if step == 0 {
            new_seq_len
        } else {
            new_seq_len
        };

        let vocab_size = 128256;
        let total_logits = seq_len_for_logits * vocab_size;
        if logits.len() < total_logits {
            break;
        }
        let start = (seq_len_for_logits - 1) * vocab_size;
        let slice = &logits[start..start + vocab_size];

        let mut logits_vec: Vec<(usize, f32)> = slice.iter().copied().enumerate().collect();
        let local_ids = &all_ids[all_ids.len().saturating_sub(50)..];
        for (idx, val) in logits_vec.iter_mut() {
            if local_ids.contains(&(*idx as i64)) {
                *val /= REPETITION_PENALTY;
            }
        }
        logits_vec.sort_unstable_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        for candidate in logits_vec.iter().take(TOP_K) {
            if !generated_tokens.contains(&(candidate.0 as i64)) {
                let token_id = candidate.0;
                generated_tokens.insert(token_id as i64);
                all_ids.push(token_id as i64);
                let piece = tokenizer
                    .decode(std::slice::from_ref(&(token_id as u32)), true)
                    .map_err(|e| Error::new(format!("Tokenizer error: {e}")))?;
                if let Some(s) = sink {
                    let _ = s.add(piece.clone());
                }
                output_tokens.push(piece);
                break;
            }
        }
    }

    Ok(output_tokens)
}

fn build_inputs(
    input_specs: &[(String, ValueType)],
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

                let shape = vec![1i64, NUM_KV_HEADS, kv_seq_len, HEAD_DIM];
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
                    if layer < NUM_LAYERS {
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
        data.len() / 128256
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
