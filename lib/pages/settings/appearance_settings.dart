import 'package:flutter/material.dart';
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
            title: '主题',
            description: '切换亮色/暗色模式',
            child: MossSettingsRow(
              label: '主题模式',
              control: Row(
                children: [
                  _themeChip(context, 'light', '亮色', Icons.light_mode),
                  const SizedBox(width: kS8),
                  _themeChip(context, 'dark', '暗色', Icons.dark_mode),
                ],
              ),
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '语言',
            description: '界面语言设置',
            child: MossSettingsRow(
              label: '语言',
              control: MossDropdown<String>(
                value: SettingsService.language,
                onChanged: (v) {
                  if (v != null) SettingsService.setLanguage(v);
                },
                placeholder: '选择语言',
                color: color,
                items: const [
                  DropdownItem('中文', 'zh'),
                  DropdownItem('English', 'en'),
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
