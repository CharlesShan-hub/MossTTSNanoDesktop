import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../theme/components.dart';

/// 参数编辑弹窗
class SingleParamDialog extends StatefulWidget {
  const SingleParamDialog();

  @override
  State<SingleParamDialog> createState() => _SingleParamDialogState();
}

class _SingleParamDialogState extends State<SingleParamDialog> {
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
              label: '温度', hint: '越高越随机',
              value: _temperature,
              min: 0.1, max: 2.0, divisions: 38,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() { _temperature = v; SettingsService.setTemperature(v); }),
            ),
            MossSettingsSlider(
              label: 'Top-K', hint: '候选 token 数',
              value: _topK,
              min: 1, max: 100, divisions: 99,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() { _topK = v; SettingsService.setTopK(v.round()); }),
            ),
            MossSettingsSlider(
              label: 'Top-P', hint: '累积概率阈值',
              value: _topP,
              min: 0.1, max: 1.0, divisions: 18,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() { _topP = v; SettingsService.setTopP(v); }),
            ),
            MossSettingsSlider(
              label: '重复惩罚', hint: '越高越不重复',
              value: _repPenalty,
              min: 1.0, max: 2.0, divisions: 20,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() { _repPenalty = v; SettingsService.setRepetitionPenalty(v); }),
            ),
            MossSettingsSlider(
              label: '最大帧', hint: '越长音频越久',
              value: _maxFrames,
              min: 50, max: 1000, divisions: 38,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() { _maxFrames = v; SettingsService.setMaxFrames(v.round()); }),
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
                    if (parsed != null) { _seed = parsed; SettingsService.setSeed(parsed); }
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
