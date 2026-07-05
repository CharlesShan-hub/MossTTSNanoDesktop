from __future__ import annotations

import json
import logging
import os
import tempfile
from pathlib import Path

from fastapi import Request, UploadFile

from moss_tts_server.defaults import APP_DIR, ASSETS_AUDIO_DIR, PROMPT_UPLOAD_DIR
from moss_tts_server.models import DemoEntry
from moss_tts_server.utils import _maybe_delete_file, _sanitize_uploaded_prompt_filename, _format_uploaded_prompt_display_name
from moss_tts_nano_runtime import NanoTTSService


# ── Shared server state ───────────────────────────────────────────────────


class ServerState:
    """Container for all shared objects used across route modules.

    This avoids passing a dozen parameters to every router factory.
    """

    def __init__(
        self,
        app,
        runtime: NanoTTSService,
        runtime_manager,
        warmup_manager,
        text_normalizer_manager,
        stream_jobs,
        demo_entries: list[DemoEntry],
        demo_entries_by_id: dict[str, DemoEntry],
        voices_manifest: dict[str, dict[str, str]],
    ) -> None:
        self.app = app
        self.runtime = runtime
        self.runtime_manager = runtime_manager
        self.warmup_manager = warmup_manager
        self.text_normalizer_manager = text_normalizer_manager
        self.stream_jobs = stream_jobs
        self.demo_entries = demo_entries
        self.demo_entries_by_id = demo_entries_by_id
        self.voices_manifest = voices_manifest


# ── Data loading (moved from app.py) ─────────────────────────────────────


def load_demo_entries() -> list[DemoEntry]:
    from moss_tts_server.defaults import DEMO_METADATA_PATH

    if not DEMO_METADATA_PATH.is_file():
        logging.warning("demo metadata file not found: %s", DEMO_METADATA_PATH)
        return []

    demo_entries: list[DemoEntry] = []
    for line_index, raw_line in enumerate(DEMO_METADATA_PATH.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except Exception:
            logging.warning("failed to parse demo metadata line=%s path=%s", line_index, DEMO_METADATA_PATH, exc_info=True)
            continue

        prompt_audio_relative_path = str(payload.get("role", "")).strip()
        text = str(payload.get("text", "")).strip()
        if not prompt_audio_relative_path or not text:
            logging.warning("skip invalid demo metadata line=%s role/text missing", line_index)
            continue

        prompt_audio_path = (APP_DIR / prompt_audio_relative_path).resolve()
        if not prompt_audio_path.is_file():
            logging.warning("skip demo metadata line=%s prompt speech missing: %s", line_index, prompt_audio_path)
            continue

        try:
            prompt_audio_relative_path = str(prompt_audio_path.relative_to(APP_DIR))
        except ValueError:
            logging.warning("skip demo metadata line=%s prompt speech escaped app dir: %s", line_index, prompt_audio_path)
            continue

        demo_index = len(demo_entries) + 1
        name = str(payload.get("name", "")).strip() or f"Demo {demo_index}: {prompt_audio_path.stem}"
        demo_entries.append(
            DemoEntry(
                demo_id=f"demo-{demo_index}",
                name=name,
                prompt_audio_path=prompt_audio_path,
                prompt_audio_relative_path=prompt_audio_relative_path,
                text=text,
            )
        )
    return demo_entries


def load_voices_manifest() -> dict[str, dict[str, str]]:
    from moss_tts_server.defaults import VOICES_METADATA_PATH

    if not VOICES_METADATA_PATH.is_file():
        logging.warning("voice manifest not found: %s", VOICES_METADATA_PATH)
        return {}
    try:
        raw = json.loads(VOICES_METADATA_PATH.read_text(encoding="utf-8"))
    except Exception:
        logging.warning("failed to parse voice manifest: %s", VOICES_METADATA_PATH, exc_info=True)
        return {}
    if not isinstance(raw, dict):
        logging.warning("voice manifest must be a JSON object: %s", VOICES_METADATA_PATH)
        return {}
    validated: dict[str, dict[str, str]] = {}
    for voice_id, info in raw.items():
        if not isinstance(info, dict):
            continue
        file_path = str(info.get("file", "")).strip()
        if not file_path:
            continue
        resolved = (APP_DIR / file_path).resolve()
        if not resolved.is_file():
            logging.warning("voice file not found: %s (voice_id=%s)", resolved, voice_id)
            continue
        validated[voice_id] = {
            "name": str(info.get("name", "")).strip() or voice_id,
            "file": file_path,
            "language": str(info.get("language", "")).strip(),
            "description": str(info.get("description", "")).strip(),
            "hidden": bool(info.get("hidden", False)),
        }
    return validated


def resolve_vscode_root_path(vscode_proxy_uri: str | None, server_port: int) -> str | None:
    import urllib.parse

    if not vscode_proxy_uri:
        return None
    raw = vscode_proxy_uri.strip()
    if not raw or raw == "/":
        return None

    port_str = str(server_port)
    replacements = (
        "{{port}}", "{port}",
        "%7B%7Bport%7D%7D", "%7b%7bport%7d%7d",
        "%7Bport%7D", "%7bport%7d",
    )
    resolved = raw
    for token in replacements:
        resolved = resolved.replace(token, port_str)

    parsed = urllib.parse.urlsplit(resolved)
    path = parsed.path or "/" if parsed.scheme and parsed.netloc else resolved
    if not path.startswith("/"):
        path = "/" + path
    normalized = path.rstrip("/")
    return normalized or None


# ── Shared helpers ───────────────────────────────────────────────────────


def resolve_demo_entry(demo_entries_by_id: dict[str, DemoEntry], demo_id: str) -> DemoEntry:
    normalized_demo_id = str(demo_id or "").strip()
    if not normalized_demo_id:
        raise ValueError("demo_id is required.")
    entry = demo_entries_by_id.get(normalized_demo_id)
    if entry is None:
        raise ValueError(f"Unknown demo_id: {normalized_demo_id}")
    return entry


async def resolve_prompt_audio_request(
    demo_entries_by_id: dict[str, DemoEntry],
    demo_id: str,
    prompt_audio: UploadFile | None,
) -> tuple[DemoEntry | None, str | None, str | None, str | None]:
    upload_path: str | None = None
    upload_display_name: str | None = None

    if prompt_audio is not None and prompt_audio.filename:
        try:
            upload_path, upload_display_name = await persist_uploaded_prompt_audio(prompt_audio)
        except ValueError as exc:
            raise exc

    if upload_path:
        return None, upload_path, upload_display_name, upload_path

    try:
        demo_entry = resolve_demo_entry(demo_entries_by_id, demo_id)
    except ValueError:
        if PROMPT_UPLOAD_DIR.is_dir():
            existing = sorted(PROMPT_UPLOAD_DIR.iterdir(), key=os.path.getmtime)
            if existing:
                most_recent = str(existing[-1])
                display_name = _format_uploaded_prompt_display_name(Path(most_recent).name)
                return None, most_recent, display_name, None
        raise

    return (
        demo_entry,
        str(demo_entry.prompt_audio_path),
        demo_entry.prompt_audio_relative_path,
        None,
    )


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
            mode="wb", delete=False,
            prefix="prompt-speech-", suffix=suffix,
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


def save_voices_manifest(manifest: dict[str, dict[str, str]]) -> None:
    """Persist the voices manifest back to the JSON file."""
    from moss_tts_server.defaults import VOICES_METADATA_PATH
    VOICES_METADATA_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def generate_voice_id(name: str) -> str:
    """Generate a unique voice ID from a name."""
    import re
    # Keep only alphanumeric and underscore, lowercase
    safe = re.sub(r"[^a-zA-Z0-9_]", "_", name.strip().lower())
    safe = re.sub(r"_+", "_", safe).strip("_")
    return safe or f"voice_{int(__import__('time').time())}"
