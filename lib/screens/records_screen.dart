import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../models/room.dart';
import '../services/record_repository.dart';
import '../theme.dart';
import '../widgets/jd_widgets.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/skin.dart';

/// 개인 기록 목록. 기록 하나 삭제·전체 삭제는 확인창을 거친다.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    super.key,
    required this.repository,
    this.onPickMission,
    this.initialDay,
    this.loadChallenges,
    this.onOpenChallenge,
  });

  final RecordRepository repository;

  /// 기록이 없을 때 '미션 고르기'를 누르면 부른다. 없으면 이전 화면으로 돌아간다.
  final VoidCallback? onPickMission;

  /// 처음 고를 날짜. 없으면 오늘.
  final DateTime? initialDay;

  /// 내가 참여한 챌린지들을 불러온다. 없으면(로그인 전 등) 챌린지 기록 칸을 숨긴다.
  final Future<List<ChallengeHistory>> Function()? loadChallenges;

  /// 챌린지 하나를 누르면 그 방 화면(진행도·단톡방·인증)을 연다.
  final Future<void> Function(String roomId)? onOpenChallenge;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<MissionRecord>? _records; // null이면 불러오는 중
  bool _loadFailed = false;
  bool _deleting = false;
  late DateTime _selected = dayOf(widget.initialDay ?? DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  /// 기록 탭에서 지금 보는 칸: false면 내 미션, true면 챌린지.
  bool _showChallenges = false;
  List<ChallengeHistory>? _challenges; // null이면 불러오는 중
  bool _challengesFailed = false;

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

  Future<void> _loadChallenges() async {
    final load = widget.loadChallenges;
    if (load == null) return;
    setState(() => _challengesFailed = false);
    try {
      final list = await load();
      if (mounted) setState(() => _challenges = list);
    } catch (_) {
      if (mounted) setState(() => _challengesFailed = true);
    }
  }

  void _pickView(bool challenges) {
    setState(() => _showChallenges = challenges);
    if (challenges && _challenges == null) _loadChallenges();
  }

  Future<void> _openChallenge(ChallengeHistory c) async {
    await widget.onOpenChallenge?.call(c.id);
    if (mounted) await _loadChallenges();
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
    final body = _showChallenges ? _challengeList() : _missionBody(records);
    return Scaffold(
      backgroundColor: JdColors.ocean ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: JdColors.ocean ? Colors.transparent : null,
        title: const Text('내 기록'),
        actions: [
          if (!_showChallenges && records != null && records.isNotEmpty)
            IconButton(
              tooltip: '전체 삭제',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _deleting ? null : _deleteAll,
            ),
        ],
      ),
      body: widget.loadChallenges == null
          ? body
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('내 미션'), icon: Icon(Icons.spa_outlined)),
                      ButtonSegment(value: true, label: Text('챌린지'), icon: Icon(Icons.groups_outlined)),
                    ],
                    selected: {_showChallenges},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => _pickView(v.first),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }

  Widget _missionBody(List<MissionRecord>? records) {
    return _loadFailed
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
                    if (JdColors.ocean)
                      const SeaCrabReader()
                    else
                      Icon(Icons.spa_outlined, size: 56, color: JdColors.solo),
                    const SizedBox(height: 16),
                    const Text('아직 기록이 없어요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('미션 하나를 완료하고 첫 기록을 남겨 보세요.'),
                    const SizedBox(height: 16),
                    SkinPrimaryButton(
                      onPressed: widget.onPickMission ?? () => Navigator.of(context).pop(),
                      label: '미션 고르기',
                    ),
                  ]),
                ))
              : _calendar(records);
  }

  /// 내가 참여한 모든 챌린지. 누르면 방 화면에서 진행도·단톡방·인증을 다시 볼 수 있다.
  Widget _challengeList() {
    final list = _challenges;
    if (_challengesFailed) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('챌린지 기록을 불러오지 못했어요'),
        TextButton(onPressed: _loadChallenges, child: const Text('다시 불러오기')),
      ]));
    }
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (JdColors.ocean) ...[const SeaEmptyArt(), const SizedBox(height: 16)],
              Text('아직 함께한 챌린지가 없어요.\n챌린지 탭에서 친구와 시작해 보세요.',
                  textAlign: TextAlign.center, style: TextStyle(color: JdColors.subtle)),
            ],
          ),
        ),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final c in list) _ChallengeTile(item: c, now: now, onTap: () => _openChallenge(c)),
        ],
      ),
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
            // 연속 기록은 한 번 끊기면 0이 돼서 의욕을 꺾는다. 끊겨도 줄지 않는 '해낸 날'을 센다.
            _Stat(label: '이번 달 해낸 날', value: '${monthRecords.map((r) => dayOf(r.completedAt)).toSet().length}일'),
            const SizedBox(width: 10),
            _Stat(label: '전체 기록', value: '${records.length}개'),
          ],
        ),
        const SizedBox(height: 16),
        PixelPanel(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: _MonthGrid(
            month: _month,
            today: today,
            selected: _selected,
            byDay: byDay,
            onSelect: (day) => setState(() => _selected = day),
          ),
        ),
        const Divider(height: 28),
        Text('${_selected.month}월 ${_selected.day}일 (${_dowNames[_selected.weekday % 7]})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (dayRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('이날은 기록이 없어요.', style: TextStyle(color: JdColors.subtle)),
          ),
        for (final r in dayRecords)
          _RecordTile(record: r, onDelete: _deleting ? null : () => _deleteOne(r)),
      ],
    );
  }
}

const _dowNames = ['일', '월', '화', '수', '목', '금', '토'];

String _md(DateTime t) => '${t.year}.${t.month}.${t.day}';

/// 챌린지 기록 한 줄: 이름·회차·기간·결과.
class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.item, required this.now, required this.onTap});

  final ChallengeHistory item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = item;
    final status = c.statusAt(now);
    final goal = c.goal;
    final String state = switch (status) {
      RoomStatus.recruiting => '친구 모집 중',
      RoomStatus.scheduled => '시작 예정',
      RoomStatus.active => '진행 중',
      RoomStatus.finished => c.goalReachedAt != null ? '목표 달성' : '끝남',
      RoomStatus.cancelled => '취소됨',
      RoomStatus.expired => '모집 끝남',
    };
    final period = c.startsAt == null || c.endsAt == null
        ? '${c.memberCount}명'
        : '${_md(c.startsAt!.toLocal())} ~ ${_md(c.endsAt!.toLocal().subtract(const Duration(days: 1)))} · ${c.memberCount}명';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        customBorder: JdShapes.card,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(challengeIcon(c.kind), color: JdColors.together),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.round > 1 ? '${c.round}회차 · ' : ''}${c.challengeName}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(period, style: TextStyle(fontSize: 12, color: JdColors.faint)),
                    if (goal != null && goal > 0) ...[
                      const SizedBox(height: 8),
                      PixelBar(value: c.earned / goal, color: JdColors.together),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(state,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: status == RoomStatus.finished && c.goalReachedAt != null
                              ? JdColors.leaf
                              : JdColors.subtle)),
                  if (goal != null && goal > 0)
                    Text('${c.earned}/$goal회', style: TextStyle(fontSize: 12, color: JdColors.faint)),
                ],
              ),
              Icon(Icons.chevron_right, color: JdColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: ShapeDecoration(color: JdColors.cream, shape: JdShapes.soft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: JdColors.subtle)),
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
            Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, color: JdColors.faint)))),
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
              full: missions >= kDailyMissionCount,
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
    final time = record.completedAt.toLocal();
    final title = recordTitle(record);
    return InkWell(
      onTap: record.hasPhoto ? () => _showPhoto(context, record) : null,
      customBorder: const PixelBorder(step: 2, steps: 1),
      child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          if (record.hasPhoto)
            Semantics(
              label: '사진 크게 보기',
              child: ClipPath(
                key: ValueKey('recordPhoto-${record.id}'),
                clipper: const ShapeBorderClipper(shape: PixelBorder(step: 2, steps: 1)),
                child: Image.memory(base64Decode(record.photo!),
                    width: 48, height: 48, fit: BoxFit.cover, gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const CheckSquare(checked: true)),
              ),
            )
          else
            const CheckSquare(checked: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                if (record.memo.isNotEmpty)
                  Text(record.memo, style: TextStyle(fontSize: 12, color: JdColors.faint)),
              ],
            ),
          ),
          Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: JdColors.faint)),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline, size: 20),
            color: JdColors.faint,
            onPressed: onDelete,
          ),
        ],
      ),
      ),
    );
  }
}

/// 미션 기록 사진을 크게 본다. 미션 이름·메모·시각을 함께 보여 준다.
Future<void> _showPhoto(BuildContext context, MissionRecord record) {
  final t = record.completedAt.toLocal();
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InteractiveViewer(
            maxScale: 4,
            child: Image.memory(base64Decode(record.photo!),
                key: const Key('recordPhotoLarge'),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('사진을 불러오지 못했어요', textAlign: TextAlign.center),
                    )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recordTitle(record), style: gameText(size: 16)),
                      const SizedBox(height: 2),
                      Text('${t.year}.${t.month}.${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: JdColors.faint)),
                      if (record.memo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(record.memo, style: TextStyle(fontSize: 14, color: JdColors.ink)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
