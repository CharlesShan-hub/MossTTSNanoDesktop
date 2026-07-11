import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'theme.dart';
import 'moss_theme.dart';

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
    final c = MossTheme.of(context);
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(kS12),
      decoration: BoxDecoration(
        color: this.color ?? c.surface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: c.border),
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

  const MossGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = kBlurGlass,
    this.height,
    this.width,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = MossTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(kS12),
          decoration: BoxDecoration(
            color: this.color ?? c.glassBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: c.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── MossGlassPanel ──────────────────────────────────────────────────────
class MossGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const MossGlassPanel({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = MossTheme.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadiusXl),
        border: Border.all(color: c.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusXl - 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: kBlurGlass, sigmaY: kBlurGlass),
          child: Container(
            padding: padding ?? const EdgeInsets.all(kS20),
            decoration: BoxDecoration(
              color: c.glassBg,
              borderRadius: BorderRadius.circular(kRadiusXl - 2),
            ),
            child: child,
          ),
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
    final c = MossTheme.of(context);
    return Container(
      width: 200,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusXl),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: kBlurGlass, sigmaY: kBlurGlass),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassBg,
              border: Border(right: BorderSide(color: c.glassBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MossBackground ──────────────────────────────────────────────────────
/// 页面背景（渐变 + tab 切换涟漪扩散效果）
class MossBackground extends StatefulWidget {
  final Widget child;
  final ColorSeries? theme;
  final int tabIndex;

  const MossBackground({
    super.key,
    required this.child,
    this.theme,
    this.tabIndex = 0,
  });

  @override
  State<MossBackground> createState() => _MossBackgroundState();
}

class _MossBackgroundState extends State<MossBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spreadCtrl;
  ColorSeries _prev = kBlue;

  @override
  void initState() {
    super.initState();
    _spreadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() => setState(() {}));
    _prev = widget.theme ?? kBlue;
  }

  @override
  void didUpdateWidget(MossBackground old) {
    super.didUpdateWidget(old);
    if (widget.theme != old.theme) {
      _prev = old.theme ?? kBlue;
      _spreadCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spreadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MossTheme.of(context);
    final isDark = c.bg == kDarkBg; // 检测是否暗黑模式
    final prevC = _prev;
    final curC = widget.theme ?? kBlue;
    final raw = _spreadCtrl.value;
    // 小球扩散：0.6s 内完成 (前 60% 的动画)
    final spreadV = (raw / 0.6).clamp(0.0, 1.0);
    // 环透明度跟随扩散进度渐入，避免突然闪亮
    final ringAlpha = Curves.easeIn.transform(spreadV);
    // 旧颜色在动画前半段渐隐至纯黑
    final oldFade = 1.0 - (raw / 0.4).clamp(0.0, 1.0);
    // 暗黑模式下颜色提亮 + 更高透明度，更鲜明
    final colorBoost = isDark ? 1.5 : 1.0;
    final curMain = curC.main;
    final prevMain = prevC.main;
    // 底色使用主题色
    final baseBg = c.bg;
    // 半圆涟漪：圆心在对应 Tab 的上边沿，从上往下扩散
    final tabX = -0.75 + widget.tabIndex * 0.5;
    final spreadRadius = 0.1 + Curves.easeOut.transform(spreadV) * 2.5;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.bg,
            baseBg.withValues(alpha: 0.4),
            c.bg,
          ],
        ),
      ),
      child: Stack(
        children: [
          // ── 旧颜色涟漪渐隐（旧色 → 纯黑） ──
          if (oldFade > 0 && _spreadCtrl.isAnimating)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(tabX, -1.7),
                      radius: spreadRadius,
                      colors: [
                        Colors.transparent,
                        prevMain.withValues(alpha: 0.20 * oldFade * colorBoost),
                        prevMain.withValues(alpha: 0.05 * oldFade * colorBoost),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.35, 0.65, 1],
                    ),
                  ),
                ),
              ),
            ),
          // ── 新颜色涟漪扩散 ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(tabX, -1.7),
                    radius: spreadRadius,
                    colors: [
                      Colors.transparent,
                      curMain.withValues(alpha: 0.20 * ringAlpha * colorBoost),
                      curMain.withValues(alpha: 0.05 * ringAlpha * colorBoost),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.35, 0.65, 1],
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
