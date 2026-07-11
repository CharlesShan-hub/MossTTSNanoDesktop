import 'package:flutter/material.dart';

import '../services/i18n_service.dart';
import 'theme/components.dart';
import 'settings/model_settings.dart';
import 'settings/param_settings.dart';
import 'settings/api_settings.dart';
import 'settings/appearance_settings.dart';
import 'settings/shortcuts_settings.dart';

class SettingsPage extends StatefulWidget {
  final ColorSeries theme;
  final VoidCallback? onThemeToggle;
  const SettingsPage({super.key, required this.theme, this.onThemeToggle});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _navIndex = 0;

  List<(String, IconData)> get _navItems => [
    (I18n.t('settings.navModel'), Icons.memory),
    (I18n.t('settings.navParams'), Icons.tune),
    (I18n.t('settings.navApi'), Icons.cloud),
    (I18n.t('settings.navAppearance'), Icons.palette_outlined),
    (I18n.t('settings.navShortcuts'), Icons.keyboard),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, kS8),
              child: Text(I18n.t('settings.pageTitle'), style: TextStyle(
                fontSize: kTextBase, fontWeight: FontWeight.w600,
                color: theme.textSecondary, letterSpacing: 0.5,
              )),
            ),
            ...List.generate(_navItems.length, (i) {
              final (label, icon) = _navItems[i];
              return MossSettingsNavItem(
                label: label,
                icon: icon,
                active: _navIndex == i,
                color: widget.theme.main,
                onTap: () => setState(() => _navIndex = i),
              );
            }),
          ],
        ),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: const EdgeInsets.all(kS20),
          child: _buildContent(),
        )),
      ],
    );
  }

  Widget _buildContent() {
    final accent = widget.theme.main;
    switch (_navIndex) {
      case 0: return ModelSettings(color: accent);
      case 1: return ParamSettings(color: accent);
      case 2: return ApiServiceSettings(color: accent);
      case 3: return AppearanceSettings(color: accent, onThemeToggle: widget.onThemeToggle);
      case 4: return ShortcutsSettings();
      default: return const SizedBox.shrink();
    }
  }
}
