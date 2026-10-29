import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../models/room.dart';
import '../services/account_service.dart';
import '../services/draft_store.dart';
import '../services/room_service.dart';
import '../services/record_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/jd_widgets.dart';
import 'design_compare_screen.dart';
import 'mission_screen.dart';
import 'records_screen.dart';
import 'room_entry_screen.dart';
import 'room_screen.dart';

/// 앱 첫 화면. 아래 탭으로 홈·챌린지·기록·마이를 오간다.
/// 챌린지 탭은 화면을 바꾸지 않고 방 화면(또는 방 만들기)을 연다.
class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key,
      required this.repository,
      this.account,
      this.rooms,
      this.drafts});

  final RecordRepository repository;
  final AccountService? account;
  final RoomService? rooms;
  final DraftStore? drafts;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _homeTab = 0;
  static const _challengeTab = 1;
  static const _recordsTab = 2;

  int _tab = _homeTab;
  int _recordsVersion = 0; // 기록 탭을 열 때마다 새로 불러온다
  DateTime? _recordsDay; // 기록 탭에서 처음 고를 날짜

  List<MissionRecord> _records = [];
  bool _loadFailed = false;

  RoomSummary? _room;
  List<RoomMember> _members = [];

  bool get _challengeAvailable =>
      widget.account != null && widget.rooms != null;

  @override
  void initState() {
    super.initState();
    widget.account?.addListener(_onAccountChanged);
    _refreshCount();
    _loadRoom();
    // 초대 QR·링크로 열었으면 바로 참가 흐름을 띄운다 (Google 로그인 후 돌아와도 같은 방으로).
    if (_challengeAvailable && widget.drafts?.invite != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openChallenge();
      });
    }
  }

  @override
  void dispose() {
    widget.account?.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
    _loadRoom();
  }

  Future<void> _signIn() async {
    try {
      await widget.account!.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인을 시작하지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  /// 로그인 전에 함께하기를 누르면 게스트로 바로 참여할지, Google로 로그인할지 고른다.
  /// 게스트로 들어오면 true.
  Future<bool> _askHowToJoin() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('어떻게 참여할까요?'),
        content: const Text(
          '회원가입 없이 닉네임만으로 바로 참여할 수 있어요(테스트용). '
          '게스트 기록은 이 브라우저에서만 이어서 볼 수 있어요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('google'),
              child: const Text('Google로 로그인')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop('guest'),
              child: const Text('로그인 없이 참여')),
        ],
      ),
    );
    if (choice == 'google') {
      await _signIn();
      return false;
    }
    if (choice != 'guest') return false;
    try {
      await widget.account!.signInAsGuest();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('바로 참여하지 못했어요. 잠시 후 다시 시도해 주세요')),
        );
      }
      return false;
    }
  }

  Future<void> _requestDeletion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 삭제를 요청할까요?'),
        content: const Text(
          '참여 중인 방에서 바로 나가고, 내 인증 사진은 지금부터 아무도 볼 수 없어요. '
          '이미 정리된 책상 요소는 방에 남아요. 사진·기록·계정은 7일 안에 실제로 삭제돼요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제 요청')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final due = await widget.account!.requestDeletion();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('삭제 요청을 접수했어요'),
          content: Text(
              '접수일: ${formatDateTime(DateTime.now())}\n처리 예정일: ${formatDateTime(due.toLocal())}까지'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'))
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 요청을 보내지 못했어요. 다시 시도해 주세요')),
      );
    }
  }

  /// 홈의 친구 줄과 챌린지 카드에 쓸 내 방. 실패해도 홈은 그대로 쓴다.
  Future<void> _loadRoom() async {
    final rooms = widget.rooms;
    if (rooms == null || !(widget.account?.signedIn ?? false)) {
      if (_room != null && mounted) {
        setState(() {
          _room = null;
          _members = [];
        });
      }
      return;
    }
    try {
      final id = await rooms.myRoomId();
      final summary = id == null ? null : await rooms.summary(id);
      final members = id == null ? <RoomMember>[] : await rooms.members(id);
      if (!mounted) return;
      setState(() {
        _room = summary;
        _members = members;
      });
    } catch (_) {}
  }

  /// 함께하기: 로그인 → (참여 중인 방이 없으면) 방 만들기·참가 → 방 화면.
  Future<void> _openChallenge() async {
    if (!_challengeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금은 서버에 연결하지 못해 친구 챌린지를 쓸 수 없어요')),
      );
      return;
    }
    final account = widget.account!;
    final rooms = widget.rooms!;
    if (!account.signedIn && !await _askHowToJoin()) return;
    if (!mounted) return;
    String? roomId;
    try {
      roomId = await rooms.myRoomId();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방 정보를 불러오지 못했어요. 다시 시도해 주세요')),
      );
      return;
    }
    if (!mounted) return;
    if (roomId == null) {
      roomId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) =>
              RoomEntryScreen(rooms: rooms, inviteCode: widget.drafts?.invite),
        ),
      );
      if (roomId == null || !mounted) return;
      widget.drafts?.clearInvite();
    } else if (widget.drafts?.invite != null) {
      widget.drafts!.clearInvite();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 참여 중인 방이 있어 그 방을 열었어요')),
      );
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
          builder: (_) => RoomScreen(rooms: rooms, roomId: roomId!)),
    );
    if (mounted) setState(() {});
    await _loadRoom();
  }

  /// 기기 저장이 끝난 기록을 계정에도 올린다. 로그인 전이면 초안으로 보관된다.
  Future<String> _saveToAccount(MissionRecord record) async {
    final account = widget.account;
    if (account == null) return '기록을 이 기기에 저장했어요';
    try {
      final uploaded = await account.saveRecord(record);
      return uploaded
          ? '기록을 이 기기와 내 계정에 저장했어요'
          : '기록을 이 기기에 저장했어요. 30분 안에 로그인하면 계정에도 저장돼요';
    } catch (_) {
      return '기록을 이 기기에 저장했어요. 계정 저장은 실패했어요';
    }
  }

  Future<void> _refreshCount() async {
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

  Future<void> _openMission(Mission mission) async {
    final saved = await Navigator.of(context).push<MissionRecord>(
      MaterialPageRoute(
        builder: (_) =>
            MissionScreen(mission: mission, repository: widget.repository),
      ),
    );
    await _refreshCount();
    if (saved == null) return;
    final message = await _saveToAccount(saved);
    if (!mounted) return;
    final offerSignIn = widget.account != null && !widget.account!.signedIn;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: offerSignIn
            ? SnackBarAction(label: 'Google 로그인', onPressed: _signIn)
            : null,
      ),
    );
  }

  /// 주간 날짜 칸을 누르면 그날이 골라진 기록 달력을 연다.
  void _openDay(DateTime day) {
    _recordsDay = day;
    _selectTab(_recordsTab);
  }

  void _selectTab(int index) {
    if (index != _recordsTab) _recordsDay = null;
    if (index == _challengeTab) {
      _openChallenge();
      return;
    }
    if (index == _homeTab) _refreshCount();
    setState(() {
      if (index == _recordsTab) _recordsVersion++;
      _tab = index;
    });
  }

  void _openDesignCompare() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DesignCompareScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_tab) {
      _recordsTab => RecordsScreen(
          key: ValueKey(_recordsVersion),
          repository: widget.repository,
          initialDay: _recordsDay,
          onPickMission: () => _selectTab(_homeTab),
        ),
      _homeTab => _homeBody(context),
      _ => _MyPage(
          account: widget.account,
          onSignIn: _signIn,
          onDelete: _requestDeletion,
          onDesignCompare: _openDesignCompare),
    };
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.check_box_outlined),
              selectedIcon: Icon(Icons.check_box),
              label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined), label: '챌린지'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '기록'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이'),
        ],
      ),
    );
  }

  Widget _homeBody(BuildContext context) {
    final now = DateTime.now();
    final today = dayOf(now);
    final byDay = recordsByDay(_records);
    final todayRecords = byDay[today] ?? const <MissionRecord>[];
    final todayMissions = todayRecords.map((r) => r.missionId).toSet();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: JdColors.solo,
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('저두잇',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const Spacer(),
              if (_challengeAvailable)
                IconButton(
                  tooltip: '친구 초대',
                  icon: const Icon(Icons.person_add_alt_outlined),
                  onPressed: _openChallenge,
                ),
            ],
          ),
          if (_challengeAvailable) ...[
            const SizedBox(height: 12),
            _FriendRow(
              members: _members,
              signedIn: widget.account!.signedIn,
              onTap: _openChallenge,
            ),
          ],
          const SizedBox(height: 16),
          _WeekStrip(
            today: today,
            byDay: byDay,
            loadFailed: _loadFailed,
            todayCount: todayRecords.length,
            recordCount: _records.length,
            onRetry: _refreshCount,
            onOpenRecords: () => _selectTab(_recordsTab),
            onOpenDay: _openDay,
          ),
          const Divider(height: 32),
          Row(
            children: [
              const CategoryChip.solo(label: '혼자 미션'),
              const Spacer(),
              Text('오늘 할 미션',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: JdColors.subtle)),
            ],
          ),
          const SizedBox(height: 6),
          for (final mission in kMissions)
            _MissionRow(
              mission: mission,
              completed: todayMissions.contains(mission.id),
              onTap: () => _openMission(mission),
            ),
          if (_challengeAvailable) ...[
            const SizedBox(height: 22),
            const Align(
                alignment: Alignment.centerLeft,
                child: CategoryChip.together(label: '친구 3일 챌린지')),
            const SizedBox(height: 10),
            _ChallengeCard(
              room: _room,
              signedIn: widget.account!.signedIn,
              invited: widget.drafts?.invite != null,
              onTap: _openChallenge,
            ),
          ],
        ],
      ),
    );
  }
}

/// 같은 방 참가자 동그라미 줄. 방이 없으면 나와 초대 버튼만 보인다.
class _FriendRow extends StatelessWidget {
  const _FriendRow(
      {required this.members, required this.signedIn, required this.onTap});

  final List<RoomMember> members;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final people = members.isEmpty
        ? [(name: '나', label: '나')]
        : [
            for (final m in [
              ...members.where((m) => m.isMe),
              ...members.where((m) => !m.isMe)
            ])
              (name: m.nickname, label: m.isMe ? '나' : m.displayName),
          ];
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (i, p) in people.indexed)
            _FriendSlot(
              label: p.label,
              onTap: onTap,
              child: FriendAvatar(
                  name: p.name,
                  index: i,
                  ring: members.isEmpty ? null : JdColors.togetherFill),
            ),
          if (members.length < 4)
            _FriendSlot(
              label: '초대',
              onTap: onTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: JdColors.panel,
                  border: Border.all(color: const Color(0xFFE4E6E9), width: 2),
                ),
                child: const Icon(Icons.add, color: JdColors.subtle),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendSlot extends StatelessWidget {
  const _FriendSlot(
      {required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              child,
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF4A5056))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이번 주(월~일) 날짜 줄. 그날 마친 미션 수를 칸에 보여 준다.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.today,
    required this.byDay,
    required this.loadFailed,
    required this.todayCount,
    required this.recordCount,
    required this.onRetry,
    required this.onOpenRecords,
    required this.onOpenDay,
  });

  static const _dow = ['월', '화', '수', '목', '금', '토', '일'];

  final DateTime today;
  final Map<DateTime, List<MissionRecord>> byDay;
  final bool loadFailed;
  final int todayCount;
  final int recordCount;
  final VoidCallback onRetry;
  final VoidCallback onOpenRecords;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${today.year}년 ${today.month}월',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loadFailed ? onRetry : onOpenRecords,
                  child: Text(
                    loadFailed ? '다시 불러오기' : '전체 기록 $recordCount개 보기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: _day(monday.add(Duration(days: i)), _dow[i])),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          loadFailed ? '기록을 불러오지 못했어요' : '오늘 $todayCount번 완료',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (!loadFailed)
          Text(
            todayCount == 0 ? '하나만 해도 좋은 시작이에요.' : '작은 실천이 쌓이고 있어요.',
            style: const TextStyle(fontSize: 13, color: JdColors.subtle),
          ),
      ],
    );
  }

  Widget _day(DateTime day, String dow) {
    final records = byDay[day] ?? const <MissionRecord>[];
    final missions = records.map((r) => r.missionId).toSet().length;
    final isToday = day == today;
    final strong = isToday ? JdColors.ink : JdColors.faint;
    final future = day.isAfter(today);
    return InkWell(
      onTap: future ? null : () => onOpenDay(day),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Text(dow, style: TextStyle(fontSize: 12, color: strong)),
          const SizedBox(height: 6),
          DayBlob(
            count: missions,
            full: missions >= kMissions.length,
            today: isToday,
            future: future,
          ),
          const SizedBox(height: 6),
          Text('${day.day}',
              style: TextStyle(
                  fontSize: 12,
                  color: strong,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow(
      {required this.mission, required this.completed, required this.onTap});

  final Mission mission;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            CheckSquare(checked: completed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mission.title,
                      style: TextStyle(
                          fontSize: 15,
                          color: completed ? JdColors.faint : JdColors.ink)),
                  if (completed)
                    const Text('오늘 완료했어요 · 다시 해도 좋아요',
                        style: TextStyle(fontSize: 12, color: JdColors.faint)),
                ],
              ),
            ),
            if (mission.timerMinutes != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: JdColors.panel,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${mission.timerMinutes}분',
                    style:
                        const TextStyle(fontSize: 12, color: JdColors.subtle)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard(
      {required this.room,
      required this.signedIn,
      required this.invited,
      required this.onTap});

  final RoomSummary? room;
  final bool signedIn;
  final bool invited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = room;
    final status = r?.statusAt(DateTime.now());
    final showProgress =
        status == RoomStatus.active || status == RoomStatus.finished;
    final String title;
    final String detail;
    if (r != null) {
      title = roomStatusTitle(status!);
      detail = showProgress
          ? '정리된 요소 ${r.earned} / ${r.totalElements}${r.goal != null ? ' · 목표 ${r.goal}개' : ''}'
          : '방에 들어가서 확인해 보세요';
    } else if (invited) {
      title = '초대받은 방이 있어요';
      detail = signedIn ? '눌러서 참가해 보세요' : '로그인 없이 닉네임만으로 참가할 수 있어요';
    } else {
      title = '친구와 3일 정리 챌린지';
      detail = signedIn ? '함께 정리할수록 공동 책상이 정돈돼요' : '로그인 없이도 친구를 초대할 수 있어요';
    }
    return Material(
      color: JdColors.togetherTint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(detail,
                        style: const TextStyle(
                            fontSize: 13, color: JdColors.subtle)),
                    if (showProgress && r!.totalElements > 0) ...[
                      const SizedBox(height: 10),
                      ElementBar(
                          earned: r.earned, total: r.totalElements, height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: JdColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyPage extends StatelessWidget {
  const _MyPage(
      {required this.account,
      required this.onSignIn,
      required this.onDelete,
      required this.onDesignCompare});

  final AccountService? account;
  final VoidCallback onSignIn;
  final VoidCallback onDelete;
  final VoidCallback onDesignCompare;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (account == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('기록은 이 기기·브라우저에만 저장돼요.',
                    style: TextStyle(fontSize: 13)),
              ),
            )
          else
            ListenableBuilder(
              listenable: account,
              builder: (context, _) => _AccountCard(
                  account: account, onSignIn: onSignIn, onDelete: onDelete),
            ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.compare_outlined),
            title: const Text('시안 비교'),
            subtitle: const Text('인터뷰용 공동 책상 시안'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onDesignCompare,
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmGuestSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('게스트에서 로그아웃할까요?'),
      content: const Text('로그아웃하면 이 게스트 계정으로 다시 들어올 수 없어요. 참여 중인 방도 다시 볼 수 없어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('로그아웃')),
      ],
    ),
  );
  return ok ?? false;
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(
      {required this.account, required this.onSignIn, required this.onDelete});

  final AccountService account;
  final VoidCallback onSignIn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: account.signedIn
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      account.isGuest
                          ? '게스트로 참여 중이에요 (테스트).\n이 브라우저에서만 이어서 쓸 수 있어요.'
                          : '${account.email ?? 'Google 계정'}로 로그인했어요.\n기록이 내 계정에도 저장돼요.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '계정',
                    onSelected: (v) async {
                      if (v != 'out') return onDelete();
                      // 게스트는 로그아웃하면 같은 계정으로 다시 들어올 방법이 없다.
                      if (account.isGuest && !await _confirmGuestSignOut(context)) return;
                      await account.signOut();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'out', child: Text('로그아웃')),
                      PopupMenuItem(value: 'delete', child: Text('계정 삭제 요청')),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '로그인하면 기록을 계정에 저장하고 친구와 방을 만들 수 있어요.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Google로 로그인'),
                  ),
                ],
              ),
      ),
    );
  }
}
