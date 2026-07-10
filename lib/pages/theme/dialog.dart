import 'package:flutter/material.dart';
import 'theme.dart';

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
