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

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSegment(BookSegment seg) async {
    final voiceId = VoiceChip.firstVoiceForTag(_voices, seg.voiceId) ?? seg.voiceId;
    if (seg.text.trim().isEmpty || voiceId.isEmpty) return;
    if (_playingSegments.contains(seg.id)) { _player.stop(); return; }
    setState(() => _playingSegments.add(seg.id));
    try {
      // 优先用缓存
      String? wavPath = _cache[seg.id];
      if (wavPath == null || !File(wavPath).existsSync()) {
        wavPath = await AppState.of(context).synthesize(
          voiceId: voiceId, text: seg.text, params: {},
        );
        if (wavPath != null) {
          // 复制到缓存目录
          final dest = _cachePath(seg.id);
          Directory(_cacheDir).createSync(recursive: true);
          await File(wavPath).copy(dest);
          _markCached(seg.id, dest);
          wavPath = dest;
        }
      }
      if (wavPath != null) await _player.play(DeviceFileSource(wavPath));
    } catch (_) {}
    if (mounted) setState(() => _playingSegments.remove(seg.id));
  }

  Future<void> _generateAll() async {
    if (_project == null || _project!.segments.isEmpty) return;
    setState(() => _generating = true);
    final ctrl = AppState.of(context);
    final total = _project!.segments.length;

    try {
      Directory(_cacheDir).createSync(recursive: true);
      final appDir = await getApplicationSupportDirectory();
      final exportDir = Directory('${appDir.path}/Exports/${_project!.name}');
      exportDir.createSync(recursive: true);

      for (int i = 0; i < total; i++) {
        final seg = _project!.segments[i];
        if (seg.text.trim().isEmpty || seg.voiceId.isEmpty) continue;

        final tagLabel = seg.voiceId.isNotEmpty ? seg.voiceId : 'unknown';
        final dest = '${exportDir.path}/${(i + 1).toString().padLeft(3, '0')}_$tagLabel.wav';

        // 检查缓存
        final cachePath = _cachePath(seg.id);
        if (_cache.containsKey(seg.id) && File(cachePath).existsSync()) {
          // 有缓存 → 复制到导出目录
          if (!File(dest).existsSync()) await File(cachePath).copy(dest);
          continue;
        }

        ctrl.status = I18n.t('book.generatingProgress', params: {'i': '${i + 1}', 'total': '$total'});

        final voiceId = VoiceChip.firstVoiceForTag(_voices, seg.voiceId) ?? seg.voiceId;
        final wavPath = await ctrl.synthesize(voiceId: voiceId, text: seg.text, params: {});
        if (wavPath != null) {
          await File(wavPath).copy(dest);
          await File(wavPath).copy(cachePath);
          _markCached(seg.id, cachePath);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(I18n.t('book.generateDone', params: {'n': '$total'})),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: I18n.t('single.openDir'), onPressed: () => Process.run('open', ['-R', exportDir.path])),
        ));
      }
    } catch (_) {}
    if (mounted) setState(() => _generating = false);
    ctrl.status = I18n.t('app.ready');
  }

  Future<void> _loadVoices() async {
    final v = await VoiceService.loadVoices();
    if (mounted) setState(() => _voices = v.where((v) => !v.hidden).toList());
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

  Future<void> _loadProject() async {
    final projects = await BookService.listProjects();
    if (!mounted || projects.isEmpty) return;
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
    if (project != null && mounted) { _clearAllCache(); setState(() { _project = project; _hasUnsaved = false; }); }
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
