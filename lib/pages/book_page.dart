import 'package:flutter/material.dart';

import '../services/i18n_service.dart';
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
            MossSidebarSection(title: I18n.t('tabs.book'), child: const SizedBox.shrink()),
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
              Text(I18n.t('book.comingSoon'),
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
      text: I18n.t('book.defaultParams'),
      icon: Icons.tune,
      type: MossButtonType.secondary,
      color: theme.main,
      onTap: () => showMossDialog(
        context: context,
        title: I18n.t('book.dialogTitle'),
        content: const _ParamDialogContent(),
        confirmText: I18n.t('book.dialogConfirm'),
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
              label: I18n.t('single.paramTemp'),
              hint: I18n.t('single.hintTemp'),
              value: _temperature,
              min: 0.1, max: 2.0, divisions: 38,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _temperature = v;
                SettingsService.setTemperature(v);
              }),
            ),
            MossSettingsSlider(
              label: I18n.t('single.paramTopK'),
              hint: I18n.t('single.hintTopK'),
              value: _topK,
              min: 1, max: 100, divisions: 99,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _topK = v;
                SettingsService.setTopK(v.round());
              }),
            ),
            MossSettingsSlider(
              label: I18n.t('single.paramTopP'),
              hint: I18n.t('single.hintTopP'),
              value: _topP,
              min: 0.1, max: 1.0, divisions: 18,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _topP = v;
                SettingsService.setTopP(v);
              }),
            ),
            MossSettingsSlider(
              label: I18n.t('single.paramRep'),
              hint: I18n.t('single.hintRep'),
              value: _repPenalty,
              min: 1.0, max: 2.0, divisions: 20,
              formatValue: (v) => v.toStringAsFixed(2),
              onChanged: (v) => setState(() {
                _repPenalty = v;
                SettingsService.setRepetitionPenalty(v);
              }),
            ),
            MossSettingsSlider(
              label: I18n.t('single.paramMaxFrames'),
              hint: I18n.t('single.hintMaxFrames'),
              value: _maxFrames,
              min: 50, max: 1000, divisions: 38,
              formatValue: (v) => v.round().toString(),
              onChanged: (v) => setState(() {
                _maxFrames = v;
                SettingsService.setMaxFrames(v.round());
              }),
            ),
            MossSettingsRow(
              label: I18n.t('single.paramSeed'),
              control: SizedBox(
                width: 120,
                child: MossTextField(
                  controller: TextEditingController(text: _seed.toString()),
                  hintText: I18n.t('single.hintSeed'),
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
