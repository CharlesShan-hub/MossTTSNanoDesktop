import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/voice.dart';

class VoiceService {
  static List<Voice> _builtinVoices = [];
  static List<Voice> _userVoices = [];
  static bool _loaded = false;

  /// 音色数据变更通知 — 页面通过 addListener 订阅
  static final ChangeNotifier notifier = ChangeNotifier();

  /// 平台无关的应用支持目录
  /// macOS: ~/Library/Application Support/com.example.mossTtsNano
  /// Windows: C:\Users\<user>\AppData\Roaming\com.example.mossTtsNano
  /// Linux: ~/.local/share/com.example.mossTtsNano
  static Future<Directory> get _appDir async {
    final dir = await getApplicationSupportDirectory();
    dir.createSync(recursive: true);
    return dir;
  }

  /// 用户音色配置路径
  static Future<File> get _userVoicesFile async {
    final dir = await _appDir;
    return File('${dir.path}/user_voices.json');
  }

  /// 用户音色目录
  static Future<Directory> get _userVoicesDir async {
    final dir = await _appDir;
    final voicesDir = Directory('${dir.path}/voices');
    voicesDir.createSync(recursive: true);
    return voicesDir;
  }

  /// 内置音色覆盖文件路径
  static Future<File> get _builtinOverridesFile async {
    final dir = await _appDir;
    return File('${dir.path}/builtin_overrides.json');
  }

  static Map<String, Map<String, String?>> _builtinOverrides = {};

  static Future<void> _loadBuiltinOverrides() async {
    final file = await _builtinOverridesFile;
    if (!file.existsSync()) return;
    try {
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _builtinOverrides = map.map((k, v) => MapEntry(
        k,
        (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as String?)),
      ));
    } catch (_) {
      _builtinOverrides = {};
    }
  }

  static Future<void> _saveBuiltinOverrides() async {
    final file = await _builtinOverridesFile;
    await file.writeAsString(jsonEncode(_builtinOverrides));
  }

  /// 加载所有音色（内置 + 用户）
  static Future<List<Voice>> loadVoices() async {
    if (!_loaded) {
      // 加载内置音色
      final raw = await rootBundle.loadString('assets/audio/voices.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _builtinVoices = map.entries
          .map((e) => Voice.fromJson(e.key, e.value as Map<String, dynamic>, isUserVoice: false))
          .toList();
      // 应用内置音色的编辑覆盖
      await _loadBuiltinOverrides();
      _builtinVoices = _builtinVoices.map((v) {
        final override = _builtinOverrides[v.id];
        if (override == null) return v;
        return v.copyWith(
          name: override['name'],
          language: override['language'],
          description: override['description'],
          tag: override['tag'],
        );
      }).toList();
      _loaded = true;
    }
    // 加载用户音色
    await _loadUserVoices();
    return [..._builtinVoices, ..._userVoices];
  }

  /// 更新内置音色元数据（持久化覆盖）
  static Future<void> updateBuiltinVoice({
    required String id,
    String? name,
    String? language,
    String? description,
    String? tag,
  }) async {
    final existing = _builtinOverrides[id] ?? {};
    _builtinOverrides[id] = {
      ...existing,
      if (name != null && name.isNotEmpty) 'name': name,
      if (language != null) 'language': language,
      if (description != null) 'description': description,
      if (tag != null) 'tag': tag,
    };
    await _saveBuiltinOverrides();
    // 同步更新内存中的内置音色
    final idx = _builtinVoices.indexWhere((v) => v.id == id);
    if (idx != -1) {
      _builtinVoices[idx] = _builtinVoices[idx].copyWith(
        name: name,
        language: language,
        description: description,
        tag: tag,
      );
    }
    notifier.notifyListeners();
  }

  /// 加载用户自定义音色
  static Future<void> _loadUserVoices() async {
    final file = await _userVoicesFile;
    if (!file.existsSync()) {
      _userVoices = [];
      return;
    }
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      _userVoices = list
          .map((e) => Voice.fromJson(e['id'] as String, e, isUserVoice: true))
          .toList();
    } catch (_) {
      _userVoices = [];
    }
  }

  /// 保存用户音色列表
  static Future<void> _saveUserVoices() async {
    final file = await _userVoicesFile;
    final data = _userVoices.map((v) => {
      'id': v.id,
      'name': v.name,
      'file': v.file,
      'language': v.language,
      'description': v.description,
      'hidden': v.hidden,
      if (v.tag != null) 'tag': v.tag,
    }).toList();
    await file.writeAsString(jsonEncode(data));
  }

  /// 添加用户音色
  static Future<Voice> addVoice({
    required String name,
    required String language,
    required String description,
    required String sourceFilePath,
    String? tag,
  }) async {
    final voicesDir = await _userVoicesDir;
    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourceFilePath.split('.').last;
    final destPath = '${voicesDir.path}/$id.$ext';

    // 复制文件
    await File(sourceFilePath).copy(destPath);

    final voice = Voice(
      id: id,
      name: name,
      file: destPath,
      language: language,
      description: description,
      hidden: false,
      isUserVoice: true,
      tag: tag,
    );

    _userVoices.add(voice);
    await _saveUserVoices();
    notifier.notifyListeners();
    return voice;
  }

  /// 更新用户音色
  static Future<void> updateVoice({
    required String id,
    String? name,
    String? language,
    String? description,
    String? sourceFilePath,
    String? tag,
  }) async {
    final idx = _userVoices.indexWhere((v) => v.id == id);
    if (idx == -1) return;

    var voice = _userVoices[idx];

    if (sourceFilePath != null) {
      final ext = sourceFilePath.split('.').last;
      final destPath = '${(await _userVoicesDir).path}/$id.$ext';
      await File(sourceFilePath).copy(destPath);
      voice = voice.copyWith(file: destPath);
    }

    _userVoices[idx] = voice.copyWith(
      name: name,
      language: language,
      description: description,
      tag: tag,
    );
    await _saveUserVoices();
    notifier.notifyListeners();
  }

  /// 删除用户音色
  static Future<void> deleteVoice(String id) async {
    final idx = _userVoices.indexWhere((v) => v.id == id);
    if (idx == -1) return;

    // 删除文件
    final file = File(_userVoices[idx].file);
    if (file.existsSync()) {
      file.deleteSync();
    }

    _userVoices.removeAt(idx);
    await _saveUserVoices();
    notifier.notifyListeners();
  }

  /// 检查音频文件是否存在
  static Future<bool> checkFileExists(Voice voice) async {
    try {
      if (voice.isUserVoice) {
        return File(voice.file).existsSync();
      }
      await rootBundle.load(voice.file);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 重置缓存（强制重新加载）
  static void resetCache() {
    _loaded = false;
  }
}
