"""ONNX adapter that wraps OnnxTtsRuntime to match the NanoTTSService interface.

Extracted from app_onnx.py so the unified app.py can import both runtimes.
"""

from __future__ import annotations

import logging
import os
import time
from pathlib import Path

import numpy as np

from onnx_tts_runtime import OnnxTtsRuntime, ensure_browser_onnx_model_dir
from ort_cpu_runtime import _normalize_execution_provider
from text_normalization_pipeline import WeTextProcessingManager


class _OnnxDeviceInfo:
    def __init__(self, execution_provider: str) -> None:
        self.type = "cuda" if _normalize_execution_provider(execution_provider) == "cuda" else "cpu"

    def __str__(self) -> str:
        return self.type


class OnnxNanoTTSServiceAdapter:
    """Wraps OnnxTtsRuntime so it quacks like NanoTTSService."""

    def __init__(
        self,
        *,
        model_dir: str | Path | None,
        output_dir: str | Path | None = None,
        cpu_threads: int = 4,
        execution_provider: str = "cpu",
        max_new_frames: int = 375,
        text_normalizer_manager: WeTextProcessingManager | None = None,
    ) -> None:
        self.output_dir = Path(output_dir or (Path.cwd() / "generated_audio")).expanduser().resolve()
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.runtime = OnnxTtsRuntime(
            model_dir=model_dir,
            thread_count=max(1, int(cpu_threads)),
            max_new_frames=int(max_new_frames),
            execution_provider=execution_provider,
            output_dir=self.output_dir,
        )
        self.model_dir = self.runtime.model_dir
        self.runtime._text_normalizer_manager = text_normalizer_manager
        self.execution_provider = self.runtime.execution_provider
        self.device = _OnnxDeviceInfo(self.execution_provider)
        self.dtype = "float32"
        self.attn_implementation = "fixed"
        self._onnxruntime_implementation = f"onnxruntime_{self.execution_provider}"
        self._checkpoint_global_attn_implementation = self._onnxruntime_implementation
        self._checkpoint_local_attn_implementation = self._onnxruntime_implementation
        self._configured_global_attn_implementation = self._onnxruntime_implementation
        self._configured_local_attn_implementation = self._onnxruntime_implementation
        self.checkpoint_path = self.runtime.tts_meta_path.parent.resolve()
        self.audio_tokenizer_path = self.runtime.codec_meta_path.parent.resolve()
        self.thread_count = max(1, int(cpu_threads))

    def get_model(self) -> "OnnxNanoTTSServiceAdapter":
        return self

    def warmup(self) -> dict[str, object]:
        voice_name = str(self.runtime.list_builtin_voices()[0]["voice"])
        return self.synthesize(
            text="Warmup.", mode="voice_clone", voice=voice_name,
            prompt_audio_path=None,
            max_new_frames=min(16, int(self.runtime.manifest["generation_defaults"]["max_new_frames"])),
            voice_clone_max_text_tokens=75,
            do_sample=True, text_temperature=1.0, text_top_p=1.0, text_top_k=50,
            audio_temperature=0.8, audio_top_p=0.95, audio_top_k=25,
            audio_repetition_penalty=1.2, seed=1234,
        )

    def split_voice_clone_text(self, *, text: str, voice_clone_max_text_tokens: int) -> list[str]:
        return self.runtime.split_voice_clone_text(str(text or ""), max_tokens=int(voice_clone_max_text_tokens))

    def _apply_generation_options(self, *, sample_mode, max_new_frames, do_sample,
                                   text_temperature, text_top_p, text_top_k,
                                   audio_temperature, audio_top_p, audio_top_k,
                                   audio_repetition_penalty, seed):
        resolved_sample_mode = self._resolve_sample_mode(sample_mode, do_sample=do_sample)
        gd = self.runtime.manifest["generation_defaults"]
        gd["max_new_frames"] = int(max_new_frames)
        gd["sample_mode"] = resolved_sample_mode
        gd["do_sample"] = resolved_sample_mode != "greedy"
        gd["text_temperature"] = float(text_temperature)
        gd["text_top_p"] = float(text_top_p)
        gd["text_top_k"] = int(text_top_k)
        gd["audio_temperature"] = float(audio_temperature)
        gd["audio_top_p"] = float(audio_top_p)
        gd["audio_top_k"] = int(audio_top_k)
        gd["audio_repetition_penalty"] = float(audio_repetition_penalty)
        if seed is not None:
            self.runtime.rng = np.random.default_rng(int(seed))

    @staticmethod
    def _resolve_sample_mode(raw_sample_mode: str | None, *, do_sample: bool) -> str:
        normalized = str(raw_sample_mode or "").strip().lower()
        if normalized in {"fixed", "full", "greedy"}:
            return normalized if do_sample else ("greedy" if normalized == "greedy" else "greedy")
        return "fixed" if bool(do_sample) else "greedy"

    def _format_result_payload(self, *, waveform, sample_rate, elapsed_seconds, audio_path,
                                voice, prompt_audio_path, text_chunks):
        return {
            "audio_path": audio_path,
            "waveform_numpy": np.asarray(waveform, dtype=np.float32),
            "sample_rate": int(sample_rate),
            "elapsed_seconds": float(elapsed_seconds),
            "mode": "voice_clone",
            "voice": str(voice or ""),
            "prompt_audio_path": str(prompt_audio_path or ""),
            "voice_clone_text_chunks": list(text_chunks),
            "effective_global_attn_implementation": self._onnxruntime_implementation,
            "effective_local_attn_implementation": self._onnxruntime_implementation,
            "voice_clone_chunk_batch_size": 1,
            "voice_clone_codec_batch_size": 1,
        }

    def synthesize(self, *, text, mode, voice, prompt_audio_path, max_new_frames,
                    voice_clone_max_text_tokens, tts_max_batch_size=0, codec_max_batch_size=0,
                    attn_implementation="model_default", do_sample=True,
                    text_temperature=1.0, text_top_p=1.0, text_top_k=50,
                    audio_temperature=0.8, audio_top_p=0.95, audio_top_k=25,
                    audio_repetition_penalty=1.2, seed=None, **kwargs):
        resolved_sample_mode = self._resolve_sample_mode(attn_implementation, do_sample=do_sample)
        self._apply_generation_options(
            sample_mode=resolved_sample_mode, max_new_frames=max_new_frames, do_sample=do_sample,
            text_temperature=text_temperature, text_top_p=text_top_p, text_top_k=text_top_k,
            audio_temperature=audio_temperature, audio_top_p=audio_top_p, audio_top_k=audio_top_k,
            audio_repetition_penalty=audio_repetition_penalty, seed=seed,
        )
        start_time = time.perf_counter()
        result = self.runtime.synthesize(
            text=str(text or ""), voice=voice, prompt_audio_path=prompt_audio_path,
            sample_mode=resolved_sample_mode, do_sample=resolved_sample_mode != "greedy",
            seed=seed,
        )
        elapsed = time.perf_counter() - start_time
        text_chunks = self.split_voice_clone_text(text=str(text or ""), voice_clone_max_text_tokens=int(voice_clone_max_text_tokens))
        return self._format_result_payload(
            waveform=result["waveform"], sample_rate=result.get("sample_rate", 48000),
            elapsed_seconds=elapsed, audio_path=result.get("audio_path", ""),
            voice=voice, prompt_audio_path=prompt_audio_path, text_chunks=text_chunks,
        )

    def synthesize_streaming(self, *, text, mode, voice, prompt_audio_path, max_new_frames,
                              voice_clone_max_text_tokens, tts_max_batch_size=0, codec_max_batch_size=0,
                              attn_implementation="model_default", do_sample=True,
                              text_temperature=1.0, text_top_p=1.0, text_top_k=50,
                              audio_temperature=0.8, audio_top_p=0.95, audio_top_k=25,
                              audio_repetition_penalty=1.2, seed=None):
        """Streaming is not implemented for ONNX — yield a single full result."""
        result = self.synthesize(
            text=text, mode=mode, voice=voice, prompt_audio_path=prompt_audio_path,
            max_new_frames=max_new_frames, voice_clone_max_text_tokens=voice_clone_max_text_tokens,
            do_sample=do_sample, text_temperature=text_temperature, text_top_p=text_top_p,
            text_top_k=text_top_k, audio_temperature=audio_temperature, audio_top_p=audio_top_p,
            audio_top_k=audio_top_k, audio_repetition_penalty=audio_repetition_penalty, seed=seed,
        )
        yield _make_stream_start_event(result, text, prompt_audio_path)
        yield _make_stream_audio_event(result)
        yield _make_stream_end_event(result)

    def __getattr__(self, name):
        """Fallback: return None for any missing property."""
        return None


# ── Streaming event helpers ──────────────────────────────────────────────


def _make_stream_start_event(result: dict, text: str, prompt_audio_path: str | None) -> dict:
    return {"type": "stream_start", "text_chunks": result.get("voice_clone_text_chunks", [text])}


def _make_stream_audio_event(result: dict) -> dict:
    import io
    import wave
    import numpy as np
    waveform = np.asarray(result["waveform_numpy"], dtype=np.float32)
    if waveform.ndim == 1:
        waveform = waveform[:, None]
    waveform = np.clip(waveform, -1.0, 1.0)
    audio_int16 = (waveform * 32767.0).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(int(waveform.shape[1]))
        wf.setsampwidth(2)
        wf.setframerate(int(result.get("sample_rate", 48000)))
        wf.writeframes(audio_int16.tobytes())
    pcm_data = audio_int16.tobytes()
    duration = len(audio_int16) / int(result.get("sample_rate", 48000)) / int(waveform.shape[1])
    return {
        "type": "audio_chunk",
        "audio_chunk_data": pcm_data,
        "chunk_element_index": 0,
        "chunk_total_count": 1,
        "sample_rate": int(result.get("sample_rate", 48000)),
        "channels": int(waveform.shape[1]),
        "chunk_start_seconds": 0.0,
        "chunk_end_seconds": duration,
        "is_first_chunk": True,
        "is_last_chunk_of_total": True,
        "prompt_audio_display_path": result.get("prompt_audio_path", ""),
    }


def _make_stream_end_event(result: dict) -> dict:
    return {
        "type": "audio_chunk",
        "audio_chunk_data": b"",
        "chunk_element_index": 1,
        "chunk_total_count": 1,
        "sample_rate": int(result.get("sample_rate", 48000)),
        "channels": 2,
        "chunk_start_seconds": 0.0,
        "chunk_end_seconds": 0.0,
        "is_first_chunk": False,
        "is_last_chunk_of_total": True,
        "audio_path": result.get("audio_path", ""),
        "prompt_audio_display_path": result.get("prompt_audio_path", ""),
    }
