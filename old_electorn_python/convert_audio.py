"""将 assets/audio/ 中的 MP3/FLAC 文件转为真正的 WAV"""
from pathlib import Path
import subprocess, tempfile, shutil

audio_dir = Path(__file__).resolve().parent.parent / "assets" / "audio"
converted = 0
for f in sorted(audio_dir.iterdir()):
    if f.suffix.lower() != '.wav':
        continue
    # 检查前 4 字节
    h = f.read_bytes()[:4]
    if h == b'RIFF':
        continue  # 已经是正确 WAV
    # 需要转换
    tmp = Path(tempfile.mktemp(suffix='.wav'))
    print(f"  {f.name}: header={h} -> converting")
    ret = subprocess.run(['ffmpeg', '-y', '-i', str(f), '-acodec', 'pcm_s16le', '-ac', '1', '-ar', '48000', str(tmp)], capture_output=True)
    if ret.returncode != 0:
        print(f"    FAILED: {ret.stderr.decode()[-100:]}")
        tmp.unlink(missing_ok=True)
        continue
    shutil.copy2(tmp, f)
    tmp.unlink()
    converted += 1
    print(f"    OK ({f.stat().st_size} bytes)")

print(f"\nDone: {converted} files converted to real WAV")
