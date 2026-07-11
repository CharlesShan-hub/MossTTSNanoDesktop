import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../../services/i18n_service.dart';
import '../theme/components.dart';
import 'param_dialog.dart';

/// 高级参数面板（显示 + 编辑入口）
class AdvParamsPanel extends StatelessWidget {
  final VoidCallback? onChanged;

  const AdvParamsPanel({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = MossTheme.of(context);
    return MossGlassCard(
      padding: const EdgeInsets.all(kS12),
      child: Column(
        children: [
          _row(theme, I18n.t('single.paramTemp'), SettingsService.temperature.toStringAsFixed(2)),
          _row(theme, I18n.t('single.paramTopK'), SettingsService.topK.toString()),
          _row(theme, I18n.t('single.paramTopP'), SettingsService.topP.toStringAsFixed(2)),
          _row(theme, I18n.t('single.paramRep'), SettingsService.repetitionPenalty.toStringAsFixed(2)),
          _row(theme, I18n.t('single.paramMaxFrames'), SettingsService.maxFrames.toString()),
          _row(theme, I18n.t('single.paramSeed'), SettingsService.seed.toString()),
          const SizedBox(height: kS4),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _edit(context),
                borderRadius: BorderRadius.circular(kRadiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kS8, vertical: kS4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: theme.accent),
                      const SizedBox(width: kS4),
                      Text(I18n.t('single.editParams'), style: TextStyle(fontSize: kTextXs, color: theme.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(MossThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kS6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: kTextSm, color: theme.textSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: kTextSm, color: theme.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    await showMossDialog(
      context: context,
      title: I18n.t('single.dialogTitle'),
      content: const SingleParamDialog(),
      confirmText: I18n.t('single.dialogConfirm'),
    );
    onChanged?.call();
  }
}
