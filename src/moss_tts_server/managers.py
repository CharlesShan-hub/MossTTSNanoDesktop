from __future__ import annotations

import logging
import os
import threading
from typing import Callable, Iterator, TypeVar

import torch

from moss_tts_nano_runtime import NanoTTSService
from moss_tts_server.models import WarmupSnapshot
from moss_tts_server.utils import _maybe_delete_file

T = TypeVar("T")


class WarmupManager:
    def __init__(self, runtime: NanoTTSService, text_normalizer_manager=None) -> None:
        self.runtime = runtime
        self.text_normalizer_manager = text_normalizer_manager
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._started = False
        self._state = "pending"
        self._progress = 0.0
        self._message = "Waiting for startup warmup."
        self._error: str | None = None

    def start(self) -> None:
        with self._lock:
            if self._started:
                return
            self._started = True
            self._thread = threading.Thread(target=self._run, name="nano-tts-warmup", daemon=True)
            self._thread.start()

    def snapshot(self) -> WarmupSnapshot:
        with self._lock:
            return WarmupSnapshot(
                state=self._state,
                progress=self._progress,
                message=self._message,
                error=self._error,
            )

    def ensure_ready(self) -> WarmupSnapshot:
        with self._lock:
            if not self._started:
                self._started = True
                self._thread = threading.Thread(target=self._run, name="nano-tts-warmup", daemon=True)
                self._thread.start()
            thread = self._thread
        if thread is not None and thread.is_alive():
            thread.join()
        return self.snapshot()

    def _set_state(
        self,
        *,
        state: str | None = None,
        progress: float | None = None,
        message: str | None = None,
        error: str | None = None,
    ) -> None:
        with self._lock:
            if state is not None:
                self._state = state
            if progress is not None:
                self._progress = max(0.0, min(1.0, float(progress)))
            if message is not None:
                self._message = message
            self._error = error

    def _run(self) -> None:
        try:
            self._set_state(state="running", progress=0.1, message="Loading Nano-TTS model.", error=None)
            self.runtime.get_model()
            self._set_state(state="running", progress=0.6, message="Running startup warmup synthesis.", error=None)
            result = self.runtime.warmup()
            _maybe_delete_file(result["audio_path"])
            if self.text_normalizer_manager is not None:
                self._set_state(
                    state="running",
                    progress=0.85,
                    message="Loading WeTextProcessing text normalization.",
                    error=None,
                )
                normalization_snapshot = self.text_normalizer_manager.ensure_ready()
                if normalization_snapshot.failed:
                    raise RuntimeError(normalization_snapshot.error or normalization_snapshot.message)
            self._set_state(
                state="ready",
                progress=1.0,
                message=(
                    f"Warmup complete. device={self.runtime.device} "
                    f"elapsed={result['elapsed_seconds']:.2f}s"
                    + (" | WeTextProcessing ready." if self.text_normalizer_manager is not None else "")
                ),
                error=None,
            )
        except Exception as exc:
            logging.exception("Nano-TTS warmup failed")
            self._set_state(state="failed", progress=1.0, message="Warmup failed.", error=str(exc))


class RequestRuntimeManager:
    def __init__(self, default_runtime: NanoTTSService) -> None:
        self.default_runtime = default_runtime
        self.default_cpu_threads = max(1, int(os.cpu_count() or 1))
        self._lock = threading.Lock()
        self._cpu_execution_lock = threading.Lock()
        self._cpu_runtime: NanoTTSService | None = None

    @staticmethod
    def normalize_requested_execution_device(requested: str | None) -> str:
        normalized = str(requested or "default").strip().lower()
        if normalized not in {"default", "cpu"}:
            return "default"
        return normalized

    def is_dedicated_cpu_request(self, requested: str | None) -> bool:
        normalized = self.normalize_requested_execution_device(requested)
        return normalized == "cpu" and self.default_runtime.device.type != "cpu"

    def is_cpu_runtime_loaded(self) -> bool:
        with self._lock:
            return self._cpu_runtime is not None

    def _build_cpu_runtime_locked(self) -> NanoTTSService:
        if self._cpu_runtime is not None:
            return self._cpu_runtime
        self._cpu_runtime = NanoTTSService(
            checkpoint_path=self.default_runtime.checkpoint_path,
            audio_tokenizer_path=self.default_runtime.audio_tokenizer_path,
            device="cpu",
            dtype="float32",
            attn_implementation=self.default_runtime.attn_implementation or "auto",
            output_dir=self.default_runtime.output_dir,
            voice_presets=self.default_runtime.voice_presets,
        )
        return self._cpu_runtime

    def resolve_runtime(self, requested: str | None) -> tuple[NanoTTSService, str]:
        normalized = self.normalize_requested_execution_device(requested)
        if normalized != "cpu":
            return self.default_runtime, str(self.default_runtime.device.type)
        if self.default_runtime.device.type == "cpu":
            return self.default_runtime, "cpu"
        with self._lock:
            return self._build_cpu_runtime_locked(), "cpu"

    def _resolve_cpu_threads(self, cpu_threads: int | None) -> int:
        if cpu_threads is None:
            return self.default_cpu_threads
        try:
            normalized_threads = int(cpu_threads)
        except Exception:
            return self.default_cpu_threads
        if normalized_threads <= 0:
            return self.default_cpu_threads
        return max(1, normalized_threads)

    def call_with_runtime(
        self,
        *,
        requested_execution_device: str | None,
        cpu_threads: int | None,
        callback: Callable[[NanoTTSService], T],
    ) -> tuple[T, str, int | None]:
        runtime, execution_device = self.resolve_runtime(requested_execution_device)
        if runtime.device.type != "cpu":
            return callback(runtime), execution_device, None

        resolved_cpu_threads = self._resolve_cpu_threads(cpu_threads)
        with self._cpu_execution_lock:
            previous_threads = torch.get_num_threads()
            threads_changed = previous_threads != resolved_cpu_threads
            if threads_changed:
                torch.set_num_threads(resolved_cpu_threads)
            try:
                return callback(runtime), execution_device, resolved_cpu_threads
            finally:
                if threads_changed:
                    torch.set_num_threads(previous_threads)

    def iter_with_runtime(
        self,
        *,
        requested_execution_device: str | None,
        cpu_threads: int | None,
        factory: Callable[[NanoTTSService], Iterator[T]],
    ) -> Iterator[tuple[T, str, int | None]]:
        runtime, execution_device = self.resolve_runtime(requested_execution_device)
        if runtime.device.type != "cpu":
            for item in factory(runtime):
                yield item, execution_device, None
            return

        resolved_cpu_threads = self._resolve_cpu_threads(cpu_threads)
        with self._cpu_execution_lock:
            previous_threads = torch.get_num_threads()
            threads_changed = previous_threads != resolved_cpu_threads
            if threads_changed:
                torch.set_num_threads(resolved_cpu_threads)
            try:
                for item in factory(runtime):
                    yield item, execution_device, resolved_cpu_threads
            finally:
                if threads_changed:
                    torch.set_num_threads(previous_threads)
