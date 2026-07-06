from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, File, Form, UploadFile
from fastapi.responses import JSONResponse

from moss_tts_server.defaults import APP_DIR
from moss_tts_server.routes import ServerState, resolve_prompt_audio_request
from moss_tts_server.utils import (
    _warmup_status_text, _format_run_status, _maybe_delete_file,
    _coerce_bool, _read_audio_file_base64, _text_normalization_status_text,
)
from text_normalization_pipeline import prepare_tts_request_texts as shared_prepare_tts_request_texts
from moss_tts_nano_runtime import NanoTTSService


def _resolve_attn_for_runtime(selected_runtime: NanoTTSService, requested: str) -> str | None:
    normalized = str(requested or "").strip().lower()
    if normalized in {"model_default", "auto", ""}:
        return None
    return normalized


def create_generate_router(state: ServerState) -> APIRouter:
    router = APIRouter()

    @router.post("/api/generate")
    async def generate(
        text: str = Form(...),
        voice_name: str = Form(""),
        demo_id: str = Form(""),
        prompt_audio: UploadFile | None = File(None),
        max_new_frames: int = Form(375),
        voice_clone_max_text_tokens: int = Form(75),
        tts_max_batch_size: int = Form(0),
        codec_max_batch_size: int = Form(0),
        enable_text_normalization: str = Form("1"),
        enable_normalize_tts_text: str = Form("1"),
        cpu_threads: int = Form(0),
        attn_implementation: str = Form("model_default"),
        do_sample: str = Form("1"),
        text_temperature: float = Form(1.0),
        text_top_p: float = Form(1.0),
        text_top_k: int = Form(50),
        audio_temperature: float = Form(0.8),
        audio_top_p: float = Form(0.95),
        audio_top_k: int = Form(25),
        audio_repetition_penalty: float = Form(1.2),
        seed: str = Form("0"),
    ):
        voice_name = str(voice_name or "").strip()
        if voice_name:
            voice_info = state.voices_manifest.get(voice_name)
            if voice_info is None:
                return JSONResponse(status_code=400, content={"error": f"Unknown voice_name: {voice_name}. Use GET /api/voices to list available voices."})
            prompt_audio_path = str((APP_DIR / voice_info["file"]).resolve())
            prompt_audio_display_path = voice_info["file"]
            prompt_audio_cleanup_path = None
            demo_entry = None
        else:
            try:
                demo_entry, prompt_audio_path, prompt_audio_display_path, prompt_audio_cleanup_path = (
                    await resolve_prompt_audio_request(state.demo_entries_by_id, demo_id, prompt_audio)
                )
            except ValueError as exc:
                return JSONResponse(status_code=400, content={"error": str(exc)})

        resolved_text = str(text or "").strip() or (demo_entry.text if demo_entry is not None else "")
        if not resolved_text:
            _maybe_delete_file(prompt_audio_cleanup_path)
            return JSONResponse(status_code=400, content={"error": "text is required."})

        try:
            prepared_texts = shared_prepare_tts_request_texts(
                text=resolved_text,
                enable_wetext=_coerce_bool(enable_text_normalization, False),
                enable_normalize_tts_text=_coerce_bool(enable_normalize_tts_text, True),
                text_normalizer_manager=state.text_normalizer_manager,
            )
        except Exception:
            _maybe_delete_file(prompt_audio_cleanup_path)
            raise

        warmup_snapshot = state.warmup_manager.snapshot()
        if not warmup_snapshot.ready:
            warmup_snapshot = state.warmup_manager.ensure_ready()
            if not warmup_snapshot.ready:
                _maybe_delete_file(prompt_audio_cleanup_path)
                return JSONResponse(status_code=500, content={"error": _warmup_status_text(warmup_snapshot)})

        generated_audio_path: str | None = None
        try:
            normalized_seed = None if seed in {"", "0"} else int(seed)

            def _synthesize(selected_runtime: NanoTTSService):
                return selected_runtime.synthesize(
                    text=str(prepared_texts["text"]),
                    mode="voice_clone", voice=None,
                    prompt_audio_path=prompt_audio_path,
                    max_new_frames=int(max_new_frames),
                    voice_clone_max_text_tokens=int(voice_clone_max_text_tokens),
                    tts_max_batch_size=int(tts_max_batch_size),
                    codec_max_batch_size=int(codec_max_batch_size),
                    attn_implementation=_resolve_attn_for_runtime(selected_runtime, attn_implementation),
                    do_sample=_coerce_bool(do_sample, True),
                    text_temperature=float(text_temperature),
                    text_top_p=float(text_top_p),
                    text_top_k=int(text_top_k),
                    audio_temperature=float(audio_temperature),
                    audio_top_p=float(audio_top_p),
                    audio_top_k=int(audio_top_k),
                    audio_repetition_penalty=float(audio_repetition_penalty),
                    seed=normalized_seed,
                )

            result, resolved_execution_device, resolved_cpu_threads = state.runtime_manager.call_with_runtime(
                requested_execution_device="cpu", cpu_threads=cpu_threads, callback=_synthesize,
            )
            result["execution_device"] = resolved_execution_device
            result["prompt_audio_display_path"] = prompt_audio_display_path
            if resolved_cpu_threads is not None:
                result["cpu_threads"] = resolved_cpu_threads

            audio_base64_payload: str = str(result.get("audio_base64") or "")
            audio_path_for_response = str(result.get("audio_path") or "").strip()
            if not audio_base64_payload and audio_path_for_response:
                audio_base64_payload = _read_audio_file_base64(audio_path_for_response)
                if audio_base64_payload:
                    result["audio_base64"] = audio_base64_payload
                    result["audio_path"] = ""
                    generated_audio_path = audio_path_for_response

            return {
                "audio_base64": audio_base64_payload,
                "sample_rate": int(result["sample_rate"]),
                "text_chunks": result.get("text_chunks") or [],
                "run_status": _format_run_status(result),
                "prompt_audio_path": prompt_audio_display_path,
                "warmup_status_text": _warmup_status_text(state.warmup_manager.snapshot()),
                "text_normalization_status_text": _text_normalization_status_text(
                    state.text_normalizer_manager.snapshot() if state.text_normalizer_manager is not None else None
                ),
                "normalized_text": str(prepared_texts["normalized_text"]),
                "normalization_method": str(prepared_texts["normalization_method"]),
                "text_normalization_language": str(prepared_texts["text_normalization_language"]),
            }
        except Exception:
            _maybe_delete_file(prompt_audio_cleanup_path)
            raise
        finally:
            _maybe_delete_file(generated_audio_path)

    return router
