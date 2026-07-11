import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/i18n_service.dart';
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
            title: I18n.t('settings.currentModel'),
            description: I18n.t('settings.modelDesc'),
            child: Column(
              children: [
                _infoRow(context, I18n.t('settings.modelName'), 'MOSS-TTS-Nano-100M'),
                const SizedBox(height: kS8),
                _infoRow(context, I18n.t('settings.modelArch'), I18n.t('settings.modelArchValue')),
                const SizedBox(height: kS8),
                _infoRow(context, I18n.t('settings.modelParams'), I18n.t('settings.modelParamsValue')),
                const SizedBox(height: kS8),
                _infoRow(context, I18n.t('settings.modelLangs'), I18n.t('settings.modelLangsValue')),
                const SizedBox(height: kS8),
                _infoRow(context, I18n.t('settings.modelSampleRate'), I18n.t('settings.modelSampleRateValue')),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: I18n.t('settings.repoUrl'),
            description: I18n.t('settings.repoDesc'),
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
            text: I18n.t('settings.copy'),
            icon: Icons.content_copy,
            type: MossButtonType.ghost,
            color: color,
            height: 28,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.t('settings.copied')), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}
