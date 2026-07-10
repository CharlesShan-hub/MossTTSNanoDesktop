import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/settings_service.dart';
import 'theme/components.dart';

class SettingsPage extends StatefulWidget {
  final ColorSeries theme;
  const SettingsPage({super.key, required this.theme});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _navIndex = 0;

  final _navItems = const [
    ('模型信息', Icons.memory),
    ('生成参数', Icons.tune),
    ('API 服务', Icons.cloud),
    ('外观', Icons.palette_outlined),
    ('快捷键', Icons.keyboard),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kS16, kS16, kS16, kS8),
              child: Text('设置', style: TextStyle(
                fontSize: kTextBase, fontWeight: FontWeight.w600,
                color: kTextSecondary, letterSpacing: 0.5,
              )),
            ),
            ...List.generate(_navItems.length, (i) {
              final (label, icon) = _navItems[i];
              return MossSettingsNavItem(
                label: label,
                icon: icon,
                active: _navIndex == i,
                color: widget.theme.main,
                onTap: () => setState(() => _navIndex = i),
              );
            }),
          ],
        ),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: const EdgeInsets.all(kS20),
          child: _buildContent(),
        )),
      ],
    );
  }

  Widget _buildContent() {
    final accent = widget.theme.main;
    switch (_navIndex) {
      case 0: return _ModelSettings(color: accent);
      case 1: return _ParamSettings(color: accent);
      case 2: return _ApiServiceSettings(color: accent);
      case 3: return _AppearanceSettings(color: accent);
      case 4: return _ShortcutsSettings();
      default: return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  模型信息
// ═══════════════════════════════════════════════════════════════════════════════

class _ModelSettings extends StatelessWidget {
  final Color color;
  const _ModelSettings({required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '当前模型',
            description: 'MOSS-TTS-Nano 是一个轻量级的语音合成模型',
            child: Column(
              children: [
                _infoRow('模型名称', 'MOSS-TTS-Nano-100M'),
                const SizedBox(height: kS8),
                _infoRow('架构类型', 'Attention-based AR Decoder + AudioCodec'),
                const SizedBox(height: kS8),
                _infoRow('参数量', '约 100M'),
                const SizedBox(height: kS8),
                _infoRow('支持语言', '中文 / English'),
                const SizedBox(height: kS8),
                _infoRow('采样率', '48000 Hz'),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '开源地址',
            description: '欢迎 Star & Fork',
            child: _GitHubLink(color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: kTextBase, color: kTextSecondary)),
        ),
        Text(value, style: TextStyle(fontSize: kTextBase, color: kTextPrimary)),
      ],
    );
  }
}

class _GitHubLink extends StatelessWidget {
  final Color color;
  const _GitHubLink({required this.color});

  @override
  Widget build(BuildContext context) {
    const url = 'https://github.com/OpenMOSS/MOSS-TTS-Nano';
    return Container(
      padding: const EdgeInsets.all(kS12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: color),
          const SizedBox(width: kS8),
          Expanded(
            child: Text(url,
              style: TextStyle(fontSize: kTextBase, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: kS8),
          MossButton(
            text: '复制',
            icon: Icons.content_copy,
            type: MossButtonType.ghost,
            color: color,
            height: 28,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已复制链接'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  生成参数设置
// ═══════════════════════════════════════════════════════════════════════════════

class _ParamSettings extends StatefulWidget {
  final Color color;
  const _ParamSettings({required this.color});

  @override
  State<_ParamSettings> createState() => _ParamSettingsState();
}

class _ParamSettingsState extends State<_ParamSettings> {
  late double _temperature;
  late double _topK;
  late double _topP;
  late double _repPenalty;
  late double _maxFrames;
  late int _seed;

  @override
  void initState() {
    super.initState();
    _temperature = SettingsService.temperature;
    _topK = SettingsService.topK.toDouble();
    _topP = SettingsService.topP;
    _repPenalty = SettingsService.repetitionPenalty;
    _maxFrames = SettingsService.maxFrames.toDouble();
    _seed = SettingsService.seed;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '采样参数',
            description: '控制生成语音的随机性和多样性',
            child: Column(
              children: [
                MossSettingsSlider(
                  label: '温度',
                  hint: '越高越随机',
                  value: _temperature,
                  min: 0.1, max: 2.0, divisions: 38,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) {
                    setState(() => _temperature = v);
                    SettingsService.setTemperature(v);
                  },
                ),
                MossSettingsSlider(
                  label: 'Top-K',
                  hint: '候选 token 数',
                  value: _topK,
                  min: 1, max: 100, divisions: 99,
                  formatValue: (v) => v.round().toString(),
                  color: widget.color,
                  onChanged: (v) {
                    setState(() => _topK = v);
                    SettingsService.setTopK(v.round());
                  },
                ),
                MossSettingsSlider(
                  label: 'Top-P',
                  hint: '累积概率阈值',
                  value: _topP,
                  min: 0.1, max: 1.0, divisions: 18,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) {
                    setState(() => _topP = v);
                    SettingsService.setTopP(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '惩罚与限制',
            description: '控制重复和音频长度',
            child: Column(
              children: [
                MossSettingsSlider(
                  label: '重复惩罚',
                  hint: '越高越不重复',
                  value: _repPenalty,
                  min: 1.0, max: 2.0, divisions: 20,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) {
                    setState(() => _repPenalty = v);
                    SettingsService.setRepetitionPenalty(v);
                  },
                ),
                MossSettingsSlider(
                  label: '最大帧',
                  hint: '越长音频越久',
                  value: _maxFrames,
                  min: 50, max: 1000, divisions: 38,
                  formatValue: (v) => v.round().toString(),
                  color: widget.color,
                  onChanged: (v) {
                    setState(() => _maxFrames = v);
                    SettingsService.setMaxFrames(v.round());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '种子',
            description: '固定种子可复现相同结果（0=随机）',
            child: MossSettingsRow(
              label: '种子',
              control: SizedBox(
                width: 120,
                child: MossTextField(
                  controller: TextEditingController(text: _seed.toString()),
                  hintText: '0 = 随机',
                  color: widget.color,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      _seed = parsed;
                      SettingsService.setSeed(parsed);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  API 服务
// ═══════════════════════════════════════════════════════════════════════════════

class _ApiServiceSettings extends StatefulWidget {
  final Color color;
  const _ApiServiceSettings({required this.color});

  @override
  State<_ApiServiceSettings> createState() => _ApiServiceSettingsState();
}

class _ApiServiceSettingsState extends State<_ApiServiceSettings> {
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

  void _onCtrlChanged() => setState(() {});

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
            title: 'HTTP API 服务',
            description: '启动后可通过 HTTP 请求调用 TTS 合成',
            child: Column(
              children: [
                MossSettingsRow(
                  label: '启用服务',
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
                  label: '端口号',
                  control: SizedBox(
                    width: 120,
                    child: MossTextField(
                      controller: _portCtrl,
                      hintText: '8080',
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 1024 && parsed <= 65535) {
                          _port = parsed;
                          SettingsService.setApiPort(parsed);
                        }
                      },
                      color: widget.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '状态',
            description: running ? '服务运行中' : '服务已停止',
            child: Column(
              children: [
                MossSettingsRow(
                  label: '状态',
                  control: Row(
                    children: [
                      MossStatusDot(active: running),
                      const SizedBox(width: kS6),
                      Text(running ? '运行中' : '已停止',
                        style: TextStyle(fontSize: kTextBase, color: running ? kSuccess : kTextSecondary)),
                    ],
                  ),
                ),
                if (running) ...[
                  const SizedBox(height: kS8),
                  MossSettingsRow(
                    label: '地址',
                    control: Text('http://localhost:${server?.port ?? _port}',
                      style: TextStyle(fontSize: kTextBase, color: widget.color)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '接口文档',
            description: '所有接口返回 JSON 或 WAV 音频',
            child: Column(
              children: [
                _endpointRow('POST', '/v1/tts', '合成语音 → WAV'),
                const SizedBox(height: kS6),
                _endpointRow('GET', '/v1/voices', '音色列表 → JSON'),
                const SizedBox(height: kS6),
                _endpointRow('GET', '/v1/health', '健康检查 → JSON'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpointRow(String method, String path, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kS10, vertical: kS6),
      decoration: BoxDecoration(
        color: kBg,
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
          Text(path, style: TextStyle(fontSize: kTextBase, color: kTextPrimary, fontFamily: 'monospace')),
          const Spacer(),
          Text(desc, style: TextStyle(fontSize: kTextSm, color: kTextSecondary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  外观设置
// ═══════════════════════════════════════════════════════════════════════════════

class _AppearanceSettings extends StatelessWidget {
  final Color color;
  const _AppearanceSettings({required this.color});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '主题',
            description: '切换亮色/暗色模式',
            child: MossSettingsRow(
              label: '主题模式',
              control: Row(
                children: [
                  _themeChip('light', '亮色', Icons.light_mode),
                  const SizedBox(width: kS8),
                  _themeChip('dark', '暗色', Icons.dark_mode),
                ],
              ),
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '语言',
            description: '界面语言设置',
            child: MossSettingsRow(
              label: '语言',
              control: MossDropdown<String>(
                value: SettingsService.language,
                onChanged: (v) {
                  if (v != null) SettingsService.setLanguage(v);
                },
                placeholder: '选择语言',
                color: color,
                items: const [
                  DropdownItem('中文', 'zh'),
                  DropdownItem('English', 'en'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeChip(String mode, String label, IconData icon) {
    final active = SettingsService.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => SettingsService.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: kS8),
          decoration: BoxDecoration(
            color: active ? kAccent.withValues(alpha: 0.1) : kBg,
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(
              color: active ? kAccent : kBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? kAccent : kTextSecondary),
              const SizedBox(width: kS6),
              Text(label, style: TextStyle(
                fontSize: kTextBase,
                color: active ? kAccent : kTextPrimary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  快捷键说明
// ═══════════════════════════════════════════════════════════════════════════════

class _ShortcutsSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('⌘ + Enter', '生成语音'),
      ('⌘ + S', '保存音频'),
      ('⌘ + ,', '打开设置'),
      ('⌘ + 1-4', '切换 Tab'),
      ('⌘ + F', '搜索音色'),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '键盘快捷键',
            description: '提高操作效率的快捷键组合',
            child: Column(
              children: shortcuts.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: kS8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kS8, vertical: kS4,
                      ),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(kRadiusSm),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(s.$1, style: const TextStyle(
                        fontSize: kTextSm,
                        color: kTextPrimary,
                        fontFamily: kFontFamily,
                      )),
                    ),
                    const SizedBox(width: kS12),
                    Text(s.$2, style: const TextStyle(
                      fontSize: kTextBase, color: kTextSecondary,
                    )),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
