from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent.parent.parent  # src/moss_tts_server/ -> src/ -> repo root
DEMO_METADATA_PATH = APP_DIR / "assets" / "demo.jsonl"
VOICES_METADATA_PATH = APP_DIR / "assets" / "audio" / "voices.json"
ASSETS_AUDIO_DIR = APP_DIR / "assets" / "audio"
PROMPT_UPLOAD_DIR = APP_DIR / ".app_prompt_uploads"
