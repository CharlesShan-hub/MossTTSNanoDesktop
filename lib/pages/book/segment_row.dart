import 'package:flutter/material.dart';

import '../../models/book_project.dart';
import '../../models/voice.dart';
import '../../services/i18n_service.dart';
import '../theme/components.dart';
import 'voice_chip.dart';

/// 有声书片段行（可编辑文本）
class SegmentRow extends StatefulWidget {
  final int index;
  final BookSegment segment;
  final List<Voice> voices;
  final ColorSeries accent;
  final bool hasCache;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onVoiceChanged;
  final VoidCallback? onPlay;
  final VoidCallback onInsertAfter;
  final VoidCallback onDelete;

  const SegmentRow({
    super.key,
    required this.index,
    required this.segment,
    required this.voices,
    required this.accent,
    this.hasCache = false,
    required this.onTextChanged,
    required this.onVoiceChanged,
    this.onPlay,
    required this.onInsertAfter,
    required this.onDelete,
  });

  @override
  State<SegmentRow> createState() => _SegmentRowState();
}

class _SegmentRowState extends State<SegmentRow> {
  late TextEditingController _textCtrl;
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.segment.text);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(SegmentRow old) {
    super.didUpdateWidget(old);
    // 外部 text 变化时同步（但正在编辑时不同步，避免打断输入）
    if (widget.segment.text != old.segment.text && !_focused) {
      if (_textCtrl.text != widget.segment.text) {
        _textCtrl.text = widget.segment.text;
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _focused ? theme.surface : theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: _focused ? widget.accent.main.withValues(alpha: 0.4) : theme.border),
      ),
      padding: const EdgeInsets.all(kS12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号 + 缓存标记
          SizedBox(
            width: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  widget.hasCache ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: widget.hasCache ? widget.accent.main : theme.textMuted.withValues(alpha: 0.4),
                ),
                Text('${widget.index + 1}',
                    style: TextStyle(fontSize: kTextSm, color: theme.textMuted)),
              ],
            ),
          ),
          // 文本（可编辑）
          Expanded(
            flex: 3,
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              maxLines: null,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: I18n.t('book.editHint'),
                hintStyle: TextStyle(fontSize: kTextBase, color: theme.textMuted),
              ),
              style: TextStyle(fontSize: kTextBase, color: theme.textPrimary),
              onChanged: widget.onTextChanged,
            ),
          ),
          const SizedBox(width: kS12),
          // 音色选择 + 标签
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VoiceChip(
                  voices: widget.voices,
                  selectedTag: widget.segment.voiceId.isNotEmpty ? widget.segment.voiceId : null,
                  accent: widget.accent,
                  onSelected: widget.onVoiceChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: kS8),
          // 操作按钮
          Column(
            children: [
              MossIconButton(
                icon: Icons.play_arrow,
                tooltip: I18n.t('voices.play'),
                onTap: widget.onPlay,
                color: widget.onPlay != null ? widget.accent.main : theme.textMuted,
              ),
              const SizedBox(height: kS4),
              MossIconButton(
                icon: Icons.add,
                tooltip: I18n.t('book.insertAfter'),
                onTap: widget.onInsertAfter,
                color: widget.accent.main,
              ),
              const SizedBox(height: kS4),
              MossIconButton(
                icon: Icons.close,
                tooltip: I18n.t('book.remove'),
                onTap: widget.onDelete,
                color: theme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
