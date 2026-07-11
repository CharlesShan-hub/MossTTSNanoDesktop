import 'package:flutter/material.dart';
import '../../services/i18n_service.dart';
import '../../services/settings_service.dart';
import '../theme/components.dart';

class AppearanceSettings extends StatelessWidget {
  final Color color;
  final VoidCallback? onThemeToggle;
  const AppearanceSettings({required this.color, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: I18n.t('settings.theme'),
            description: I18n.t('settings.themeDesc'),
            child: MossSettingsRow(
              label: I18n.t('settings.themeMode'),
              control: Row(
                children: [
                  _themeChip(context, 'light', I18n.t('settings.light'), Icons.light_mode),
                  const SizedBox(width: kS8),
                  _themeChip(context, 'dark', I18n.t('settings.dark'), Icons.dark_mode),
                ],
              ),
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: I18n.t('settings.language'),
            description: I18n.t('settings.langDesc2'),
            child: MossSettingsRow(
              label: I18n.t('settings.language'),
              control: MossDropdown<String>(
                value: SettingsService.language,
                onChanged: (v) {
                  if (v != null) {
                    SettingsService.setLanguage(v);
                    I18n.load(v);
                  }
                },
                placeholder: I18n.t('settings.langSelect'),
                color: color,
                items: [
                  DropdownItem(I18n.t('settings.zh'), 'zh'),
                  DropdownItem(I18n.t('settings.en'), 'en'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeChip(BuildContext context, String mode, String label, IconData icon) {
    final theme = MossTheme.of(context);
    final active = SettingsService.themeMode == mode;
    final accent = color;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SettingsService.setThemeMode(mode);
          onThemeToggle?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: kS8),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.15) : theme.bg,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: active ? accent : theme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? accent : theme.textSecondary),
              const SizedBox(width: kS6),
              Text(label, style: TextStyle(
                fontSize: kTextBase,
                color: active ? accent : theme.textPrimary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
