import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MOSS-TTS 设计系统 — 颜色 · 间距 · 字体 · 组件 · 玻璃态
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

// 玻璃态 — 云朵般轻薄飘渺
const kGlassWhite  = Color(0x5CFFFFFF);   // 36% 白 — 轻薄透亮
const kGlassBg     = Color(0x2EF5F5F7);   // 18% 背景
const kGlassBorder = Color(0x14D2D2D7);   // 8%  边框 — 几乎隐形的边缘
const kGlassShadow = Color(0x08000000);   // 3%  阴影
const kBlurGlass   = 10.0;                // 模糊半径 — 柔和光晕

// 暗色模式
const kDarkBg        = Color(0xFF1C1C1E);
const kDarkSurface   = Color(0xFF2C2C2E);
const kDarkSurfaceAlt = Color(0xFF3A3A3C);
const kDarkTextPrimary   = Color(0xFFF5F5F7);
const kDarkTextSecondary = Color(0xFF98989D);
const kDarkTextMuted     = Color(0xFF636366);
const kDarkBorder    = Color(0xFF48484A);

// ─── 色系（每个 Tab 一套） ──────────────────────────────────────────────
class ColorSeries {
  final Color light;
  final Color main;
  final Color dark;
  final Color bg;       // 极浅色（背景/选中态底色）
  final Color text;     // 文字色（与深色背景搭配）

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

// ═══════════════════════════════════════════════════════════════════════════════
//  通用组件（积木）
// ═══════════════════════════════════════════════════════════════════════════════

// ─── MossButton ───────────────────────────────────────────────────────────
enum MossButtonType { primary, secondary, ghost }

class MossButton extends StatefulWidget {
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
  State<MossButton> createState() => _MossButtonState();
}

class _MossButtonState extends State<MossButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;
    final accent = widget.color ?? kAccent;

    Color bgColor;
    Color textColor;
    Color borderColor;
    Color splashColor;

    if (disabled) {
      switch (widget.type) {
        case MossButtonType.primary:
          bgColor = accent.withValues(alpha: 0.5);
          textColor = Colors.white;
          borderColor = Colors.transparent;
        case MossButtonType.secondary:
          bgColor = accent.withValues(alpha: 0.04);
          textColor = accent.withValues(alpha: 0.4);
          borderColor = accent.withValues(alpha: 0.1);
        case MossButtonType.ghost:
          bgColor = Colors.transparent;
          textColor = kTextMuted;
          borderColor = Colors.transparent;
      }
      splashColor = Colors.transparent;
    } else {
      switch (widget.type) {
        case MossButtonType.primary:
          bgColor = _pressed
              ? Color.lerp(accent, Colors.black, 0.15)!
              : _hovered
                  ? Color.lerp(accent, Colors.black, 0.06)!
                  : accent;
          textColor = Colors.white;
          borderColor = Colors.transparent;
          splashColor = accent.withValues(alpha: 0.3);
        case MossButtonType.secondary:
          bgColor = _pressed
              ? accent.withValues(alpha: 0.18)
              : _hovered
                  ? accent.withValues(alpha: 0.10)
                  : accent.withValues(alpha: 0.06);
          textColor = accent;
          borderColor = _hovered
              ? accent.withValues(alpha: 0.40)
              : accent.withValues(alpha: 0.20);
          splashColor = accent.withValues(alpha: 0.2);
        case MossButtonType.ghost:
          bgColor = _pressed
              ? accent.withValues(alpha: 0.15)
              : _hovered
                  ? accent.withValues(alpha: 0.07)
                  : Colors.transparent;
          textColor = accent;
          borderColor = Colors.transparent;
          splashColor = accent.withValues(alpha: 0.2);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: widget.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: InkWell(
                onTap: disabled ? null : widget.onTap,
                borderRadius: BorderRadius.circular(kRadiusMd),
                splashColor: splashColor,
                highlightColor: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.icon != null ? kS10 : kS16,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.loading)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        if (widget.loading && widget.icon != null)
                          const SizedBox(width: 6),
                        if (widget.icon != null && !widget.loading) ...[
                          Icon(widget.icon, size: 14, color: textColor),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          widget.text,
                          style: TextStyle(fontSize: kTextBase, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MossIconButton ───────────────────────────────────────────────────────
class MossIconButton extends StatefulWidget {
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
  State<MossIconButton> createState() => _MossIconButtonState();
}

class _MossIconButtonState extends State<MossIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    final iconColor = active
        ? (widget.color ?? kTextSecondary)
        : kTextMuted;
    final bgColor = _pressed
        ? iconColor.withValues(alpha: 0.15)
        : _hovered
            ? iconColor.withValues(alpha: 0.08)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: active ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(kS4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(kRadiusSm),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: active ? widget.onTap : null,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  splashColor: active
                      ? iconColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Icon(
                    widget.icon,
                    size: widget.size,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MossCard ─────────────────────────────────────────────────────────────
class MossCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? height;
  final double? width;

  const MossCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(kS12),
      decoration: BoxDecoration(
        color: color ?? kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

// ─── MossGlassCard ─────────────────────────────────────────────────────────
class MossGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double? height;
  final double? width;
  final Color? color;
  final BorderSide? border;

  const MossGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = kBlurGlass,
    this.height,
    this.width,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(kS12),
          decoration: BoxDecoration(
            color: color ?? kGlassWhite,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(
              color: border?.color ?? kGlassBorder,
              width: border?.width ?? 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── MossGlassSidebar ──────────────────────────────────────────────────────
class MossGlassSidebar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const MossGlassSidebar({super.key, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: SizedBox(
        width: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusXl),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: kBlurGlass, sigmaY: kBlurGlass),
            child: Container(
              decoration: BoxDecoration(
                color: kGlassWhite,
                border: Border(right: BorderSide(color: kGlassBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MossBackground ──────────────────────────────────────────────────────
/// 页面背景（渐变 + 动画装饰光晕 + 漂浮装饰元素）
class MossBackground extends StatelessWidget {
  final Widget child;
  final ColorSeries? theme;

  const MossBackground({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final c = theme ?? kBlue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kBg,
            c.bg.withValues(alpha: 0.6),
            kBg,
          ],
        ),
      ),
      child: Stack(
        children: [
          // ── 动画装饰光晕（漂浮在玻璃面板后面） ──
          // 大圆：慢速漂移 + 柔和脉动
          Positioned(
            top: -80, right: -40,
            child: _AnimatedDecorBlob(
              size: 280,
              color: c.light.withValues(alpha: 0.12),
              driftX: 30, driftY: 20,
              pulseRate: 0.6, driftRate: 0.3,
            ),
          ),
          Positioned(
            bottom: 60, left: -60,
            child: _AnimatedDecorBlob(
              size: 220,
              color: c.main.withValues(alpha: 0.10),
              driftX: 25, driftY: 35,
              pulseRate: 0.8, driftRate: 0.4,
            ),
          ),
          // 小圆：较快节奏
          Positioned(
            top: 120, left: 80,
            child: _AnimatedDecorBlob(
              size: 120,
              color: c.light.withValues(alpha: 0.08),
              driftX: 15, driftY: 10,
              pulseRate: 1.2, driftRate: 0.5,
            ),
          ),
          Positioned(
            bottom: -30, right: 100,
            child: _AnimatedDecorBlob(
              size: 160,
              color: c.dark.withValues(alpha: 0.08),
              driftX: 20, driftY: 15,
              pulseRate: 0.9, driftRate: 0.35,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 动画装饰光晕圆点 — 脉动缩放 + 缓慢漂移
class _AnimatedDecorBlob extends StatefulWidget {
  final double size;
  final Color color;
  final double driftX;
  final double driftY;
  final double pulseRate;
  final double driftRate;

  const _AnimatedDecorBlob({
    required this.size,
    required this.color,
    this.driftX = 0,
    this.driftY = 0,
    this.pulseRate = 1,
    this.driftRate = 0.5,
  });

  @override
  State<_AnimatedDecorBlob> createState() => _AnimatedDecorBlobState();
}

class _AnimatedDecorBlobState extends State<_AnimatedDecorBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = _ctrl.value;
        // 脉动：sin 波在 0.75~1.25 之间平滑变化
        final scale =
            0.75 + 0.25 * ((math.sin(v * math.pi * 2 * widget.pulseRate) + 1) / 2);
        // 漂移：不同频率和相位的 sin 组合，产生自然游走感
        final dx = widget.driftX * math.sin(v * math.pi * 2 * widget.driftRate);
        final dy = widget.driftY *
            math.sin(v * math.pi * 2 * widget.driftRate * 0.7 + 1.3);
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}

// ─── MossBadge ────────────────────────────────────────────────────────────
class MossBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const MossBadge({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: Text(text, style: TextStyle(fontSize: kTextXs, color: c)),
    );
  }
}

// ─── MossDropdown ─────────────────────────────────────────────────────────
class MossDropdown<T> extends StatelessWidget {
  final T? value;
  final ValueChanged<T?> onChanged;
  final String placeholder;
  final List<DropdownItem<T>> items;
  final Color? color;

  const MossDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '选择...',
    required this.items,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kAccent;
    final label = items.where((e) => e.value == value).firstOrNull?.label ?? placeholder;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: PopupMenuButton<T>(
        onSelected: onChanged,
        offset: const Offset(0, 40),
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: BorderSide(color: accent.withValues(alpha: 0.30)),
        ),
        itemBuilder: (_) => [
          for (final item in items)
            PopupMenuItem<T>(
              value: item.value,
              height: 32,
              child: Row(
                children: [
                  if (item.value == value)
                    Icon(Icons.check, size: 14, color: accent)
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: kS8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: kTextBase,
                      color: item.value == value ? accent : kTextPrimary,
                      fontWeight: item.value == value ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kS10),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: kTextBase, color: kTextPrimary)),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: accent.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class DropdownItem<T> {
  final String label;
  final T value;
  const DropdownItem(this.label, this.value);
}

// ─── MossGlassPanel ───────────────────────────────────────────────────────
/// 通用的玻璃面板容器（用于右侧操作区/主内容区）
class MossGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double? height;
  final double? width;
  final BorderRadiusGeometry? borderRadius;

  const MossGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = kBlurGlass,
    this.height,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(kRadiusXl),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(kS16),
            decoration: BoxDecoration(
              color: kGlassWhite,
              borderRadius: borderRadius ?? BorderRadius.circular(kRadiusXl),
              border: Border.all(color: kGlassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── MossSidebar ──────────────────────────────────────────────────────────
class MossSidebar extends StatelessWidget {
  final List<Widget> children;

  const MossSidebar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class MossSidebarSection extends StatelessWidget {
  final String title;
  final Widget child;

  const MossSidebarSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontSize: kTextBase, fontWeight: FontWeight.w600,
            color: kTextSecondary, letterSpacing: 0.5,
          )),
          const SizedBox(height: kS8),
          child,
        ],
      ),
    );
  }
}

// ─── MossStatusDot ────────────────────────────────────────────────────────
class MossStatusDot extends StatelessWidget {
  final bool active;
  final double size;

  const MossStatusDot({super.key, this.active = true, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: active ? kSuccess : kWarning,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── MossTextField ────────────────────────────────────────────────────────
class MossTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final bool expands;
  final Color? color;

  const MossTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.maxLines,
    this.expands = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kAccent;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      expands: expands,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontSize: kTextBase),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: kTextBase, color: kTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS8),
        filled: true,
        fillColor: accent.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: accent.withValues(alpha: 0.20)),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent.withValues(alpha: 0.20)),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        isDense: true,
      ),
    );
  }
}

// ─── MossDialog ───────────────────────────────────────────────────────────
Future<T?> showMossDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  String? confirmText,
  String? cancelText,
  Future<bool?> Function()? onConfirm,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: kTextMd)),
      content: SizedBox(width: 300, child: content),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusXl)),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelText, style: const TextStyle(fontSize: kTextBase)),
          ),
        if (confirmText != null)
          TextButton(
            onPressed: () async {
              if (onConfirm != null) {
                final ok = await onConfirm();
                if (ok == true) Navigator.pop(ctx, true);
              } else {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(confirmText, style: const TextStyle(fontSize: kTextBase)),
          ),
      ],
    ),
  );
}

// ─── MossStatusBar ────────────────────────────────────────────────────────
class MossStatusBar extends StatefulWidget {
  final String status;
  const MossStatusBar({super.key, required this.status});

  @override
  State<MossStatusBar> createState() => _MossStatusBarState();
}

class _MossStatusBarState extends State<MossStatusBar> {
  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) { setState(() {}); _tick(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS12, vertical: kS6),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          MossStatusDot(active: widget.status.contains('就绪')),
          const SizedBox(width: kS6),
          Expanded(
            child: Text(widget.status, style: const TextStyle(fontSize: kTextSm, color: kTextSecondary),
              overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: kS8),
          Text(time, style: const TextStyle(fontSize: kTextSm, color: kTextSecondary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  滚动物理 — QQ 弹弹的弹簧手感
// ═══════════════════════════════════════════════════════════════════════════════

/// 弹性十足的滚动物理 — QQ 弹弹的拉长回弹手感
class BouncyPhysics extends BouncingScrollPhysics {
  const BouncyPhysics({super.parent});

  @override
  BouncyPhysics applyTo(ScrollPhysics? ancestor) {
    return BouncyPhysics(parent: buildParent(ancestor));
  }

  /// 拉到底 → 弹回一点 → 干净归零
  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.6,
    stiffness: 80.0,
    damping:8.0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  设置页通用组件
// ═══════════════════════════════════════════════════════════════════════════════

/// 设置分组卡片
class MossSettingsGroup extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const MossSettingsGroup({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MossGlassCard(
      padding: const EdgeInsets.all(kS16),
      color: Colors.white.withValues(alpha: 0.30),
      border: BorderSide(color: Colors.white.withValues(alpha: 0.40), width: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontSize: kTextMd, fontWeight: FontWeight.w600, color: kTextPrimary,
          )),
          if (description != null) ...[
            const SizedBox(height: kS4),
            Text(description!, style: const TextStyle(
              fontSize: kTextSm, color: kTextSecondary,
            )),
          ],
          const SizedBox(height: kS12),
          child,
        ],
      ),
    );
  }
}

/// 设置项行（label 居左，control 居右）
class MossSettingsRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget control;

  const MossSettingsRow({
    super.key,
    required this.label,
    this.hint,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kS10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                  fontSize: kTextBase, color: kTextPrimary,
                )),
                if (hint != null)
                  Text(hint!, style: const TextStyle(
                    fontSize: kTextXs, color: kTextMuted,
                  )),
              ],
            ),
          ),
          const SizedBox(width: kS12),
          Expanded(child: control),
        ],
      ),
    );
  }
}

/// 带标签和数值显示的滑块
class MossSettingsSlider extends StatelessWidget {
  final String label;
  final String? hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;

  const MossSettingsSlider({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    this.min = 0,
    this.max = 2,
    this.divisions = 40,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MossSettingsRow(
      label: label,
      hint: hint,
      control: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: kAccent,
                inactiveTrackColor: kBorder,
                thumbColor: kAccent,
                overlayColor: kAccent.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              formatValue(value),
              style: const TextStyle(fontSize: kTextSm, color: kTextSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置页导航项
class MossSettingsNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const MossSettingsNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kS16, vertical: kS10),
          decoration: BoxDecoration(
            color: active ? kAccent.withValues(alpha: 0.1) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: active ? kAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: active ? kAccent : kTextSecondary),
              const SizedBox(width: kS10),
              Text(label, style: TextStyle(
                fontSize: kTextBase,
                color: active ? kAccent : kTextPrimary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  向后兼容（旧组件名 → 新组件）
// ═══════════════════════════════════════════════════════════════════════════════

// 旧有的函数保持可用，避免一次性改所有页面
InputDecoration inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: kTextBase, color: kTextMuted),
  contentPadding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS8),
  filled: true,
  fillColor: kBg,
  border: OutlineInputBorder(
    borderSide: const BorderSide(color: kBorder),
    borderRadius: BorderRadius.circular(kRadiusMd),
  ),
  enabledBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: kBorder),
    borderRadius: BorderRadius.circular(kRadiusMd),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: kAccent),
    borderRadius: BorderRadius.circular(kRadiusMd),
  ),
  isDense: true,
);

Widget langDropdown({
  required String? value,
  required ValueChanged<String?> onChanged,
  required List<MapEntry<String, String>> items,
}) {
  final label = items
      .where((e) => e.value == value)
      .map((e) => e.key)
      .firstOrNull ?? '全部语言';
  return Container(
    height: 36,
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(kRadiusMd),
      border: Border.all(color: kBorder),
    ),
    child: PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
        side: const BorderSide(color: kBorder),
      ),
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.value,
            height: 32,
            child: Row(
              children: [
                if (item.value == value)
                  const Icon(Icons.check, size: 14, color: kAccent)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: kS8),
                Text(
                  item.key,
                  style: TextStyle(
                    fontSize: kTextBase,
                    color: item.value == value ? kAccent : kTextPrimary,
                    fontWeight: item.value == value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kS10),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: kTextBase, color: kTextPrimary)),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: kTextSecondary),
          ],
        ),
      ),
    ),
  );
}

Widget sidebarGroup(String label, Widget child) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontSize: kTextBase, fontWeight: FontWeight.w600,
          color: kTextSecondary, letterSpacing: 0.5,
        )),
        const SizedBox(height: kS8),
        child,
      ],
    ),
  );
}

Widget btn(String text, VoidCallback onTap, {Color? color}) {
  final c = color ?? kAccent;
  return Padding(
    padding: const EdgeInsets.only(bottom: kS6),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: kS8),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Center(
            child: Text(text, style: const TextStyle(fontSize: kTextBase, color: Colors.white)),
          ),
        ),
      ),
    ),
  );
}

Widget iconBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: Padding(
        padding: const EdgeInsets.all(kS4),
        child: Icon(icon, size: 16, color: color ?? kTextSecondary),
      ),
    ),
  );
}
