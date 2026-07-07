import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter/services.dart';

/// SentencePiece 分词器，对应 Python 的 spm.SentencePieceProcessor。
///
/// Python:
/// ```python
/// self.sp_model = spm.SentencePieceProcessor(model_file=str(tokenizer_path))
/// def encode_text(self, text: str) -> list[int]:
///     return [int(token_id) for token_id in self.sp_model.encode(str(text or ""), out_type=int)]
/// ```
class MossTokenizer {
  SentencePieceTokenizer? _tokenizer;

  /// 从 assets 中的 tokenizer.model 加载分词器
  Future<void> load({required String assetPath}) async {
    final raw = await rootBundle.load(assetPath);
    final bytes = raw.buffer.asUint8List();
    // Python: spm.SentencePieceProcessor(model_file=path)
    // 不附加 BOS/EOS（MOSS 用 im_start_token_id / im_end_token_id 控制）
    _tokenizer = SentencePieceTokenizer.fromBytes(
      bytes,
      config: const SentencePieceConfig(
        addBosToken: false,
        addEosToken: false,
      ),
    );
  }

  /// encode_text — 将文本编码为 token ID 列表。
  /// Python: sp_model.encode(str(text or ""), out_type=int)
  List<int> encodeText(String text) {
    final encoding = _tokenizer!.encode(text);
    return encoding.ids.toList();
  }

  /// count_text_tokens — 统计文本对应的 token 数量。
  /// Python: len(self.encode_text(text))
  int countTokens(String text) {
    return encodeText(text).length;
  }

  /// 将文本按 token 预算切分为块，模仿 Python OnnxTtsRuntime.split_voice_clone_text。
  /// 优先在标点处切分，兜底用二分搜索找字符级切分点。
  List<String> splitTextByTokenBudget(String text, {int maxTokens = 75}) {
    final t = text.trim();
    if (t.isEmpty || countTokens(t) <= maxTokens) return [t];

    final chunks = <String>[];
    String remaining = t;

    while (remaining.isNotEmpty) {
      if (countTokens(remaining) <= maxTokens) {
        chunks.add(remaining);
        break;
      }

      // 二分搜索找到不超过 maxTokens 的最长前缀
      int low = 1, high = remaining.length, bestPos = 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        if (countTokens(remaining.substring(0, mid)) <= maxTokens) {
          bestPos = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      // 往前找最近的标点/空格作为切分点
      int adjusted = bestPos;
      final start = bestPos > 25 ? bestPos - 25 : 0;
      for (int i = bestPos - 1; i >= start; i--) {
        final c = remaining.codeUnitAt(i);
        // 句子终结标点: 。！？；：
        if (c == 0x3002 || c == 0xFF01 || c == 0xFF1F ||
            c == 0xFF1B || c == 0xFF1A ||
            c == 0x002E || c == 0x0021 || c == 0x003F ||
            c == 0x003B || c == 0x003A) {
          adjusted = i + 1;
          break;
        }
        // 子句/停顿标点: ，,、 和空格
        if (c == 0xFF0C || c == 0x002C || c == 0x3001 || c == 0x0020) {
          adjusted = i + 1;
          break;
        }
      }

      final part = remaining.substring(0, adjusted).trim();
      if (part.isNotEmpty) chunks.add(part);
      remaining = remaining.substring(adjusted).trim();
    }

    return chunks.length > 1 ? chunks : [text];
  }
}
