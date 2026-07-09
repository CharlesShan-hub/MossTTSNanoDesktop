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

// 玻璃态
const kGlassWhite  = Color(0xCCFFFFFF);   // 80% 白
const kGlassBg     = Color(0x80F5F5F7);   // 50% 背景
const kGlassBorder = Color(0x4DD2D2D7);   // 30% 边框
const kGlassShadow = Color(0x1A000000);   // 10% 黑阴影
const kBlurGlass   = 16.0;                // 玻璃模糊半径

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
    final disabled = onTap == null || loading;
    Color bgColor;
    Color textColor;
    Color borderColor;

    final accent = color ?? kAccent;

    switch (type) {
      case MossButtonType.primary:
        bgColor = disabled ? accent.withValues(alpha: 0.5) : accent;
        textColor = Colors.white;
        borderColor = Colors.transparent;
      case MossButtonType.secondary:
        bgColor = disabled ? kSurface.withValues(alpha: 0.5) : kSurface;
        textColor = disabled ? kTextMuted : kTextPrimary;
        borderColor = kBorder;
      case MossButtonType.ghost:
        bgColor = Colors.transparent;
        textColor = disabled ? kTextMuted : accent;
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
    final isActive = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusSm),
        child: Padding(
          padding: const EdgeInsets.all(kS4),
          child: Icon(icon, size: size, color: isActive ? (color ?? kTextSecondary) : kTextMuted),
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

  const MossGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.blur = kBlurGlass,
    this.height,
    this.width,
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

// ─── MossGlassSidebar ──────────────────────────────────────────────────────
class MossGlassSidebar extends StatelessWidget {
  final List<Widget> children;

  const MossGlassSidebar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}

// ─── MossBackground ──────────────────────────────────────────────────────
/// 页面背景（渐变 + 装饰光晕）
class MossBackground extends StatelessWidget {
  final Widget child;
  final ColorSeries? theme;

  const MossBackground({super.key, required this.child, this.theme});

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

  const MossDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '选择...',
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final label = items.where((e) => e.value == value).firstOrNull?.label ?? placeholder;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: PopupMenuButton<T>(
        onSelected: onChanged,
        offset: const Offset(0, 40),
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: const BorderSide(color: kBorder),
        ),
        itemBuilder: (_) => [
          for (final item in items)
            PopupMenuItem<T>(
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
                    item.label,
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
}

class DropdownItem<T> {
  final String label;
  final T value;
  const DropdownItem(this.label, this.value);
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

  const MossTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.maxLines,
    this.expands = false,
  });

  @override
  Widget build(BuildContext context) {
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
          borderSide: const BorderSide(color: kAccent),
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
