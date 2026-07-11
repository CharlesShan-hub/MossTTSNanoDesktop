import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'theme/components.dart';

class BookPage extends StatelessWidget {
  final ColorSeries theme;
  const BookPage({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return Row(
      children: [
        MossGlassSidebar(
          margin: const EdgeInsets.fromLTRB(kS16, kS16, 0, kS16),
          children: [
            MossSidebarSection(title: '有声书', child: const SizedBox.shrink()),
          ],
        ),
        Expanded(child: MossGlassPanel(
          margin: const EdgeInsets.all(kS16),
          padding: const EdgeInsets.all(kS24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 48, color: theme.textMuted),
              const SizedBox(height: kS16),
              Text('有声书功能即将上线',
                style: TextStyle(fontSize: kTextLg, color: theme.textSecondary)),
              const SizedBox(height: kS24),
              _BookSettingsButton(theme: this.theme),
            ],
          ),
        )),
      ],
    );
  }
}

class _BookSettingsButton extends StatelessWidget {
  final ColorSeries theme;
  const _BookSettingsButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return MossButton(
      text: '默认参数',
      icon: Icons.tune,
      type: MossButtonType.secondary,
      color: theme.main,
      onTap: () => showMossDialog(
        context: context,
        title: '有声书默认参数',
        content: const _ParamDialogContent(),
        confirmText: '确定',
      ),
    );
  }
}

class _ParamDialogContent extends StatefulWidget {
  const _ParamDialogContent();

  @override
  State<_ParamDialogContent> createState() => _ParamDialogContentState();
}

class _ParamDialogContentState extends State<_ParamDialogContent> {
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
    return SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MossSettingsSlider(
              label: '温度',
              hint: '越高越随机',
              value: _temperature,
              min: 0.1, max: 2.0, divisions: 38,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _temperature = v;
                SettingsService.setTemperature(v);
              }),
            ),
            MossSettingsSlider(
              label: 'Top-K',
              hint: '候选 token 数',
              value: _topK,
              min: 1, max: 100, divisions: 99,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _topK = v;
                SettingsService.setTopK(v.round());
              }),
            ),
            MossSettingsSlider(
              label: 'Top-P',
              hint: '累积概率阈值',
              value: _topP,
              min: 0.1, max: 1.0, divisions: 18,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _topP = v;
                SettingsService.setTopP(v);
              }),
            ),
            MossSettingsSlider(
              label: '重复惩罚',
              hint: '越高越不重复',
              value: _repPenalty,
              min: 1.0, max: 2.0, divisions: 20,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _repPenalty = v;
                SettingsService.setRepetitionPenalty(v);
              }),
            ),
            MossSettingsSlider(
              label: '最大帧',
              hint: '越长音频越久',
              value: _maxFrames,
              min: 50, max: 1000, divisions: 38,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _maxFrames = v;
                SettingsService.setMaxFrames(v.round());
              }),
            ),
            MossSettingsRow(
              label: '种子',
              control: SizedBox(
                width: 120,
                child: MossTextField(
                  controller: TextEditingController(text: _seed.toString()),
                  hintText: '0 = 随机',
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
          ],
        ),
      ),
    );
  }
}
