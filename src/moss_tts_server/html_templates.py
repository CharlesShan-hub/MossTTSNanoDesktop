from __future__ import annotations

import json
import logging
import tempfile
from pathlib import Path

from fastapi import Request, UploadFile

from moss_tts_server.defaults import PROMPT_UPLOAD_DIR
from moss_tts_server.models import DemoEntry
from moss_tts_server.utils import _maybe_delete_file, _sanitize_uploaded_prompt_filename, _format_uploaded_prompt_display_name
from moss_tts_nano_runtime import NanoTTSService


async def persist_uploaded_prompt_audio(upload: UploadFile | None) -> tuple[str | None, str | None]:
    if upload is None:
        return None, None

    original_filename = _sanitize_uploaded_prompt_filename(upload.filename)
    suffix = Path(original_filename).suffix
    if not suffix or len(suffix) > 16:
        suffix = ".wav"

    PROMPT_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    temp_path: str | None = None
    bytes_written = 0
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            delete=False,
            prefix="prompt-speech-",
            suffix=suffix,
            dir=str(PROMPT_UPLOAD_DIR),
        ) as handle:
            temp_path = handle.name
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)
                bytes_written += len(chunk)
    finally:
        await upload.close()

    if not temp_path or bytes_written <= 0:
        _maybe_delete_file(temp_path)
        raise ValueError("Uploaded prompt speech is empty.")

    return temp_path, _format_uploaded_prompt_display_name(original_filename)


def render_index_html(
    *,
    request: Request,
    runtime: NanoTTSService,
    demo_entries: list[DemoEntry],
    warmup_status: str,
    text_normalization_status: str,
) -> str:
    base_path = request.scope.get("root_path", "").rstrip("/")

    demos_payload = _build_demos_json(demo_entries)
    default_demo_id = demo_entries[0].demo_id if demo_entries else ""
    default_attn_impl = runtime.attn_implementation or "model_default"
    default_cpu_threads = max(1, int(__import__("os").cpu_count() or 1))

    template = _read_index_template()
    html = template.replace("__APP_BASE__", json.dumps(base_path))
    html = html.replace("__DEMOS__", json.dumps(demos_payload, ensure_ascii=False))
    html = html.replace("__DEFAULT_DEMO_ID__", json.dumps(default_demo_id))
    html = html.replace("__DEFAULT_ATTN_IMPLEMENTATION__", json.dumps(default_attn_impl))
    html = html.replace("__DEFAULT_CPU_THREADS__", json.dumps(default_cpu_threads))
    html = html.replace("__CHECKPOINT__", str(runtime.checkpoint_path))
    html = html.replace("__AUDIO_TOKENIZER__", str(runtime.audio_tokenizer_path))
    html = html.replace("__WARMUP_STATUS__", warmup_status)
    html = html.replace("__TEXT_NORMALIZATION_STATUS__", text_normalization_status)
    return html


def render_index_html_onnx(
    *,
    request: Request,
    runtime,
    demo_entries,
    warmup_status: str,
    text_normalization_status: str,
) -> str:
    """ONNX-specific HTML — built on top of render_index_html."""
    html = render_index_html(
        request=request, runtime=runtime,
        demo_entries=demo_entries, warmup_status=warmup_status,
        text_normalization_status=text_normalization_status,
    )
    html = html.replace("MOSS-TTS-Nano Demo", "MOSS-TTS-Nano ONNX Demo")
    html = html.replace(
        '<label for="attn-implementation">Attention Backend</label>\n'
        '              <select id="attn-implementation">\n'
        '                <option value="model_default">model_default</option>\n'
        '                <option value="sdpa">sdpa</option>\n'
        '                <option value="eager">eager</option>\n'
        '              </select>',
        '<label for="attn-implementation">Sampling Mode</label>\n'
        '              <select id="attn-implementation">\n'
        '                <option value="fixed">fixed</option>\n'
        '                <option value="full">full</option>\n'
        '                <option value="greedy">greedy</option>\n'
        '              </select>\n'
        '              <div id="onnx-sampling-mode-note" class="meta">fixed uses the baked ONNX sampling constants.</div>',
    )
    html = html.replace(
        '<label><input id="do-sample" type="checkbox" checked> Do Sample</label>',
        '<label><input id="do-sample" type="checkbox" checked disabled> Do Sample (derived from Sampling Mode)</label>',
    )
    html = html.replace(
        'This app is CPU-only. CPU Threads maps to torch.set_num_threads for that request.',
        'This ONNX app uses the server-start execution provider. CPU Threads selects the cached ONNX runtime instance for that request.',
    )
    html = html.replace(
        '</style>',
        '    .field.disabled-field { opacity: 0.5; }\n'
        '    .field.disabled-field input { cursor: not-allowed; background: #f4f6fb; }\n'
        '</style>',
        1,
    )
    # Add the ONNX-specific JS
    onnx_js = (
        '    const onnxSamplingModeSelect = document.getElementById("attn-implementation");\n'
        '    const onnxDoSampleToggle = document.getElementById("do-sample");\n'
        '    const onnxSamplingModeNote = document.getElementById("onnx-sampling-mode-note");\n'
        '    const onnxSamplingParamIds = [\n'
        '      "text-temperature","text-top-p","text-top-k",\n'
        '      "audio-temperature","audio-top-p","audio-top-k","audio-repetition-penalty"\n'
        '    ];\n'
        '    function syncOnnxSamplingUi() {\n'
        '      const mode = (onnxSamplingModeSelect && onnxSamplingModeSelect.value) || "fixed";\n'
        '      const enabled = mode === "full";\n'
        '      if (onnxDoSampleToggle) onnxDoSampleToggle.checked = mode !== "greedy";\n'
        '      for (const id of onnxSamplingParamIds) {\n'
        '        const input = document.getElementById(id);\n'
        '        if (!input) continue;\n'
        '        input.disabled = !enabled;\n'
        '        const field = input.closest(".field");\n'
        '        if (field) field.classList.toggle("disabled-field", !enabled);\n'
        '      }\n'
        '      if (onnxSamplingModeNote) {\n'
        '        const msgs = { fixed:"fixed uses the baked ONNX sampling constants.",\n'
        '          full:"full uses the current page sampling hyperparameters.",\n'
        '          greedy:"greedy disables sampling and ignores the hyperparameter inputs below." };\n'
        '        onnxSamplingModeNote.textContent = msgs[mode] || "";\n'
        '      }\n'
        '    }\n'
        '    if (onnxSamplingModeSelect) {\n'
        '      onnxSamplingModeSelect.addEventListener("change", syncOnnxSamplingUi);\n'
        '      syncOnnxSamplingUi();\n'
        '    }\n'
    )
    marker = 'document.getElementById("attn-implementation").value = DEFAULT_ATTN_IMPLEMENTATION;'
    html = html.replace(marker, marker + "\n" + onnx_js, 1)
    return html


def _build_demos_json(demo_entries: list[DemoEntry]) -> list[dict[str, str]]:
    return [
        {
            "id": entry.demo_id,
            "name": entry.name,
        }
        for entry in demo_entries
    ]


def _read_index_template() -> str:
    """Read the Web UI HTML template from the embedded template file."""
    template_path = Path(__file__).resolve().parent / "templates" / "index.html"
    if template_path.is_file():
        return template_path.read_text(encoding="utf-8")
    # Fallback for backward compatibility
    return _EMBEDDED_TEMPLATE


_EMBEDDED_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MOSS-TTS-Nano Demo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    :root {
      --font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      --bg: #f5f5f7;
      --surface: #ffffff;
      --border: #d1d1d6;
      --text: #1d1d1f;
      --text-secondary: #6e6e73;
      --accent: #0071e3;
      --radius: 8px;
    }
    body {
      font-family: var(--font);
      background: var(--bg);
      color: var(--text);
      padding: 24px;
      max-width: 960px;
      margin: 0 auto;
    }
    h1 { font-size: 24px; margin-bottom: 16px; }
    .field { margin-bottom: 16px; }
    .field label { display: block; font-size: 13px; font-weight: 600; color: var(--text-secondary); margin-bottom: 4px; }
    .field select, .field textarea, .field input {
      width: 100%; padding: 8px 12px;
      border: 1px solid var(--border); border-radius: var(--radius);
      font-size: 14px; font-family: var(--font);
    }
    .field textarea { min-height: 120px; resize: vertical; }
    .btn { padding: 8px 20px; border-radius: 20px; border: none; font-size: 14px; font-weight: 500; cursor: pointer; background: var(--accent); color: #fff; }
    .btn:hover { opacity: 0.85; }
    .meta { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }
    .status { padding: 8px 12px; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); font-size: 13px; margin-top: 12px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    @media (max-width: 640px) { .grid { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <h1>MOSS-TTS-Nano Demo</h1>
  <div class="meta">Checkpoint: __CHECKPOINT__</div>
  <div class="meta">Audio Tokenizer: __AUDIO_TOKENIZER__</div>
  <div class="meta" id="warmup-status">__WARMUP_STATUS__</div>
  <div class="meta" id="text-normalization-status">__TEXT_NORMALIZATION_STATUS__</div>
  <div class="grid">
    <div class="field">
      <label for="demo">Demo</label>
      <select id="demo"></select>
    </div>
    <div class="field">
      <label for="text">Text</label>
      <textarea id="text" placeholder="Enter text to synthesize..."></textarea>
    </div>
  </div>
  <button class="btn" id="generate-btn">Generate</button>
  <div class="status" id="status">Ready.</div>
  <audio id="audio-output" controls style="width:100%;margin-top:12px;display:none;"></audio>
  <script>
    const DEMOS = __DEMOS__;
    const DEFAULT_DEMO_ID = __DEFAULT_DEMO_ID__;
    const APP_BASE = __APP_BASE__;

    const demoSelect = document.getElementById('demo');
    for (const d of DEMOS) {
      const o = document.createElement('option');
      o.value = d.id; o.textContent = d.name;
      if (d.id === DEFAULT_DEMO_ID) o.selected = true;
      demoSelect.appendChild(o);
    }

    document.getElementById('generate-btn').addEventListener('click', async () => {
      const demo = demoSelect.value;
      const text = document.getElementById('text').value.trim();
      if (!text) return;
      const status = document.getElementById('status');
      status.textContent = 'Generating...';
      const form = new FormData();
      form.append('demo_id', demo);
      form.append('text', text);
      const r = await fetch(APP_BASE + '/api/generate', { method: 'POST', body: form });
      const data = await r.json();
      if (data.audio_base64) {
        const blob = new Blob([Uint8Array.from(atob(data.audio_base64), c => c.charCodeAt(0))], { type: 'audio/wav' });
        const audio = document.getElementById('audio-output');
        audio.src = URL.createObjectURL(blob);
        audio.style.display = 'block';
        audio.play();
        status.textContent = data.run_status || 'Done.';
      } else {
        status.textContent = data.error || 'Failed.';
      }
    });
  </script>
</body>
</html>
"""
