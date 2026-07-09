import 'package:flutter/material.dart';

import 'services/app_state.dart';
import 'pages/theme.dart';
import 'pages/single_page.dart';
import 'pages/book_page.dart';
import 'pages/voices_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MossTTSApp());
}

class MossTTSApp extends StatelessWidget {
  const MossTTSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOSS-TTS-Nano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: kFontFamily,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final _ctrl = TtsController();

  @override
  void initState() {
    super.initState();
    _ctrl.loadModels();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppState(
      controller: _ctrl,
      child: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) => Scaffold(
          backgroundColor: kBg,
          body: MossBackground(
            theme: kTabColorSeries[_tab],
            child: SafeArea(
              child: Column(
                children: [
                  _TitleBar(loading: _ctrl.loading || !_ctrl.loaded),
                  _TabBar(tab: _tab, labels: _tabLabels, colors: kTabColors, onChanged: (i) => setState(() => _tab = i)),
                  Expanded(
                    child: IndexedStack(index: _tab, children: _pages),
                  ),
                  MossStatusBar(status: _ctrl.status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _tabLabels = ['单次生成', '有声书', '音色管理', '设置'];

List<Widget> get _pages => [
  SinglePage(theme: kTabColorSeries[0]),
  const BookPage(),
  VoicesPage(theme: kTabColorSeries[2]),
  const SettingsPage(),
];

// ─── 标题栏 ──────────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final bool loading;
  const _TitleBar({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS16, vertical: kS8),
      color: kSurface,
      child: Row(
        children: [
          MossStatusDot(active: !loading),
          const SizedBox(width: kS8),
          const Text('CTTS', style: TextStyle(
            fontSize: kTextMd, fontWeight: FontWeight.w500, color: kTextPrimary,
          )),
          const Spacer(),
          Text(loading ? '加载模型中...' : '服务运行中',
            style: const TextStyle(fontSize: kTextSm, color: kTextSecondary)),
        ],
      ),
    );
  }
}

// ─── Tab 栏 ──────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int tab;
  final List<String> labels;
  final List<Color> colors;
  final ValueChanged<int> onChanged;
  const _TabBar({
    required this.tab, required this.labels,
    required this.colors, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: kS10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? colors[i] : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabIcons[i], size: 14, color: active ? colors[i] : kTextSecondary),
                      const SizedBox(width: kS6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: kTextBase,
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          color: active ? colors[i] : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

const _tabIcons = [
  Icons.record_voice_over,
  Icons.menu_book,
  Icons.voice_chat,
  Icons.settings,
];
