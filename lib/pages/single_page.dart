import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import '../services/app_state.dart';
import 'theme.dart';

class SinglePage extends StatefulWidget {
  final ColorSeries theme;
  const SinglePage({super.key, required this.theme});

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
  String? _lastWavPath;

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
    if (Platform.isMacOS) {
      final dir = Directory('$home/Library/Application Support/com.example.mossTtsNano');
      dir.createSync(recursive: true);
      return dir;
    }
    final appData = Platform.environment['APPDATA']
        ?? '${home}/.local/share';
    return Directory('$appData/com.example.mossTtsNano');
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
        MossGlassSidebar(children: [
          MossSidebarSection(title: '音色', child: _voiceSelector()),
          const SizedBox(height: kS8),
          MossSidebarSection(title: '高级参数', child: _advParams()),
        ]),
        Expanded(child: Container(
          color: kBg,
          child: Column(
            children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.all(kS16),
                child: MossGlassCard(
                  padding: const EdgeInsets.all(kS16),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: '输入要合成的文字...',
                      hintStyle: TextStyle(fontSize: kTextMd, color: kTextMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kRadiusLg),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.all(kS12),
                    ),
                    style: const TextStyle(fontSize: kTextMd, color: kTextPrimary),
                  ),
                ),
              )),
              MossGlassCard(
                padding: const EdgeInsets.fromLTRB(kS16, kS10, kS16, kS10),
                child: Row(
                  children: [
                    Text('${_textCtrl.text.length} 字',
                      style: TextStyle(fontSize: kTextSm, color: kTextSecondary)),
                    const Spacer(),
                    if (_lastWavPath != null) ...[
                      MossButton(
                      text: '保存',
                      icon: Icons.save_alt,
                      type: MossButtonType.secondary,
                      color: widget.theme.main,
                      onTap: _saveWav,
                    ),
                      const SizedBox(width: kS8),
                    ],
                    MossButton(
                      text: _generating ? '生成中...' : '生成语音',
                      icon: _generating ? null : Icons.play_arrow,
                      loading: _generating,
                      color: widget.theme.main,
                      onTap: _selectedVoiceId != null && _textCtrl.text.trim().isNotEmpty && !_generating
                          ? _generate : null,
                    ),
                    const SizedBox(width: kS8),
                    Text('⌘+Enter', style: TextStyle(fontSize: kTextSm, color: kTextMuted)),
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
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) => setState(() => _selectedVoiceId = v),
        offset: const Offset(0, 40),
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: const BorderSide(color: kBorder),
        ),
        itemBuilder: (_) {
          if (!_loaded) {
            return [const PopupMenuItem(value: null, height: 32, child: Text('加载中...', style: TextStyle(fontSize: kTextBase)))];
          }
          return [
            const PopupMenuItem(value: null, height: 32, child: Text('选择音色...', style: TextStyle(fontSize: kTextBase, color: kTextMuted))),
            for (final v in _available)
              PopupMenuItem(
                value: v.id,
                height: 32,
                child: Text(v.name, style: TextStyle(fontSize: kTextBase, color: v.id == _selectedVoiceId ? widget.theme.main : kTextPrimary)),
              ),
          ];
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kS10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedVoiceId != null
                      ? (_voices.where((v) => v.id == _selectedVoiceId).firstOrNull?.name ?? '选择音色...')
                      : '选择音色...',
                  style: TextStyle(fontSize: kTextBase, color: _selectedVoiceId != null ? kTextPrimary : kTextSecondary),
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
    return MossGlassCard(
      padding: const EdgeInsets.all(kS12),
      child: Column(
        children: [
          _paramRow('温度', '0.80'),
          _paramRow('Top-K', '25'),
          _paramRow('Top-P', '0.95'),
          _paramRow('重复惩罚', '1.20'),
          _paramRow('最大帧', '375'),
          _paramRow('种子', '0'),
        ],
      ),
    );
  }

  Widget _paramRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kS6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: kTextSm, color: kTextSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: kTextSm, color: kTextPrimary)),
        ],
      ),
    );
  }

  Future<void> _saveWav() async {
    if (_lastWavPath == null) return;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '保存语音',
      fileName: 'tts_output.wav',
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    if (result == null) return;
    try {
      await File(_lastWavPath!).copy(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到 $result'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
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
      _lastWavPath = wavPath;
      try {
        await _player.stop();
        await _player.play(DeviceFileSource(wavPath));
      } catch (e) {
        debugPrint('playback error: $e');
      }
    }

    if (mounted) setState(() => _generating = false);
  }
}
