from __future__ import annotations

import base64
import io
import logging
import wave
from pathlib import Path

import numpy as np

from moss_tts_server.models import WarmupSnapshot
from text_normalization_pipeline import TextNormalizationSnapshot as SharedTextNormalizationSnapshot


def _warmup_status_text(snapshot: WarmupSnapshot) -> str:
    progress_pct = int(round(snapshot.progress * 100.0))
    if snapshot.failed:
        return f"Warmup failed: {snapshot.error or snapshot.message}"
    if snapshot.ready:
        return snapshot.message
    return f"Warmup in progress ({progress_pct}%): {snapshot.message}"


def _text_normalization_status_text(snapshot: SharedTextNormalizationSnapshot | None) -> str:
    if snapshot is None:
        return "WeTextProcessing disabled."
    if snapshot.failed:
        return f"WeTextProcessing failed: {snapshot.error or snapshot.message}"
    if snapshot.ready:
        return "WeTextProcessing ready."
    return snapshot.message


def _format_run_status(result: dict[str, object]) -> str:
    waveform_numpy = np.asarray(result["waveform_numpy"])
    sample_count = int(waveform_numpy.shape[0]) if waveform_numpy.ndim >= 1 else 0
    sample_rate = int(result["sample_rate"])
    audio_seconds = sample_count / sample_rate if sample_rate > 0 else 0.0
    global_attn = str(result.get("effective_global_attn_implementation", "unknown"))
    local_attn = str(result.get("effective_local_attn_implementation", global_attn))
    attn_summary = global_attn if global_attn == local_attn else f"{global_attn}/{local_attn}"
    tts_batch_size = result.get("voice_clone_chunk_batch_size")
    codec_batch_size = result.get("voice_clone_codec_batch_size")
    batch_summary = ""
    if tts_batch_size is not None or codec_batch_size is not None:
        batch_summary = f" | tts_batch={int(tts_batch_size or 1)} | codec_batch={int(codec_batch_size or 1)}"
    execution_summary = ""
    execution_device = result.get("execution_device")
    cpu_threads = result.get("cpu_threads")
    if execution_device:
        execution_summary = f" | exec={execution_device}"
        if cpu_threads is not None:
            execution_summary += f" | cpu_threads={int(cpu_threads)}"
    prompt_audio_display_path = str(result.get("prompt_audio_display_path") or "").strip()
    prompt_audio_path = str(result.get("prompt_audio_path") or "").strip()
    speaker_summary = f"voice={result['voice']}"
    if prompt_audio_display_path:
        if prompt_audio_display_path.lower().startswith("uploaded:"):
            speaker_summary = f"prompt={prompt_audio_display_path.split(':', 1)[1].strip()}"
        else:
            speaker_summary = f"prompt={Path(prompt_audio_display_path).stem}"
    elif prompt_audio_path:
        speaker_summary = f"prompt={Path(prompt_audio_path).stem}"
    return (
        f"Done | mode={result['mode']} | {speaker_summary} | "
        f"attn={attn_summary}{batch_summary}{execution_summary} | audio={audio_seconds:.2f}s | elapsed={float(result['elapsed_seconds']):.2f}s"
    )


def _format_stream_status(snapshot: dict[str, object]) -> str:
    if bool(snapshot.get("failed")):
        return f"Stream failed: {snapshot.get('error') or snapshot.get('run_status') or 'Unknown error'}"
    if bool(snapshot.get("ready")):
        return str(snapshot.get("run_status") or "Stream complete.")
    if bool(snapshot.get("closed")):
        return "Stream closed."
    return str(snapshot.get("run_status") or "Streaming...")


def _normalize_stream_chunk_index(
    raw_chunk_index: object,
    *,
    chunk_count: int,
    current_base: int | None,
) -> tuple[int | None, int | None]:
    try:
        numeric_chunk_index = int(raw_chunk_index)
    except Exception:
        return None, current_base
    if chunk_count <= 0:
        return max(0, numeric_chunk_index), current_base
    normalized_base = current_base
    if normalized_base is None:
        if numeric_chunk_index == 0: normalized_base = 0
        elif numeric_chunk_index == chunk_count: normalized_base = 1
        elif numeric_chunk_index == 1: normalized_base = 1
        else: normalized_base = 0
    normalized_chunk_index = numeric_chunk_index - normalized_base
    if 0 <= normalized_chunk_index < chunk_count:
        return normalized_chunk_index, normalized_base
    if 0 <= numeric_chunk_index < chunk_count:
        return numeric_chunk_index, 0
    if 1 <= numeric_chunk_index <= chunk_count:
        return numeric_chunk_index - 1, 1
    return None, normalized_base


def _audio_to_wav_bytes(audio_array, sample_rate: int) -> bytes:
    audio_np = np.asarray(audio_array, dtype=np.float32)
    if audio_np.ndim == 1:
        audio_np = audio_np[:, None]
    elif audio_np.ndim == 2 and audio_np.shape[0] <= 8 and audio_np.shape[0] < audio_np.shape[1]:
        audio_np = audio_np.T
    elif audio_np.ndim != 2:
        raise ValueError(f"Unsupported audio array shape: {audio_np.shape}")
    audio_np = np.clip(audio_np, -1.0, 1.0)
    audio_int16 = (audio_np * 32767.0).astype(np.int16)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(int(audio_int16.shape[1]))
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_int16.tobytes())
    buffer.seek(0)
    return buffer.read()


def _audio_to_pcm16le_bytes(audio_array) -> bytes:
    audio_np = np.asarray(audio_array, dtype=np.float32)
    if audio_np.ndim == 1:
        audio_np = audio_np[:, None]
    elif audio_np.ndim == 2 and audio_np.shape[0] <= 8 and audio_np.shape[0] < audio_np.shape[1]:
        audio_np = audio_np.T
    elif audio_np.ndim != 2:
        raise ValueError(f"Unsupported audio array shape: {audio_np.shape}")
    audio_np = np.clip(audio_np, -1.0, 1.0)
    audio_int16 = (audio_np * 32767.0).astype(np.int16)
    return audio_int16.tobytes()


def _read_audio_file_base64(path_value: str | None) -> str:
    path_text = str(path_value or "").strip()
    if not path_text:
        return ""
    path = Path(path_text)
    if not path.is_file():
        return ""
    try:
        return base64.b64encode(path.read_bytes()).decode("ascii")
    except Exception:
        logging.warning("failed to read audio file for base64 response: %s", path, exc_info=True)
        return ""


def _maybe_delete_file(path_value: str | None) -> None:
    if not path_value:
        return
    try:
        Path(path_value).unlink(missing_ok=True)
    except Exception:
        logging.warning("failed to remove temporary file: %s", path_value, exc_info=True)


def _coerce_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "yes", "y", "on"}:
        return True
    if normalized in {"0", "false", "no", "n", "off"}:
        return False
    return default


def _sanitize_uploaded_prompt_filename(filename: str | None) -> str:
    base_name = Path(str(filename or "")).name.strip()
    if not base_name:
        return "prompt_speech.wav"
    return base_name


def _format_uploaded_prompt_display_name(filename: str | None) -> str:
    return f"Uploaded: {_sanitize_uploaded_prompt_filename(filename)}"


def _stream_metrics_text(snapshot: dict[str, object]) -> str:
    parts: list[str] = []
    first_audio = snapshot.get("first_audio_latency_seconds")
    if first_audio is not None:
        parts.append(f"first_audio={first_audio:.2f}s")
    emitted_seconds = snapshot.get("emitted_audio_seconds")
    if emitted_seconds is not None:
        parts.append(f"audio={emitted_seconds:.2f}s")
    return " | ".join(parts) if parts else ""
