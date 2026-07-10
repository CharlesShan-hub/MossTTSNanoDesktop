import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import '../services/app_state.dart';
import '../services/settings_service.dart';
import 'theme/components.dart';

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
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _playerPos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playerDur = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerPlaying = s == PlayerState.playing);
    });
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
      // 自动选中默认音色
      final defaultId = SettingsService.defaultVoiceId;
      if (defaultId.isNotEmpty && _voices.any((v) => v.id == defaultId)) {
        _selectedVoiceId = defaultId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            MossSidebarSection(title: '音色', child: _voiceSelector()),
            if (_selectedVoiceId != null) ...[
              const SizedBox(height: kS6),
              Center(
                child: GestureDetector(
                  onTap: () {
                      SettingsService.setDefaultVoiceId(_selectedVoiceId!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已设为默认音色'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline, size: 12, color: widget.theme.main),
                        const SizedBox(width: kS4),
                        Text('设为默认音色', style: TextStyle(
                          fontSize: kTextXs, color: widget.theme.main,
                        )),
                      ],
                    ),
                ),
              ),
            ],
            const SizedBox(height: kS8),
            MossSidebarSection(title: '高级参数', child: _advParams()),
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
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(kS16, kS10, kS16, kS10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: kGlassBorder)),
                ),
                child: _generating
                    ? _buildProgressBar()
                    : _lastWavPath != null
                        ? _buildPlaybackBar()
                        : _buildIdleBar(),
              ),
            ],
          ),
        )),
      ],
    );
  }

  List<Voice> get _available => _voices;

  Widget _voiceSelector() {
    final accent = widget.theme.main;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: PopupMenuButton<String>(
        onSelected: (v) => setState(() => _selectedVoiceId = v),
        offset: const Offset(0, 40),
        color: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: BorderSide(color: accent.withValues(alpha: 0.30)),
        ),
        itemBuilder: (_) {
          if (!_loaded) {
            return [const PopupMenuItem(value: null, height: 32, child: Text('加载中...', style: TextStyle(fontSize: kTextBase)))];
          }
          return [
            PopupMenuItem(
              value: null, height: 32,
              child: Text('选择音色...', style: TextStyle(fontSize: kTextBase, color: kTextMuted)),
            ),
            for (final v in _available)
              PopupMenuItem(
                value: v.id,
                height: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: kS6),
                  decoration: BoxDecoration(
                    color: v.id == _selectedVoiceId
                        ? accent.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                  ),
                  child: Row(
                    children: [
                      if (v.id == SettingsService.defaultVoiceId)
                        Icon(Icons.star, size: 12, color: accent)
                      else
                        const SizedBox(width: 12),
                      const SizedBox(width: kS6),
                      Text(v.name, style: TextStyle(fontSize: kTextBase, color: v.id == _selectedVoiceId ? accent : kTextPrimary)),
                    ],
                  ),
                ),
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
              Icon(Icons.arrow_drop_down, size: 16, color: accent.withValues(alpha: 0.6)),
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
          _paramRow('温度', SettingsService.temperature.toStringAsFixed(2)),
          _paramRow('Top-K', SettingsService.topK.toString()),
          _paramRow('Top-P', SettingsService.topP.toStringAsFixed(2)),
          _paramRow('重复惩罚', SettingsService.repetitionPenalty.toStringAsFixed(2)),
          _paramRow('最大帧', SettingsService.maxFrames.toString()),
          _paramRow('种子', SettingsService.seed.toString()),
          const SizedBox(height: kS4),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showParamDialog(),
                borderRadius: BorderRadius.circular(kRadiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: kAccent),
                      const SizedBox(width: kS4),
                      Text('编辑', style: TextStyle(
                        fontSize: kTextXs, color: kAccent,
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  void _showParamDialog() async {
    await showMossDialog(
      context: context,
      title: '生成参数',
      content: const _SingleParamDialog(),
      confirmText: '确定',
    );
    if (mounted) setState(() {});
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
    _playerPos = Duration.zero;
    _playerDur = Duration.zero;

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

  // ─── 底部栏三种状态 ─────────────────────────────────────────────────

  Widget _buildIdleBar() {
    return Row(
      children: [
        Text('${_textCtrl.text.length} 字',
          style: TextStyle(fontSize: kTextSm, color: kTextSecondary)),
        const Spacer(),
        MossButton(
          text: '生成语音',
          icon: Icons.play_arrow,
          color: widget.theme.main,
          onTap: _selectedVoiceId != null && _textCtrl.text.trim().isNotEmpty
              ? _generate : null,
        ),
        const SizedBox(width: kS8),
        Text('⌘+Enter', style: TextStyle(fontSize: kTextSm, color: kTextMuted)),
      ],
    );
  }

  Widget _buildProgressBar() {
    final ctrl = AppState.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 2),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            backgroundColor: widget.theme.main.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(widget.theme.main),
            minHeight: 2,
          ),
        ),
        const SizedBox(height: kS8),
        Row(
          children: [
            Icon(Icons.hourglass_bottom, size: 12, color: kTextSecondary),
            const SizedBox(width: kS6),
            Expanded(
              child: Text(ctrl.status, style: TextStyle(
                fontSize: kTextSm, color: kTextSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.theme.main.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackBar() {
    final posSec = _playerPos.inMilliseconds / 1000.0;
    final durSec = _playerDur.inMilliseconds / 1000.0;
    final posStr = '${posSec ~/ 60}:${(posSec % 60).toStringAsFixed(0).padLeft(2, '0')}';
    final durStr = durSec > 0
        ? '${durSec ~/ 60}:${(durSec % 60).toStringAsFixed(0).padLeft(2, '0')}'
        : '--:--';

    return Row(
      children: [
        MossIconButton(
          icon: _playerPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: _playerPlaying ? '暂停' : '播放',
          onTap: () {
            if (_playerPlaying) {
              _player.pause();
            } else {
              _player.play(DeviceFileSource(_lastWavPath!));
            }
          },
          color: widget.theme.main,
          size: 20,
        ),
        const SizedBox(width: kS8),
        Text(posStr, style: TextStyle(fontSize: kTextXs, color: kTextSecondary)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: widget.theme.main,
              inactiveTrackColor: kBorder,
              thumbColor: widget.theme.main,
              overlayColor: widget.theme.main.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: _playerDur.inMilliseconds > 0
                  ? (_playerPos.inMilliseconds / _playerDur.inMilliseconds).clamp(0.0, 1.0)
                  : 0,
              onChanged: (v) {
                final pos = Duration(milliseconds: (v * _playerDur.inMilliseconds).round());
                _player.seek(pos);
              },
            ),
          ),
        ),
        Text(durStr, style: TextStyle(fontSize: kTextXs, color: kTextSecondary)),
        const SizedBox(width: kS8),
        MossButton(
          text: '保存',
          icon: Icons.save_alt,
          type: MossButtonType.secondary,
          color: widget.theme.main,
          onTap: _saveWav,
        ),
        const SizedBox(width: kS8),
        MossButton(
          text: '生成语音',
          icon: Icons.play_arrow,
          color: widget.theme.main,
          onTap: _textCtrl.text.trim().isNotEmpty ? _generate : null,
        ),
      ],
    );
  }
}

// ─── 参数编辑弹窗 ─────────────────────────────────────────────────────────

class _SingleParamDialog extends StatefulWidget {
  const _SingleParamDialog();

  @override
  State<_SingleParamDialog> createState() => _SingleParamDialogState();
}

class _SingleParamDialogState extends State<_SingleParamDialog> {
  late double _temperature;
  late double _topK;
  late double _topP;
  late double _repPenalty;
  late double _maxFrames;
  late int _seed;

  @override
  void initState() {
    super.initState();
    _temperature = SettingsService.temperature;
    _topK = SettingsService.topK.toDouble();
    _topP = SettingsService.topP;
    _repPenalty = SettingsService.repetitionPenalty;
    _maxFrames = SettingsService.maxFrames.toDouble();
    _seed = SettingsService.seed;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MossSettingsSlider(
              label: '温度', hint: '越高越随机',
              value: _temperature,
              min: 0.1, max: 2.0, divisions: 38,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _temperature = v;
                SettingsService.setTemperature(v);
              }),
            ),
            MossSettingsSlider(
              label: 'Top-K', hint: '候选 token 数',
              value: _topK,
              min: 1, max: 100, divisions: 99,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _topK = v;
                SettingsService.setTopK(v.round());
              }),
            ),
            MossSettingsSlider(
              label: 'Top-P', hint: '累积概率阈值',
              value: _topP,
              min: 0.1, max: 1.0, divisions: 18,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _topP = v;
                SettingsService.setTopP(v);
              }),
            ),
            MossSettingsSlider(
              label: '重复惩罚', hint: '越高越不重复',
              value: _repPenalty,
              min: 1.0, max: 2.0, divisions: 20,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _repPenalty = v;
                SettingsService.setRepetitionPenalty(v);
              }),
            ),
            MossSettingsSlider(
              label: '最大帧', hint: '越长音频越久',
              value: _maxFrames,
              min: 50, max: 1000, divisions: 38,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _maxFrames = v;
                SettingsService.setMaxFrames(v.round());
              }),
            ),
            MossSettingsRow(
              label: '种子',
              control: SizedBox(
                width: 120,
                child: MossTextField(
                  controller: TextEditingController(text: _seed.toString()),
                  hintText: '0 = 随机',
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      _seed = parsed;
                      SettingsService.setSeed(parsed);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
