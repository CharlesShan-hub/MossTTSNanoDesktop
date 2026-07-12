import 'package:flutter/material.dart';

import '../../models/text_rule.dart';
import '../../services/i18n_service.dart';
import '../../services/text_rule_service.dart';
import '../theme/components.dart';

class TextRulesSettings extends StatefulWidget {
  final Color color;
  const TextRulesSettings({super.key, required this.color});

  @override
  State<TextRulesSettings> createState() => _TextRulesSettingsState();
}

class _TextRulesSettingsState extends State<TextRulesSettings> {
  List<TextRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await TextRuleService.loadRules();
    if (mounted) setState(() => _rules = rules);
  }

  Future<void> _add() async {
    final rule = await _editRule(TextRule(from: '', to: ''));
    if (rule != null) {
      await TextRuleService.addRule(rule);
      await _load();
    }
  }

  Future<void> _edit(int index) async {
    final rule = await _editRule(_rules[index]);
    if (rule != null) {
      await TextRuleService.updateRule(index, rule);
      await _load();
    }
  }

  Future<void> _delete(int index) async {
    await TextRuleService.deleteRule(index);
    await _load();
  }

  Future<TextRule?> _editRule(TextRule original) async {
    final fromCtrl = TextEditingController(text: original.from);
    final toCtrl = TextEditingController(text: original.to);
    final ok = await showMossDialog<bool>(
      context: context,
      title: original.from.isEmpty ? I18n.t('settings.addRule') : I18n.t('settings.editRule'),
      accentColor: widget.color,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        MossTextField(controller: fromCtrl, hintText: I18n.t('settings.ruleFromHint')),
        const SizedBox(height: kS8),
        MossTextField(controller: toCtrl, hintText: I18n.t('settings.ruleToHint')),
      ]),
      confirmText: I18n.t('settings.save'),
      cancelText: I18n.t('voices.cancel'),
      onConfirm: () async {
        if (fromCtrl.text.isEmpty) return false;
        return true;
      },
    );
    fromCtrl.dispose();
    toCtrl.dispose();
    if (ok != true) return null;
    return TextRule(from: fromCtrl.text, to: toCtrl.text, enabled: original.enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.find_replace, size: 20, color: widget.color),
          const SizedBox(width: kS8),
          Text(I18n.t('settings.textRules'), style: TextStyle(fontSize: kTextLg, color: theme.textPrimary, fontWeight: FontWeight.w500)),
          const Spacer(),
          MossIconButton(
            icon: Icons.add, tooltip: I18n.t('settings.addRule'),
            onTap: _add, color: widget.color,
          ),
        ]),
        const SizedBox(height: kS12),
        Text(I18n.t('settings.textRulesDesc'), style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
        const SizedBox(height: kS12),
        Expanded(
          child: _rules.isEmpty
              ? Center(child: Text(I18n.t('settings.noRules'), style: TextStyle(color: theme.textMuted)))
              : ListView.builder(
                  itemCount: _rules.length,
                  itemBuilder: (_, i) => _ruleTile(i),
                ),
        ),
      ],
    );
  }

  Widget _ruleTile(int i) {
    final theme = MossTheme.of(context);
    final rule = _rules[i];
    return Container(
      margin: const EdgeInsets.only(bottom: kS6),
      padding: const EdgeInsets.symmetric(horizontal: kS12, vertical: kS8),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await TextRuleService.updateRule(i, rule.copyWith(enabled: !rule.enabled));
              await _load();
            },
            child: Icon(
              rule.enabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18, color: rule.enabled ? widget.color : theme.textMuted,
            ),
          ),
          const SizedBox(width: kS6),
          // from
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kS6, vertical: kS4),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(color: theme.border),
              ),
              child: Text(rule.from.isEmpty ? '(empty)' : rule.from, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: kTextSm, color: rule.enabled ? theme.textPrimary : theme.textMuted,
                      fontFamily: 'monospace')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kS4),
            child: Icon(Icons.arrow_forward, size: 12, color: theme.textMuted),
          ),
          // to
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kS6, vertical: kS4),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(color: widget.color.withValues(alpha: 0.2)),
              ),
              child: Text(rule.to.isEmpty ? '(empty)' : rule.to, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: kTextSm, color: rule.enabled ? widget.color : theme.textMuted,
                      fontFamily: 'monospace')),
            ),
          ),
          const Spacer(),
          MossIconButton(
            icon: Icons.edit, tooltip: I18n.t('settings.editRule'),
            onTap: () => _edit(i), color: theme.textSecondary,
          ),
          const SizedBox(width: kS4),
          MossIconButton(
            icon: Icons.delete_outline, tooltip: I18n.t('settings.deleteRule'),
            onTap: () => _delete(i), color: theme.error,
          ),
        ],
      ),
    );
  }
}
