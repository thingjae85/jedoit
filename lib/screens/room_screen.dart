import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/jd_widgets.dart';
import '../widgets/room_feed.dart';
import 'checkin_screen.dart';

/// 초대 링크: 앱 주소에 `?invite=코드`를 붙인다. OAuth의 `code` 파라미터와 겹치지 않는다.
String inviteLink(Uri base, String code) => Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
      queryParameters: {'invite': code},
    ).toString();

/// 방 상태를 한 줄 제목으로. 홈의 챌린지 카드에서도 쓴다.
String roomStatusTitle(RoomStatus status) => switch (status) {
      RoomStatus.recruiting => '친구를 기다리고 있어요',
      RoomStatus.scheduled => '시작을 기다리고 있어요',
      RoomStatus.active => '함께 하는 중',
      RoomStatus.finished => '챌린지가 끝났어요',
      RoomStatus.cancelled => '취소된 방이에요',
      RoomStatus.expired => '모집 시간이 끝났어요',
    };

/// 방 화면: 모집(초대 QR) → 예약 → 기간(3·5·7일) 동안 인증 → 종료 결과.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.rooms,
    required this.roomId,
    this.now = DateTime.now,
    this.autoRefresh = const Duration(seconds: 8),
  });

  final RoomService rooms;
  final String roomId;
  final DateTime Function() now;

  /// 방 화면을 보는 동안 피드를 다시 불러오는 간격. null이면 끈다.
  final Duration? autoRefresh;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomSummary? _summary;
  List<RoomMember> _members = [];
  List<MyCheckin> _mine = [];
  List<FeedItem> _feed = [];
  bool _loadFailed = false;
  bool _busy = false;
  Timer? _timer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    final every = widget.autoRefresh;
    if (every != null) _timer = Timer.periodic(every, (_) => _autoRefresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 친구가 인증하면 새로고침 없이 피드에 나타나고, 알림을 띄운다.
  Future<void> _autoRefresh() async {
    final s = _summary;
    if (_refreshing || _busy || s == null || s.statusAt(widget.now()) != RoomStatus.active) return;
    _refreshing = true;
    try {
      final before = {for (final f in _feed) f.key};
      await _load();
      if (!mounted) return;
      final fresh = _feed.where((f) => !f.isMe && !before.contains(f.key)).toList();
      for (final f in fresh.take(1)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.displayName}님이 방금 인증했어요! 응원해 주세요 👏')),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _react(FeedItem item, Reaction r) async {
    final i = _feed.indexWhere((f) => f.key == item.key);
    if (i < 0) return;
    setState(() => _feed[i] = item.withReaction(r, !item.mine(r)));
    try {
      final on = await widget.rooms.toggleReaction(widget.roomId, item, r);
      final j = _feed.indexWhere((f) => f.key == item.key);
      if (mounted && j >= 0) setState(() => _feed[j] = item.withReaction(r, on));
    } catch (e) {
      final j = _feed.indexWhere((f) => f.key == item.key);
      if (!mounted) return;
      if (j >= 0) setState(() => _feed[j] = item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(roomErrorMessage(e))));
    }
  }

  int _avatarIndexOf(FeedItem item) =>
      _members.indexWhere((m) => m.nickname == item.nickname && m.nicknameNo == item.nicknameNo).clamp(0, 99);

  /// 오늘(한국 시간) 인증만
  List<FeedItem> _todayFeed() {
    final k = widget.now().toUtc().add(const Duration(hours: 9));
    return _feed.where((f) => f.date.year == k.year && f.date.month == k.month && f.date.day == k.day).toList();
  }

  Future<void> _load() async {
    try {
      final s = await widget.rooms.summary(widget.roomId);
      final m = await widget.rooms.members(widget.roomId);
      // 내 인증 목록을 못 불러와도 방 화면은 보여 준다.
      var mine = <MyCheckin>[];
      var feed = <FeedItem>[];
      if (s.status != RoomStatus.recruiting) {
        try {
          mine = await widget.rooms.myCheckins(widget.roomId);
        } catch (_) {}
        try {
          feed = await widget.rooms.feed(widget.roomId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _summary = s;
        _members = m;
        _mine = mine;
        _feed = feed;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(roomErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStart() async {
    final ok = await _ask('시작을 확정할까요?',
        '지금 참가한 ${_members.length}명으로 오늘부터 바로 시작해 ${_summary?.days ?? 3}일 동안 진행해요. 오늘이 1일차예요. 확정 후에는 새로 참가할 수 없어요.');
    if (ok) await _run(() => widget.rooms.confirmStart(widget.roomId), done: '시작했어요! 오늘 첫 인증을 올려 보세요');
    await _load();
  }

  Future<void> _leave() async {
    final active = _summary?.statusAt(widget.now()) == RoomStatus.active;
    final ok = await _ask(
      '방에서 나갈까요?',
      active
          ? '지금까지 쌓은 진행도는 방에 남고, 이후에는 인증과 방 보기가 끝나요.'
          : '시작 전에 나가면 이 방은 취소되고, 모두 새 방을 만들 수 있어요.',
    );
    if (!ok) return;
    await _run(() => widget.rooms.leave(widget.roomId));
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _ask(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('확인')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deletePhoto(MyCheckin c) async {
    final ok = await _ask('사진을 삭제할까요?',
        '사진과 메모가 지워져요. 완료 체크와 이미 쌓인 진행도는 그대로 남아요.');
    if (!ok) return;
    await _run(() => widget.rooms.deletePhoto(widget.roomId, c.date), done: '사진을 삭제했어요');
    await _load();
  }

  Future<void> _cancelCheckin(MyCheckin c) async {
    final ok = await _ask('인증을 취소할까요?',
        '완료 체크가 취소되고 사진·메모가 지워져요. 현재 인증 수는 줄지만, 이미 쌓인 진행도는 남아요. '
        '오늘 인증이라면 남은 사진 올리기 횟수 안에서 다시 인증할 수 있어요.');
    if (!ok) return;
    await _run(() => widget.rooms.cancelCheckin(widget.roomId, c.date), done: '인증을 취소했어요');
    await _load();
  }

  Future<void> _openCheckIn() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckInScreen(
          rooms: widget.rooms,
          roomId: widget.roomId,
          mode: _summary?.checkinMode ?? CheckinMode.result,
          kind: _summary?.kind ?? ChallengeKind.tidy,
          title: _summary?.title ?? '책상 한 구역 정리',
        ),
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 인증했어요. 함께 진행도가 올라갔어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: Text(summary == null ? '챌린지' : '${summary.challengeName} 챌린지'),
        actions: [IconButton(tooltip: '새로고침', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: summary == null
          ? Center(
              child: _loadFailed
                  ? TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('방 정보를 다시 불러오기'))
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(onRefresh: _load, child: _body(context, summary)),
      bottomNavigationBar: summary?.statusAt(widget.now()) == RoomStatus.active
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: JdColors.together,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _busy ? null : _openCheckIn,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('오늘 인증하기'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body(BuildContext context, RoomSummary s) {
    final now = widget.now();
    final status = s.statusAt(now);
    final me = _members.where((m) => m.isMe).firstOrNull;
    final showChecks = status != RoomStatus.recruiting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(roomStatusTitle(status),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(_statusDetail(s, status), style: const TextStyle(fontSize: 14, color: JdColors.subtle)),
        const SizedBox(height: 18),
        if (status == RoomStatus.recruiting) _InviteCard(code: s.inviteCode, link: inviteLink(Uri.base, s.inviteCode)),
        if (status == RoomStatus.active || status == RoomStatus.finished) _ProgressCard(summary: s, feed: _feed, now: now),
        if (showChecks) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('방 피드', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: JdColors.togetherChip, borderRadius: BorderRadius.circular(8)),
                child: Text(s.checkinMode.label,
                    style: const TextStyle(fontSize: 12, color: JdColors.togetherText, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (status == RoomStatus.active && _todayFeed().isNotEmpty)
            TodayCollage(items: _todayFeed(), memberCount: _members.length, avatarIndexOf: _avatarIndexOf),
          if (_feed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('아직 인증이 없어요. 첫 인증을 올려 보세요!', style: TextStyle(color: JdColors.faint)),
            ),
          for (final item in _feed)
            FeedCard(
              key: ValueKey(item.key),
              item: item,
              avatarIndex: _avatarIndexOf(item),
              onReact: (r) => _react(item, r),
            ),
        ],
        if (_mine.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('내 인증', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final c in _mine)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  CheckSquare(checked: c.valid, color: JdColors.togetherFill),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.date.month}/${c.date.day} ${c.valid ? '인증 완료' : '인증 취소됨'}',
                            style: TextStyle(fontSize: 15, color: c.valid ? JdColors.ink : JdColors.faint)),
                        Text(
                          c.valid ? (c.hasPhoto ? '사진 있음' : '사진 삭제됨 · 완료 체크 유지') : '쌓인 진행도는 남아 있어요',
                          style: const TextStyle(fontSize: 12, color: JdColors.faint),
                        ),
                      ],
                    ),
                  ),
                  if (c.valid)
                    PopupMenuButton<String>(
                      tooltip: '인증 관리',
                      onSelected: (v) => v == 'photo' ? _deletePhoto(c) : _cancelCheckin(c),
                      itemBuilder: (_) => [
                        if (c.hasPhoto) const PopupMenuItem(value: 'photo', child: Text('사진 삭제')),
                        const PopupMenuItem(value: 'cancel', child: Text('인증 취소')),
                      ],
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Text('참가자 ${_members.length}명', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (showChecks) Text('${s.days}일 인증', style: const TextStyle(fontSize: 12, color: JdColors.faint)),
          ],
        ),
        const SizedBox(height: 8),
        for (final (i, m) in _members.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                FriendAvatar(name: m.nickname, index: i, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.displayName}${m.isMe ? ' (나)' : ''}', style: const TextStyle(fontSize: 15)),
                      Text(
                        '${m.isHost ? '방장' : '참가자'}${showChecks ? ' · 인증 ${m.checkins}회' : ''}',
                        style: const TextStyle(fontSize: 12, color: JdColors.faint),
                      ),
                    ],
                  ),
                ),
                if (showChecks && s.days > 7)
                  Text('${m.checkins} / ${s.days}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: JdColors.togetherText))
                else if (showChecks)
                  for (var d = 0; d < s.days; d++) ...[
                    SizedBox(width: s.days > 3 ? 3 : 6),
                    CheckSquare(checked: d < m.checkins, color: JdColors.togetherFill, size: s.days > 3 ? 18 : 30),
                  ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (status == RoomStatus.recruiting && s.isHost)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: JdColors.together),
            onPressed: _busy || _members.length < 2 ? null : _confirmStart,
            child: Text(_members.length < 2 ? '2명 이상 모이면 시작할 수 있어요' : '이 인원으로 시작 확정'),
          ),
        if (status != RoomStatus.finished && me != null)
          TextButton(
            onPressed: _busy ? null : _leave,
            child: const Text('방 나가기', style: TextStyle(color: JdColors.subtle)),
          ),
      ],
    );
  }

  String _statusDetail(RoomSummary s, RoomStatus status) => switch (status) {
        RoomStatus.recruiting =>
          '2~4명이 모이면 방장이 시작을 확정해요. ${formatDateTime(s.recruitExpiresAt.toLocal())}까지 모집해요.',
        RoomStatus.scheduled => '${formatDateTime(s.startsAt!.toLocal())}에 시작해서 ${s.days}일 동안 진행해요.',
        RoomStatus.active => '하루 한 번, ${withObject(s.title)} 하고 ${switch (s.checkinMode) {
            CheckinMode.result => '사진이나 짧은 동영상으로',
            CheckinMode.beforeAfter => '전후 사진으로',
            CheckinMode.light => '한 줄로',
          }} 인증해요. ${formatDateTime(s.endsAt!.toLocal())}에 끝나요.',
        RoomStatus.finished => s.goalReachedAt != null
            ? '공동 목표를 달성했어요! 진행도와 배지는 그대로 남아요.'
            : '쌓인 진행도와 인증 기록은 그대로 남아요.',
        RoomStatus.cancelled => '새 방을 만들 수 있어요.',
        RoomStatus.expired => '새 방을 만들 수 있어요.',
      };
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.link});

  final String code;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: JdColors.togetherTint, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const CategoryChip.together(label: '친구 초대'),
          const SizedBox(height: 12),
          const Text('친구가 카메라로 찍으면 바로 참가 화면이 열려요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF4A5056))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(key: const Key('inviteQr'), data: link, size: 190),
          ),
          const SizedBox(height: 14),
          SelectableText(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4)),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(backgroundColor: JdColors.togetherChip, foregroundColor: JdColors.togetherText),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초대 링크를 복사했어요')));
              }
            },
            icon: const Icon(Icons.link),
            label: const Text('초대 링크 복사'),
          ),
        ],
      ),
    );
  }
}

/// 함께 진행도: 원형 그래프(쌓인 진행도 H / T)와 일차별로 몇 명이 인증했는지.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary, required this.feed, required this.now});

  final RoomSummary summary;
  final List<FeedItem> feed;
  final DateTime now;

  static DateTime _kstDay(DateTime t) {
    final k = t.toUtc().add(const Duration(hours: 9));
    return DateTime.utc(k.year, k.month, k.day);
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final ratio = s.totalElements == 0 ? 0.0 : (s.earned / s.totalElements).clamp(0.0, 1.0);
    final members = s.activeCount;
    // 일차별 인증 인원 (시작일 기준, 한국 날짜)
    final start = s.startsAt == null ? null : _kstDay(s.startsAt!);
    final today = _kstDay(now);
    final days = s.days;
    final perDay = List.filled(days, 0);
    if (start != null) {
      for (final f in feed) {
        final d = DateTime.utc(f.date.year, f.date.month, f.date.day).difference(start).inDays;
        if (d >= 0 && d < days) perDay[d]++;
      }
    }
    final todayIndex = start == null ? -1 : today.difference(start).inDays;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: JdColors.togetherTint, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('함께 진행도',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
              const Spacer(),
              if (s.goal != null) Text('목표 ${s.goal}회', style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: JdColors.togetherEmpty,
                        color: JdColors.together,
                      ),
                    ),
                    Center(
                      child: Text('${(ratio * 100).round()}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.earned} / ${s.totalElements}',
                        key: const Key('progressText'),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 6),
                    Text(
                      s.goalReachedAt != null
                          ? '공동 목표 ${s.goal}회 달성! 배지를 받았어요'
                          : '공동 목표 ${s.goal}회까지 ${((s.goal ?? 0) - s.earned).clamp(0, 99)}회 남았어요',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4A5056)),
                    ),
                    const SizedBox(height: 2),
                    Text('현재 유효 인증 ${s.validCount}회', style: const TextStyle(fontSize: 12, color: JdColors.faint)),
                  ],
                ),
              ),
            ],
          ),
          if (start != null && days > 7) ...[
            const SizedBox(height: 18),
            _DayGrid(perDay: perDay, members: members, todayIndex: todayIndex),
          ] else if (start != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (var d = 0; d < days; d++) ...[
                  if (d > 0) SizedBox(width: days > 3 ? 4 : 8),
                  Expanded(
                    child: _DayCell(
                      key: Key('day$d'),
                      compact: days > 3,
                      label: days > 3 ? '${d + 1}일' : '${d + 1}일차',
                      done: perDay[d],
                      members: members,
                      today: d == todayIndex,
                      future: d > todayIndex,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (s.startCount != null && s.activeCount < s.startCount!)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('참가자가 나가서 목표를 조정했어요. 이미 쌓인 진행도는 그대로예요.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// 8일 이상 챌린지: 한 줄에 7칸씩 달력처럼. 모두 인증한 날은 진하게, 일부만 한 날은 옅게 칠한다.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.perDay, required this.members, required this.todayIndex});

  final List<int> perDay;
  final int members;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final allDays = perDay.where((n) => members > 0 && n >= members).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('모두 인증한 날 $allDays일 · ${(todayIndex + 1).clamp(0, perDay.length)}일째 진행 중',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
        const SizedBox(height: 8),
        GridView.count(
          key: const Key('dayGrid'),
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var d = 0; d < perDay.length; d++)
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: d > todayIndex
                      ? Colors.white
                      : members > 0 && perDay[d] >= members
                          ? JdColors.together
                          : perDay[d] > 0
                              ? JdColors.togetherChip
                              : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: d == todayIndex ? JdColors.together : Colors.transparent, width: 2),
                ),
                child: Text('${d + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: members > 0 && perDay[d] >= members && d <= todayIndex
                          ? Colors.white
                          : d > todayIndex
                              ? JdColors.faint
                              : JdColors.ink,
                    )),
              ),
          ],
        ),
      ],
    );
  }
}

/// 일차 칸: "2일차 · 2/3명"과 인원만큼 채운 점
class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.label,
    required this.done,
    required this.members,
    required this.today,
    required this.future,
    this.compact = false,
  });

  /// 5·7일 챌린지는 칸이 좁아서 점 대신 숫자만 보여 준다.
  final bool compact;
  final String label;
  final int done;
  final int members;
  final bool today;
  final bool future;

  @override
  Widget build(BuildContext context) {
    final all = members > 0 && done >= members;
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: all ? JdColors.together : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: today ? JdColors.together : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: all ? Colors.white : (future ? JdColors.faint : JdColors.togetherText))),
            const SizedBox(height: 4),
            Text(future ? '-' : '$done/$members',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: all ? Colors.white : JdColors.ink)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: all ? JdColors.together : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: today ? JdColors.together : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Text(today ? '$label · 오늘' : label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: all ? Colors.white : (future ? JdColors.faint : JdColors.togetherText))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < members; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < done ? (all ? Colors.white : JdColors.togetherFill) : (all ? Colors.white38 : JdColors.togetherEmpty),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(future ? '-' : '$done/$members명',
              style: TextStyle(fontSize: 12, color: all ? Colors.white : JdColors.subtle)),
        ],
      ),
    );
  }
}
