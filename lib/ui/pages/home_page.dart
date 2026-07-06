import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_settings.dart';
import '../widgets/animated_background.dart';
import 'single_generate_page.dart';
import 'audiobook_page.dart';
import 'voices_page.dart';
import 'settings_page.dart';
import '../../ui/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    const SingleGeneratePage(),
    const AudiobookPage(),
    const VoicesPage(),
    const SettingsPage(),
  ];

  final List<Color> _tabColors = [
    AppTheme.singleTabColor,
    AppTheme.audiobookTabColor,
    AppTheme.voicesTabColor,
    AppTheme.settingsTabColor,
  ];

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    return Scaffold(
      body: Stack(
        children: [
          if (appSettings.showAnimBg)
            const AnimatedBackground(),
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) => _pages[index],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Single',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Audiobook',
          ),
          NavigationDestination(
            icon: Icon(Icons.voice_chat_outlined),
            selectedIcon: Icon(Icons.voice_chat),
            label: 'Voices',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
