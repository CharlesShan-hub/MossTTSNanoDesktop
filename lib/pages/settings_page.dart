import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/settings_service.dart';
import 'theme/components.dart';
import 'settings/model_settings.dart';
import 'settings/param_settings.dart';
import 'settings/api_settings.dart';
import 'settings/appearance_settings.dart';
import 'settings/shortcuts_settings.dart';

class SettingsPage extends StatefulWidget {
  final ColorSeries theme;
  const SettingsPage({super.key, required this.theme});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _navIndex = 0;

  final _navItems = const [
    ('模型信息', Icons.memory),
    ('生成参数', Icons.tune),
    ('API 服务', Icons.cloud),
    ('外观', Icons.palette_outlined),
    ('快捷键', Icons.keyboard),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, kS8),
              child: Text('设置', style: TextStyle(
                fontSize: kTextBase, fontWeight: FontWeight.w600,
                color: kTextSecondary, letterSpacing: 0.5,
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
      case 3: return AppearanceSettings(color: accent);
      case 4: return ShortcutsSettings();
      default: return const SizedBox.shrink();
    }
  }
}
