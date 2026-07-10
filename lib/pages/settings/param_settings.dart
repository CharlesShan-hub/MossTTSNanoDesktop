import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../theme/components.dart';

class ParamSettings extends StatefulWidget {
  final Color color;
  const ParamSettings({required this.color});

  @override
  State<ParamSettings> createState() => _ParamSettingsState();
}

class _ParamSettingsState extends State<ParamSettings> {
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
                  label: '温度', hint: '越高越随机',
                  value: _temperature,
                  min: 0.1, max: 2.0, divisions: 38,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) { setState(() => _temperature = v); SettingsService.setTemperature(v); },
                ),
                MossSettingsSlider(
                  label: 'Top-K', hint: '候选 token 数',
                  value: _topK,
                  min: 1, max: 100, divisions: 99,
                  formatValue: (v) => v.round().toString(),
                  color: widget.color,
                  onChanged: (v) { setState(() => _topK = v); SettingsService.setTopK(v.round()); },
                ),
                MossSettingsSlider(
                  label: 'Top-P', hint: '累积概率阈值',
                  value: _topP,
                  min: 0.1, max: 1.0, divisions: 18,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) { setState(() => _topP = v); SettingsService.setTopP(v); },
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
                  label: '重复惩罚', hint: '越高越不重复',
                  value: _repPenalty,
                  min: 1.0, max: 2.0, divisions: 20,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) { setState(() => _repPenalty = v); SettingsService.setRepetitionPenalty(v); },
                ),
                MossSettingsSlider(
                  label: '最大帧', hint: '越长音频越久',
                  value: _maxFrames,
                  min: 50, max: 1000, divisions: 38,
                  formatValue: (v) => v.round().toString(),
                  color: widget.color,
                  onChanged: (v) { setState(() => _maxFrames = v); SettingsService.setMaxFrames(v.round()); },
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
                  hintText: '0 = 随机', color: widget.color,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) { _seed = parsed; SettingsService.setSeed(parsed); }
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
