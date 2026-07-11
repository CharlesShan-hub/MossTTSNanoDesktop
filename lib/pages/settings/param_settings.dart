import 'package:flutter/material.dart';
import '../../services/i18n_service.dart';
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
            title: I18n.t('settings.sampling'),
            description: I18n.t('settings.samplingDesc'),
            child: Column(
              children: [
                MossSettingsSlider(
                  label: I18n.t('single.paramTemp'), hint: I18n.t('single.hintTemp'),
                  value: _temperature,
                  min: 0.1, max: 2.0, divisions: 38,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) { setState(() => _temperature = v); SettingsService.setTemperature(v); },
                ),
                MossSettingsSlider(
                  label: I18n.t('single.paramTopK'), hint: I18n.t('single.hintTopK'),
                  value: _topK,
                  min: 1, max: 100, divisions: 99,
                  formatValue: (v) => v.round().toString(),
                  color: widget.color,
                  onChanged: (v) { setState(() => _topK = v); SettingsService.setTopK(v.round()); },
                ),
                MossSettingsSlider(
                  label: I18n.t('single.paramTopP'), hint: I18n.t('single.hintTopP'),
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
            title: I18n.t('settings.penalty'),
            description: I18n.t('settings.penaltyDesc'),
            child: Column(
              children: [
                MossSettingsSlider(
                  label: I18n.t('single.paramRep'), hint: I18n.t('single.hintRep'),
                  value: _repPenalty,
                  min: 1.0, max: 2.0, divisions: 20,
                  formatValue: (v) => v.toStringAsFixed(2),
                  color: widget.color,
                  onChanged: (v) { setState(() => _repPenalty = v); SettingsService.setRepetitionPenalty(v); },
                ),
                MossSettingsSlider(
                  label: I18n.t('single.paramMaxFrames'), hint: I18n.t('single.hintMaxFrames'),
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
            title: I18n.t('settings.seed'),
            description: I18n.t('settings.seedDesc'),
            child: MossSettingsRow(
              label: I18n.t('settings.seed'),
              control: SizedBox(
                width: 120,
                child: MossTextField(
                  controller: TextEditingController(text: _seed.toString()),
                  hintText: I18n.t('single.hintSeed'), color: widget.color,
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
