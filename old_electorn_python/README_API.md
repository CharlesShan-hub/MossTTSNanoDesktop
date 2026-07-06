# HTTP API

MOSS-TTS-Nano 启动服务后（`pixi run serve` 或 `pixi run serve-onnx`），提供以下 HTTP 接口。

---

## `GET /api/voices`

获取预制语音列表。

```bash
curl http://localhost:18083/api/voices
```

**返回示例：**

```json
{
  "voices": [
    {"id": "zh_female_1", "name": "中文女声", "file": "assets/audio/zh_1.wav", "description": "标准中文女声，适合朗读"},
    {"id": "en_news_4",  "name": "英文新闻女声", "file": "assets/audio/en_4.wav", "description": "标准英文新闻播报"}
  ]
}
```

---

## `POST /api/generate`

语音合成。

### 方式一：按名称选用预制语音（推荐）

```bash
curl -s -X POST http://localhost:18083/api/generate \
  -F "voice_name=zh_female_1" \
  -F "text=第一章。在很久很久以前，有一座大山，山脚下住着一位老爷爷。" \
  | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
with open('chapter1.wav', 'wb') as f:
    f.write(base64.b64decode(data['audio_base64']))
print('已保存: chapter1.wav')
"
```

### 方式二：上传自己的参考音频

```bash
curl -X POST http://localhost:18083/api/generate \
  -F "text=你好，这是我的声音克隆。" \
  -F "prompt_audio=@my_voice.wav"
```

### 方式三：使用 Web Demo 上的预设文本

```bash
curl -X POST http://localhost:18083/api/generate \
  -F "text=你好" \
  -F "demo_id=demo-1"
```

### 请求参数

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `text` | string | **必填** | 要合成的文本 |
| `voice_name` | string | `""` | 预制语音 ID（见 `GET /api/voices`）。优先于 `demo_id` 和 `prompt_audio` |
| `demo_id` | string | `""` | Web Demo 预设条目 ID。与 `prompt_audio` 二选一 |
| `prompt_audio` | file | `null` | 上传的参考音频（wav）。与 `demo_id` 二选一 |
| `max_new_frames` | int | `375` | 最大生成帧数 |
| `audio_temperature` | float | `0.8` | 音频层采样温度。越高越随机 |
| `audio_top_k` | int | `25` | 音频层 top-k 采样 |
| `audio_top_p` | float | `0.95` | 音频层 top-p 采样 |
| `audio_repetition_penalty` | float | `1.2` | 音频层重复惩罚 |
| `text_temperature` | float | `1.0` | 文本层采样温度 |
| `text_top_k` | int | `50` | 文本层 top-k 采样 |
| `text_top_p` | float | `1.0` | 文本层 top-p 采样 |
| `seed` | string | `"0"` | 随机种子。`"0"` 或 `""` 表示不固定 |
| `do_sample` | string | `"1"` | `"1"` 采样 / `"0"` 贪心解码 |
| `enable_text_normalization` | string | `"1"` | 是否启用文本正则化 |

### 返回格式

```json
{
  "audio_base64": "UklGRiT...（WAV 二进制数据的 base64 编码）",
  "sample_rate": 48000,
  "text_chunks": ["第一章。", "在很久很久以前..."],
  "normalized_text": "...",
  "normalization_method": "..."
}
```

所有方式均支持长文本自动分块语音克隆。音频格式：**48kHz、双声道、WAV**。

---

## `GET /health`

服务健康检查。

```bash
curl http://localhost:18083/health
```

---

## Python 示例（有声书 App）

```python
import requests
import base64

def synthesize(voice_name: str, text: str, output_path: str = "output.wav"):
    resp = requests.post("http://localhost:18083/api/generate", data={
        "voice_name": voice_name,
        "text": text,
    })
    resp.raise_for_status()
    data = resp.json()
    with open(output_path, "wb") as f:
        f.write(base64.b64decode(data["audio_base64"]))
    print(f"已保存: {output_path}  ({data['sample_rate']}Hz)")
    return data

# 调用示例
synthesize("zh_female_1", "第一章。在很久很久以前，有一座大山。", "chapter1.wav")
synthesize("en_news_4", "Good evening. Here is the news.", "news.wav")
```

---

## `pixi.toml` 中预定义的 task 别名

```bash
pixi run serve       # 启动 PyTorch 版服务（localhost:18083）
pixi run serve-onnx  # 启动 ONNX 版服务（更快，推荐）
```