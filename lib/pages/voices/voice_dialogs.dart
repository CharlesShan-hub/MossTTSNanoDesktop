import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/voice.dart';
import '../../services/voice_service.dart';
import '../../../services/i18n_service.dart';
import '../theme/components.dart';

/// 导入音色对话框
Future<bool?> showImportVoiceDialog(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
  if (result == null || result.files.isEmpty) return null;
  final filePath = result.files.single.path;
  if (filePath == null) return null;

  final nameCtrl = TextEditingController(text: result.files.single.name.split('.').first);
  final langCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final tagCtrl = TextEditingController();

  return showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.importTitle'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MossTextField(controller: nameCtrl, hintText: I18n.t('voices.importName')),
        const SizedBox(height: kS8),
        MossTextField(controller: langCtrl, hintText: I18n.t('voices.importLang')),
        const SizedBox(height: kS8),
        MossTextField(controller: tagCtrl, hintText: I18n.t('voices.importTag')),
        const SizedBox(height: kS8),
        MossTextField(controller: descCtrl, hintText: I18n.t('voices.importDesc')),
      ],
    ),
    cancelText: I18n.t('voices.cancel'),
    confirmText: I18n.t('voices.submitImport'),
    onConfirm: () async {
      if (nameCtrl.text.trim().isEmpty) return false;
      await VoiceService.addVoice(
        name: nameCtrl.text.trim(),
        language: langCtrl.text.trim(),
        description: descCtrl.text.trim(),
        sourceFilePath: filePath,
        tag: tagCtrl.text.trim().isNotEmpty ? tagCtrl.text.trim() : null,
      );
      return true;
    },
  );
}

/// 编辑音色对话框
Future<bool?> showEditVoiceDialog(BuildContext context, Voice voice) async {
  final nameCtrl = TextEditingController(text: voice.name);
  final langCtrl = TextEditingController(text: voice.language);
  final tagCtrl = TextEditingController(text: voice.tag ?? '');
  final descCtrl = TextEditingController(text: voice.description);

  return showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.editTitle'),
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
Future<bool?> showDeleteVoiceDialog(BuildContext context, Voice voice) {
  return showMossDialog<bool>(
    context: context,
    title: I18n.t('voices.deleteTitle'),
    content: Text(I18n.t('voices.deleteConfirm', params: {'name': voice.name}), style: TextStyle(fontSize: kTextMd)),
    cancelText: I18n.t('voices.cancel'),
    confirmText: I18n.t('voices.delete'),
  );
}
