import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import '../services/app_state.dart';
import 'theme.dart';

class SinglePage extends StatefulWidget {
  const SinglePage({super.key});

  @override
  State<SinglePage> createState() => _SinglePageState();
}

class _SinglePageState extends State<SinglePage> {
  final _textCtrl = TextEditingController();
  String? _selectedVoiceId;
  List<Voice> _voices = [];
  bool _loaded = false;
  Set<String> _hiddenIds = {};
  bool _generating = false;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadHiddenIds();
    _loadVoices();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<Directory> get _appDir async {
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '/tmp';
    final dir = Directory('$home/Library/Application Support/com.example.mossTtsNano');
    if (!Platform.isMacOS) {
      final appData = Platform.environment['APPDATA']
          ?? '${home}/.local/share';
      return Directory('$appData/com.example.mossTtsNano');
    }
    dir.createSync(recursive: true);
    return dir;
  }

  Future<File> get _configFile async {
    final dir = await _appDir;
    return File('${dir.path}/hidden_voices.json');
  }

  Future<void> _loadHiddenIds() async {
    final file = await _configFile;
    if (!file.existsSync()) return;
    try {
      final raw = await file.readAsString();
      final ids = (jsonDecode(raw) as List).cast<String>();
      if (ids.isNotEmpty) setState(() => _hiddenIds.addAll(ids));
    } catch (_) {}
  }

  Future<void> _loadVoices() async {
    final voices = await VoiceService.loadVoices();
    setState(() {
      _voices = voices.where((v) => !_hiddenIds.contains(v.id)).toList();
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 200, color: kSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sidebarGroup('音色', _voiceSelector()),
              const SizedBox(height: 8),
              sidebarGroup('高级参数', _advParams()),
            ],
          ),
        ),
        Expanded(child: Container(
          color: kBg,
          child: Column(
            children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '输入要合成的文字...',
                    hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: kSurface,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                ),
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                child: Row(
                  children: [
                    Text('${_textCtrl.text.length} 字',
                      style: TextStyle(fontSize: 11, color: kTextSecondary)),
                    const Spacer(),
                    _generateBtn(),
                    const SizedBox(width: 8),
                    Text('⌘+Enter', style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  List<Voice> get _available => _voices;

  Widget _voiceSelector() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorder),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) => setState(() => _selectedVoiceId = v),
        offset: const Offset(0, 40),
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kBorder),
        ),
        itemBuilder: (_) {
          if (!_loaded) {
            return [const PopupMenuItem(value: null, height: 32, child: Text('加载中...', style: TextStyle(fontSize: 12)))];
          }
          return [
            const PopupMenuItem(value: null, height: 32, child: Text('选择音色...', style: TextStyle(fontSize: 12, color: kTextMuted))),
            for (final v in _available)
              PopupMenuItem(
                value: v.id,
                height: 32,
                child: Text(v.name, style: TextStyle(fontSize: 12, color: v.id == _selectedVoiceId ? kTabColors[0] : kTextPrimary)),
              ),
          ];
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedVoiceId != null
                      ? (_voices.where((v) => v.id == _selectedVoiceId).firstOrNull?.name ?? '选择音色...')
                      : '选择音色...',
                  style: TextStyle(fontSize: 12, color: _selectedVoiceId != null ? kTextPrimary : kTextSecondary),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _advParams() {
    return Column(
      children: [
        _paramRow('温度', '0.80'),
        _paramRow('Top-K', '25'),
        _paramRow('Top-P', '0.95'),
        _paramRow('重复惩罚', '1.20'),
        _paramRow('最大帧', '375'),
        _paramRow('种子', '0'),
      ],
    );
  }

  Widget _paramRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: kTextSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 11, color: kTextPrimary)),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedVoiceId == null || _textCtrl.text.trim().isEmpty) return;
    setState(() => _generating = true);

    final ctrl = AppState.of(context);
    final wavPath = await ctrl.synthesize(
      voiceId: _selectedVoiceId!,
      text: _textCtrl.text.trim(),
      params: {},
    );

    if (wavPath != null) {
      try {
        await _player.stop();
        await _player.play(DeviceFileSource(wavPath));
      } catch (e) {
        debugPrint('playback error: $e');
      }
    }

    if (mounted) setState(() => _generating = false);
  }

  Widget _generateBtn() {
    final disabled = _selectedVoiceId == null || _textCtrl.text.trim().isEmpty || _generating;
    return SizedBox(
      height: 32,
      child: Material(
        color: kTabColors[0],
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: disabled ? null : _generate,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                _generating ? '生成中...' : '生成语音',
                style: TextStyle(fontSize: 12, color: disabled ? Colors.white38 : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
