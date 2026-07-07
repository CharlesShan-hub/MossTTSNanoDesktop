import 'package:flutter/material.dart';

// ─── 主题色 ──────────────────────────────────────────────────────────────
const kAccent = Color(0xFF4A7DA8);
const kBg = Color(0xFFF5F5F7);
const kSurface = Colors.white;
const kTextPrimary = Color(0xFF1D1D1F);
const kTextSecondary = Color(0xFF86868B);
const kTextMuted = Color(0xFFA1A1A6);
const kBorder = Color(0xFFD2D2D7);

const kTabColors = [
  Color(0xFF4A7DA8),
  Color(0xFF4A9E62),
  Color(0xFF8A5FAD),
  Color(0xFFD48C30),
];

InputDecoration inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  filled: true,
  fillColor: kBg,
  border: OutlineInputBorder(
    borderSide: const BorderSide(color: kBorder),
    borderRadius: BorderRadius.circular(6),
  ),
  enabledBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: kBorder),
    borderRadius: BorderRadius.circular(6),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: kAccent),
    borderRadius: BorderRadius.circular(6),
  ),
  isDense: true,
);

/// 统一的语言下拉框（PopupMenuButton 风格，与整体扁平 UI 一致）
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
    height: 38,
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: kBorder),
    ),
    child: PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 42),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 8),
                Text(
                  item.key,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.value == value ? kAccent : kTextPrimary,
                    fontWeight: item.value == value ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12, color: kTextPrimary)),
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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: kTextSecondary, letterSpacing: 0.5,
        )),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

Widget btn(String text, VoidCallback onTap, {Color? color}) {
  final c = color ?? kAccent;
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: color ?? kTextSecondary),
      ),
    ),
  );
}
