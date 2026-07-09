import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/settings_service.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  final ColorSeries theme;
  const SettingsPage({super.key, required this.theme});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _navIndex = 0;

  final _navItems = const [
    ('模型', Icons.memory),
    ('生成参数', Icons.tune),
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
      case 2: return _AppearanceSettings(color: accent);
      case 3: return _ShortcutsSettings();
      default: return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  模型设置
// ═══════════════════════════════════════════════════════════════════════════════

class _ModelSettings extends StatefulWidget {
  final Color color;
  const _ModelSettings({required this.color});

  @override
  State<_ModelSettings> createState() => _ModelSettingsState();
}

class _ModelSettingsState extends State<_ModelSettings> {
  final _pathCtrl = TextEditingController(text: SettingsService.modelPath);

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择模型目录',
    );
    if (result != null) {
      _pathCtrl.text = result;
      await SettingsService.setModelPath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MossSettingsGroup(
            title: '模型路径',
            description: '选择 ONNX 模型所在的目录，支持多模型切换',
            child: Column(
              children: [
                MossSettingsRow(
                  label: '路径',
                  control: Row(
                    children: [
                      Expanded(
                        child: MossTextField(
                          controller: _pathCtrl,
                          hintText: '未设置，使用内置模型',
                          onChanged: (v) => SettingsService.setModelPath(v),
                          color: widget.color,
                        ),
                      ),
                      const SizedBox(width: kS8),
                      MossButton(
                        text: '浏览',
                        icon: Icons.folder_open,
                        type: MossButtonType.secondary,
                        color: widget.color,
                        onTap: _pickPath,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kS16),
          MossSettingsGroup(
            title: '可用模型',
            description: '当前仅内置 MOSS-TTS-Nano-100M 模型',
            child: Container(
              padding: const EdgeInsets.all(kS12),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(kRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: kSuccess),
                  const SizedBox(width: kS8),
                  const Text('MOSS-TTS-Nano-100M',
                    style: TextStyle(fontSize: kTextBase, color: kTextPrimary)),
                  const Spacer(),
                  MossBadge(text: '使用中', color: kSuccess),
                ],
              ),
            ),
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
