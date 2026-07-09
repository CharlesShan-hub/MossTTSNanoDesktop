import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import 'theme.dart';

class VoicesPage extends StatefulWidget {
  final ColorSeries theme;
  const VoicesPage({super.key, required this.theme});

  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  List<Voice> _allVoices = [];
  Map<String, bool> _fileExists = {};
  bool _loaded = false;
  String _query = '';
  String _langFilter = '';
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  late final String _tempDir;
  final Set<String> _hiddenIds = {};
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _tempDir = '${Directory.systemTemp.path}/moss_tts_preview';
    Directory(_tempDir).createSync(recursive: true);
    _loadHiddenIds();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadHiddenIds() async {
    final file = await _configFile;
    if (!file.existsSync()) return;
    try {
      final raw = await file.readAsString();
      final ids = (jsonDecode(raw) as List).cast<String>();
      if (ids.isNotEmpty) {
        setState(() => _hiddenIds.addAll(ids));
      }
    } catch (_) {}
  }

  Future<File> get _configFile async {
    final dir = await _appDir;
    return File('${dir.path}/hidden_voices.json');
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

  Future<void> _saveHiddenIds() async {
    final file = await _configFile;
    (await file.parent).createSync(recursive: true);
    await file.writeAsString(jsonEncode(_hiddenIds.toList()));
  }

  void _toggleHidden(String id) {
    setState(() {
      if (_hiddenIds.contains(id)) {
        _hiddenIds.remove(id);
      } else {
        _hiddenIds.add(id);
      }
    });
    _saveHiddenIds();
  }

  void _restoreBuiltin() {
    setState(() => _hiddenIds.clear());
    _saveHiddenIds();
  }

  Future<void> _importVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final nameCtrl = TextEditingController(text: result.files.single.name.split('.').first);
    final langCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showMossDialog(
      context: context,
      title: '导入音色',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MossTextField(controller: nameCtrl, hintText: '音色名称 *'),
          const SizedBox(height: kS8),
          MossTextField(controller: langCtrl, hintText: '语言'),
          const SizedBox(height: kS8),
          MossTextField(controller: descCtrl, hintText: '描述'),
        ],
      ),
      cancelText: '取消',
      confirmText: '导入',
      onConfirm: () async {
        if (nameCtrl.text.trim().isEmpty) return false;
        await VoiceService.addVoice(
          name: nameCtrl.text.trim(),
          language: langCtrl.text.trim(),
          description: descCtrl.text.trim(),
          sourceFilePath: filePath,
        );
        await _load(refresh: true);
        return true;
      },
    );
  }

  Future<void> _editVoice(Voice voice) async {
    final nameCtrl = TextEditingController(text: voice.name);
    final langCtrl = TextEditingController(text: voice.language);
    final descCtrl = TextEditingController(text: voice.description);

    await showMossDialog(
      context: context,
      title: '编辑音色',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MossTextField(controller: nameCtrl, hintText: '音色名称'),
          const SizedBox(height: kS8),
          MossTextField(controller: langCtrl, hintText: '语言'),
          const SizedBox(height: kS8),
          MossTextField(controller: descCtrl, hintText: '描述'),
        ],
      ),
      cancelText: '取消',
      confirmText: '保存',
      onConfirm: () async {
        if (voice.isUserVoice) {
          await VoiceService.updateVoice(
            id: voice.id,
            name: nameCtrl.text.trim(),
            language: langCtrl.text.trim(),
            description: descCtrl.text.trim(),
          );
        } else {
          await VoiceService.updateBuiltinVoice(
            id: voice.id,
            name: nameCtrl.text.trim(),
            language: langCtrl.text.trim(),
            description: descCtrl.text.trim(),
          );
        }
        await _load(refresh: true);
        return true;
      },
    );
  }

  Future<void> _deleteVoice(Voice voice) async {
    if (voice.isUserVoice) {
      final confirm = await showMossDialog<bool>(
        context: context,
        title: '删除音色',
        content: Text('确定要删除「${voice.name}」吗？\n音频文件也会被删除。', style: const TextStyle(fontSize: kTextMd)),
        cancelText: '取消',
        confirmText: '删除',
      );
      if (confirm != true) return;
      await VoiceService.deleteVoice(voice.id);
      await _load(refresh: true);
    } else {
      _toggleHidden(voice.id);
    }
  }

  Future<String> _getTempPath(Voice voice) async {
    final path = '$_tempDir/${voice.id}.wav';
    if (!File(path).existsSync()) {
      if (voice.isUserVoice) {
        await File(voice.file).copy(path);
      } else {
        final data = await rootBundle.load(voice.file);
        await File(path).writeAsBytes(data.buffer.asUint8List());
      }
    }
    return path;
  }

  Future<void> _playPreview(Voice voice) async {
    try {
      if (_playingId == voice.id) {
        await _player.stop();
        setState(() => _playingId = null);
        return;
      }
      await _player.stop();
      final path = await _getTempPath(voice);
      await _player.play(DeviceFileSource(path));
      setState(() => _playingId = voice.id);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingId = null);
      });
    } catch (e) {
      debugPrint('play error: $e');
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && _loaded) return;
    try {
      final voices = await VoiceService.loadVoices();
      for (final v in voices) {
        _fileExists[v.id] = await VoiceService.checkFileExists(v);
      }
      setState(() {
        _allVoices = voices;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Voices load error: $e');
    }
  }

  List<Voice> get _filtered {
    // 默认显示所有音色（隐藏的以低透明度展示），切换后彻底隐藏
    var v = _showHidden ? _allVoices.where((e) => !_hiddenIds.contains(e.id)).toList() : _allVoices;
    if (_query.isNotEmpty) {
      v = v.where((e) => e.name.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_langFilter.isNotEmpty) {
      v = v.where((e) => e.language == _langFilter).toList();
    }
    return v;
  }

  Set<String> get _langs => _allVoices.map((e) => e.language).toSet();

  static Color _langBadgeColor(String lang) {
    const colors = [
      Color(0xFF4A7DA8), // 蓝
      Color(0xFF4A9E62), // 绿
      Color(0xFFD48C30), // 橙
      Color(0xFF8A5FAD), // 紫
      Color(0xFFC06040), // 红棕
      Color(0xFF3D8A8A), // 青
    ];
    return colors[lang.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filtered;
    final groups = <String, List<Voice>>{};
    for (final v in filtered) {
      groups.putIfAbsent(v.language, () => []).add(v);
    }

    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            MossSidebarSection(title: '操作', child: Column(
            children: [
              SizedBox(width: double.infinity, child: MossButton(
                text: '导入音色', icon: Icons.add,
                onTap: _importVoice, color: widget.theme.main,
              )),
              const SizedBox(height: kS6),
              SizedBox(width: double.infinity, child: MossButton(
                text: '刷新列表', icon: Icons.refresh,
                type: MossButtonType.secondary,
                color: widget.theme.main,
                onTap: () => _load(refresh: true),
              )),
              if (_hiddenIds.isNotEmpty) ...[
                const SizedBox(height: kS6),
                SizedBox(width: double.infinity, child: MossButton(
                  text: '恢复默认音色', icon: Icons.restore,
                  type: MossButtonType.secondary,
                  color: widget.theme.main,
                  onTap: _restoreBuiltin,
                )),
              ],
              const SizedBox(height: kS8),
              Row(
                children: [
                  MossIconButton(
                    icon: _showHidden ? Icons.visibility_off : Icons.visibility,
                    tooltip: _showHidden ? '显示所有音色' : '隐藏已隐藏的音色',
                    onTap: () => setState(() => _showHidden = !_showHidden),
                    color: _showHidden ? widget.theme.main : null,
                  ),
                  const SizedBox(width: kS6),
                  Text('隐藏的音色 (${_hiddenIds.length})',
                    style: TextStyle(fontSize: kTextSm, color: _hiddenIds.isEmpty ? kTextMuted : kTextSecondary)),
                ],
              ),
            ],
          )),
          MossSidebarSection(title: '筛选', child: Column(
            children: [
              MossTextField(
                onChanged: (v) => setState(() => _query = v),
                hintText: '搜索音色...',
                color: widget.theme.main,
              ),
              const SizedBox(height: kS6),
              MossDropdown<String>(
                value: _langFilter.isEmpty ? null : _langFilter,
                onChanged: (v) => setState(() => _langFilter = v ?? ''),
                placeholder: '全部语言',
                color: widget.theme.main,
                items: [
                  const DropdownItem('全部语言', ''),
                  for (final l in _langs)
                    DropdownItem(l, l),
                ],
              ),
            ],
          )),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(kS16, 0, kS16, kS16),
            child: Text(
              '导入的音频文件（WAV）将作为语音克隆的参考音色。\n建议 3-10 秒的清晰人声片段。',
              style: TextStyle(fontSize: kTextSm, color: kTextMuted, height: 1.5),
            ),
          ),
        ]),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: const EdgeInsets.all(kS16),
          child: filtered.isEmpty
            ? Center(child: Text('没有匹配的音色', style: TextStyle(color: kTextMuted)))
            : ListView(
                physics: const BouncyPhysics(),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: kS8),
                      child: Text('${entry.key} (${entry.value.length})',
                        style: const TextStyle(fontSize: kTextBase, fontWeight: FontWeight.w600, color: kTextSecondary)),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = kS12;
                        const childW = 240.0;
                        const childH = 130.0;
                        final cols = ((constraints.maxWidth + gap) / (childW + gap)).floor().clamp(1, 10);
                        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap, runSpacing: gap,
                          children: entry.value.map((v) => SizedBox(
                            width: cardW, height: childH,
                            child: Opacity(
                              opacity: _hiddenIds.contains(v.id) ? 0.4 : 1.0,
                              child: _voiceCard(v),
                            ),
                          )).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: kS16),
                  ],
                ],
              ),
        )),
      ],
    );
  }

  Widget _voiceCard(Voice v) {
    return MossGlassCard(
      height: 130,
      padding: const EdgeInsets.all(kS12),
      color: Colors.white.withValues(alpha: 0.45),
      border: BorderSide(color: Colors.white.withValues(alpha: 0.50), width: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MossBadge(text: v.language, color: _langBadgeColor(v.language)),
            ],
          ),
          const SizedBox(height: kS6),
          Text(v.name, style: const TextStyle(fontSize: kTextMd, fontWeight: FontWeight.w500, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (v.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: kS2),
              child: Text(v.description, style: TextStyle(fontSize: kTextSm, color: kTextMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const Expanded(child: SizedBox.shrink()),
          Row(
            children: [
              MossIconButton(
                icon: _playingId == v.id ? Icons.stop : Icons.play_arrow,
                tooltip: '试听',
                onTap: () => _playPreview(v),
                color: _playingId == v.id ? Colors.blue : null,
              ),
              const SizedBox(width: kS8),
              MossIconButton(
                icon: _hiddenIds.contains(v.id) ? Icons.visibility_off : Icons.visibility_outlined,
                tooltip: _hiddenIds.contains(v.id) ? '显示' : '隐藏',
                onTap: () => _toggleHidden(v.id),
                color: _hiddenIds.contains(v.id) ? widget.theme.main.withValues(alpha: 0.5) : null,
              ),
              const SizedBox(width: kS8),
              MossIconButton(icon: Icons.edit_outlined, tooltip: '编辑', onTap: () => _editVoice(v)),
              const SizedBox(width: kS8),
              MossIconButton(icon: Icons.delete_outline, tooltip: '删除', onTap: () => _deleteVoice(v), color: kError),
            ],
          ),
        ],
      ),
    );
  }
}
