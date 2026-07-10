import 'package:flutter/material.dart';
import 'theme.dart';
import 'moss_theme.dart';

// ─── MossButton ───────────────────────────────────────────────────────────
enum MossButtonType { primary, secondary, ghost }

class MossButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final MossButtonType type;
  final IconData? icon;
  final double height;
  final Color? color;
  final bool loading;

  const MossButton({
    super.key,
    required this.text,
    this.onTap,
    this.type = MossButtonType.primary,
    this.icon,
    this.height = 32,
    this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final disabled = onTap == null || loading;
    Color bgColor;
    Color textColor;
    Color borderColor;

    final accent = color ?? theme.accent;

    switch (type) {
      case MossButtonType.primary:
        bgColor = disabled ? accent.withValues(alpha: 0.5) : accent;
        textColor = Colors.white;
        borderColor = Colors.transparent;
      case MossButtonType.secondary:
        bgColor = disabled ? theme.surface.withValues(alpha: 0.5) : theme.surface;
        textColor = disabled ? theme.textMuted : theme.textPrimary;
        borderColor = theme.border;
      case MossButtonType.ghost:
        bgColor = Colors.transparent;
        textColor = disabled ? theme.textMuted : accent;
        borderColor = Colors.transparent;
    }

    return SizedBox(
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          splashColor: textColor.withValues(alpha: 0.15),
          highlightColor: textColor.withValues(alpha: 0.08),
          child: Container(
            decoration: type == MossButtonType.secondary
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    border: Border.all(color: borderColor),
                  )
                : null,
            padding: EdgeInsets.symmetric(horizontal: icon != null ? kS10 : kS16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  if (loading && icon != null) const SizedBox(width: 6),
                  if (icon != null && !loading) ...[
                    Icon(icon, size: 14, color: textColor),
                    const SizedBox(width: 4),
                  ],
                  Text(text, style: TextStyle(fontSize: kTextBase, color: textColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MossIconButton ───────────────────────────────────────────────────────
class MossIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const MossIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final isActive = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusSm),
        splashColor: (color ?? theme.textSecondary).withValues(alpha: 0.15),
        highlightColor: (color ?? theme.textSecondary).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(kS4),
          child: Icon(icon, size: size, color: isActive ? (color ?? theme.textSecondary) : theme.textMuted),
        ),
      ),
    );
  }
}
