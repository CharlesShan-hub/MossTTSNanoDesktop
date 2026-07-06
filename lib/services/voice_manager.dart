import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/voice.dart';

class VoiceManager extends ChangeNotifier {
  List<Voice> _voices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Voice> get voices => _voices.where((v) => !v.isHidden).toList();
  List<Voice> get allVoices => _voices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  VoiceManager() {
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final voicesDir = Directory('${appDir.path}/voices');
      final voicesJson = File('${voicesDir.path}/voices.json');

      if (!await voicesJson.exists()) {
        // 尝试从 assets 加载默认音色
        await _createDefaultVoices(voicesDir);
      }

      if (await voicesJson.exists()) {
        final jsonString = await voicesJson.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _voices = jsonList.map((json) => Voice.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _errorMessage = 'Failed to load voices: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createDefaultVoices(Directory voicesDir) async {
    await voicesDir.create(recursive: true);
    
    // 这里可以复制默认音色文件
    // 暂时先创建空的 voices.json
    final voicesJson = File('${voicesDir.path}/voices.json');
    await voicesJson.writeAsString('[]');
  }

  Future<void> _saveVoices() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final voicesJson = File('${appDir.path}/voices/voices.json');
      final jsonString = jsonEncode(_voices.map((v) => v.toJson()).toList());
      await voicesJson.writeAsString(jsonString);
    } catch (e) {
      _errorMessage = 'Failed to save voices: $e';
      debugPrint(_errorMessage);
    }
  }

  Future<Voice?> importVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    return _addVoiceFromFile(filePath);
  }

  Future<Voice> _addVoiceFromFile(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final voicesDir = Directory('${appDir.path}/voices');
    final fileName = DateTime.now().millisecondsSinceEpoch.toString() + 
        File(filePath).uri.pathSegments.last;
    
    final newFilePath = '${voicesDir.path}/$fileName';
    await File(filePath).copy(newFilePath);

    final voice = Voice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: File(filePath).uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), ''),
      audioPath: newFilePath,
      createdAt: DateTime.now(),
    );

    _voices.add(voice);
    await _saveVoices();
    notifyListeners();
    return voice;
  }

  Future<void> updateVoice(Voice voice) async {
    final index = _voices.indexWhere((v) => v.id == voice.id);
    if (index != -1) {
      _voices[index] = voice.copyWith(updatedAt: DateTime.now());
      await _saveVoices();
      notifyListeners();
    }
  }

  Future<void> deleteVoice(Voice voice) async {
    try {
      if (await File(voice.audioPath).exists()) {
        await File(voice.audioPath).delete();
      }
    } catch (e) {
      debugPrint('Failed to delete voice audio: $e');
    }
    
    _voices.removeWhere((v) => v.id == voice.id);
    await _saveVoices();
    notifyListeners();
  }

  Future<void> toggleVoiceHidden(Voice voice) async {
    final index = _voices.indexWhere((v) => v.id == voice.id);
    if (index != -1) {
      _voices[index] = voice.copyWith(
        isHidden: !voice.isHidden,
        updatedAt: DateTime.now(),
      );
      await _saveVoices();
      notifyListeners();
    }
  }

  Voice? getVoiceById(String id) {
    try {
      return _voices.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }
}
