import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice.dart';
import '../services/voice_service.dart';
import '../../services/i18n_service.dart';
import 'theme/components.dart';
import 'voices/voice_card.dart';
import 'voices/voice_dialogs.dart';

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
  int _refreshKey = 0; // 强制刷新触发器

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
      final ids = (jsonDecode(await file.readAsString()) as List).cast<String>();
      if (ids.isNotEmpty) setState(() => _hiddenIds.addAll(ids));
    } catch (_) {}
  }

  Future<File> get _configFile async {
    final dir = await _appDir;
    return File('${dir.path}/hidden_voices.json');
  }

  Future<Directory> get _appDir async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    if (Platform.isMacOS) {
      final dir = Directory('$home/Library/Application Support/com.example.mossTtsNano');
      dir.createSync(recursive: true); return dir;
    }
    final appData = Platform.environment['APPDATA'] ?? '${home}/.local/share';
    return Directory('$appData/com.example.mossTtsNano');
  }

  Future<void> _saveHiddenIds() async {
    final file = await _configFile;
    (await file.parent).createSync(recursive: true);
    await file.writeAsString(jsonEncode(_hiddenIds.toList()));
  }

  void _toggleHidden(String id) {
    setState(() {
      if (_hiddenIds.contains(id)) { _hiddenIds.remove(id); } else { _hiddenIds.add(id); }
    });
    _saveHiddenIds();
  }

  void _restoreBuiltin() { setState(() => _hiddenIds.clear()); _saveHiddenIds(); }

  Future<void> _importVoice() async {
    final ok = await showImportVoiceDialog(context, accentColor: widget.theme.main);
    if (ok == true) await _load(refresh: true);
  }

  Future<void> _editVoice(Voice voice) async {
    final ok = await showEditVoiceDialog(context, voice, accentColor: widget.theme.main);
    if (ok == true) await _load(refresh: true);
  }

  Future<void> _deleteVoice(Voice voice) async {
    if (!voice.isUserVoice) { _toggleHidden(voice.id); return; }
    final confirm = await showDeleteVoiceDialog(context, voice, accentColor: widget.theme.main);
    if (confirm != true) return;
    await VoiceService.deleteVoice(voice.id);
    await _load(refresh: true);
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
      if (_playingId == voice.id) { await _player.stop(); setState(() => _playingId = null); return; }
      await _player.stop();
      final path = await _getTempPath(voice);
      await _player.play(DeviceFileSource(path));
      setState(() => _playingId = voice.id);
      _player.onPlayerComplete.listen((_) { if (mounted) setState(() => _playingId = null); });
    } catch (e) { debugPrint('play error: $e'); }
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && _loaded) return;
    try {
      if (refresh) VoiceService.resetCache();
      final voices = await VoiceService.loadVoices();
      for (final v in voices) { _fileExists[v.id] = await VoiceService.checkFileExists(v); }
      setState(() { _allVoices = voices; _loaded = true; });
    } catch (e) { debugPrint('Voices load error: $e'); }
  }

  List<Voice> get _filtered {
    var v = _showHidden ? _allVoices.where((e) => !_hiddenIds.contains(e.id)).toList() : _allVoices;
    if (_query.isNotEmpty) v = v.where((e) => e.name.toLowerCase().contains(_query.toLowerCase())).toList();
    if (_langFilter.isNotEmpty) v = v.where((e) => e.language == _langFilter).toList();
    return v;
  }

  Set<String> get _langs => _allVoices.map((e) => e.language).toSet();

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;
    final groups = <String, List<Voice>>{};
    for (final v in filtered) groups.putIfAbsent(v.language, () => []).add(v);

    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            MossSidebarSection(title: I18n.t('voices.operations'), child: Column(children: [
              SizedBox(width: double.infinity, child: MossButton(
                text: I18n.t('voices.import'), icon: Icons.add, pill: true,
                color: widget.theme.main, onTap: _importVoice)),
              const SizedBox(height: kS6),
              SizedBox(width: double.infinity, child: MossButton(
                text: I18n.t('voices.refresh'), icon: Icons.refresh, pill: true,
                color: widget.theme.main, onTap: () => _load(refresh: true))),
              if (_hiddenIds.isNotEmpty) ...[
                const SizedBox(height: kS6),
                SizedBox(width: double.infinity, child: MossButton(
                  text: I18n.t('voices.restore'), icon: Icons.restore, pill: true,
                  color: widget.theme.main, onTap: _restoreBuiltin)),
              ],
              const SizedBox(height: kS8),
              Row(children: [
                MossIconButton(
                  icon: _showHidden ? Icons.visibility_off : Icons.visibility,
                  tooltip: _showHidden ? I18n.t('voices.showAll') : I18n.t('voices.hideHidden'),
                  onTap: () => setState(() => _showHidden = !_showHidden),
                  color: _showHidden ? widget.theme.main : null,
                ),
                const SizedBox(width: kS6),
                Text(I18n.t('voices.hiddenCount', params: {'n': _hiddenIds.length.toString()}),
                  style: TextStyle(fontSize: kTextSm, color: _hiddenIds.isEmpty ? theme.textMuted : theme.textSecondary)),
              ]),
            ])),
            MossSidebarSection(title: I18n.t('voices.filter'), child: Column(children: [
              MossTextField(onChanged: (v) => setState(() => _query = v), hintText: I18n.t('voices.search'), color: widget.theme.main),
              const SizedBox(height: kS6),
              MossDropdown<String>(
                value: _langFilter.isEmpty ? null : _langFilter,
                onChanged: (v) => setState(() => _langFilter = v ?? ''),
                placeholder: I18n.t('voices.allLanguages'), color: widget.theme.main,
                items: [DropdownItem(I18n.t('voices.allLanguages'), ''), for (final l in _langs) DropdownItem(l, l)],
              ),
            ])),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(kS16, 0, kS16, kS16),
              child: Text(I18n.t('voices.tip'),
                style: TextStyle(fontSize: kTextSm, color: theme.textMuted, height: 1.5)),
            ),
          ]),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16), padding: const EdgeInsets.all(kS16),
          child: filtered.isEmpty
            ? Center(child: Text(I18n.t('voices.noMatch'), style: TextStyle(color: theme.textMuted)))
            : ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(padding: const EdgeInsets.only(bottom: kS8),
                      child: Text('${entry.key} (${entry.value.length})',
                        style: TextStyle(fontSize: kTextBase, fontWeight: FontWeight.w600, color: theme.textSecondary))),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = kS12;
                        const childW = 240.0;
                        final cols = ((constraints.maxWidth + gap) / (childW + gap)).floor().clamp(1, 10);
                        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap, runSpacing: gap,
                          children: entry.value.map((v) => SizedBox(width: cardW, height: 130,
                            child: Opacity(
                              opacity: _hiddenIds.contains(v.id) ? 0.4 : 1.0,
                              child: VoiceCard(
                                key: ValueKey('${v.id}_$_refreshKey'),
                                voice: v,
                                isPlaying: _playingId == v.id,
                                isHidden: _hiddenIds.contains(v.id),
                                themeAccent: widget.theme.main,
                                onPlay: () => _playPreview(v),
                                onToggleHidden: () => _toggleHidden(v.id),
                                onEdit: () => _editVoice(v),
                                onDelete: () => _deleteVoice(v),
                              ),
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
}
