import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_settings.dart';
import '../../providers/theme_provider.dart';
import '../../services/tts_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _WideLayout(selectedIndex: _selectedIndex);
            }
            return _NarrowLayout(selectedIndex: _selectedIndex);
          },
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  final int selectedIndex;

  const _WideLayout({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) {
            // TODO: 实现切换
          },
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.palette_outlined),
              selectedIcon: Icon(Icons.palette),
              label: Text('Appearance'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.language_outlined),
              selectedIcon: Icon(Icons.language),
              label: Text('Language'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.audiotrack_outlined),
              selectedIcon: Icon(Icons.audiotrack),
              label: Text('Audio'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.info_outlined),
              selectedIcon: Icon(Icons.info),
              label: Text('About'),
            ),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        const Expanded(child: _SettingsContent()),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final int selectedIndex;

  const _NarrowLayout({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return const _SettingsContent();
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<AppSettings>();
    final ttsService = context.watch<TtsService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (value) {
              themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          SwitchListTile(
            title: const Text('Animated Background'),
            value: settings.showAnimBg,
            onChanged: (value) {
              settings.showAnimBg = value;
            },
            secondary: const Icon(Icons.animation_outlined),
          ),
          if (settings.showAnimBg)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Orb Opacity'),
                  Slider(
                    value: settings.orbOpacity,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      settings.orbOpacity = value;
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SectionTitle(title: 'Language'),
          ListTile(
            title: const Text('Interface Language'),
            subtitle: Text(settings.language == 'zh' ? '中文' : 'English'),
            leading: const Icon(Icons.language_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, settings),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SectionTitle(title: 'System'),
          SwitchListTile(
            title: const Text('Close to Tray'),
            value: settings.closeToTray,
            onChanged: (value) {
              settings.closeToTray = value;
            },
            secondary: const Icon(Icons.minimize_outlined),
          ),
          SwitchListTile(
            title: const Text('Auto Start'),
            value: settings.autoStart,
            onChanged: (value) {
              settings.autoStart = value;
            },
            secondary: const Icon(Icons.start_outlined),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SectionTitle(title: 'About'),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info_outlined),
          ),
          ListTile(
            title: const Text('Models Status'),
            subtitle: Text(
              ttsService.isReady ? 'Loaded' : 'Loading...',
              style: TextStyle(
                color: ttsService.isReady ? Colors.green : Colors.orange,
              ),
            ),
            leading: const Icon(Icons.memory_outlined),
            trailing: ttsService.isReady
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ),
          ListTile(
            title: const Text('GitHub Repository'),
            leading: const Icon(Icons.code),
            onTap: () {
              // TODO: 打开链接
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              settings.language = 'zh';
              Navigator.pop(context);
            },
            child: const Text('中文'),
          ),
          SimpleDialogOption(
            onPressed: () {
              settings.language = 'en';
              Navigator.pop(context);
            },
            child: const Text('English'),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
