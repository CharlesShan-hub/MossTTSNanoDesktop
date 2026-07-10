import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/components.dart';

class ModelSettings extends StatelessWidget {
  final Color color;
  const ModelSettings({required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '当前模型',
            description: 'MOSS-TTS-Nano 是一个轻量级的语音合成模型',
            child: Column(
              children: [
                _infoRow(context, '模型名称', 'MOSS-TTS-Nano-100M'),
                const SizedBox(height: kS8),
                _infoRow(context, '架构类型', 'Attention-based AR Decoder + AudioCodec'),
                const SizedBox(height: kS8),
                _infoRow(context, '参数量', '约 100M'),
                const SizedBox(height: kS8),
                _infoRow(context, '支持语言', '中文 / English'),
                const SizedBox(height: kS8),
                _infoRow(context, '采样率', '48000 Hz'),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '开源地址',
            description: '欢迎 Star & Fork',
            child: _GitHubLink(color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = MossTheme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: kTextBase, color: theme.textSecondary)),
        ),
        Text(value, style: TextStyle(fontSize: kTextBase, color: theme.textPrimary)),
      ],
    );
  }
}

class _GitHubLink extends StatelessWidget {
  final Color color;
  const _GitHubLink({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    const url = 'https://github.com/OpenMOSS/MOSS-TTS-Nano';
    return Container(
      padding: const EdgeInsets.all(kS12),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: color),
          const SizedBox(width: kS8),
          Expanded(
            child: Text(url,
              style: TextStyle(fontSize: kTextBase, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: kS8),
          MossButton(
            text: '复制',
            icon: Icons.content_copy,
            type: MossButtonType.ghost,
            color: color,
            height: 28,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已复制链接'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}
