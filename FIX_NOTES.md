# Dart TTS 质量修复记录

## 背景

将 Python 版 MOSS-TTS-Nano 移植到 Flutter/Dart 时，输出音频质量明显低于 Python 版。经过系统排查，共发现 5 个问题。

---

## 问题 1：文本未分块

**症状**：长文本合成不完整，音频在中间截断。

**原因**：Python 按 token 预算将长文本分块（默认每块 ≤75 tokens），逐块推理后拼接。Dart 版没有分块逻辑。

**修复**：实现 `splitTextByTokenBudget`，模仿 Python 的 `split_voice_clone_text`：
1. 先按句末标点（。！？；）切分句子
2. 再按子句标点（，、；：）切分
3. 合并成 ≤maxTokens 的块

---

## 问题 2：next_row 填充值错误

**症状**：decode step 输入异常，导致后续帧质量下降。

**原因**：Python 用 `np.full(row_width, audio_pad_token_id)` 初始化 next_row（填 1024），Dart 的 `Int32List(n)` 默认填 0。0 在 codebook 中是有效 token，导致模型读到错误输入。

**修复**：在创建 `Int32List` 后用 `audio_pad_token_id`（1024）填充。

---

## 问题 3：OrtValue 内存泄漏

**症状**：长文本生成时 C 侧内存耗尽，应用崩溃（Lost connection to device）。

**原因**：ONNX Runtime 的 OrtValue 是 C 对象，Dart GC 无法自动回收。每步 decode 产生约 24 个 KV cache OrtValue，累积几百步后 C 侧内存耗尽 → 复用已释放内存 → 读到垃圾数据（噪声帧）→ 崩溃。

**修复**：每步 decode 后显式释放旧 KV cache 的 OrtValue，同时保存新输出。

---

## 问题 4：随机数生成器不兼容

**症状**：Dart 和 Python 对同一文本输出不同，含杂音。

**原因**：Dart 用 `Random(1234)`，Python 用 `np.random.default_rng(1234)`（PCG64 DXSM）。不同 RNG → 不同采样值 → 不同帧序列。

**修复**：用 Python 预计算 375 步 × 17 个随机值（assistant_random_u + 16 audio_random_u），保存为 JSON 资产文件。Dart 加载后按索引使用，与 Python 完全一致。

---

## 问题 5：分词器不兼容

**症状**：中文标点导致分词不同，推理路径完全偏离。

**原因**：`dart_sentencepiece_tokenizer` 和 Python `sentencepiece` 对全角标点（U+FF00+）的 BPE 合并优先级不同。
- Python 将"，我"合并为 1 个 token [10364]
- Dart 拆分为 3 个 token [254, 203, 155]

**修复**（两步法）：
1. **替换**：分词前将中文全角标点映射为 ASCII 半角（，→,  。→.  ！→!  ？→? 等）
2. **回映射**：分词后将英文句号 token [10380] 映射回中文句号 token [10382]

Python 对 ASCII 标点和中文标点分词结果相同，所以替换后 Dart 的 token 序列就与 Python 一致了。

---

## 最终效果

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 长文本合成 | 截断 | 完整 |
| 应用崩溃 | 频繁 | 无 |
| 短文本质量 | 差 | 与 Python 一致 |
| 长文本质量 | 差 | 接近 Python |
| 中文标点 | 分词错误 | 正确分词 |
| 帧数匹配度 | 差异大 | ±5% 以内 |
