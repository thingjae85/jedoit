import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../services/record_repository.dart';
import '../theme.dart';
import '../widgets/jd_widgets.dart';

/// 개인 기록 목록. 기록 하나 삭제·전체 삭제는 확인창을 거친다.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.repository, this.onPickMission});

  final RecordRepository repository;

  /// 기록이 없을 때 '미션 고르기'를 누르면 부른다. 없으면 이전 화면으로 돌아간다.
  final VoidCallback? onPickMission;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<MissionRecord>? _records; // null이면 불러오는 중
  bool _loadFailed = false;
  bool _deleting = false;
  late DateTime _selected = dayOf(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _remove(Future<void> Function() action) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteOne(MissionRecord record) async {
    final ok = await _confirm(
      title: '이 기록을 삭제할까요?',
      message: '삭제하면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok) return;
    await _remove(() => widget.repository.delete(record.id));
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: '모든 기록을 삭제할까요?',
      message: '이 기기에 저장된 기록이 모두 지워지며 되돌릴 수 없어요.',
      confirmLabel: '전체 삭제',
    );
    if (!ok) return;
    await _remove(widget.repository.deleteAll);
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 기록'),
        actions: [
          if (records != null && records.isNotEmpty)
            IconButton(
              tooltip: '전체 삭제',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _deleting ? null : _deleteAll,
            ),
        ],
      ),
      body: _loadFailed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('기록을 불러오지 못했어요'),
              TextButton(onPressed: _load, child: const Text('다시 불러오기')),
            ]))
          : records == null
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.spa_outlined, size: 56, color: JdColors.solo),
                    const SizedBox(height: 16),
                    const Text('아직 기록이 없어요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('미션 하나를 완료하고 첫 기록을 남겨 보세요.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.onPickMission ?? () => Navigator.of(context).pop(),
                      child: const Text('미션 고르기'),
                    ),
                  ]),
                ))
              : _calendar(records),
    );
  }

  Widget _calendar(List<MissionRecord> records) {
    final byDay = recordsByDay(records);
    final today = dayOf(DateTime.now());
    final monthRecords = records.where((r) => dayOf(r.completedAt).year == _month.year && dayOf(r.completedAt).month == _month.month);
    final dayRecords = byDay[_selected] ?? const <MissionRecord>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Text('${_month.year}년 ${_month.month}월', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(tooltip: '이전 달', onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
            IconButton(tooltip: '다음 달', onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Stat(label: '이번 달 완료', value: '${monthRecords.length}개'),
            const SizedBox(width: 10),
            _Stat(label: '연속 실천', value: '${_streak(byDay, today)}일'),
            const SizedBox(width: 10),
            _Stat(label: '전체 기록', value: '${records.length}개'),
          ],
        ),
        const SizedBox(height: 16),
        _MonthGrid(
          month: _month,
          today: today,
          selected: _selected,
          byDay: byDay,
          onSelect: (day) => setState(() => _selected = day),
        ),
        const Divider(height: 28),
        Text('${_selected.month}월 ${_selected.day}일 (${_dowNames[_selected.weekday % 7]})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (dayRecords.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('이날은 기록이 없어요.', style: TextStyle(color: JdColors.subtle)),
          ),
        for (final r in dayRecords)
          _RecordTile(record: r, onDelete: _deleting ? null : () => _deleteOne(r)),
      ],
    );
  }

  /// 오늘(오늘 기록이 없으면 어제)부터 거꾸로 이어진 기록한 날 수.
  static int _streak(Map<DateTime, List<MissionRecord>> byDay, DateTime today) {
    var day = byDay.containsKey(today) ? today : today.subtract(const Duration(days: 1));
    var count = 0;
    while (byDay.containsKey(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}

const _dowNames = ['일', '월', '화', '수', '목', '금', '토'];

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: JdColors.panel, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// 일요일부터 시작하는 월 달력. 날짜마다 마친 미션 수를 칸에 보여 준다.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.byDay,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, List<MissionRecord>> byDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _cell(DateTime(month.year, month.month, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        Row(children: [
          for (final w in _dowNames)
            Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 12, color: JdColors.faint)))),
        ]),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [for (final c in cells.sublist(row * 7, row * 7 + 7)) Expanded(child: c)]),
          ),
      ],
    );
  }

  Widget _cell(DateTime day) {
    final missions = (byDay[day] ?? const <MissionRecord>[]).map((r) => r.missionId).toSet().length;
    final isToday = day == today;
    return InkWell(
      onTap: () => onSelect(day),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            DayBlob(
              count: missions,
              full: missions >= kMissions.length,
              today: isToday,
              future: day.isAfter(today),
              selected: day == selected,
              size: 32,
            ),
            const SizedBox(height: 3),
            Text('${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  color: isToday || day == selected ? JdColors.ink : JdColors.faint,
                  fontWeight: isToday || day == selected ? FontWeight.w700 : FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final MissionRecord record;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final mission = missionById(record.missionId);
    final time = record.completedAt.toLocal();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          const CheckSquare(checked: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission?.title ?? '알 수 없는 미션', style: const TextStyle(fontSize: 15)),
                if (record.memo.isNotEmpty)
                  Text(record.memo, style: const TextStyle(fontSize: 12, color: JdColors.faint)),
              ],
            ),
          ),
          Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: JdColors.faint)),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline, size: 20),
            color: JdColors.faint,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
