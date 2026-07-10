import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'theme.dart';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(kS12),
          decoration: BoxDecoration(
            color: kGlassWhite,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kGlassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── MossGlassPanel (全宽面板, 用于设置页内容区) ──────────────────────────
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
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(kS20),
      decoration: BoxDecoration(
        color: kGlassWhite,
        borderRadius: BorderRadius.circular(kRadiusXl),
        border: Border.all(color: kGlassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusXl - 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: kBlurGlass, sigmaY: kBlurGlass),
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
    return Container(
      width: 200,
      margin: margin,
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
    );
  }
}

// ─── MossBackground ──────────────────────────────────────────────────────
class MossBackground extends StatelessWidget {
  final Widget child;
  final ColorSeries? theme;
  final int? tabIndex;

  const MossBackground({super.key, required this.child, this.theme, this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final c = theme ?? kBlue;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kBg,
            c.bg.withValues(alpha: 0.3),
            kBg,
          ],
        ),
      ),
      child: child,
    );
  }
}
