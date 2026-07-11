import 'package:flutter/material.dart';

import '../../models/voice.dart';
import '../../services/settings_service.dart';
import '../../../services/i18n_service.dart';
import '../theme/components.dart';

/// 可搜索的音色选择器
class VoiceSelector extends StatefulWidget {
  final List<Voice> voices;
  final String? selectedVoiceId;
  final ValueChanged<String> onSelected;
  final Color accent;

  const VoiceSelector({
    super.key,
    required this.voices,
    required this.selectedVoiceId,
    required this.onSelected,
    required this.accent,
  });

  @override
  State<VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<VoiceSelector> {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showDropdown = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Voice> get _filtered {
    if (_queryCtrl.text.trim().isEmpty) return widget.voices;
    final q = _queryCtrl.text.trim().toLowerCase();
    return widget.voices
        .where((v) => v.name.toLowerCase().contains(q) || v.language.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final accent = widget.accent;
    final selectedName = widget.selectedVoiceId != null
        ? widget.voices.where((v) => v.id == widget.selectedVoiceId).firstOrNull?.name
        : null;

    return TapRegion(
      onTapOutside: (_) {
        if (_showDropdown) setState(() => _showDropdown = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _queryCtrl,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: selectedName ?? I18n.t('single.searchVoice'),
              hintStyle: TextStyle(fontSize: kTextBase, color: theme.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS8),
              filled: true,
              fillColor: accent.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: accent.withValues(alpha: 0.20)),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent.withValues(alpha: 0.20)),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent),
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
            ),
            style: TextStyle(fontSize: kTextBase, color: theme.textPrimary),
            onChanged: (_) => setState(() {
              if (!_showDropdown) _showDropdown = true;
            }),
            onTap: () => setState(() => _showDropdown = true),
          ),
          const SizedBox(height: kS6),
          if (_showDropdown && _filtered.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: theme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusMd - 1),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final v = _filtered[i];
                    return _item(v, v.id == widget.selectedVoiceId, accent, theme);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(Voice v, bool selected, Color accent, MossThemeData theme) {
    return InkWell(
      onTap: () {
        widget.onSelected(v.id);
        _queryCtrl.text = v.name;
        _queryCtrl.selection = TextSelection.collapsed(offset: v.name.length);
        _focusNode.unfocus();
        setState(() => _showDropdown = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : null,
        ),
        child: Row(
          children: [
            if (v.id == SettingsService.defaultVoiceId)
              Icon(Icons.star, size: 10, color: accent)
            else
              const SizedBox(width: 10),
            const SizedBox(width: kS4),
            Expanded(
              child: Text(v.name, style: TextStyle(
                fontSize: kTextBase,
                color: selected ? accent : theme.textPrimary,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
