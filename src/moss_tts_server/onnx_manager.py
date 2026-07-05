from __future__ import annotations

import logging
import os
import threading
from pathlib import Path
from typing import Any

from onnx_tts_runtime import OnnxTtsRuntime, ensure_browser_onnx_model_dir
from moss_tts_server.managers import RequestRuntimeManager
from moss_tts_nano_runtime import NanoTTSService


class OnnxRequestRuntimeManager(RequestRuntimeManager):
    """ONNX-specific RequestRuntimeManager.

    Replaces the PyTorch one.  There is only ever one ONNX runtime
    since ONNX runs on CPU only.
    """

    _factory_model_dir: str | None = None
    _factory_output_dir: str | None = None
    _factory_max_new_frames: int = 375
    _factory_execution_provider: str = "cpu"
    _factory_text_normalizer_manager: Any = None
    _factory_onnx_runtime: OnnxTtsRuntime | None = None

    def __init__(self, default_runtime: NanoTTSService) -> None:
        # Q: why pass default_runtime at all?
        # A: the base class expects one; the ONNX version ignores it
        #    and always returns the same OnnxTtsRuntime singleton.
        super().__init__(default_runtime)
        self._onnx_runtime_lock = threading.Lock()
        self._onnx_runtime: OnnxTtsRuntime | None = None
        self._built = False

    @property
    def onnx_runtime(self) -> OnnxTtsRuntime:
        if not self._built:
            with self._onnx_runtime_lock:
                if not self._built:
                    model_dir = (
                        Path(str(self.__class__._factory_model_dir)).expanduser().resolve()
                        if self.__class__._factory_model_dir
                        else None
                    )
                    model_dir = ensure_browser_onnx_model_dir(model_dir)
                    output_dir = (
                        Path(str(self.__class__._factory_output_dir)).expanduser().resolve()
                        if self.__class__._factory_output_dir
                        else None
                    )
                    self._onnx_runtime = OnnxTtsRuntime(
                        model_dir=model_dir,
                        thread_count=max(1, int(os.cpu_count() or 1)),
                        output_dir=output_dir,
                        enable_wetext=self.__class__._factory_text_normalizer_manager is not None,
                        text_normalizer_manager=self.__class__._factory_text_normalizer_manager,
                    )
                    # Patch max_new_frames overlay
                    self._onnx_runtime.max_new_frames = self.__class__._factory_max_new_frames
                    self._onnx_runtime = self.__class__._factory_onnx_runtime or self._onnx_runtime
                    self._built = True
        return self._onnx_runtime

    def is_dedicated_cpu_request(self, requested: str | None) -> bool:
        return False  # ONNX always runs on CPU, no extra load needed

    def is_cpu_runtime_loaded(self) -> bool:
        return self._built

    def resolve_runtime(self, requested: str | None) -> tuple[NanoTTSService, str]:
        return self.onnx_runtime, "cpu"  # type: ignore[return-value]

    def call_with_runtime(self, *, requested_execution_device, cpu_threads, callback):
        result = callback(self.onnx_runtime)
        return result, "cpu", max(1, int(os.cpu_count() or 1))

    def iter_with_runtime(self, *, requested_execution_device, cpu_threads, factory):
        for item in factory(self.onnx_runtime):
            yield item, "cpu", max(1, int(os.cpu_count() or 1))

    def _resolve_cpu_threads(self, cpu_threads: int | None) -> int:
        return max(1, int(os.cpu_count() or 1))
