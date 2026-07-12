import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/book_project.dart';
import '../models/voice.dart';
import '../services/book_service.dart';
import '../services/i18n_service.dart';
import '../services/settings_service.dart';
import '../services/voice_service.dart';
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
  String? _tagFilter;
  bool _hasUnsaved = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final v = await VoiceService.loadVoices();
    if (mounted) setState(() => _voices = v.where((v) => !v.hidden).toList());
  }

  List<String> get _availableTags =>
      _voices.map((v) => v.tag).where((t) => t != null && t.isNotEmpty).toSet().cast<String>().toList()..sort();

  List<BookSegment> get _filteredSegments {
    if (_project == null) return [];
    if (_tagFilter == null) return _project!.segments;
    return _project!.segments.where((s) {
      final voice = _voices.where((v) => v.id == s.voiceId).firstOrNull;
      return voice?.tag == _tagFilter;
    }).toList();
  }

  void _markUnsaved() {
    _hasUnsaved = true;
  }

  Future<void> _importTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final name = result.files.single.name.replaceAll('.txt', '');
      final segments = BookProject.splitText(content);
      setState(() {
        _project = BookProject(name: name, segments: segments);
        _tagFilter = null;
        _hasUnsaved = true;
      });
    } catch (e) {
      if (mounted) {
        showMossDialog(
          context: context,
          title: I18n.t('book.importError'),
          content: Text(I18n.t('book.importErrorDesc', params: {'e': '$e'}),
              style: TextStyle(fontSize: kTextMd)),
          confirmText: I18n.t('book.dialogConfirm'),
        );
      }
    }
  }

  Future<void> _saveProject() async {
    if (_project == null) return;
    await BookService.saveProject(_project!);
    setState(() => _hasUnsaved = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(I18n.t('book.saved')),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _loadProject() async {
    final projects = await BookService.listProjects();
    if (!mounted || projects.isEmpty) return;
    // 简单的选择器：弹窗列出所有项目
    final selected = await showMossDialog<String>(
      context: context,
      title: I18n.t('book.loadProject'),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: projects.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(projects[i].name),
            subtitle: Text('${projects[i].segments.length} ${I18n.t('book.segments')}'),
            onTap: () => Navigator.of(context).pop(projects[i].name),
          ),
        ),
      ),
      cancelText: I18n.t('voices.cancel'),
      confirmText: '',
    );
    if (selected == null) return;
    final project = await BookService.loadProject(selected);
    if (project != null && mounted) {
      setState(() {
        _project = project;
        _tagFilter = null;
        _hasUnsaved = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final accent = widget.theme;
    final segments = _filteredSegments;

    return Row(
      children: [
        // ── 左侧边栏 ──
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [_buildSidebar(theme, accent)],
        ),
        // ── 右侧内容 ──
        Expanded(
          child: MossGlassPanel(
            margin: const EdgeInsets.all(kS16),
            padding: const EdgeInsets.all(kS24),
            child: _project == null ? _buildEmptyState(theme) : _buildSegmentList(theme, accent, segments),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(MossThemeData theme, ColorSeries accent) {
    final tags = _availableTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MossSidebarSection(
          title: _project?.name ?? I18n.t('tabs.book'),
          child: Column(children: [
            SizedBox(width: double.infinity, child: MossButton(
              text: I18n.t('book.importChapters'),
              pill: true,
              color: accent.main,
              onTap: _importTxt,
            )),
            if (_project != null) ...[
              const SizedBox(height: kS6),
              SizedBox(width: double.infinity, child: MossButton(
                text: I18n.t('book.saveProject'),
                icon: Icons.save,
                pill: true,
                color: accent.main,
                onTap: _saveProject,
              )),
              const SizedBox(height: kS6),
              SizedBox(width: double.infinity, child: MossButton(
                text: I18n.t('book.loadProject'),
                icon: Icons.folder_open,
                pill: true,
                color: accent.main,
                onTap: _loadProject,
              )),
            ],
          ]),
        ),
        if (_project != null) ...[
          MossSidebarSection(
            title: '',
            child: Container(
              padding: const EdgeInsets.all(kS12),
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Text('${I18n.t('book.segmentCount')}: ${_project!.segments.length}',
                  style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
            ),
          ),
          if (tags.isNotEmpty)
            MossSidebarSection(
              title: I18n.t('book.filterByTag'),
              child: Column(children: [
                _tagChip(null, I18n.t('book.allTags'), theme, accent),
                const SizedBox(height: kS4),
                for (final tag in tags) ...[
                  _tagChip(tag, tag, theme, accent),
                  const SizedBox(height: kS4),
                ],
              ]),
            ),
        ],
      ],
    );
  }

  Widget _tagChip(String? tag, String label, MossThemeData theme, ColorSeries accent) {
    final selected = _tagFilter == tag;
    return GestureDetector(
      onTap: () => setState(() => _tagFilter = selected ? null : tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS6),
        decoration: BoxDecoration(
          color: selected ? accent.main.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(
            color: selected ? accent.main.withValues(alpha: 0.4) : theme.border,
          ),
        ),
        child: Row(
          children: [
            if (selected)
              Icon(Icons.check, size: 12, color: accent.main)
            else
              const SizedBox(width: 12),
            const SizedBox(width: kS4),
            Text(label, style: TextStyle(fontSize: kTextSm, color: selected ? accent.main : theme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(MossThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book_rounded, size: 48, color: theme.textMuted),
        const SizedBox(height: kS16),
        Text(I18n.t('book.noChapters'),
            style: TextStyle(fontSize: kTextMd, color: theme.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: kS24),
        MossButton(
          text: I18n.t('book.importChapters'),
          icon: Icons.file_open,
          type: MossButtonType.primary,
          color: widget.theme.main,
          onTap: _importTxt,
        ),
      ],
    );
  }

  Widget _buildSegmentList(MossThemeData theme, ColorSeries accent, List<BookSegment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Row(
          children: [
            Icon(Icons.list_alt, size: 20, color: theme.textSecondary),
            const SizedBox(width: kS8),
            Text('${_project!.name} — ${segments.length} ${I18n.t('book.segments')}',
                style: TextStyle(fontSize: kTextLg, color: theme.textPrimary, fontWeight: FontWeight.w500)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: kS16),
        // 片段列表
        Expanded(
          child: segments.isEmpty
              ? Center(
                  child: Text(I18n.t('book.noMatchFilter'),
                      style: TextStyle(color: theme.textMuted)))
              : ListView.separated(
                  itemCount: segments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: kS6),
                  itemBuilder: (_, i) => _SegmentRow(
                    index: i,
                    segment: segments[i],
                    voices: _voices,
                    accent: accent,
                    onTextChanged: (text) {
                      final idx = _project!.segments.indexOf(segments[i]);
                      if (idx != -1) {
                        _project!.segments[idx] = segments[i].copyWith(text: text);
                        _markUnsaved();
                        setState(() {});
                      }
                    },
                    onVoiceChanged: (voiceId) {
                      final idx = _project!.segments.indexOf(segments[i]);
                      if (idx != -1) {
                        _project!.segments[idx] = segments[i].copyWith(voiceId: voiceId);
                        _markUnsaved();
                        setState(() {});
                      }
                    },
                    onDelete: () {
                      _project!.segments.remove(segments[i]);
                      _markUnsaved();
                      setState(() {});
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// 单个片段行
class _SegmentRow extends StatelessWidget {
  final int index;
  final BookSegment segment;
  final List<Voice> voices;
  final ColorSeries accent;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onVoiceChanged;
  final VoidCallback onDelete;

  const _SegmentRow({
    required this.index,
    required this.segment,
    required this.voices,
    required this.accent,
    required this.onTextChanged,
    required this.onVoiceChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final selectedVoice = voices.where((v) => v.id == segment.voiceId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(kS12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          SizedBox(
            width: 32,
            child: Text('${index + 1}',
                style: TextStyle(fontSize: kTextSm, color: theme.textMuted)),
          ),
          // 文本（可编辑）
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: segment.text),
              maxLines: null,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(fontSize: kTextBase, color: theme.textPrimary),
              onChanged: onTextChanged,
            ),
          ),
          const SizedBox(width: kS12),
          // 音色选择 + 标签
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VoiceChip(
                  voices: voices,
                  selectedVoiceId: segment.voiceId,
                  accent: accent,
                  onSelected: onVoiceChanged,
                ),
                if (selectedVoice?.tag != null && selectedVoice!.tag!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: kS4),
                    child: MossBadge(text: selectedVoice.tag!, color: accent.main),
                  ),
              ],
            ),
          ),
          const SizedBox(width: kS8),
          // 操作按钮
          Column(
            children: [
              MossIconButton(
                icon: Icons.play_arrow,
                tooltip: I18n.t('voices.play'),
                onTap: null,
                color: theme.textMuted,
              ),
              const SizedBox(height: kS4),
              MossIconButton(
                icon: Icons.close,
                tooltip: I18n.t('book.remove'),
                onTap: onDelete,
                color: theme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 片段内的音色快捷选择器
class _VoiceChip extends StatefulWidget {
  final List<Voice> voices;
  final String? selectedVoiceId;
  final ColorSeries accent;
  final ValueChanged<String> onSelected;

  const _VoiceChip({
    required this.voices,
    required this.selectedVoiceId,
    required this.accent,
    required this.onSelected,
  });

  @override
  State<_VoiceChip> createState() => _VoiceChipState();
}

class _VoiceChipState extends State<_VoiceChip> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    final selected = widget.voices.where((v) => v.id == widget.selectedVoiceId).firstOrNull;

    return TapRegion(
      onTapOutside: (_) {
        if (_showDropdown) setState(() => _showDropdown = false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showDropdown = !_showDropdown),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS6),
              decoration: BoxDecoration(
                color: widget.accent.main.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadiusSm),
                border: Border.all(color: widget.accent.main.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 14, color: widget.accent.main),
                  const SizedBox(width: kS4),
                  Flexible(
                    child: Text(
                      selected?.name ?? I18n.t('single.searchVoice'),
                      style: TextStyle(fontSize: kTextSm, color: widget.accent.main),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: kS4),
                  Icon(Icons.arrow_drop_down, size: 16, color: widget.accent.main),
                ],
              ),
            ),
          ),
          if (_showDropdown)
            Container(
              margin: const EdgeInsets.only(top: kS4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: theme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusMd - 1),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // 按标签分组显示
                    ..._buildGroupItems(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupItems() {
    final items = <Widget>[];
    final tagged = widget.voices.where((v) => v.tag != null && v.tag!.isNotEmpty).toList();
    final untagged = widget.voices.where((v) => v.tag == null || v.tag!.isEmpty).toList();

    // 按标签分组
    final Map<String, List<Voice>> groups = {};
    for (final v in tagged) {
      groups.putIfAbsent(v.tag!, () => []).add(v);
    }

    for (final entry in groups.entries) {
      // 组标题
      items.add(_groupHeader(entry.key));
      for (final v in entry.value) {
        items.add(_voiceItem(v));
      }
    }

    if (untagged.isNotEmpty) {
      items.add(_groupHeader(I18n.t('book.other')));
      for (final v in untagged) {
        items.add(_voiceItem(v));
      }
    }
    return items;
  }

  Widget _groupHeader(String label) {
    final theme = MossTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS4),
      color: theme.bg,
      child: Text(label, style: TextStyle(fontSize: kTextXs, color: theme.textMuted, fontWeight: FontWeight.w600)),
    );
  }

  Widget _voiceItem(Voice v) {
    final theme = MossTheme.of(context);
    final selected = v.id == widget.selectedVoiceId;
    return InkWell(
      onTap: () {
        widget.onSelected(v.id);
        setState(() => _showDropdown = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS6),
        decoration: BoxDecoration(
          color: selected ? widget.accent.main.withValues(alpha: 0.10) : null,
        ),
        child: Row(
          children: [
            if (v.id == SettingsService.defaultVoiceId)
              Icon(Icons.star, size: 10, color: widget.accent.main)
            else
              const SizedBox(width: 10),
            const SizedBox(width: kS4),
            Text(v.name, style: TextStyle(fontSize: kTextSm, color: selected ? widget.accent.main : theme.textPrimary)),
          ],
        ),
      ),
    );
  }
}
