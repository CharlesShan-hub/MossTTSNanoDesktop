import 'package:flutter/material.dart';

import '../../models/voice.dart';
import '../../../services/i18n_service.dart';
import '../theme/components.dart';

Color _langBadgeColor(String lang) {
  const colors = [
    Color(0xFF4A7DA8), Color(0xFF4A9E62), Color(0xFFD48C30),
    Color(0xFF8A5FAD), Color(0xFFC06040), Color(0xFF3D8A8A),
  ];
  return colors[lang.hashCode.abs() % colors.length];
}

/// 音色卡片
class VoiceCard extends StatelessWidget {
  final Voice voice;
  final bool isPlaying;
  final bool isHidden;
  final Color themeAccent;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleHidden;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VoiceCard({
    super.key,
    required this.voice,
    required this.isPlaying,
    required this.isHidden,
    required this.themeAccent,
    this.onPlay,
    this.onToggleHidden,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return MossGlassCard(
      height: 130,
      padding: const EdgeInsets.all(kS12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MossBadge(text: voice.language, color: _langBadgeColor(voice.language)),
            ],
          ),
          const SizedBox(height: kS6),
          Text(voice.name, style: TextStyle(fontSize: kTextMd, fontWeight: FontWeight.w500, color: theme.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (voice.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: kS2),
              child: Text(voice.description, style: TextStyle(fontSize: kTextSm, color: theme.textMuted),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const Expanded(child: SizedBox.shrink()),
          Row(
            children: [
              MossIconButton(
                icon: isPlaying ? Icons.stop : Icons.play_arrow,
                tooltip: I18n.t('voices.play'),
                onTap: onPlay,
                color: isPlaying ? themeAccent : null,
              ),
              const SizedBox(width: kS8),
              MossIconButton(
                icon: isHidden ? Icons.visibility_off : Icons.visibility_outlined,
                tooltip: isHidden ? I18n.t('voices.unhide') : I18n.t('voices.hide'),
                onTap: onToggleHidden,
                color: isHidden ? themeAccent.withValues(alpha: 0.5) : null,
              ),
              const SizedBox(width: kS8),
              MossIconButton(icon: Icons.edit_outlined, tooltip: I18n.t('voices.edit'), onTap: onEdit),
              const SizedBox(width: kS8),
              MossIconButton(icon: Icons.delete_outline, tooltip: I18n.t('voices.delete'), onTap: onDelete, color: theme.error),
            ],
          ),
        ],
      ),
    );
  }
}
