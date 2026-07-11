import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MOSS-TTS 设计系统 — 颜色 · 间距 · 字体 · 圆角
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 颜色令牌 ──────────────────────────────────────────────────────────────
// 主色
const kAccent = Color(0xFF4A7DA8);
const kAccentLight = Color(0xFF6B9FC8);
const kAccentDark = Color(0xFF2D5A82);

// 语义色
const kSuccess = Color(0xFF30D158);
const kWarning = Color(0xFFFF9F0A);
const kError   = Color(0xFFFF453A);

// 亮色模式
const kBg          = Color(0xFFF5F5F7);
const kSurface     = Colors.white;
const kSurfaceAlt  = Color(0xFFFAFAFA);
const kTextPrimary   = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kTextMuted     = Color(0xFFA1A1A6);
const kBorder      = Color(0xFFD2D2D7);

// 玻璃态
const kGlassWhite  = Color(0x5CFFFFFF);
const kGlassBg     = Color(0x2EF5F5F7);
const kGlassBorder = Color(0x14D2D2D7);
const kGlassShadow = Color(0x08000000);
const kBlurGlass   = 6.0;

// 暗色模式 — 干净冷灰，避免脏感
const kDarkBg        = Color(0xFF000000);
const kDarkSurface   = Color(0xFF262628);
const kDarkSurfaceAlt = Color(0xFF2C2C2E);
const kDarkTextPrimary   = Color(0xFFF5F5F7);
const kDarkTextSecondary = Color(0xFF8E8E93);
const kDarkTextMuted     = Color(0xFF636366);
const kDarkBorder    = Color(0xFF3A3A3C);

// ─── 色系（每个 Tab 一套） ──────────────────────────────────────────────
class ColorSeries {
  final Color light;
  final Color main;
  final Color dark;
  final Color bg;
  final Color text;

  const ColorSeries({
    required this.light,
    required this.main,
    required this.dark,
    required this.bg,
    this.text = Colors.white,
  });

  ColorSeries lerp(double t) => ColorSeries(
    light: Color.lerp(light, main, t)!,
    main: Color.lerp(main, dark, t)!,
    dark: Color.lerp(dark, dark, t)!,
    bg: Color.lerp(bg, bg, t)!,
  );
}

// 蓝 —— 单次生成
const kBlue = ColorSeries(
  light: Color(0xFF7BAFCF),
  main:  Color(0xFF4A7DA8),
  dark:  Color(0xFF2D5A82),
  bg:    Color(0xFFE8F1F8),
);

// 绿 —— 有声书
const kGreen = ColorSeries(
  light: Color(0xFF7BC89A),
  main:  Color(0xFF4A9E62),
  dark:  Color(0xFF2D7D42),
  bg:    Color(0xFFE6F5EC),
);

// 紫 —— 音色管理
const kPurple = ColorSeries(
  light: Color(0xFFB594CF),
  main:  Color(0xFF8A5FAD),
  dark:  Color(0xFF6A3F8D),
  bg:    Color(0xFFF2EBF7),
);

// 橙 —— 设置
const kOrange = ColorSeries(
  light: Color(0xFFE8B060),
  main:  Color(0xFFD48C30),
  dark:  Color(0xFFB06C10),
  bg:    Color(0xFFFCF2E3),
);

// Tab 索引 → 色系
const kTabColorSeries = [kBlue, kGreen, kPurple, kOrange];
final kTabColors = [kBlue.main, kGreen.main, kPurple.main, kOrange.main];

// ─── 间距系统 (4px 网格) ──────────────────────────────────────────────────
const kS2  = 2.0;
const kS4  = 4.0;
const kS6  = 6.0;
const kS8  = 8.0;
const kS10 = 10.0;
const kS12 = 12.0;
const kS16 = 16.0;
const kS20 = 20.0;
const kS24 = 24.0;
const kS32 = 32.0;

// ─── 字体系统 ─────────────────────────────────────────────────────────────
const kFontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';
const kTextXs  = 10.0;
const kTextSm  = 11.0;
const kTextBase = 12.0;
const kTextMd  = 13.0;
const kTextLg  = 15.0;
const kTextXl  = 17.0;

// ─── 圆角 ─────────────────────────────────────────────────────────────────
const kRadiusSm  = 4.0;
const kRadiusMd  = 6.0;
const kRadiusLg  = 8.0;
const kRadiusXl  = 12.0;
