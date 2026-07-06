from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path
from typing import Optional, Sequence

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from moss_tts_nano_runtime import DEFAULT_AUDIO_TOKENIZER_PATH, DEFAULT_CHECKPOINT_PATH, DEFAULT_OUTPUT_DIR, NanoTTSService
from text_normalization_pipeline import WeTextProcessingManager as SharedWeTextProcessingManager

from moss_tts_server.managers import WarmupManager, RequestRuntimeManager
from moss_tts_server.html_templates import render_index_html, render_index_html_onnx
from moss_tts_server.utils import _warmup_status_text, _text_normalization_status_text
from moss_tts_server.routes import ServerState, load_demo_entries, load_voices_manifest, resolve_vscode_root_path
from moss_tts_server.routes.health import create_health_router
from moss_tts_server.routes.voices import create_voices_router
from moss_tts_server.routes.generate import create_generate_router
from moss_tts_server.routes.streaming import create_streaming_router


_OVERRIDE_RENDER_HTML = None  # set by app_onnx monkey-patch (legacy compat)


def _build_app(
    runtime,
    warmup_manager: WarmupManager,
    text_normalizer_manager: SharedWeTextProcessingManager | None,
    root_path: str | None,
) -> FastAPI:
    app = FastAPI(title="MOSS-TTS-Nano Demo", root_path=root_path or "")
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

    demo_entries = load_demo_entries()
    demo_entries_by_id = {e.demo_id: e for e in demo_entries}
    voices_manifest = load_voices_manifest()

    from moss_tts_server.models import StreamingJobManager
    runtime_manager = RequestRuntimeManager(runtime)
    stream_jobs = StreamingJobManager()

    state = ServerState(
        app=app, runtime=runtime, runtime_manager=runtime_manager,
        warmup_manager=warmup_manager, text_normalizer_manager=text_normalizer_manager,
        stream_jobs=stream_jobs, demo_entries=demo_entries,
        demo_entries_by_id=demo_entries_by_id, voices_manifest=voices_manifest,
    )

    app.include_router(create_health_router(state))
    app.include_router(create_voices_router(state))
    app.include_router(create_generate_router(state))
    app.include_router(create_streaming_router(state))

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request):
        render_fn = _OVERRIDE_RENDER_HTML or render_index_html
        return HTMLResponse(
            render_fn(
                request=request, runtime=runtime,
                demo_entries=demo_entries,
                warmup_status=_warmup_status_text(warmup_manager.snapshot()),
                text_normalization_status=_text_normalization_status_text(
                    text_normalizer_manager.snapshot() if text_normalizer_manager is not None else None
                ),
            )
        )

    return app


def main(argv: Optional[Sequence[str]] = None) -> None:
    parser = argparse.ArgumentParser(description="MOSS-TTS-Nano Demo Server")
    parser.add_argument("--runtime", choices=["pytorch", "onnx"], default="pytorch",
                        help="Model runtime backend (default: pytorch).")
    # PyTorch options
    parser.add_argument("--checkpoint-path", default=DEFAULT_CHECKPOINT_PATH, help="Model checkpoint path or HF repo ID.")
    parser.add_argument("--audio-tokenizer-path", default=DEFAULT_AUDIO_TOKENIZER_PATH, help="Audio tokenizer path or HF repo ID.")
    parser.add_argument("--device", default="cpu", help="Torch device (cpu, cuda, mps).")
    parser.add_argument("--dtype", default="auto", help="Torch dtype (auto, float32, float16, bfloat16).")
    parser.add_argument("--attn-implementation", default="auto", help="Attention backend (auto, sdpa, eager).")
    # ONNX options
    parser.add_argument("--model-dir", default=None, help="ONNX model directory (auto-downloads if omitted).")
    parser.add_argument("--execution-provider", choices=("cpu", "cuda"), default="cpu", help="ONNX execution provider.")
    parser.add_argument("--cpu-threads", type=int, default=0, help="CPU threads for ONNX (default: all cores).")
    parser.add_argument("--max-new-frames", type=int, default=375, help="Max new frames (ONNX only).")
    # Shared options
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="Directory for generated wav files.")
    parser.add_argument("--host", type=str, default="localhost")
    parser.add_argument("--port", type=int, default=18083)
    parser.add_argument("--root-path", type=str, default=None, help="FastAPI root_path for reverse proxy.")
    parser.add_argument("--vscode-proxy-uri", type=str, default=None, help="VS Code proxy URI override for webview.")
    parser.add_argument("--share", action="store_true", help="Ignored for FastAPI-based builds.")
    parser.add_argument("--log-level", type=str, default="info", help="Logging level.")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    text_normalizer_manager = SharedWeTextProcessingManager()
    text_normalizer_manager.start()

    if args.runtime == "onnx":
        _run_onnx(args, text_normalizer_manager)
    else:
        _run_pytorch(args, text_normalizer_manager)


def _run_pytorch(args, text_normalizer_manager):
    normalized_attn = str(args.attn_implementation or "").strip().lower()
    runtime = NanoTTSService(
        checkpoint_path=args.checkpoint_path,
        audio_tokenizer_path=args.audio_tokenizer_path,
        device=args.device,
        dtype=args.dtype,
        attn_implementation=normalized_attn if normalized_attn not in {"", "auto"} else "auto",
        output_dir=Path(args.output_dir).resolve(),
    )
    warmup_manager = WarmupManager(runtime, text_normalizer_manager)
    warmup_manager.start()
    root_path = resolve_vscode_root_path(args.vscode_proxy_uri, args.port) or args.root_path
    app = _build_app(runtime, warmup_manager, text_normalizer_manager, root_path)
    uvicorn.run(app, host=args.host, port=args.port, log_level=args.log_level)


def _run_onnx(args, text_normalizer_manager):
    import os
    from moss_tts_server.onnx_adapter import OnnxNanoTTSServiceAdapter
    from moss_tts_server.onnx_manager import OnnxRequestRuntimeManager

    output_dir = Path(args.output_dir).expanduser().resolve()
    cpu_threads = args.cpu_threads or max(1, int(os.cpu_count() or 1))

    runtime = OnnxNanoTTSServiceAdapter(
        model_dir=args.model_dir,
        output_dir=output_dir,
        cpu_threads=cpu_threads,
        execution_provider=args.execution_provider,
        max_new_frames=args.max_new_frames,
        text_normalizer_manager=text_normalizer_manager,
    )
    warmup_manager = WarmupManager(runtime, text_normalizer_manager=text_normalizer_manager)
    warmup_manager.start()

    # Override for ONNX
    global _OVERRIDE_RENDER_HTML
    _OVERRIDE_RENDER_HTML = lambda *a, **kw: render_index_html_onnx(*a, **kw)

    # Monkey-patch RequestRuntimeManager so routes use the ONNX version
    import app as _app_mod
    _app_mod.RequestRuntimeManager = OnnxRequestRuntimeManager
    from moss_tts_server.managers import RequestRuntimeManager as _orig_rtm
    import moss_tts_server.managers as _mgr_mod
    _mgr_mod.RequestRuntimeManager = OnnxRequestRuntimeManager

    root_path = resolve_vscode_root_path(args.vscode_proxy_uri, args.port) or args.root_path
    app = _build_app(runtime, warmup_manager, text_normalizer_manager, root_path)
    app.title = "MOSS-TTS-Nano ONNX Demo"
    uvicorn.run(app, host=args.host, port=args.port, log_level=args.log_level)


if __name__ == "__main__":
    main()
