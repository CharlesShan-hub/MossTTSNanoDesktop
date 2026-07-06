from __future__ import annotations

import logging
import queue
import threading
import time
from pathlib import Path

from fastapi import APIRouter, File, Form, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse

from moss_tts_server.defaults import APP_DIR
from moss_tts_server.models import StreamingJob
from moss_tts_server.routes import ServerState, resolve_prompt_audio_request
from moss_tts_server.utils import (
    _warmup_status_text, _format_run_status, _format_stream_status,
    _normalize_stream_chunk_index, _maybe_delete_file, _coerce_bool,
    _read_audio_file_base64, _stream_metrics_text, _text_normalization_status_text,
)
from text_normalization_pipeline import prepare_tts_request_texts as shared_prepare_tts_request_texts
from moss_tts_nano_runtime import NanoTTSService


def _resolve_attn_for_runtime(selected_runtime: NanoTTSService, requested: str) -> str | None:
    normalized = str(requested or "").strip().lower()
    if normalized in {"model_default", "auto", ""}:
        return None
    return normalized


def _resolve_voice_clone_text_chunks(
    runtime_manager, text: str, voice_clone_max_text_tokens: int, cpu_threads: int = 0,
) -> list[str]:
    try:
        chunks = runtime_manager.call_with_runtime(
            requested_execution_device="cpu",
            cpu_threads=cpu_threads,
            callback=lambda selected_runtime: selected_runtime.split_voice_clone_text(
                text=text, voice_clone_max_text_tokens=int(voice_clone_max_text_tokens),
            ),
        )
    except Exception:
        logging.warning("failed to resolve playback text chunks", exc_info=True)
        return [text]
    normalized_chunks = [str(chunk).strip() for chunk in chunks if str(chunk).strip()]
    return normalized_chunks or [text]


def _run_streaming_job(
    *,
    job: StreamingJob,
    text: str,
    prompt_audio_path: str | None,
    prompt_audio_display_path: str | None,
    prompt_audio_cleanup_path: str | None,
    max_new_frames: int,
    voice_clone_max_text_tokens: int,
    tts_max_batch_size: int,
    codec_max_batch_size: int,
    cpu_threads: int,
    attn_implementation: str,
    do_sample: bool,
    text_temperature: float,
    text_top_p: float,
    text_top_k: int,
    audio_temperature: float,
    audio_top_p: float,
    audio_top_k: int,
    audio_repetition_penalty: float,
    seed: int | None,
    runtime_manager,
):
    try:
        def _stream_synthesize(selected_runtime: NanoTTSService):
            return selected_runtime.synthesize_streaming(
                text=str(text), mode="voice_clone", voice=None,
                prompt_audio_path=prompt_audio_path,
                max_new_frames=int(max_new_frames),
                voice_clone_max_text_tokens=int(voice_clone_max_text_tokens),
                tts_max_batch_size=int(tts_max_batch_size),
                codec_max_batch_size=int(codec_max_batch_size),
                attn_implementation=_resolve_attn_for_runtime(selected_runtime, attn_implementation),
                do_sample=do_sample,
                text_temperature=float(text_temperature),
                text_top_p=float(text_top_p),
                text_top_k=int(text_top_k),
                audio_temperature=float(audio_temperature),
                audio_top_p=float(audio_top_p),
                audio_top_k=int(audio_top_k),
                audio_repetition_penalty=float(audio_repetition_penalty),
                seed=seed,
            )

        initial_sample_rate = 48000
        initial_channels = 2
        with job.lock:
            job.started_at = time.monotonic()
            job.sample_rate = initial_sample_rate
            job.channels = initial_channels

        for event, resolved_execution_device, resolved_cpu_threads in runtime_manager.iter_with_runtime(
            requested_execution_device="cpu", cpu_threads=cpu_threads, factory=_stream_synthesize,
        ):
            if event.get("type") == "audio_chunk":
                audio_chunk_data = event.get("audio_chunk_data")
                chunk_element_index = event.get("chunk_element_index", 0)
                chunk_total_count = event.get("chunk_total_count", 1)
                sample_rate = event.get("sample_rate", initial_sample_rate)
                channels = event.get("channels", initial_channels)
                chunk_start_seconds = event.get("chunk_start_seconds", 0.0)
                chunk_end_seconds = event.get("chunk_end_seconds", 0.0)
                is_first_chunk = event.get("is_first_chunk", False)
                is_last_chunk_of_total = event.get("is_last_chunk_of_total", False)
                resolved_pad = str(event.get("prompt_audio_display_path") or prompt_audio_display_path or "")
                if is_first_chunk:
                    with job.lock:
                        job.first_audio_at = time.monotonic()
                        if resolved_pad:
                            job.prompt_audio_path = resolved_pad
                job.audio_queue.put(audio_chunk_data)
                range_chunk_index, new_base = _normalize_stream_chunk_index(
                    chunk_element_index, chunk_count=chunk_total_count, current_base=job.chunk_index_base,
                )
                with job.lock:
                    if new_base is not None: job.chunk_index_base = new_base
                    if range_chunk_index is not None:
                        job.current_chunk_index = range_chunk_index
                        job.audio_chunk_ranges.append((chunk_start_seconds, chunk_end_seconds, range_chunk_index))
                    job.emitted_audio_seconds = chunk_end_seconds
                    job.lead_seconds = chunk_end_seconds - chunk_start_seconds
                    job.sample_rate = sample_rate
                    job.channels = channels
                if is_last_chunk_of_total:
                    formatted = dict(event)
                    formatted["execution_device"] = resolved_execution_device
                    formatted["prompt_audio_display_path"] = resolved_pad
                    if resolved_cpu_threads is not None: formatted["cpu_threads"] = resolved_cpu_threads
                    run_status = _format_run_status(formatted)
                    with job.lock:
                        job.final_result = {
                            "audio_path": event.get("audio_path"),
                            "prompt_audio_path": prompt_audio_display_path,
                            "run_status": run_status,
                            "text_chunks": list(job.text_chunks),
                        }
                        job.prompt_audio_path = prompt_audio_display_path
                        job.state = "done"
                        job.completed_at = time.monotonic()
                        job.run_status = run_status
    except Exception as exc:
        logging.exception("Nano-TTS realtime streaming job failed")
        with job.lock:
            job.state = "failed"
            job.error = str(exc)
            job.completed_at = time.monotonic()
            job.run_status = f"Stream failed: {exc}"
    finally:
        _maybe_delete_file(prompt_audio_cleanup_path)
        try:
            job.audio_queue.put_nowait(None)
        except queue.Full:
            pass


def create_streaming_router(state: ServerState) -> APIRouter:
    router = APIRouter()

    @router.post("/api/generate-stream/start")
    async def generate_stream_start(
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
        vn = str(voice_name or "").strip()
        if vn:
            vi = state.voices_manifest.get(vn)
            if vi is None:
                return JSONResponse(status_code=400, content={"error": f"Unknown voice_name: {vn}"})
            prompt_audio_path = str((APP_DIR / vi["file"]).resolve())
            prompt_audio_display_path = vi["file"]
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
        ws = state.warmup_manager.snapshot()
        if not ws.ready:
            ws = state.warmup_manager.ensure_ready()
            if not ws.ready:
                _maybe_delete_file(prompt_audio_cleanup_path)
                return JSONResponse(status_code=500, content={"error": _warmup_status_text(ws)})

        try:
            normalized_seed = None if seed in {"", "0"} else int(seed)
            text_chunks = _resolve_voice_clone_text_chunks(
                state.runtime_manager, str(prepared_texts["text"]),
                int(voice_clone_max_text_tokens), int(cpu_threads),
            )
            job = state.stream_jobs.create()
            with job.lock:
                job.prompt_audio_path = prompt_audio_display_path
                job.text_chunks = list(text_chunks)
            t = threading.Thread(target=_run_streaming_job, kwargs={
                "job": job, "text": str(prepared_texts["text"]),
                "prompt_audio_path": prompt_audio_path,
                "prompt_audio_display_path": prompt_audio_display_path,
                "prompt_audio_cleanup_path": prompt_audio_cleanup_path,
                "max_new_frames": int(max_new_frames),
                "voice_clone_max_text_tokens": int(voice_clone_max_text_tokens),
                "tts_max_batch_size": int(tts_max_batch_size),
                "codec_max_batch_size": int(codec_max_batch_size),
                "cpu_threads": int(cpu_threads),
                "attn_implementation": attn_implementation,
                "do_sample": _coerce_bool(do_sample, True),
                "text_temperature": float(text_temperature),
                "text_top_p": float(text_top_p),
                "text_top_k": int(text_top_k),
                "audio_temperature": float(audio_temperature),
                "audio_top_p": float(audio_top_p),
                "audio_top_k": int(audio_top_k),
                "audio_repetition_penalty": float(audio_repetition_penalty),
                "seed": normalized_seed,
                "runtime_manager": state.runtime_manager,
            }, name=f"nano-tts-stream-{job.stream_id}", daemon=True)
            t.start()
            prompt_audio_cleanup_path = None
            return {
                "stream_id": job.stream_id,
                "audio_url": f"{state.app.root_path}/api/generate-stream/{job.stream_id}/audio",
                "status_url": f"{state.app.root_path}/api/generate-stream/{job.stream_id}/status",
                "result_url": f"{state.app.root_path}/api/generate-stream/{job.stream_id}/result",
                "sample_rate": job.sample_rate, "channels": job.channels,
                "run_status": "Streaming realtime audio... exec=cpu",
                "prompt_audio_path": prompt_audio_display_path,
                "warmup_status_text": _warmup_status_text(state.warmup_manager.snapshot()),
                "text_normalization_status_text": _text_normalization_status_text(
                    state.text_normalizer_manager.snapshot() if state.text_normalizer_manager is not None else None
                ),
                "text_chunks": text_chunks,
                "normalized_text": str(prepared_texts["normalized_text"]),
                "normalization_method": str(prepared_texts["normalization_method"]),
                "text_normalization_language": str(prepared_texts["text_normalization_language"]),
            }
        except Exception:
            _maybe_delete_file(prompt_audio_cleanup_path)
            raise

    @router.get("/api/generate-stream/{stream_id}/status")
    async def generate_stream_status(stream_id: str):
        job = state.stream_jobs.get(stream_id)
        if job is None:
            return JSONResponse(status_code=404, content={"error": "stream not found"})
        snapshot = job.snapshot()
        snapshot["status_text"] = _format_stream_status(snapshot)
        snapshot["stream_metrics"] = _stream_metrics_text(snapshot)
        return snapshot

    @router.get("/api/generate-stream/{stream_id}/audio")
    async def generate_stream_audio(stream_id: str):
        job = state.stream_jobs.get(stream_id)
        if job is None:
            return JSONResponse(status_code=404, content={"error": "stream not found"})

        async def audio_stream():
            try:
                while True:
                    chunk = await job.audio_queue.get()
                    if chunk is None:
                        break
                    yield chunk
            except GeneratorExit:
                pass

        return StreamingResponse(
            audio_stream(), media_type="audio/L16",
            headers={
                "X-Audio-Sample-Rate": str(job.sample_rate),
                "X-Audio-Channels": str(job.channels),
                "Cache-Control": "no-cache",
            },
        )

    @router.get("/api/generate-stream/{stream_id}/result")
    async def generate_stream_result(stream_id: str):
        job = state.stream_jobs.get(stream_id)
        if job is None:
            return JSONResponse(status_code=404, content={"error": "stream not found"})
        snapshot = job.snapshot()
        if snapshot["failed"]:
            return JSONResponse(status_code=500, content={"error": snapshot["error"], **snapshot})
        if not snapshot["ready"] or job.final_result is None:
            return JSONResponse(status_code=202, content=snapshot)

        result = dict(job.final_result)
        audio_chunk_ranges = []
        with job.lock:
            audio_chunk_ranges = [
                [float(s), float(e), int(ci)] for s, e, ci in job.audio_chunk_ranges
            ]
        audio_b64 = str(result.get("audio_base64") or "")
        audio_path = str(result.get("audio_path") or "").strip()
        if not audio_b64 and audio_path:
            audio_b64 = _read_audio_file_base64(audio_path)
            if audio_b64:
                with job.lock:
                    if job.final_result is not None:
                        job.final_result["audio_base64"] = audio_b64
                        job.final_result["audio_path"] = ""
                _maybe_delete_file(audio_path)

        return {
            "stream_id": stream_id, "ready": True, "state": snapshot["state"],
            "prompt_audio_path": result.get("prompt_audio_path") or snapshot.get("prompt_audio_path") or "",
            "run_status": result.get("run_status") or snapshot["run_status"],
            "stream_metrics": _stream_metrics_text(snapshot),
            "warmup_status_text": _warmup_status_text(state.warmup_manager.snapshot()),
            "text_chunks": result.get("text_chunks") or snapshot.get("text_chunks") or [],
            "audio_chunk_ranges": audio_chunk_ranges,
            "audio_base64": audio_b64,
        }

    @router.post("/api/generate-stream/{stream_id}/close")
    async def generate_stream_close(stream_id: str):
        job = state.stream_jobs.close(stream_id)
        if job is None:
            return JSONResponse(status_code=404, content={"error": "stream not found"})
        audio_cleanup_path = ""
        with job.lock:
            if job.final_result is not None:
                audio_cleanup_path = str(job.final_result.get("audio_path") or "").strip()
        snapshot = job.snapshot()
        snapshot["status_text"] = _format_stream_status(snapshot)
        state.stream_jobs.delete(stream_id)
        _maybe_delete_file(audio_cleanup_path)
        return snapshot

    return router
