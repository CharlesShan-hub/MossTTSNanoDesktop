import json
import subprocess
import tempfile
import os

AUDIO_LIST = "src/audio_list.json"
BASE_URL = "http://localhost:18083"


def main():
    with open(AUDIO_LIST, "r", encoding="utf-8") as f:
        entries = json.load(f)

    for i, entry in enumerate(entries):
        name = os.path.splitext(entry["name"])[0]
        audio_url = entry["audio"]
        lang = entry.get("lang", "中文")
        trait = entry.get("trait", "")
        age = entry.get("age", "")
        scenario = entry.get("scenario", "")

        # description 字段合并特质、年龄、场景
        desc_parts = []
        if trait:
            desc_parts.append(f"特质：{trait}")
        if age:
            desc_parts.append(f"年龄：{age}")
        if scenario:
            desc_parts.append(f"场景：{scenario}")
        description = "；".join(desc_parts)

        print(f"\n[{i + 1}/{len(entries)}] ▶ 处理: {name}")

        # 1. 下载音频文件到临时目录
        ext = os.path.splitext(name)[1] or ".wav"
        tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
        tmp_path = tmp.name
        tmp.close()

        ret = subprocess.run(
            ["curl", "-s", "-o", tmp_path, "-L", audio_url],
        )
        if ret.returncode != 0:
            print(f"  ✗ 下载失败: {name}")
            os.unlink(tmp_path)
            continue
        file_size = os.path.getsize(tmp_path)
        print(f"  ✓ 下载完成 ({file_size} bytes)")

        # 2. 上传到 FastAPI
        ret2 = subprocess.run(
            [
                "curl", "-s", "-X", "POST",
                f"{BASE_URL}/api/voices",
                "-F", f"name={name}",
                "-F", f"language={lang}",
                "-F", f"description={description}",
                "-F", f"audio_file=@{tmp_path}",
            ],
            capture_output=True, text=True,
        )
        print(f"  → 上传响应: {ret2.stdout}")

        # 清理临时文件
        os.unlink(tmp_path)

        # 测试模式：只上传第一条
        # print("\n🔹 测试模式：仅上传第一条，已结束")
        # break


if __name__ == "__main__":
    main()
