import 'package:flutter/material.dart';

import '../../../services/i18n_service.dart';
import '../theme/components.dart';

/// 底部控制栏 — 空闲/进度/播放三种状态
class IdleBar extends StatelessWidget {
  final String textLength;
  final bool canGenerate;
  final VoidCallback? onGenerate;
  const IdleBar({
    super.key,
    required this.textLength,
    required this.canGenerate,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Row(
      children: [
        Text(textLength, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
        const Spacer(),
        MossButton(
          text: I18n.t('single.generate'),
          icon: Icons.play_arrow,
          onTap: canGenerate ? onGenerate : null,
        ),
        const SizedBox(width: kS8),
        Text(I18n.t('single.shortcut'), style: TextStyle(fontSize: kTextSm, color: theme.textMuted)),
      ],
    );
  }
}

class ProgressBar extends StatelessWidget {
  final String status;
  final Color themeColor;
  const ProgressBar({super.key, required this.status, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 2),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: themeColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(themeColor),
            minHeight: 2,
          ),
        ),
        const SizedBox(height: kS8),
        Row(
          children: [
            Icon(Icons.hourglass_bottom, size: 12, color: theme.textSecondary),
            const SizedBox(width: kS6),
            Expanded(
              child: Text(status, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary),
                overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: themeColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PlaybackBar extends StatelessWidget {
  final bool playing;
  final String posText;
  final String durText;
  final double sliderValue;
  final Color themeColor;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSliderChange;
  final VoidCallback? onSave;
  final VoidCallback? onGenerate;

  const PlaybackBar({
    super.key,
    required this.playing,
    required this.posText,
    required this.durText,
    required this.sliderValue,
    required this.themeColor,
    this.onPlayPause,
    this.onSliderChange,
    this.onSave,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Row(
      children: [
        MossIconButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: playing ? 'Pause' : 'Play',
          onTap: onPlayPause,
          color: themeColor, size: 20,
        ),
        const SizedBox(width: kS8),
        Text(posText, style: TextStyle(fontSize: kTextXs, color: theme.textSecondary)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: themeColor,
              inactiveTrackColor: theme.border,
              thumbColor: themeColor,
              overlayColor: themeColor.withValues(alpha: 0.1),
            ),
            child: Slider(value: sliderValue, onChanged: onSliderChange ?? (_) {}),
          ),
        ),
        Text(durText, style: TextStyle(fontSize: kTextXs, color: theme.textSecondary)),
        const SizedBox(width: kS8),
        MossButton(text: I18n.t('single.save'), icon: Icons.save_alt, type: MossButtonType.secondary, onTap: onSave),
        const SizedBox(width: kS8),
        MossButton(text: I18n.t('single.generate'), icon: Icons.play_arrow, onTap: onGenerate),
      ],
    );
  }
}
