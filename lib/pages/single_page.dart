import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import '../services/app_state.dart';
import '../services/settings_service.dart';
import '../services/i18n_service.dart';
import 'theme/components.dart';
import 'single/controls_bar.dart';
import 'single/voice_selector.dart';
import 'single/adv_params.dart';

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
  Duration _playerPos = Duration.zero;
  Duration _playerDur = Duration.zero;
  bool _playerPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((d) { if (mounted) setState(() => _playerPos = d); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _playerDur = d); });
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _playerPlaying = s == PlayerState.playing); });
    _textCtrl.addListener(() { if (mounted) setState(() {}); });
    VoiceService.notifier.addListener(_onVoicesChanged);
    _loadVoices();
  }

  @override
  void dispose() {
    VoiceService.notifier.removeListener(_onVoicesChanged);
    _player.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onVoicesChanged() => _loadVoices();

  Future<Directory> get _appDir async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    if (Platform.isMacOS) {
      final dir = Directory('$home/Library/Application Support/com.example.mossTtsNano');
      dir.createSync(recursive: true); return dir;
    }
    final appData = Platform.environment['APPDATA'] ?? '${home}/.local/share';
    return Directory('$appData/com.example.mossTtsNano');
  }

  Future<File> get _configFile async => File('${(await _appDir).path}/hidden_voices.json');

  Future<void> _loadHiddenIds() async {
    final file = await _configFile;
    if (!file.existsSync()) return;
    try {
      _hiddenIds.addAll((jsonDecode(await file.readAsString()) as List).cast<String>());
    } catch (_) {}
  }

  Future<void> _loadVoices() async {
    await _loadHiddenIds();
    try {
      final voices = await VoiceService.loadVoices();
      setState(() {
        _voices = voices.where((v) => !_hiddenIds.contains(v.id)).toList();
        _loaded = true;
      });
      _ensureVoiceSelected();
    } catch (e) {
      debugPrint('[VOICE] 加载失败: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _ensureVoiceSelected() {
    if (_selectedVoiceId != null && _voices.any((v) => v.id == _selectedVoiceId)) return;
    if (_voices.isEmpty) return;
    final defaultId = SettingsService.defaultVoiceId;
    if (defaultId.isNotEmpty && _voices.any((v) => v.id == defaultId)) {
      _selectedVoiceId = defaultId;
    } else {
      _selectedVoiceId = _voices.first.id;
      SettingsService.setDefaultVoiceId(_selectedVoiceId!);
    }
    if (mounted) setState(() {});
  }

  void _generateAndPlay({bool autoSelectVoice = false}) async {
    if (autoSelectVoice && _selectedVoiceId == null && _voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
      SettingsService.setDefaultVoiceId(_selectedVoiceId!);
    }
    if (_selectedVoiceId == null || _textCtrl.text.trim().isEmpty) return;
    setState(() => _generating = true);
    _playerPos = Duration.zero;
    _playerDur = Duration.zero;

    final wavPath = await AppState.of(context).synthesize(
      voiceId: _selectedVoiceId!,
      text: _textCtrl.text.trim(),
      params: {},
    );
    if (wavPath != null) {
      _lastWavPath = wavPath;
      try { await _player.stop(); await _player.play(DeviceFileSource(wavPath)); } catch (_) {}
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _saveWav() async {
    if (_lastWavPath == null) return;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/Exports');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final dest = '${dir.path}/moss_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(_lastWavPath!).copy(dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(I18n.t('single.saved')), duration: const Duration(seconds: 4),
          action: SnackBarAction(label: I18n.t('single.openDir'), onPressed: () => Process.run('open', ['-R', dest])),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('single.saveFailed', params: {'e': '$e'}))));
    }
  }

  // ── 构建 ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final accent = widget.theme.main;
    final canGenerate = _textCtrl.text.trim().isNotEmpty;

    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MossSidebarSection(
                      title: I18n.t('single.voiceLabel'),
                      child: VoiceSelector(
                        voices: _voices,
                        selectedVoiceId: _selectedVoiceId,
                        accent: accent,
                        onSelected: (id) {
                          setState(() => _selectedVoiceId = id);
                          SettingsService.setDefaultVoiceId(id);
                        },
                      ),
                    ),
                    if (_selectedVoiceId != null) ...[
                      const SizedBox(height: kS6),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            SettingsService.setDefaultVoiceId(_selectedVoiceId!);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(I18n.t('single.defaultSet')), duration: const Duration(seconds: 1)),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_outline, size: 12, color: accent),
                              const SizedBox(width: kS4),
                              Text(I18n.t('single.defaultSet'), style: TextStyle(fontSize: kTextXs, color: accent)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: kS8),
                    MossSidebarSection(title: I18n.t('single.params'), child: AdvParamsPanel(onChanged: () { if (mounted) setState(() {}); })),
                  ],
                ),
              ),
            ),
          ],
        ),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.all(kS16),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: null, expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: I18n.t('single.textPlaceholder'),
                    hintStyle: TextStyle(fontSize: kTextMd, color: theme.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusLg), borderSide: BorderSide.none),
                    filled: true, fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.all(kS12),
                  ),
                  style: TextStyle(fontSize: kTextMd, color: theme.textPrimary),
                ),
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(kS16, kS10, kS16, kS10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.glassBorder))),
                child: _generating
                    ? ProgressBar(status: AppState.of(context).status, themeColor: accent)
                    : _lastWavPath != null
                        ? _buildPlaybackBar(theme, accent, canGenerate)
                        : IdleBar(
                            textLength: I18n.t('single.charCount', params: {'n': _textCtrl.text.length.toString()}),
                            canGenerate: canGenerate,
                            onGenerate: () => _generateAndPlay(autoSelectVoice: true),
                          ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildPlaybackBar(MossThemeData theme, Color accent, bool canGenerate) {
    final posSec = _playerPos.inMilliseconds / 1000.0;
    final durSec = _playerDur.inMilliseconds / 1000.0;
    return PlaybackBar(
      playing: _playerPlaying,
      posText: '${posSec ~/ 60}:${(posSec % 60).toStringAsFixed(0).padLeft(2, '0')}',
      durText: durSec > 0
          ? '${durSec ~/ 60}:${(durSec % 60).toStringAsFixed(0).padLeft(2, '0')}'
          : '--:--',
      sliderValue: _playerDur.inMilliseconds > 0
          ? (_playerPos.inMilliseconds / _playerDur.inMilliseconds).clamp(0.0, 1.0).toDouble()
          : 0.0,
      themeColor: accent,
      onPlayPause: () {
        if (_playerPlaying) { _player.pause(); } else { _player.play(DeviceFileSource(_lastWavPath!)); }
      },
      onSliderChange: (v) => _player.seek(Duration(milliseconds: (v * _playerDur.inMilliseconds).round())),
      onSave: _saveWav,
      onGenerate: canGenerate ? _generateAndPlay : null,
    );
  }
}
