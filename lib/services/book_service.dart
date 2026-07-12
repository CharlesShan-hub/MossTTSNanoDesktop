import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book_project.dart';

/// 有声书项目管理服务
class BookService {
  static final ChangeNotifier notifier = ChangeNotifier();

  /// 项目根目录
  static Future<Directory> get _bookDir async {
    final dir = await getApplicationSupportDirectory();
    final bookDir = Directory('${dir.path}/books');
    bookDir.createSync(recursive: true);
    return bookDir;
  }

  /// 列出所有项目
  static Future<List<BookProject>> listProjects() async {
    final dir = await _bookDir;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final projects = <BookProject>[];
    for (final f in files) {
      try {
        final raw = await f.readAsString();
        projects.add(BookProject.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return projects;
  }

  /// 保存项目
  static Future<void> saveProject(BookProject project) async {
    final dir = await _bookDir;
    final file = File('${dir.path}/${_safeFileName(project.name)}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(project.toJson()));
    notifier.notifyListeners();
  }

  /// 加载项目
  static Future<BookProject?> loadProject(String name) async {
    final dir = await _bookDir;
    final file = File('${dir.path}/${_safeFileName(name)}.json');
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      return BookProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 重命名项目（改名后旧文件删除，保存新文件）
  static Future<void> renameProject(String oldName, String newName) async {
    if (oldName == newName) return;
    final dir = await _bookDir;
    final oldFile = File('${dir.path}/${_safeFileName(oldName)}.json');
    if (!oldFile.existsSync()) return;
    try {
      final raw = await oldFile.readAsString();
      final project = BookProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      project.name = newName;
      final newFile = File('${dir.path}/${_safeFileName(newName)}.json');
      await newFile.writeAsString(const JsonEncoder.withIndent('  ').convert(project.toJson()));
      oldFile.deleteSync();
      notifier.notifyListeners();
    } catch (_) {}
  }

  /// 删除项目
  static Future<void> deleteProject(String name) async {
    final dir = await _bookDir;
    final file = File('${dir.path}/${_safeFileName(name)}.json');
    if (file.existsSync()) file.deleteSync();
    notifier.notifyListeners();
  }

  static String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\u4e00-\u9fff\- ]'), '_');
  }
}
