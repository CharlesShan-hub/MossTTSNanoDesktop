import 'package:flutter/material.dart';
import '../../services/i18n_service.dart';
import '../../services/app_state.dart';
import '../../services/settings_service.dart';
import '../theme/components.dart';

class ApiServiceSettings extends StatefulWidget {
  final Color color;
  const ApiServiceSettings({required this.color});

  @override
  State<ApiServiceSettings> createState() => _ApiServiceSettingsState();
}

class _ApiServiceSettingsState extends State<ApiServiceSettings> {
  late bool _enabled;
  late int _port;
  late final TextEditingController _portCtrl;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _enabled = SettingsService.apiEnabled;
    _port = SettingsService.apiPort;
    _portCtrl = TextEditingController(text: _port.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      AppState.of(context).addListener(_onCtrlChanged);
      _listening = true;
    }
  }

  @override
  void dispose() {
    if (_listening) {
      try { AppState.of(context).removeListener(_onCtrlChanged); } catch (_) {}
    }
    _portCtrl.dispose();
    super.dispose();
  }

  void _onCtrlChanged() { if (mounted) setState(() {}); }

  Future<void> _toggle(bool on) async {
    final ctrl = AppState.of(context);
    if (on) {
      await ctrl.startApiServer(port: _port);
    } else {
      await ctrl.stopApiServer();
    }
    await SettingsService.setApiEnabled(on);
    if (mounted) setState(() => _enabled = on);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppState.of(context);
    final running = ctrl.apiRunning;
    final server = ctrl.apiServer;

    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: I18n.t('settings.apiService'),
            description: I18n.t('settings.apiDesc'),
            child: Column(
              children: [
                MossSettingsRow(
                  label: I18n.t('settings.apiEnable'),
                  control: SizedBox(
                    width: 44, height: 24,
                    child: Switch(
                      value: _enabled,
                      onChanged: _toggle,
                      activeColor: widget.color,
                    ),
                  ),
                ),
                const SizedBox(height: kS12),
                MossSettingsRow(
                  label: I18n.t('settings.apiPort'),
                  control: SizedBox(
                    width: 120,
                    child: MossTextField(
                      controller: _portCtrl, hintText: '8080',
                      color: widget.color,
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 1024 && parsed <= 65535) {
                          _port = parsed;
                          SettingsService.setApiPort(parsed);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: I18n.t('settings.apiStatus'),
            description: running ? I18n.t('settings.apiStatusRunning') : I18n.t('settings.apiStatusStopped'),
            child: Column(
              children: [
                MossSettingsRow(
                    label: I18n.t('settings.apiStatus'),
                    control: Row(
                      children: [
                        MossStatusDot(active: running),
                        const SizedBox(width: kS6),
                        Text(running ? I18n.t('settings.apiRunning') : I18n.t('settings.apiStopped'),
                          style: TextStyle(fontSize: kTextBase, color: running ? kSuccess : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)),
                      ],
                    ),
                  ),
                if (running) ...[
                  const SizedBox(height: kS8),
                  MossSettingsRow(
                    label: I18n.t('settings.apiAddress'),
                    control: Text('http://localhost:${server?.port ?? _port}',
                      style: TextStyle(fontSize: kTextBase, color: widget.color)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: I18n.t('settings.apiDocs'),
            description: I18n.t('settings.apiDocsDesc'),
            child: Column(
              children: [
                _endpointRow('POST', '/v1/tts', I18n.t('settings.endpointTts')),
                const SizedBox(height: kS6),
                _endpointRow('GET', '/v1/voices', I18n.t('settings.endpointVoices')),
                const SizedBox(height: kS6),
                _endpointRow('GET', '/v1/health', I18n.t('settings.endpointHealth')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpointRow(String method, String path, String desc) {
    final theme = MossTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS6),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kS6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Text(method, style: TextStyle(
              fontSize: kTextXs, fontWeight: FontWeight.w600, color: widget.color)),
          ),
          const SizedBox(width: kS8),
          Text(path, style: TextStyle(fontSize: kTextBase, color: theme.textPrimary, fontFamily: 'monospace')),
          const Spacer(),
          Text(desc, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
        ],
      ),
    );
  }
}
