from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import APIRouter, File, Form, Query, UploadFile
from fastapi.responses import FileResponse, JSONResponse

from moss_tts_server.defaults import ASSETS_AUDIO_DIR, APP_DIR
from moss_tts_server.routes import ServerState, save_voices_manifest, generate_voice_id
from moss_tts_server.utils import _maybe_delete_file


def _voice_to_dict(voice_id: str, info: dict) -> dict:
    return {
        "id": voice_id,
        "name": info.get("name", voice_id),
        "file": info["file"],
        "language": info["language"],
        "description": info["description"],
        "hidden": bool(info.get("hidden", False)),
    }


def create_voices_router(state: ServerState) -> APIRouter:
    router = APIRouter()

    @router.get("/api/voices")
    async def list_voices(show_hidden: bool = Query(False, alias="show_hidden")):
        voices = []
        for voice_id, info in state.voices_manifest.items():
            if not show_hidden and info.get("hidden", False):
                continue
            voices.append(_voice_to_dict(voice_id, info))
        return {"voices": voices}

    @router.get("/api/voices/{voice_id}/audio")
    async def get_voice_audio(voice_id: str):
        info = state.voices_manifest.get(voice_id)
        if info is None:
            return JSONResponse(status_code=404, content={"error": f"Voice '{voice_id}' not found"})
        audio_path = (APP_DIR / info["file"]).resolve()
        if not audio_path.is_file():
            return JSONResponse(status_code=404, content={"error": f"Audio file not found: {audio_path}"})
        return FileResponse(
            path=str(audio_path),
            media_type="audio/wav",
            filename=audio_path.name,
        )

    @router.post("/api/voices")
    async def create_voice(
        name: str = Form(...),
        language: str = Form(""),
        description: str = Form(""),
        audio_file: UploadFile = File(...),
    ):
        name = str(name or "").strip()
        if not name:
            return JSONResponse(status_code=400, content={"error": "Voice name is required."})

        ext = Path(audio_file.filename or "voice.wav").suffix or ".wav"
        filename = f"{uuid.uuid4().hex[:12]}{ext}"
        dest = ASSETS_AUDIO_DIR / filename

        ASSETS_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
        try:
            content = await audio_file.read()
            dest.write_bytes(content)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"Failed to save audio: {e}"})
        finally:
            await audio_file.close()

        voice_id = generate_voice_id(name)
        if voice_id in state.voices_manifest:
            voice_id = f"{voice_id}_{uuid.uuid4().hex[:4]}"

        new_entry = {
            "name": name,
            "file": f"assets/audio/{filename}",
            "language": str(language or "").strip(),
            "description": str(description or "").strip(),
            "hidden": False,
        }

        state.voices_manifest[voice_id] = new_entry
        save_voices_manifest(state.voices_manifest)

        return _voice_to_dict(voice_id, new_entry)

    @router.put("/api/voices/{voice_id}")
    async def update_voice(
        voice_id: str,
        name: str = Form(""),
        language: str = Form(""),
        description: str = Form(""),
        audio_file: UploadFile | None = File(None),
    ):
        if voice_id not in state.voices_manifest:
            return JSONResponse(status_code=404, content={"error": f"Voice '{voice_id}' not found"})

        entry = state.voices_manifest[voice_id]

        if audio_file and audio_file.filename:
            ext = Path(audio_file.filename).suffix or ".wav"
            filename = f"{uuid.uuid4().hex[:12]}{ext}"
            dest = ASSETS_AUDIO_DIR / filename
            ASSETS_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
            try:
                content = await audio_file.read()
                dest.write_bytes(content)
            except Exception as e:
                return JSONResponse(status_code=500, content={"error": f"Failed to save audio: {e}"})
            finally:
                await audio_file.close()

            old_path = APP_DIR / entry["file"]
            _maybe_delete_file(str(old_path.resolve()))
            entry["file"] = f"assets/audio/{filename}"

        name = str(name or "").strip()
        if name:
            new_id = generate_voice_id(name)
            new_entry = {
                "name": name,
                "file": entry["file"],
                "language": str(language or entry["language"]).strip(),
                "description": str(description or entry["description"]).strip(),
                "hidden": bool(entry.get("hidden", False)),
            }
            del state.voices_manifest[voice_id]
            if new_id in state.voices_manifest:
                new_id = f"{new_id}_{uuid.uuid4().hex[:4]}"
            state.voices_manifest[new_id] = new_entry
        else:
            if language:
                entry["language"] = str(language).strip()
            if description:
                entry["description"] = str(description).strip()
            new_id = voice_id

        save_voices_manifest(state.voices_manifest)
        return _voice_to_dict(new_id, state.voices_manifest[new_id])

    @router.delete("/api/voices/{voice_id}")
    async def delete_voice(voice_id: str):
        info = state.voices_manifest.pop(voice_id, None)
        if info is None:
            return JSONResponse(status_code=404, content={"error": f"Voice '{voice_id}' not found"})
        audio_path = (APP_DIR / info["file"]).resolve()
        _maybe_delete_file(str(audio_path))
        save_voices_manifest(state.voices_manifest)
        return {"deleted": voice_id, "file": info["file"]}

    @router.patch("/api/voices/{voice_id}/toggle-hidden")
    async def toggle_voice_hidden(voice_id: str):
        info = state.voices_manifest.get(voice_id)
        if info is None:
            return JSONResponse(status_code=404, content={"error": f"Voice '{voice_id}' not found"})
        info["hidden"] = not bool(info.get("hidden", False))
        save_voices_manifest(state.voices_manifest)
        return {"id": voice_id, "hidden": info["hidden"]}

    @router.get("/api/demo-prompt-audio/{demo_id}")
    async def demo_prompt_audio(demo_id: str):
        from moss_tts_server.routes import resolve_demo_entry
        try:
            demo_entry = resolve_demo_entry(state.demo_entries_by_id, demo_id)
        except ValueError as exc:
            return JSONResponse(status_code=404, content={"error": str(exc)})
        media_type = "audio/wav" if demo_entry.prompt_audio_path.suffix.lower() == ".wav" else "application/octet-stream"
        return FileResponse(
            path=str(demo_entry.prompt_audio_path),
            media_type=media_type,
            filename=demo_entry.prompt_audio_path.name,
        )

    return router
