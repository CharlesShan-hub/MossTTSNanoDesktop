import 'package:flutter/material.dart';
import 'theme.dart';
import 'buttons.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  向后兼容 — 旧函数包裹新组件
// ═══════════════════════════════════════════════════════════════════════════════

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
  return MossButton(text: text, onTap: onTap, color: color);
}

Widget iconBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
  return MossIconButton(icon: icon, tooltip: tooltip, onTap: onTap, color: color);
}
