import 'package:flutter/material.dart';

import '../../services/i18n_service.dart';
import '../theme/components.dart';

/// 有声书侧边栏
class BookSidebar extends StatelessWidget {
  final ColorSeries accent;
  final VoidCallback onImport;
  final VoidCallback? onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onGenerateAll;
  final bool hasProject;
  final bool generating;
  final int concurrency;
  final ValueChanged<int> onConcurrencyChanged;
  final bool playAll;
  final ValueChanged<bool> onPlayAllChanged;

  const BookSidebar({
    super.key,
    required this.accent,
    required this.onImport,
    this.onSave,
    this.onLoad,
    this.onGenerateAll,
    required this.hasProject,
    this.generating = false,
    this.concurrency = 4,
    required this.onConcurrencyChanged,
    this.playAll = false,
    required this.onPlayAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: MossButton(
            text: I18n.t('book.importChapters'),
            pill: true,
            color: accent.main,
            onTap: onImport,
          )),
          const SizedBox(height: kS6),
          SizedBox(width: double.infinity, child: MossButton(
            text: I18n.t('book.loadProject'),
            icon: Icons.folder_open,
            pill: true,
            color: accent.main,
            onTap: onLoad,
          )),
          if (hasProject) ...[
            const SizedBox(height: kS6),
            SizedBox(width: double.infinity, child: MossButton(
              text: I18n.t('book.generateAll'),
              icon: Icons.play_circle,
              pill: true,
              color: accent.main,
              loading: generating,
              onTap: onGenerateAll,
            )),
            const SizedBox(height: kS8),
            GestureDetector(
              onTap: () => onPlayAllChanged(!playAll),
              child: Row(children: [
                Icon(
                  playAll ? Icons.play_circle_filled : Icons.play_disabled,
                  size: 16, color: playAll ? accent.main : theme.textMuted,
                ),
                const SizedBox(width: kS6),
                Text(I18n.t('book.playAll'),
                    style: TextStyle(fontSize: kTextSm, color: playAll ? accent.main : theme.textSecondary)),
                const Spacer(),
                Icon(
                  playAll ? Icons.toggle_on : Icons.toggle_off_outlined,
                  size: 20, color: playAll ? accent.main : theme.textMuted,
                ),
              ]),
            ),
            const SizedBox(height: kS6),
            Row(children: [
              Text(I18n.t('book.concurrency'),
                  style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
              const Spacer(),
              SizedBox(
                width: 56, height: 28,
                child: TextField(
                  controller: TextEditingController(text: '$concurrency'),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
                  ),
                  style: TextStyle(fontSize: kTextSm, color: theme.textPrimary),
                  onSubmitted: (v) {
                    final n = int.tryParse(v) ?? 1;
                    onConcurrencyChanged(n.clamp(1, 8));
                  },
                ),
              ),
            ]),
            const SizedBox(height: kS6),
            SizedBox(width: double.infinity, child: MossButton(
              text: I18n.t('book.saveProject'),
              icon: Icons.save,
              pill: true,
              color: accent.main,
              onTap: onSave,
            )),
          ],
        ],
      ),
    );
  }
}
