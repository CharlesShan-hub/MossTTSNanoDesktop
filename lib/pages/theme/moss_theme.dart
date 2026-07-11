import 'package:flutter/material.dart';
import 'theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MossTheme — 动态主题数据（亮色 / 暗色）
//  ⚡ 所有组件通过 MossTheme.of(context) 获取颜色
// ═══════════════════════════════════════════════════════════════════════════════

/// 单个页面的主题色集合
class MossThemeData {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color glassBg;
  final Color glassBorder;

  const MossThemeData({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.glassBg,
    required this.glassBorder,
  });

  static const light = MossThemeData(
    bg: kBg,
    surface: kSurface,
    surfaceAlt: kSurfaceAlt,
    textPrimary: kTextPrimary,
    textSecondary: kTextSecondary,
    textMuted: kTextMuted,
    border: kBorder,
    accent: kAccent,
    success: kSuccess,
    warning: kWarning,
    error: kError,
    glassBg: kGlassWhite,
    glassBorder: kGlassBorder,
  );

  static const dark = MossThemeData(
    bg: kDarkBg,
    surface: kDarkSurface,
    surfaceAlt: kDarkSurfaceAlt,
    textPrimary: kDarkTextPrimary,
    textSecondary: kDarkTextSecondary,
    textMuted: kDarkTextMuted,
    border: kDarkBorder,
    accent: kAccentLight,
    success: kSuccess,
    warning: kWarning,
    error: kError,
    glassBg: Color(0x66000000),   // 暗色玻璃 — 纯黑低透明度，不泛白
    glassBorder: Color(0x2EFFFFFF), // 暗色半透边框
  );
}

/// InheritedWidget — 向下传递当前主题
class MossTheme extends InheritedWidget {
  final MossThemeData data;
  final bool isDark;

  const MossTheme({
    super.key,
    required this.data,
    required this.isDark,
    required super.child,
  });

  static MossThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MossTheme>()?.data ?? MossThemeData.light;
  }

  static MossTheme? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MossTheme>();
  }

  @override
  bool updateShouldNotify(MossTheme old) => data != old.data;
}
