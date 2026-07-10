import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'app_state.dart';
import 'voice_service.dart';
import 'settings_service.dart';

/// 基于 shelf 的 HTTP API 服务器，对标 FastAPI 风格。
///
/// ```
/// GET  /v1/health  → {"status":"ok"}
/// GET  /v1/voices  → [{id, name, language, description}, ...]
/// POST /v1/tts     → WAV 音频流
/// ```
class TtsServer {
  HttpServer? _server;
  final TtsController _ctrl;
  final List<Map<String, dynamic>> _accessLog = [];
  static const int maxLogEntries = 100;

  TtsServer(this._ctrl);

  bool get isRunning => _server != null;
  int get port => _server?.port ?? SettingsService.apiPort;
  List<Map<String, dynamic>> get accessLog => List.unmodifiable(_accessLog);

  /// 启动服务器
  Future<void> start({int? port}) async {
    if (_server != null) return;
    final p = port ?? SettingsService.apiPort;
    final router = Router();

    // ─── GET /v1/health ───
    router.get('/v1/health', (shelf.Request req) {
      _log(req, 200);
      return shelf.Response.ok(
        jsonEncode({'status': 'ok', 'model': 'MOSS-TTS-Nano-100M'}),
        headers: {'content-type': 'application/json'},
      );
    });

    // ─── GET /v1/voices ───
    router.get('/v1/voices', (shelf.Request req) async {
      final voices = await VoiceService.loadVoices();
      final list = voices.map((v) => {
        'id': v.id,
        'name': v.name,
        'language': v.language,
        'description': v.description,
        'is_user_voice': v.isUserVoice,
      }).toList();
      _log(req, 200);
      return shelf.Response.ok(
        jsonEncode(list),
        headers: {'content-type': 'application/json'},
      );
    });

    // ─── POST /v1/tts ───
    router.post('/v1/tts', (shelf.Request req) async {
      String body;
      try {
        body = await req.readAsString();
      } catch (e) {
        return shelf.Response(400, body: jsonEncode({'error': '无法读取请求体: $e'}),
            headers: {'content-type': 'application/json'});
      }

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        return shelf.Response(400, body: jsonEncode({'error': 'JSON 解析失败: $e'}),
            headers: {'content-type': 'application/json'});
      }

      final text = payload['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        return shelf.Response(400, body: jsonEncode({'error': '缺少 text 字段'}),
            headers: {'content-type': 'application/json'});
      }

      final voiceId = payload['voice_id'] as String? ?? SettingsService.defaultVoiceId;
      if (voiceId.isEmpty) {
        return shelf.Response(400, body: jsonEncode({'error': '缺少 voice_id 字段，或未设置默认音色'}),
            headers: {'content-type': 'application/json'});
      }

      final params = payload['params'] as Map<String, dynamic>? ?? {};

      try {
        final wavPath = await _ctrl.synthesize(
          voiceId: voiceId,
          text: text.trim(),
          params: params,
        );
        if (wavPath == null) {
          final status = _ctrl.status;
          return shelf.Response(500, body: jsonEncode({'error': '合成失败', 'detail': status}),
              headers: {'content-type': 'application/json'});
        }
        final wavFile = File(wavPath);
        if (!wavFile.existsSync()) {
          return shelf.Response(500, body: jsonEncode({'error': '音频文件不存在'}),
              headers: {'content-type': 'application/json'});
        }
        final bytes = await wavFile.readAsBytes();
        _log(req, 200);
        return shelf.Response.ok(bytes, headers: {
          'content-type': 'audio/wav',
          'content-length': bytes.length.toString(),
        });
      } catch (e) {
        return shelf.Response(500, body: jsonEncode({'error': '合成异常: $e'}),
            headers: {'content-type': 'application/json'});
      }
    });

    // ─── 404 ───
    router.all('/<ignored|.*>', (shelf.Request req) {
      return shelf.Response(404, body: jsonEncode({'error': 'Not found'}),
          headers: {'content-type': 'application/json'});
    });

    final handler = shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router);

    _server = await io.serve(handler, InternetAddress.anyIPv4, p);
    _logBuiltin('服务器启动', 'http://localhost:${_server!.port}');
  }

  /// 停止服务器
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _logBuiltin('服务器停止', '');
  }

  void _log(shelf.Request req, int statusCode) {
    final entry = {
      'time': DateTime.now().toIso8601String(),
      'method': req.method,
      'path': req.requestedUri.path,
      'status': statusCode,
    };
    _accessLog.insert(0, entry);
    if (_accessLog.length > maxLogEntries) _accessLog.removeLast();
  }

  void _logBuiltin(String event, String detail) {
    _accessLog.insert(0, {
      'time': DateTime.now().toIso8601String(),
      'event': event,
      'detail': detail,
    });
    if (_accessLog.length > maxLogEntries) _accessLog.removeLast();
  }
}
