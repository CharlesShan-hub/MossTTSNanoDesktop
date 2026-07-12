import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/voice.dart';
import 'package:moss_tts_nano/services/voice_service.dart';
import 'package:moss_tts_nano/services/i18n_service.dart';
import '../theme/components.dart';

class _ImportDialogState {
  String? filePath;
  final nameCtrl = TextEditingController();
  final langCtrl = TextEditingController();
  final tagCtrl = TextEditingController();
  final descCtrl = TextEditingController();
}

/// 导入音色对话框
Future<bool?> showImportVoiceDialog(BuildContext context, {Color? accentColor}) async {
  final state = _ImportDialogState();
  final accent = accentColor ?? MossTheme.of(context).accent;

  final ok = await showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.importTitle'),
    accentColor: accent,
    content: StatefulBuilder(
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MossTextField(controller: state.nameCtrl, hintText: I18n.t('voices.importName')),
          const SizedBox(height: kS8),
          MossTextField(controller: state.langCtrl, hintText: I18n.t('voices.importLang')),
          const SizedBox(height: kS8),
          MossTextField(controller: state.tagCtrl, hintText: I18n.t('voices.importTag')),
          const SizedBox(height: kS8),
          MossTextField(controller: state.descCtrl, hintText: I18n.t('voices.importDesc')),
          const SizedBox(height: kS12),
          SizedBox(
            width: double.infinity,
            child: MossButton(
              text: state.filePath != null
                  ? state.filePath!.split('/').last
                  : I18n.t('voices.selectFile'),
              icon: Icons.file_open,
              color: accent,
              pill: true,
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio, allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
                  setDialogState(() {
                    state.filePath = result.files.single.path!;
                    if (state.nameCtrl.text.trim().isEmpty) {
                      state.nameCtrl.text = result.files.single.name.split('.').first;
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    ),
    cancelText: I18n.t('voices.cancel'),
    confirmText: I18n.t('voices.submitImport'),
    onConfirm: () async {
      if (state.nameCtrl.text.trim().isEmpty || state.filePath == null) return false;
      await VoiceService.addVoice(
        name: state.nameCtrl.text.trim(),
        language: state.langCtrl.text.trim(),
        description: state.descCtrl.text.trim(),
        sourceFilePath: state.filePath!,
        tag: state.tagCtrl.text.trim().isNotEmpty ? state.tagCtrl.text.trim() : null,
      );
      return true;
    },
  );
  // 清理控制器
  state.nameCtrl.dispose();
  state.langCtrl.dispose();
  state.tagCtrl.dispose();
  state.descCtrl.dispose();
  return ok;
}

/// 编辑音色对话框
Future<bool?> showEditVoiceDialog(BuildContext context, Voice voice, {Color? accentColor}) async {
  final nameCtrl = TextEditingController(text: voice.name);
  final langCtrl = TextEditingController(text: voice.language);
  final tagCtrl = TextEditingController(text: voice.tag ?? '');
  final descCtrl = TextEditingController(text: voice.description);

  return showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.editTitle'),
    accentColor: accentColor,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MossTextField(controller: nameCtrl, hintText: I18n.t('voices.editName')),
        const SizedBox(height: kS8),
        MossTextField(controller: langCtrl, hintText: I18n.t('voices.editLang')),
        const SizedBox(height: kS8),
        MossTextField(controller: tagCtrl, hintText: I18n.t('voices.editTag')),
        const SizedBox(height: kS8),
        MossTextField(controller: descCtrl, hintText: I18n.t('voices.editDesc')),
      ],
    ),
    cancelText: I18n.t('voices.cancel'),
    confirmText: I18n.t('voices.submitEdit'),
    onConfirm: () async {
      final tag = tagCtrl.text.trim().isNotEmpty ? tagCtrl.text.trim() : null;
      if (voice.isUserVoice) {
        await VoiceService.updateVoice(
          id: voice.id, name: nameCtrl.text.trim(),
          language: langCtrl.text.trim(), description: descCtrl.text.trim(),
          tag: tag,
        );
      } else {
        await VoiceService.updateBuiltinVoice(
          id: voice.id, name: nameCtrl.text.trim(),
          language: langCtrl.text.trim(), description: descCtrl.text.trim(),
          tag: tag,
        );
      }
      return true;
    },
  );
}

/// 删除确认对话框
Future<bool?> showDeleteVoiceDialog(BuildContext context, Voice voice, {Color? accentColor}) {
  return showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.deleteTitle'),
    accentColor: accentColor,
    content: Text(I18n.t('voices.deleteConfirm', params: {'name': voice.name}), style: TextStyle(fontSize: kTextMd)),
    cancelText: I18n.t('voices.cancel'),
    confirmText: I18n.t('voices.delete'),
  );
}
