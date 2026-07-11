import 'package:flutter/material.dart';

import 'services/app_state.dart';
import 'services/settings_service.dart';
import 'services/i18n_service.dart';
import 'services/macos_titlebar.dart';
import 'pages/theme/components.dart';
import 'pages/single_page.dart';
import 'pages/book_page.dart';
import 'pages/voices_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  await I18n.load(SettingsService.language);
  runApp(const MossTTSApp());
}

class MossTTSApp extends StatefulWidget {
  const MossTTSApp({super.key});

  @override
  State<MossTTSApp> createState() => _MossTTSAppState();
}

class _MossTTSAppState extends State<MossTTSApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = SettingsService.themeMode == 'dark';
    // 延迟确保 native 通道就绪后再设置标题栏外观
    WidgetsBinding.instance.addPostFrameCallback((_) => MacOSTitleBar.setDark(_isDark));
    I18n.notifier.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    I18n.notifier.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      SettingsService.setThemeMode(_isDark ? 'dark' : 'light');
    });
    MacOSTitleBar.setDark(_isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CTTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: kFontFamily,
      ),
      home: _themeWrapper(),
    );
  }

  Widget _themeWrapper() {
    return MossTheme(
      data: _isDark ? MossThemeData.dark : MossThemeData.light,
      isDark: _isDark,
      child: HomePage(onThemeToggle: _toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback? onThemeToggle;
  const HomePage({super.key, this.onThemeToggle});

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
    final theme = MossTheme.of(context);
    return AppState(
      controller: _ctrl,
      child: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) => Scaffold(
          backgroundColor: theme.bg,
          body: MossBackground(
            theme: kTabColorSeries[_tab],
            tabIndex: _tab,
            child: SafeArea(
              child: Column(
                children: [
                  _TabBar(tab: _tab, labels: _tabLabels, colors: kTabColors, onChanged: (i) => setState(() => _tab = i)),
                  Expanded(
                    child: IndexedStack(index: _tab, children: [
                      SinglePage(theme: kTabColorSeries[0]),
                      BookPage(theme: kTabColorSeries[1]),
                      VoicesPage(theme: kTabColorSeries[2]),
                      SettingsPage(
                        theme: kTabColorSeries[3],
                        onThemeToggle: widget.onThemeToggle,
                      ),
                    ]),
                  ),
                  MossStatusBar(
                    status: _ctrl.status,
                    ready: _ctrl.loaded,
                    onThemeToggle: widget.onThemeToggle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> get _tabLabels => [I18n.t('tabs.single'), I18n.t('tabs.book'), I18n.t('tabs.voices'), I18n.t('tabs.settings')];

// ─── Tab 栏 — 流体果冻 ──────────────────────────────────────────────────
class _TabBar extends StatefulWidget {
  final int tab;
  final List<String> labels;
  final List<Color> colors;
  final ValueChanged<int> onChanged;
  const _TabBar({
    required this.tab, required this.labels,
    required this.colors, required this.onChanged,
  });

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _prevTab = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_TabBar old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab) {
      _prevTab = old.tab;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabW = constraints.maxWidth / widget.labels.length;
          final fromLeft = _prevTab * tabW + kS4;
          final toLeft = widget.tab * tabW + kS4;
          final indicatorW = tabW - kS8;

          // 流体动画值：先缩小(0.85) → 滑到新位置 → 胀大(1.08) → 归位
          final v = _ctrl.isAnimating ? _ctrl.value : 1.0;
          final smooth = Curves.easeInOut.transform(v);
          final left = fromLeft + (toLeft - fromLeft) * smooth;
          // 流体缩放：前半段缩小→复原，后半段保持 — 柔柔一捏
          final pulse = v < 0.5
              ? 1.0 - 0.10 * (v < 0.25
                  ? v / 0.25
                  : (0.5 - v) / 0.25)
              : 1.0;
          final scaleX = pulse;
          final scaleY = 2.0 - pulse; // 缩小时拉宽，胀大时收窄 — 流体守恒
          // R 角同步脉冲：压缩时变圆 (20 → 35 → 20)，像水珠
          final radius = 20.0 + 15 * (v < 0.5
              ? (v < 0.25 ? v / 0.25 : (0.5 - v) / 0.25)
              : 0);

          return SizedBox(
            height: 34,
            child: Stack(
              children: [
                // ── 流体果冻云朵指示器 ──
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: indicatorW,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(scaleX, scaleY),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.colors[widget.tab].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: widget.colors[widget.tab].withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 四个可点击标签 ──
                Row(
                  children: List.generate(widget.labels.length, (i) {
                    final active = i == widget.tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onChanged(i),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabIcons[i],
                                  size: 14,
                                  color: active ? widget.colors[i] : theme.textSecondary,
                                ),
                                const SizedBox(width: kS6),
                                Text(
                                  widget.labels[i],
                                  style: TextStyle(
                                    fontSize: kTextBase,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                    color: active ? widget.colors[i] : theme.textSecondary,
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
              ],
            ),
          );
        },
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
