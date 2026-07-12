import 'package:flutter/material.dart';

import '../../models/voice.dart';
import '../../services/i18n_service.dart';
import '../theme/components.dart';

/// 片段内按角色标签选择的快捷选择器
///
/// 下拉列表列出所有可用的角色标签（旁白、配角1...），
/// 选中后 onSelected 返回标签名。
/// 此时选中音色的 ID 可通过 [firstVoiceForTag] 获取第一个匹配的音色。
class VoiceChip extends StatefulWidget {
  final List<Voice> voices;
  final String? selectedTag;      // 当前选中的标签名
  final ColorSeries accent;
  final ValueChanged<String> onSelected;  // 返回选中的标签名

  const VoiceChip({
    super.key,
    required this.voices,
    required this.selectedTag,
    required this.accent,
    required this.onSelected,
  });

  /// 获取某个标签对应的第一个可见音色 ID
  static String? firstVoiceForTag(List<Voice> voices, String tag) {
    return voices.where((v) => v.tag == tag).firstOrNull?.id;
  }

  @override
  State<VoiceChip> createState() => _VoiceChipState();
}

class _VoiceChipState extends State<VoiceChip> {
  bool _showDropdown = false;

  /// 所有标签（去重 + 无标签的归为"其他"）
  List<String> get _availableTags {
    final tags = widget.voices
        .map((v) => v.tag)
        .where((t) => t != null && t.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList()
      ..sort();
    // 如果有无标签的音色，加一个"其他"选项
    if (widget.voices.any((v) => v.tag == null || v.tag!.isEmpty)) {
      tags.add('');
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final selectedTag = widget.selectedTag;
    // 如果选中了标签，显示标签名；否则显示"其他"或无
    String chipLabel;
    if (selectedTag != null && selectedTag.isNotEmpty) {
      chipLabel = selectedTag;
    } else if (selectedTag == '') {
      chipLabel = I18n.t('book.other');
    } else {
      chipLabel = I18n.t('single.searchVoice');
    }

    return TapRegion(
      onTapOutside: (_) {
        if (_showDropdown) setState(() => _showDropdown = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showDropdown = !_showDropdown),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS6),
              decoration: BoxDecoration(
                color: widget.accent.main.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(color: widget.accent.main.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style, size: 14, color: widget.accent.main),
                  const SizedBox(width: kS4),
                  Flexible(
                    child: Text(
                      chipLabel,
                      style: TextStyle(fontSize: kTextSm, color: widget.accent.main),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: kS4),
                  Icon(Icons.arrow_drop_down, size: 16, color: widget.accent.main),
                ],
              ),
            ),
          ),
          if (_showDropdown)
            Container(
              margin: const EdgeInsets.only(top: kS4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: theme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusMd - 1),
                child: ListView(
                  shrinkWrap: true,
                  children: _buildTagItems(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTagItems() {
    final tags = _availableTags;
    return [
      for (final tag in tags)
        _tagItem(tag),
    ];
  }

  Widget _tagItem(String tag) {
    final theme = MossTheme.of(context);
    final selected = tag == widget.selectedTag;
    // 统计该标签下的音色数
    final count = tag.isEmpty
        ? widget.voices.where((v) => v.tag == null || v.tag!.isEmpty).length
        : widget.voices.where((v) => v.tag == tag).length;
    final label = tag.isEmpty ? I18n.t('book.other') : tag;

    return InkWell(
      onTap: () {
        widget.onSelected(tag);
        setState(() => _showDropdown = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS8),
        decoration: BoxDecoration(
          color: selected ? widget.accent.main.withValues(alpha: 0.10) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? widget.accent.main : theme.textMuted,
              ),
            ),
            const SizedBox(width: kS8),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: kTextSm,
                      color: selected ? widget.accent.main : theme.textPrimary)),
            ),
            Text('$count',
                style: TextStyle(fontSize: kTextXs, color: theme.textMuted)),
          ],
        ),
      ),
    );
  }
}
