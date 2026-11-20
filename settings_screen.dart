import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'database_helper.dart';
import 'strings.dart';
import 'widgets.dart';

/// Settings: question timer, sound, and a backup you can copy / paste (no internet needed).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<int> _timerChoices = [0, 10, 20, 30, 60];

  Future<void> _backup() async {
    final text = await DatabaseHelper.instance.exportJson();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, context.t('backupCopied'));
  }

  Future<void> _restore() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (!DatabaseHelper.looksLikeBackup(text)) {
      showSnack(context, context.t('restoreFail'));
      return;
    }
    final ok = await confirmDialog(
      context,
      title: context.t('restoreTitle'),
      body: context.t('restoreConfirm'),
      confirmLabel: context.t('restore'),
    );
    if (!ok || !mounted) return;
    try {
      await DatabaseHelper.instance.importJson(text);
      AppState.drawnIds.clear();
      await AppState.selectStudent(null);
      await AppState.setActiveClass(null);
      AppState.dataEpoch.value++;
      if (mounted) showSnack(context, context.t('restoreOk'));
    } catch (_) {
      if (mounted) showSnack(context, context.t('restoreFail'));
    }
  }

  Widget _title(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Question timer
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(Icons.timer_rounded, context.t('timerTitle'), AppColors.amber),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: AppState.timerSeconds,
                  builder: (context, current, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in _timerChoices)
                        ChoiceChip(
                          label: Text(v == 0 ? context.t('timerOff') : '$v ${context.t('seconds')}'),
                          selected: current == v,
                          onSelected: (_) => AppState.setTimer(v),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sound
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ValueListenableBuilder<bool>(
              valueListenable: AppState.soundOn,
              builder: (context, on, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.volume_up_rounded, color: AppColors.indigo),
                title: Text(
                  context.t('soundTitle'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(context.t('soundSub')),
                value: on,
                onChanged: AppState.setSound,
              ),
            ),
          ),

          // Backup / restore
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(Icons.shield_rounded, context.t('backupTitle'), AppColors.emerald),
                const SizedBox(height: 8),
                Text(context.t('backupCopySub'), style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                    onPressed: _backup,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.t('backupCopy')),
                  ),
                ),
                const SizedBox(height: 16),
                Text(context.t('restoreSub'), style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.paste_rounded),
                    label: Text(context.t('restoreTitle')),
                  ),
                ),
              ],
            ),
          ),

          // About
          SoftCard(
            child: Row(
              children: [
                const Icon(Icons.functions_rounded, color: AppColors.indigo, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('appTitle'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        context.t('aboutText'),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
