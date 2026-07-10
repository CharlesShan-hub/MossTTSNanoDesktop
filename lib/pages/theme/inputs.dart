import 'package:flutter/material.dart';
import 'theme.dart';
import 'moss_theme.dart';
import 'cards.dart';

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
    final theme = MossTheme.of(context);
    final label = items.where((e) => e.value == value).firstOrNull?.label ?? placeholder;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: theme.border),
      ),
      child: PopupMenuButton<T>(
        onSelected: onChanged,
        offset: const Offset(0, 40),
        color: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: BorderSide(color: theme.border),
        ),
        itemBuilder: (_) => [
          for (final item in items)
            PopupMenuItem<T>(
              value: item.value,
              height: 32,
              child: Row(
                children: [
                  if (item.value == value)
                    Icon(Icons.check, size: 14, color: color ?? theme.accent)
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: kS8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: kTextBase,
                      color: item.value == value ? (color ?? theme.accent) : theme.textPrimary,
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
                child: Text(label, style: TextStyle(fontSize: kTextBase, color: theme.textPrimary)),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: theme.textSecondary),
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
    final theme = MossTheme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      expands: expands,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(fontSize: kTextBase, color: theme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: kTextBase, color: theme.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS8),
        filled: true,
        fillColor: theme.bg,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color ?? theme.accent),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        isDense: true,
      ),
    );
  }
}

// ─── MossSettingsSlider ────────────────────────────────────────────────────
class MossSettingsSlider extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;
  final Color? color;

  const MossSettingsSlider({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: kTextBase, color: kTextSecondary)),
            const Spacer(),
            Text(formatValue(value), style: const TextStyle(fontSize: kTextBase, color: kTextPrimary)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: color ?? kAccent,
            inactiveTrackColor: kBorder,
            thumbColor: color ?? kAccent,
            overlayColor: (color ?? kAccent).withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min, max: max, divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Text(hint, style: const TextStyle(fontSize: kTextSm, color: kTextMuted)),
      ],
    );
  }
}

// ─── MossSettingsRow ──────────────────────────────────────────────────────
class MossSettingsRow extends StatelessWidget {
  final String label;
  final Widget control;
  final Color? color;

  const MossSettingsRow({
    super.key,
    required this.label,
    required this.control,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: kTextBase, color: kTextSecondary)),
        ),
        const SizedBox(width: kS8),
        Expanded(child: control),
      ],
    );
  }
}

// ─── MossSettingsGroup ────────────────────────────────────────────────────
class MossSettingsGroup extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const MossSettingsGroup({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: kTextMd, fontWeight: FontWeight.w600, color: kTextPrimary)),
        const SizedBox(height: kS4),
        Text(description, style: const TextStyle(fontSize: kTextSm, color: kTextMuted)),
        const SizedBox(height: kS12),
        MossCard(
          padding: const EdgeInsets.all(kS16),
          child: child,
        ),
        const SizedBox(height: kS8),
      ],
    );
  }
}

// ─── MossSettingsNavItem ─────────────────────────────────────────────────
class MossSettingsNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const MossSettingsNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: kS16, vertical: kS10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.08) : Colors.transparent,
            border: Border(
              right: BorderSide(color: active ? color : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: active ? color : kTextSecondary),
              const SizedBox(width: kS10),
              Text(label, style: TextStyle(
                fontSize: kTextBase,
                color: active ? color : kTextSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
