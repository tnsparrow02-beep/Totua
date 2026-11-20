import 'package:flutter/material.dart';

import 'app_state.dart';
import 'database_helper.dart';
import 'digits.dart';
import 'strings.dart';
import 'widgets.dart';

/// Start time of every period (same hours as the timetable). Each period lasts one hour.
const List<String> kSchoolPeriodTimes = [
  '08:00', '09:00', '10:00', '11:00', '13:00', '14:00', '15:00', '16:00', '17:00',
];

class _TodayBlock {
  final int classId;
  final String className;
  final int firstSlot;
  int lastSlot;
  final List<String> rooms;

  _TodayBlock(this.classId, this.className, this.firstSlot, this.rooms) : lastSlot = firstSlot;
}

int _safeSlot(int slot) => slot.clamp(0, kSchoolPeriodTimes.length - 1).toInt();

String _startLabel(int slot) => kSchoolPeriodTimes[_safeSlot(slot)];

int _startMinutes(int slot) {
  final t = _startLabel(slot);
  return int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));
}

String _endLabel(int slot) {
  final m = _startMinutes(slot) + 60;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// Merges consecutive periods of the same class into one block.
List<_TodayBlock> _merge(List<TimetableEntry> entries) {
  final sorted = List<TimetableEntry>.of(entries)..sort((a, b) => a.slot.compareTo(b.slot));
  final blocks = <_TodayBlock>[];
  for (final e in sorted) {
    if (blocks.isNotEmpty &&
        blocks.last.classId == e.classId &&
        blocks.last.lastSlot == e.slot - 1) {
      blocks.last.lastSlot = e.slot;
      if (e.room.isNotEmpty && !blocks.last.rooms.contains(e.room)) blocks.last.rooms.add(e.room);
    } else {
      blocks.add(_TodayBlock(e.classId, e.className, e.slot, [if (e.room.isNotEmpty) e.room]));
    }
  }
  return blocks;
}

/// "Today" card: date + today's classes from the timetable.
/// The class being taught right now is highlighted; tap a class to make it the active class.
class TodayCard extends StatefulWidget {
  const TodayCard({super.key});

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
  List<_TodayBlock> _blocks = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseHelper.instance.getTimetable();
    final today = DateTime.now().weekday; // 1 = Monday
    final entries = all.where((e) => e.day == today).toList();
    if (!mounted) return;
    setState(() {
      _blocks = _merge(entries);
      _loaded = true;
    });
  }

  Widget _chip(BuildContext context, _TodayBlock b, int? activeId, int nowMinutes) {
    final color = kClassColors[b.classId % kClassColors.length];
    final isNow = nowMinutes >= _startMinutes(b.firstSlot) && nowMinutes < _startMinutes(b.lastSlot) + 60;
    final isActive = b.classId == activeId;
    final rooms = b.rooms.join(' / ');

    return Material(
      color: color.withValues(alpha: isNow ? 0.22 : 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await AppState.setActiveClass(b.classId);
          if (context.mounted) showSnack(context, '${context.t('activeClass')}: ${b.className}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    b.className,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, size: 16, color: color),
                  ],
                  if (isNow)
                    Text(
                      '  ·  ${context.t('nowLabel')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                      ),
                    ),
                ],
              ),
              Text(
                '${_startLabel(b.firstSlot)} – ${_endLabel(b.lastSlot)}${rooms.isEmpty ? '' : '  ·  $rooms'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return ValueListenableBuilder<int?>(
      valueListenable: AppState.activeClassId,
      builder: (context, activeId, _) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today_rounded, color: AppColors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.t('today')}  ·  ${formatFullDate(now, context.lang)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_blocks.isEmpty)
              Text(
                context.t('noClassesToday'),
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final b in _blocks) _chip(context, b, activeId, nowMinutes)],
              ),
          ],
        ),
      ),
    );
  }
}
