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

  const BookSidebar({
    super.key,
    required this.accent,
    required this.onImport,
    this.onSave,
    this.onLoad,
    this.onGenerateAll,
    required this.hasProject,
    this.generating = false,
  });

  @override
  Widget build(BuildContext context) {
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
