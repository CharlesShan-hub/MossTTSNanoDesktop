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
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
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
          body: SafeArea(
            child: Column(
              children: [
                _TitleBar(loading: _ctrl.loading || !_ctrl.loaded),
                _TabBar(tab: _tab, onChanged: (i) => setState(() => _tab = i)),
                Expanded(
                  child: IndexedStack(index: _tab, children: _pages),
                ),
                _StatusBar(status: _ctrl.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _tabLabels = ['单次生成', '有声书', '音色管理', '设置'];

final _pages = <Widget>[
  const SinglePage(),
  const BookPage(),
  const VoicesPage(),
  const SettingsPage(),
];

// ─── 标题栏 ──────────────────────────────────────────────────────────────
class _TitleBar extends StatelessWidget {
  final bool loading;
  const _TitleBar({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kSurface,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: loading ? const Color(0xFFFF9F0A) : const Color(0xFF30D158),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text('CTTS', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary,
          )),
          const Spacer(),
          Text(loading ? '加载模型中...' : '服务运行中',
            style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }
}

// ─── Tab 栏 ──────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const _TabBar({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final active = i == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? kTabColors[i] : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _tabLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? kTabColors[i] : kTextSecondary,
                    ),
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

// ─── 状态栏 ──────────────────────────────────────────────────────────────
class _StatusBar extends StatefulWidget {
  final String status;
  const _StatusBar({required this.status});

  @override
  State<_StatusBar> createState() => _StatusBarState();
}
class _StatusBarState extends State<_StatusBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Text(widget.status, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          const Spacer(),
          const _ClockWidget(),
        ],
      ),
    );
  }
}

class _ClockWidget extends StatefulWidget {
  const _ClockWidget();
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}
class _ClockWidgetState extends State<_ClockWidget> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final s = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Text(s, style: const TextStyle(fontSize: 11, color: kTextSecondary));
  }
}
