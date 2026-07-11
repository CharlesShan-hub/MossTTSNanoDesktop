import 'package:flutter/material.dart';
import '../../services/i18n_service.dart';
import '../theme/components.dart';

class ShortcutsSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final shortcuts = [
      ('⌘ + Enter', I18n.t('single.shortcutGenerate')),
      ('⌘ + S', I18n.t('single.shortcutSave')),
      ('⌘ + ,', I18n.t('single.shortcutSettings')),
      ('⌘ + 1-4', I18n.t('single.shortcutTab')),
      ('⌘ + F', I18n.t('single.shortcutSearch')),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: I18n.t('settings.shortcutsTitle'),
            description: I18n.t('settings.shortcutsDesc'),
            child: Column(
              children: shortcuts.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: kS8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS4),
                      decoration: BoxDecoration(
                        color: theme.bg,
                        borderRadius: BorderRadius.circular(kRadiusSm),
                        border: Border.all(color: theme.border),
                      ),
                      child: Text(s.$1, style: TextStyle(fontSize: kTextSm, color: theme.textPrimary, fontFamily: kFontFamily)),
                    ),
                    const SizedBox(width: kS12),
                    Text(s.$2, style: TextStyle(fontSize: kTextBase, color: theme.textSecondary)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
