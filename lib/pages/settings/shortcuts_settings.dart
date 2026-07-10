import 'package:flutter/material.dart';
import '../theme/components.dart';

class ShortcutsSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('⌘ + Enter', '生成语音'),
      ('⌘ + S', '保存音频'),
      ('⌘ + ,', '打开设置'),
      ('⌘ + 1-4', '切换 Tab'),
      ('⌘ + F', '搜索音色'),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '键盘快捷键',
            description: '提高操作效率的快捷键组合',
            child: Column(
              children: shortcuts.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: kS8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS4),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(kRadiusSm),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(s.$1, style: const TextStyle(fontSize: kTextSm, color: kTextPrimary, fontFamily: kFontFamily)),
                    ),
                    const SizedBox(width: kS12),
                    Text(s.$2, style: const TextStyle(fontSize: kTextBase, color: kTextSecondary)),
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
