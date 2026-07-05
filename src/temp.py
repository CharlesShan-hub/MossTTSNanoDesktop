import json
from bs4 import BeautifulSoup


def _infer_lang(trait):
    """根据特质推断语言"""
    if not trait:
        return "中文"
    # 方言标记（优先于外语，因为粤语、东北话本质是中文方言）
    dialect_kw = ("粤语", "东北", "陕北", "台湾", "四川", "山东", "湖南", "陕西", "河南")
    for kw in dialect_kw:
        if kw in trait:
            return "中文方言"
    # 外语标记
    lang_map = {
        "英文": ("英文",),
        "韩语": ("韩语",),
        "日语": ("日语", "霓虹"),
        "印尼": ("印尼",),
    }
    for lang, keywords in lang_map.items():
        for kw in keywords:
            if kw in trait:
                return lang
    return "中文"


def _parse_trait_age(info_cell):
    """从音色信息列中提取特质和年龄"""
    trait = None
    age = None
    for p in info_cell.find_all("p"):
        text = p.get_text(strip=True)
        if text.startswith("特质"):
            trait = text.split("：", 1)[-1].strip()
        elif text.startswith("年龄"):
            age = text.split("：", 1)[-1].strip()
    return trait, age


def parse_html_audio(html_path, output_json):
    with open(html_path, "r", encoding="utf-8") as f:
        html_content = f.read()

    soup = BeautifulSoup(html_content, "html.parser")
    tbody = soup.select_one("table.table tbody.tbody")
    if not tbody:
        print("❌ 未找到表格体")
        return

    result = []
    current_scenario = None
    rows = tbody.find_all("tr")

    # 跳过表头行（第一行）
    for row in rows[1:]:
        cells = row.find_all("td")
        if not cells:
            continue

        if len(cells) == 5:
            # 本组第一行：场景 + 音色信息 + 特性 + audio + 地域
            current_scenario = cells[0].get_text(strip=True)
            info_cell = cells[1]
        else:
            # 后续行：音色信息 + 特性 + audio + 地域
            info_cell = cells[0]

        trait, age = _parse_trait_age(info_cell)

        audio = row.find("audio")
        if audio:
            name = audio.get("name")
            src = audio.get("src")
            if name and src:
                entry = {
                    "scenario": current_scenario,
                    "name": name,
                    "audio": src,
                    "lang": _infer_lang(trait),
                }
                if trait:
                    entry["trait"] = trait
                if age:
                    entry["age"] = age
                result.append(entry)

    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"✅ 解析完成，共 {len(result)} 条，已保存到 {output_json}")


if __name__ == "__main__":
    parse_html_audio(
        html_path="src/temp.html",
        output_json="src/audio_list.json"
    )
