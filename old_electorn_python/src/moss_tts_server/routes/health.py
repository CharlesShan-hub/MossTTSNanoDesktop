from __future__ import annotations

from fastapi import APIRouter

from moss_tts_server.routes import ServerState
from moss_tts_server.utils import _warmup_status_text, _text_normalization_status_text


def create_health_router(state: ServerState) -> APIRouter:
    router = APIRouter()

    @router.get("/health")
    async def health():
        return {
            "status": "ok",
            "device": str(state.runtime.device),
            "dtype": str(state.runtime.dtype),
            "cpu_runtime_loaded": state.runtime_manager.is_cpu_runtime_loaded(),
            "default_cpu_threads": state.runtime_manager.default_cpu_threads,
            "attn_implementation": state.runtime.attn_implementation or "model_default",
            "checkpoint_default_attn_implementation": state.runtime._checkpoint_global_attn_implementation or "unknown",
            "checkpoint_default_local_attn_implementation": state.runtime._checkpoint_local_attn_implementation or "unknown",
            "configured_attn_implementation": state.runtime._configured_global_attn_implementation or "unknown",
            "configured_local_attn_implementation": state.runtime._configured_local_attn_implementation or "unknown",
            "checkpoint_path": str(state.runtime.checkpoint_path),
            "audio_tokenizer_path": str(state.runtime.audio_tokenizer_path),
            "text_normalization_status": _text_normalization_status_text(
                state.text_normalizer_manager.snapshot() if state.text_normalizer_manager is not None else None
            ),
        }

    @router.get("/api/warmup-status")
    async def warmup_status():
        snapshot = state.warmup_manager.snapshot()
        return {
            "state": snapshot.state,
            "progress": snapshot.progress,
            "message": snapshot.message,
            "error": snapshot.error,
            "ready": snapshot.ready,
            "failed": snapshot.failed,
            "status_text": _warmup_status_text(snapshot),
        }

    @router.get("/api/text-normalization-status")
    async def text_normalization_status():
        snapshot = state.text_normalizer_manager.snapshot() if state.text_normalizer_manager is not None else None
        if snapshot is None:
            return {
                "state": "disabled",
                "message": "WeTextProcessing disabled.",
                "error": None, "ready": False, "failed": False, "available": False,
                "status_text": "WeTextProcessing disabled.",
            }
        return {
            "state": snapshot.state, "message": snapshot.message, "error": snapshot.error,
            "ready": snapshot.ready, "failed": snapshot.failed, "available": snapshot.available,
            "status_text": _text_normalization_status_text(snapshot),
        }

    return router
