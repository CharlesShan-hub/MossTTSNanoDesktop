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

  /// 常见中文标点 → 英文标点映射。
  /// dart_sentencepiece_tokenizer 对中文全角标点分词不准确，
  /// 而 Python 对中英文标点编码结果相同，所以先做替换。
  static final _punctMap = <int, int>{
    0x3001: 0x2C,  // 、 → ,
    0x3002: 0x2E,  // 。 → .
    0xFF0C: 0x2C,  // ， → ,
    0xFF01: 0x21,  // ！ → !
    0xFF1F: 0x3F,  // ？ → ?
    0xFF1B: 0x3B,  // ； → ;
    0xFF1A: 0x3A,  // ： → :
    0xFF08: 0x28,  // （ → (
    0xFF09: 0x29,  // ） → )
    0xFF5E: 0x7E,  // ～ → ~
    0x2018: 0x27,  // ‘ → '
    0x2019: 0x27,  // ’ → '
    0x201C: 0x22,  // “ → "
    0x201D: 0x22,  // ” → "
    0x2014: 0x2D,  // — → -
    0x2026: 0x2E,  // … → .
    0x3003: 0x22,  // 〃 → "
    0x00B7: 0x2D,  // · → -
  };

  /// encode_text — 将文本编码为 token ID 列表。
  /// Python: sp_model.encode(str(text or ""), out_type=int)
  List<int> encodeText(String text) {
    // 先替换中文标点为英文，避免 dart_sentencepiece_tokenizer 分词错误
    final normalized = String.fromCharCodes(text.runes.map((r) => _punctMap[r] ?? r));
    final encoding = _tokenizer!.encode(normalized);
    final ids = encoding.ids.toList();
    // 将替换产生的英文标点 token 映射回中文标点 token，与 Python 一致
    final Map<int, int> tokenRemap = {
      10380: 10382,  // . → 。
    };
    return ids.map((id) => tokenRemap[id] ?? id).toList();
  }

  /// count_text_tokens — 统计文本对应的 token 数量。
  /// Python: len(self.encode_text(text))
  int countTokens(String text) {
    return encodeText(text).length;
  }

  /// 将文本按 token 预算切分为块，模仿 Python OnnxTtsRuntime.split_voice_clone_text。
  /// Python 策略：先按句末标点（。！？；）切分句子，再按子句标点（，、；：）切分，
  /// 最后合并成 ≤maxTokens 的块。保证块边界在句末。
  List<String> splitTextByTokenBudget(String text, {int maxTokens = 75}) {
    final t = text.trim();
    if (t.isEmpty || countTokens(t) <= maxTokens) return [t];

    // 1. 按句子终结标点切分
    final sentenceEnd = {0x3002, 0xFF01, 0xFF1F, 0xFF1B}; // 。！？；
    final clauseEnd = {0xFF0C, 0x3001, 0xFF1B, 0xFF1A, 0x002C, 0x0020}; // ，、；：, 空格
    final closing = {0x0022, 0x0027, 0x2019, 0x201D, 0xFF09, 0x300B, 0x3011}; // 闭合引号括号

    List<String> splitByPunct(String s, Set<int> punct) {
      final result = <String>[];
      final buf = <int>[];
      for (var i = 0; i < s.length; i++) {
        final code = s.codeUnitAt(i);
        buf.add(code);
        if (punct.contains(code)) {
          while (i + 1 < s.length && closing.contains(s.codeUnitAt(i + 1))) {
            i++;
            buf.add(s.codeUnitAt(i));
          }
          result.add(String.fromCharCodes(buf).trim());
          buf.clear();
        }
      }
      if (buf.isNotEmpty) result.add(String.fromCharCodes(buf).trim());
      return result.where((s) => s.isNotEmpty).toList();
    }

    // 先按句末标点拆
    var pieces = splitByPunct(t, sentenceEnd);
    if (pieces.length <= 1) {
      // 没有句末标点，按子句标点拆
      pieces = splitByPunct(t, clauseEnd);
    }

    // 2. 合并成 ≤maxTokens 的块
    final chunks = <String>[];
    String current = '';
    for (final piece in pieces) {
      final candidate = current.isEmpty ? piece : '$current $piece';
      if (countTokens(candidate) <= maxTokens) {
        current = candidate;
      } else {
        if (current.isNotEmpty) chunks.add(current);
        current = piece;
      }
    }
    if (current.isNotEmpty) chunks.add(current);

    return chunks.length > 1 ? chunks : [t];
  }
}
