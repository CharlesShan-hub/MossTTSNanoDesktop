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
  const VoicesPage({super.key});

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
    // macOS: ~/Library/Application Support/com.example.mossTtsNano
    // Windows: %APPDATA%/com.example.mossTtsNano
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '/tmp';
    final dir = Directory('$home/Library/Application Support/com.example.mossTtsNano');
    if (!Platform.isMacOS) {
      // Windows/Linux fallback
      final appData = Platform.environment['APPDATA']
          ?? '${home}/.local/share';
      return Directory('$appData/com.example.mossTtsNano');
    }
    dir.createSync(recursive: true);
    return dir;
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _importVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    // 弹出名称输入框
    final nameCtrl = TextEditingController(text: result.files.single.name.split('.').first);
    final langCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入音色', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '音色名称 *', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: langCtrl, decoration: const InputDecoration(labelText: '语言', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            await VoiceService.addVoice(
              name: nameCtrl.text.trim(),
              language: langCtrl.text.trim(),
              description: descCtrl.text.trim(),
              sourceFilePath: filePath,
            );
            await _load(refresh: true);
          }, child: const Text('导入')),
        ],
      ),
    );
  }

  Future<void> _editVoice(Voice voice) async {
    final nameCtrl = TextEditingController(text: voice.name);
    final langCtrl = TextEditingController(text: voice.language);
    final descCtrl = TextEditingController(text: voice.description);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑音色', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '音色名称', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: langCtrl, decoration: const InputDecoration(labelText: '语言', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            await VoiceService.updateVoice(
              id: voice.id,
              name: nameCtrl.text.trim(),
              language: langCtrl.text.trim(),
              description: descCtrl.text.trim(),
            );
            await _load(refresh: true);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _deleteVoice(Voice voice) async {
    if (voice.isUserVoice) {
      // 用户音色：确认后彻底删除
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除音色', style: TextStyle(fontSize: 14)),
          content: Text('确定要删除「${voice.name}」吗？\n音频文件也会被删除。', style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      await VoiceService.deleteVoice(voice.id);
      await _load(refresh: true);
    } else {
      // 内置音色：加入隐藏列表
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
    var v = _showHidden ? _allVoices : _allVoices.where((e) => !_hiddenIds.contains(e.id)).toList();
    if (_query.isNotEmpty) {
      v = v.where((e) => e.name.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_langFilter.isNotEmpty) {
      v = v.where((e) => e.language == _langFilter).toList();
    }
    return v;
  }

  Set<String> get _langs => _allVoices.map((e) => e.language).toSet();

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
        Container(
          width: 200, color: kSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sidebarGroup('操作', Column(
                children: [
                  SizedBox(width: double.infinity, child: btn('导入音色', _importVoice, color: kTabColors[2])),
                  SizedBox(width: double.infinity, child: btn('刷新列表', () => _load(refresh: true), color: kTabColors[2])),
                  const SizedBox(height: 4),
                  if (_hiddenIds.isNotEmpty)
                    SizedBox(width: double.infinity, child: btn('恢复默认音色', _restoreBuiltin, color: kTabColors[2])),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 28, height: 28,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _showHidden = !_showHidden),
                            borderRadius: BorderRadius.circular(4),
                            child: Icon(
                              _showHidden ? Icons.visibility : Icons.visibility_off,
                              size: 18, color: _showHidden ? kAccent : kTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('隐藏的音色 (${_hiddenIds.length})',
                        style: TextStyle(fontSize: 11, color: _hiddenIds.isEmpty ? kTextMuted : kTextSecondary)),
                    ],
                  ),
                ],
              )),
              sidebarGroup('筛选', Column(
                children: [
                  const SizedBox(height: 4),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: inputDec('搜索音色...'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  langDropdown(
                    value: _langFilter.isEmpty ? null : _langFilter,
                    onChanged: (v) => setState(() => _langFilter = v ?? ''),
                    items: [
                      const MapEntry('全部语言', ''),
                      for (final l in _langs)
                        MapEntry(l, l),
                    ],
                  ),
                ],
              )),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '导入的音频文件（WAV）将作为语音克隆的参考音色。\n建议 3-10 秒的清晰人声片段。',
                  style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Container(
          color: kBg, padding: const EdgeInsets.all(16),
          child: filtered.isEmpty
            ? Center(child: Text('没有匹配的音色', style: TextStyle(color: kTextMuted)))
            : ListView(
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${entry.key} (${entry.value.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        const childW = 240.0;
                        const childH = 150.0;
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
                    const SizedBox(height: 16),
                  ],
                ],
              ),
        )),
      ],
    );
  }

  Widget _voiceCard(Voice v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(v.language, style: TextStyle(fontSize: 10, color: kAccent)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(v.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (v.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(v.description, style: TextStyle(fontSize: 11, color: kTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          const Expanded(child: SizedBox.shrink()),
          Row(
            children: [
              iconBtn(
                _playingId == v.id ? Icons.stop : Icons.play_arrow,
                '试听',
                () => _playPreview(v),
                color: _playingId == v.id ? Colors.blue : null,
              ),
              const SizedBox(width: 8),
              iconBtn(
                _hiddenIds.contains(v.id) ? Icons.visibility_off : Icons.visibility_outlined,
                _hiddenIds.contains(v.id) ? '显示' : '隐藏',
                () => _toggleHidden(v.id),
                color: _hiddenIds.contains(v.id) ? kTextMuted : null,
              ),
              const SizedBox(width: 8),
              if (v.isUserVoice) ...[
                iconBtn(Icons.edit_outlined, '编辑', () => _editVoice(v)),
                const SizedBox(width: 8),
              ],
              iconBtn(Icons.delete_outline, '删除', () => _deleteVoice(v), color: Colors.red.shade400),
            ],
          ),
        ],
      ),
    );
  }
}
