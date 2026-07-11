import 'package:flutter/material.dart';
import 'theme.dart';
import 'moss_theme.dart';

// ─── MossDialog ───────────────────────────────────────────────────────────
Future<T?> showMossDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  String? confirmText,
  String? cancelText,
  Future<bool?> Function()? onConfirm,
}) {
  final theme = MossTheme.of(context);
  return showDialog<T>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.surface,
      titleTextStyle: TextStyle(fontSize: kTextMd, color: theme.textPrimary, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(fontSize: kTextBase, color: theme.textPrimary),
      title: Text(title),
      content: SizedBox(width: 300, child: content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusXl),
        side: BorderSide(color: theme.border),
      ),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelText, style: TextStyle(fontSize: kTextBase, color: theme.textSecondary)),
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
            child: Text(confirmText, style: TextStyle(fontSize: kTextBase, color: theme.accent)),
          ),
      ],
    ),
  );
}
