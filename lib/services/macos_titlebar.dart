import 'dart:io';
import 'package:flutter/services.dart';

/// macOS 窗口标题栏外观控制
class MacOSTitleBar {
  static const _channel = MethodChannel('com.example.mossTtsNano/titlebar');

  /// 设置标题栏暗色/亮色
  static Future<void> setDark(bool dark) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('setAppearance', {'dark': dark});
    } catch (_) {}
  }
}
