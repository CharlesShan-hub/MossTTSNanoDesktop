import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/book_project.dart';
import '../models/voice.dart';
import '../services/app_state.dart';
import '../services/book_service.dart';
import '../services/i18n_service.dart';
import '../services/text_rule_service.dart';
import '../services/onnx_engine.dart';
import '../services/voice_service.dart';
import 'book/book_sidebar.dart';
import 'book/segment_row.dart';
import 'book/voice_chip.dart';
import 'theme/components.dart';

class BookPage extends StatefulWidget {
  final ColorSeries theme;
  const BookPage({super.key, required this.theme});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  BookProject? _project;
  List<Voice> _voices = [];
  bool _hasUnsaved = false;
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _playingSegments = {};
  final Map<String, String> _cache = {}; // segmentId → cachedWavPath
  bool _generating = false;
  int _concurrency = 1;
  bool _playAll = false;

  /// 缓存目录
  String get _cacheDir => '${Directory.systemTemp.path}/moss_book_cache/${_project?.name ?? 'tmp'}';

  /// 获取缓存的 WAV 路径
  String _cachePath(String segId) => '$_cacheDir/$segId.wav';

  /// 标记缓存
  void _markCached(String segId, String wavPath) {
    _cache[segId] = wavPath;
  }

  /// 清除某段缓存（文本/角色变化时）
  void _clearCache(String segId) {
    _cache.remove(segId);
    final f = File(_cachePath(segId));
    if (f.existsSync()) f.deleteSync();
  }

  /// 清除所有缓存
  void _clearAllCache() {
    _cache.clear();
    final dir = Directory(_cacheDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// 从磁盘扫描加载已有缓存
  void _loadCacheFromDisk() {
    _cache.clear();
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav'));
    for (final f in files) {
      final segId = f.path.split('/').last.replaceAll('.wav', '');
      _cache[segId] = f.path;
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _player.stop());
    VoiceService.notifier.addListener(_onVoicesChanged);
    _loadVoices();
  }

  void _onVoicesChanged() {
    _clearAllCache();
    _loadVoices();
  }

  @override
  void dispose() {
    VoiceService.notifier.removeListener(_onVoicesChanged);
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSegment(BookSegment seg) async {
    final visibleVoices = _voices.where((v) => !v.hidden).toList();
    final voiceId = VoiceChip.firstVoiceForTag(visibleVoices, seg.voiceId) ?? seg.voiceId;
    if (seg.text.trim().isEmpty || voiceId.isEmpty) return;
    if (_playingSegments.contains(seg.id)) { _player.stop(); _playAll = false; return; }

    await _player.stop();
    setState(() => _playingSegments.add(seg.id));
    try {
      String? wavPath = _cache[seg.id];
      if (wavPath == null || !File(wavPath).existsSync()) {
        wavPath = await AppState.of(context).synthesize(
          voiceId: voiceId, text: TextRuleService.apply(seg.text), params: {}, tag: 'play',
        );
        if (wavPath != null) {
          final dest = _cachePath(seg.id);
          Directory(_cacheDir).createSync(recursive: true);
          await File(wavPath).copy(dest);
          _markCached(seg.id, dest);
          wavPath = dest;
        }
      }
      if (wavPath != null) {
        unawaited(_player.onPlayerComplete.firstWhere((_) => true).timeout(const Duration(seconds: 30)).then((_) {
          if (mounted && _playAll) _playNext(seg);
        }));
        await _player.play(DeviceFileSource(wavPath));
      }
    } catch (_) {}
    if (mounted) setState(() => _playingSegments.remove(seg.id));
  }

  void _playNext(BookSegment current) {
    if (_project == null) return;
    final i = _project!.segments.indexOf(current);
    if (i < 0 || i + 1 >= _project!.segments.length) { _playAll = false; return; }
    final next = _project!.segments[i + 1];
    if (next.text.trim().isEmpty || next.voiceId.isEmpty) {
      _playNext(next);
      return;
    }
    _playSegment(next);
  }

  Future<void> _generateAll() async {
    if (_project == null || _project!.segments.isEmpty) return;
    setState(() => _generating = true);
    final ctrl = AppState.of(context);
    final total = _project!.segments.length;
    final n = _concurrency.clamp(1, 8);
    final visibleVoices = _voices.where((v) => !v.hidden).toList();

    // 预创建引擎池（每个线程独立引擎）
    final engines = <OnnxEngine>[];
    if (n > 1) {
      try {
        for (int e = 0; e < n; e++) {
          final eng = OnnxEngine();
          await eng.load(bundleBasePath: 'assets/models');
          engines.add(eng);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(I18n.t('book.enginePoolFailed', params: {'e': '$e'})),
          duration: const Duration(seconds: 3),
        ));
        for (final e in engines) { e.dispose(); }
        engines.clear();
      }
    }

    try {
      Directory(_cacheDir).createSync(recursive: true);
      final appDir = await getApplicationSupportDirectory();
      final exportDir = Directory('${appDir.path}/Exports/${_project!.name}');
      if (exportDir.existsSync()) exportDir.deleteSync(recursive: true);
      exportDir.createSync(recursive: true);

      for (int batch = 0; batch < total; batch += n) {
        final end = (batch + n).clamp(0, total);
        final futures = <Future<void>>[];

        for (int i = batch; i < end; i++) {
           final engineIdx = engines.isNotEmpty ? i % engines.length : -1; // 循环分配引擎
          futures.add(() async {
            final seg = _project!.segments[i];
            if (seg.text.trim().isEmpty || seg.voiceId.isEmpty) return;

            final tagLabel = seg.voiceId.isNotEmpty ? seg.voiceId : 'unknown';
            final dest = '${exportDir.path}/${(i + 1).toString().padLeft(3, '0')}_$tagLabel.wav';
            final cachePath = _cachePath(seg.id);
            if (_cache.containsKey(seg.id) && File(cachePath).existsSync()) {
              await File(cachePath).copy(dest);
              return;
            }

            final voiceId = VoiceChip.firstVoiceForTag(visibleVoices, seg.voiceId) ?? seg.voiceId;
            final engine = engineIdx >= 0 && engineIdx < engines.length ? engines[engineIdx] : null;
            final wavPath = await ctrl.synthesize(
              voiceId: voiceId, text: TextRuleService.apply(seg.text),
              params: {}, tag: 'gen_$i', engine: engine,
            );
            if (wavPath != null) {
              await File(wavPath).copy(dest);
              await File(wavPath).copy(cachePath);
              _markCached(seg.id, cachePath);
            }
          }());
        }

        await Future.wait(futures);
        if (mounted) ctrl.status = I18n.t('book.generatingProgress',
            params: {'i': '${end.clamp(0, total)}', 'total': '$total'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(I18n.t('book.generateDone', params: {'n': '$total'})),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: I18n.t('single.openDir'), onPressed: () => Process.run('open', ['-R', exportDir.path])),
        ));
      }
    } catch (e, st) { debugPrint('[book] generateAll error: $e\n$st'); }
    // 清理引擎池
    for (final e in engines) { e.dispose(); }
    if (mounted) setState(() => _generating = false);
    ctrl.status = I18n.t('app.ready');
  }

  Future<void> _loadVoices() async {
    final v = await VoiceService.loadVoices();
    if (mounted) setState(() => _voices = v);
  }

  void _markUnsaved() { _hasUnsaved = true; }

  Future<void> _importTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['txt'], allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final name = result.files.single.name.replaceAll('.txt', '');
      final segments = BookProject.splitText(content);
      _clearAllCache();
      setState(() {
        _project = BookProject(name: name, segments: segments);
        _hasUnsaved = true;
      });
    } catch (e) {
      if (mounted) showMossDialog(
        context: context, title: I18n.t('book.importError'),
        content: Text(I18n.t('book.importErrorDesc', params: {'e': '$e'}), style: TextStyle(fontSize: kTextMd)),
        confirmText: I18n.t('book.dialogConfirm'),
      );
    }
  }

  Future<void> _saveProject() async {
    if (_project == null) return;
    await BookService.saveProject(_project!);
    setState(() => _hasUnsaved = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18n.t('book.saved')), duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _renameProject() async {
    if (_project == null) return;
    final ctrl = TextEditingController(text: _project!.name);
    final ok = await showMossDialog<bool>(
      context: context, title: I18n.t('book.rename'),
      content: MossTextField(controller: ctrl, hintText: I18n.t('book.renameHint')),
      confirmText: I18n.t('book.dialogConfirm'),
      cancelText: I18n.t('voices.cancel'),
      onConfirm: () async {
        final name = ctrl.text.trim();
        if (name.isEmpty || name == _project!.name) return false;
        final oldName = _project!.name;
        await BookService.renameProject(oldName, name);
        _project!.name = name;
        _markUnsaved();
        return true;
      },
    );
    ctrl.dispose();
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _deleteProject() async {
    if (_project == null) return;
    final projectName = _project!.name;
    final ctrl = TextEditingController();
    final ok = await showMossDialog<bool>(
      context: context, title: I18n.t('book.deleteConfirmTitle'),
      accentColor: widget.theme.main,
      content: StatefulBuilder(builder: (context, setDialogState) {
        final match = ctrl.text.trim() == projectName;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(I18n.t('book.deleteWarning', params: {'name': projectName}),
              style: TextStyle(fontSize: kTextMd, color: Colors.redAccent)),
          const SizedBox(height: kS12),
          MossTextField(
            controller: ctrl,
            hintText: I18n.t('book.deleteHint', params: {'name': projectName}),
            onChanged: (_) => setDialogState(() {}),
          ),
          const SizedBox(height: kS8),
          SizedBox(width: double.infinity, child: MossButton(
            text: I18n.t('book.deleteConfirmAction'),
            color: Colors.redAccent,
            pill: true,
            onTap: match ? () => Navigator.of(context).pop(true) : null,
          )),
        ]);
      }),
      cancelText: I18n.t('voices.cancel'), confirmText: '',
    );
    ctrl.dispose();
    if (ok != true || !mounted) return;
    await BookService.deleteProject(projectName);
    _clearAllCache();
    setState(() { _project = null; _hasUnsaved = false; });
  }

  Future<void> _loadProject() async {
    final projects = await BookService.listProjects();
    if (!mounted) return;
    if (projects.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(I18n.t('book.noProjects')), duration: const Duration(seconds: 2),
      ));
      return;
    }
    final selected = await showMossDialog<String>(
      context: context, title: I18n.t('book.loadProject'),
      content: Builder(builder: (context) {
        final theme = MossTheme.of(context);
        return SizedBox(width: 300, child: ListView.builder(
          shrinkWrap: true,
          itemCount: projects.length,
          itemBuilder: (_, i) => InkWell(
            onTap: () => Navigator.of(context).pop(projects[i].name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kS12, vertical: kS10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border)),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(projects[i].name, style: TextStyle(fontSize: kTextMd, color: theme.textPrimary)),
                    const SizedBox(height: kS4),
                    Text('${projects[i].segments.length} ${I18n.t('book.segments')}',
                        style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
                  ],
                )),
                Icon(Icons.chevron_right, size: 16, color: theme.textMuted),
              ]),
            ),
          ),
        ));
      }),
      cancelText: I18n.t('voices.cancel'), confirmText: '',
    );
    if (selected == null) return;
    final project = await BookService.loadProject(selected);
    if (project != null && mounted) {
      setState(() { _project = project; _hasUnsaved = false; });
      _loadCacheFromDisk();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final accent = widget.theme;
    final segments = _project?.segments ?? [];

    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [BookSidebar(
              accent: accent,
              onImport: _importTxt,
              onSave: _project != null ? _saveProject : null,
              onLoad: _loadProject,
              onGenerateAll: _project != null ? _generateAll : null,
              hasProject: _project != null,
              generating: _generating,
              concurrency: _concurrency,
              onConcurrencyChanged: (n) => setState(() => _concurrency = n),
              playAll: _playAll,
              onPlayAllChanged: (v) => setState(() => _playAll = v),
            )],
        ),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: const EdgeInsets.all(kS24),
          child: _project == null ? _buildEmpty(theme) : _buildList(theme, accent, segments),
        )),
      ],
    );
  }

  Widget _buildEmpty(MossThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book_rounded, size: 48, color: theme.textMuted),
        const SizedBox(height: kS16),
        Text(I18n.t('book.noChapters'),
            style: TextStyle(fontSize: kTextMd, color: theme.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: kS24),
        MossButton(
          text: I18n.t('book.importChapters'), icon: Icons.file_open,
          type: MossButtonType.primary, color: widget.theme.main, onTap: _importTxt,
        ),
      ],
    );
  }

  Widget _buildList(MossThemeData theme, ColorSeries accent, List<BookSegment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.list_alt, size: 20, color: theme.textSecondary),
          const SizedBox(width: kS8),
          Text('${_project!.name} — ${segments.length} ${I18n.t('book.segments')}',
              style: TextStyle(fontSize: kTextLg, color: theme.textPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(width: kS6),
          MossIconButton(
            icon: Icons.edit, tooltip: I18n.t('book.rename'),
            onTap: _renameProject, color: theme.textSecondary,
          ),
          const SizedBox(width: kS4),
          MossIconButton(
            icon: Icons.delete_outline, tooltip: I18n.t('book.deleteProject'),
            onTap: _deleteProject, color: theme.error,
          ),
          const Spacer(),
        ]),
        const SizedBox(height: kS16),
        Expanded(child: segments.isEmpty
            ? Center(child: Text(I18n.t('book.noMatchFilter'), style: TextStyle(color: theme.textMuted)))
            : ListView.separated(
                itemCount: segments.length,
                separatorBuilder: (_, __) => const SizedBox(height: kS6),
                itemBuilder: (_, i) => SegmentRow(
                  index: i, segment: segments[i], voices: _voices, accent: accent,
                  hasCache: _cache.containsKey(segments[i].id) && File(_cachePath(segments[i].id)).existsSync(),
                  onPlay: segments[i].text.trim().isNotEmpty && segments[i].voiceId.isNotEmpty
                      ? () => _playSegment(segments[i]) : null,
                  onTextChanged: (text) {
                    final idx = _project!.segments.indexOf(segments[i]);
                    if (idx != -1) { _project!.segments[idx] = segments[i].copyWith(text: text); _clearCache(segments[i].id); _markUnsaved(); setState(() {}); }
                  },
                  onVoiceChanged: (voiceId) {
                    final idx = _project!.segments.indexOf(segments[i]);
                    if (idx != -1) { _project!.segments[idx] = segments[i].copyWith(voiceId: voiceId); _clearCache(segments[i].id); _markUnsaved(); setState(() {}); }
                  },
                  onInsertAfter: () {
                    final idx = _project!.segments.indexOf(segments[i]);
                    if (idx != -1) {
                      _project!.segments.insert(idx + 1, BookSegment(
                        id: 'seg_${DateTime.now().millisecondsSinceEpoch}',
                        text: '',
                        voiceId: segments[i].voiceId,
                      ));
                      _markUnsaved(); setState(() {});
                    }
                  },
                  onDelete: () { _project!.segments.remove(segments[i]); _markUnsaved(); setState(() {}); },
                ),
              )),
      ],
    );
  }
}
