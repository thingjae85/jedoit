import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/mission.dart';
import '../models/mission_record.dart';
import '../models/return_days.dart';
import '../models/room.dart';
import '../models/space.dart';
import '../services/account_service.dart';
import '../services/draft_store.dart';
import '../services/room_service.dart';
import '../services/record_repository.dart';
import '../services/space_store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/photo.dart';
import '../widgets/jd_widgets.dart';
import '../widgets/space_view.dart';
import 'design_compare_screen.dart';
import 'mission_screen.dart';
import 'records_screen.dart';
import 'room_entry_screen.dart';
import 'room_screen.dart';

/// 앱 첫 화면. 아래 탭으로 홈·챌린지·기록·마이를 오간다.
/// 홈은 혼자 하는 미션과 내 공간만 보여 주고, 친구·방 관련은 모두 챌린지 탭에 둔다.
class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key,
      required this.repository,
      this.account,
      this.rooms,
      this.drafts,
      this.space,
      this.missionsFor = dailyMissions,
      this.pickPhoto = pickPhotoFromDevice});

  final RecordRepository repository;
  final AccountService? account;
  final RoomService? rooms;
  final DraftStore? drafts;

  /// 내 공간 설정·내 미션·편지 저장소. 없으면 기기 저장소를 쓴다.
  final SpaceStore? space;

  /// 그날 홈에 나올 기본 미션. 테스트에서 고정한다.
  final List<Mission> Function(DateTime day) missionsFor;
  final PhotoPicker pickPhoto;

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

  late final SpaceStore _space = widget.space ?? SpaceStore();
  SpacePrefs _prefs = const SpacePrefs();

  /// 방금 해낸 미션에 대한 캐릭터 한마디와 방에 생긴 변화.
  String? _reaction;
  String? _change;

  /// 벽 액자에 걸린 사진(가장 최근에 사진을 남긴 기록).
  String? _framePhotoId;
  List<int>? _framePixels;

  bool get _challengeAvailable =>
      widget.account != null && widget.rooms != null;

  @override
  void initState() {
    super.initState();
    widget.account?.addListener(_onAccountChanged);
    _refreshCount();
    _loadPrefs();
    _loadRoom();
    // 초대 QR·링크로 열었으면 바로 참가 흐름을 띄운다 (Google 로그인 후 돌아와도 같은 방으로).
    if (_challengeAvailable && widget.drafts?.invite != null) {
      _tab = _challengeTab;
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
          '이미 쌓인 진행도는 방에 남아요. 사진·기록·계정은 7일 안에 실제로 삭제돼요.',
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

  /// 챌린지 탭의 친구 줄과 챌린지 카드에 쓸 내 방. 실패해도 홈은 그대로 쓴다.
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
        _updateFrame(records);
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await _space.load();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {}
  }

  /// 가장 최근에 사진을 남긴 기록이 벽 액자에 걸린다.
  void _updateFrame(List<MissionRecord> records) {
    MissionRecord? latest;
    for (final r in records) {
      if (r.hasPhoto && (latest == null || r.completedAt.isAfter(latest.completedAt))) latest = r;
    }
    if (latest?.id == _framePhotoId) return;
    _framePhotoId = latest?.id;
    _framePixels = latest == null ? null : photoPixels(latest.photo!);
  }

  Future<void> _openMission(Mission mission, {DiscoveryTheme? theme}) async {
    final before = _records.length;
    final saved = await Navigator.of(context).push<MissionRecord>(
      MaterialPageRoute(
        builder: (_) => MissionScreen(
            mission: mission, repository: widget.repository, theme: theme, pickPhoto: widget.pickPhoto),
      ),
    );
    await _refreshCount();
    if (saved == null) return;
    final message = await _saveToAccount(saved.withoutPhoto());
    if (!mounted) return;

    final count = _loadFailed ? before + 1 : _records.length;
    final event = spaceEventAt(count);
    setState(() {
      _reaction = buddyReaction(mission, withPhoto: saved.hasPhoto, seed: count);
      final changes = [
        if (event != null && !event.opensRoom) '${spaceRoomById(event.roomId)?.name ?? ''} · ${event.line}',
        if (saved.hasPhoto) '사진이 벽 액자에 걸렸어요',
      ];
      _change = changes.isEmpty ? null : changes.join('\n');
    });
    if (event != null && event.opensRoom) {
      // 새 방이 열리면 고정을 풀어 새 방이 바로 보이게 한다.
      await _space.setPinnedRoom(null);
      await _loadPrefs();
      if (!mounted) return;
      await _showNewRoom(event);
      if (!mounted) return;
    }
    final offerSignIn = widget.account != null && !widget.account!.signedIn;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+$coinsPerMission 코인 · $message'),
        action: offerSignIn
            ? SnackBarAction(label: 'Google 로그인', onPressed: _signIn)
            : null,
      ),
    );
  }

  /// 새 방 문이 열리는 순간. 미리 알려 주지 않았으니 깜짝 선물처럼 보여 준다.
  Future<void> _showNewRoom(SpaceEvent event) {
    final room = spaceRoomById(event.roomId);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문이 열렸어요!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              child: RoomPicture(roomId: event.roomId, stage: 0, buddy: buddyById(_prefs.buddy)),
            ),
            const SizedBox(height: 12),
            Text('${room?.name ?? '새 방'}이 생겼어요.\n천천히 채워 가요.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('들어가 보기')),
        ],
      ),
    );
  }

  Future<void> _setHiveView(bool hive) async {
    setState(() => _prefs = _copyPrefs(hiveView: hive));
    await _space.setHiveView(hive);
  }

  /// 벌집 보기에서 방을 누르면 그 방을 고정하고 하나만 보기로 돌아간다.
  Future<void> _pinRoom(String? roomId) async {
    setState(() => _prefs = _copyPrefs(pinnedRoom: roomId, clearPinned: roomId == null, hiveView: false));
    await _space.setPinnedRoom(roomId);
    await _space.setHiveView(false);
  }

  SpacePrefs _copyPrefs({String? pinnedRoom, bool clearPinned = false, bool? hiveView, String? buddy}) {
    final p = _prefs;
    return SpacePrefs(
      pinnedRoom: clearPinned ? null : (pinnedRoom ?? p.pinnedRoom),
      hiveView: hiveView ?? p.hiveView,
      buddy: buddy ?? p.buddy,
      customMissions: p.customMissions,
      rerolledOn: p.rerolledOn,
      letters: p.letters,
    );
  }

  Future<void> _chooseBuddy() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('같이 지낼 친구', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final b in kBuddies)
              ListTile(
                leading: Image.asset(b.asset, width: 44, height: 46, filterQuality: FilterQuality.none),
                title: Text(b.name),
                trailing: b.id == _prefs.buddy ? const Icon(Icons.check, color: JdColors.solo) : null,
                onTap: () => Navigator.of(ctx).pop(b.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _prefs = _copyPrefs(buddy: picked));
    await _space.setBuddy(picked);
  }

  Future<void> _reroll(DateTime today) async {
    await _space.setRerolled(today);
    await _loadPrefs();
  }

  Future<String?> _askText({required String title, required String hint, required int maxLength, int maxLines = 1}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('저장')),
        ],
      ),
    );
  }

  Future<void> _addCustomMission() async {
    final title = await _askText(
        title: '내 미션 추가', hint: '예) 영양제 먹기', maxLength: customMissionTitleMax);
    if (title == null || title.isEmpty || !mounted) return;
    final list = [
      ..._prefs.customMissions,
      Mission.custom('$customMissionPrefix${DateTime.now().microsecondsSinceEpoch}', title),
    ];
    await _space.saveCustomMissions(list);
    await _loadPrefs();
  }

  Future<void> _removeCustomMission(Mission mission) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 미션을 목록에서 뺄까요?'),
        content: const Text('지금까지 남긴 기록은 그대로 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('빼기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _space.saveCustomMissions(_prefs.customMissions.where((m) => m.id != mission.id).toList());
    await _loadPrefs();
  }

  Future<void> _writeLetter() async {
    final text = await _askText(
        title: '미래의 나에게', hint: '일주일 뒤의 나에게 하고 싶은 말', maxLength: 300, maxLines: 5);
    if (text == null || text.isEmpty || !mounted) return;
    final now = DateTime.now();
    await _space.saveLetters([
      ..._prefs.letters,
      FutureLetter(id: 'letter-${now.microsecondsSinceEpoch}', text: text, writtenAt: now),
    ]);
    await _loadPrefs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일주일 뒤에 방 우편함으로 도착해요')),
    );
  }

  Future<void> _openLetter(FutureLetter letter) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일주일 전의 내가 보낸 편지'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${formatDateTime(letter.writtenAt)}에 썼어요',
                  style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
              const SizedBox(height: 12),
              Text(letter.text, style: const TextStyle(fontSize: 15, height: 1.5)),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('간직하기')),
        ],
      ),
    );
    await _space.saveLetters([
      for (final l in _prefs.letters) l.id == letter.id ? l.open() : l,
    ]);
    await _loadPrefs();
  }

  /// 주간 날짜 칸을 누르면 그날이 골라진 기록 달력을 연다.
  void _openDay(DateTime day) {
    _recordsDay = day;
    _selectTab(_recordsTab);
  }

  void _selectTab(int index) {
    if (index != _recordsTab) _recordsDay = null;
    if (index == _challengeTab) _loadRoom();
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
      _challengeTab => _challengeBody(context),
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
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: '챌린지'),
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
    final away = _loadFailed ? 0 : daysAway(_records, today);
    final state = SpaceState.of(_records.length);
    final shown = state.shownRoom(_prefs.pinnedRoom);
    final buddy = buddyById(_prefs.buddy);
    final rerolled = _prefs.rerolled(today);
    final theme = discoveryThemeFor(today, rerolled: rerolled);
    final letters = _prefs.letters.where((l) => !l.opened && l.arrived(now)).toList();

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
              _CoinChip(coins: state.coins),
            ],
          ),
          const SizedBox(height: 14),
          if (away >= 2) ...[
            _WelcomeBack(daysAway: away),
            const SizedBox(height: 12),
          ],
          _RoomCard(
            state: state,
            shownRoom: shown,
            pinned: _prefs.pinnedRoom != null && state.isOpen(_prefs.pinnedRoom!),
            hiveView: _prefs.hiveView,
            buddy: buddy,
            photo: _framePixels,
            line: _reaction ?? buddyIdleLine(state, shown, doneToday: todayRecords.isNotEmpty),
            change: _change,
            letter: letters.isEmpty ? null : letters.first,
            onToggleView: _setHiveView,
            onPickRoom: _pinRoom,
            onUnpin: () => _pinRoom(null),
            onTapBuddy: _chooseBuddy,
            onOpenLetter: _openLetter,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text('오늘의 미션',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('하나만 해도 충분해요',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: JdColors.subtle)),
            ],
          ),
          const SizedBox(height: 6),
          for (final mission in widget.missionsFor(today))
            if (mission.kind == MissionKind.discovery)
              _MissionRow(
                mission: mission,
                completed: todayMissions.contains(mission.id),
                subtitle: '주제: ${theme.title}',
                onTap: () => _openMission(mission, theme: theme),
                trailing: rerolled || todayMissions.contains(mission.id)
                    ? null
                    : TextButton(
                        onPressed: () => _reroll(today),
                        child: const Text('다른 걸로'),
                      ),
              )
            else
              _MissionRow(
                mission: mission,
                completed: todayMissions.contains(mission.id),
                onTap: () => _openMission(mission),
              ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('내 미션',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_prefs.customMissions.length < maxCustomMissions)
                TextButton.icon(
                  onPressed: _addCustomMission,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('내 미션 추가'),
                ),
            ],
          ),
          if (_prefs.customMissions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('매일 하고 싶은 걸 2개까지 넣어 둘 수 있어요.',
                  style: TextStyle(fontSize: 13, color: JdColors.faint)),
            ),
          for (final mission in _prefs.customMissions)
            _MissionRow(
              mission: mission,
              completed: todayMissions.contains(mission.id),
              onTap: () => _openMission(mission),
              trailing: IconButton(
                tooltip: '내 미션 빼기',
                icon: const Icon(Icons.close, size: 18),
                color: JdColors.faint,
                onPressed: () => _removeCustomMission(mission),
              ),
            ),
          const Divider(height: 32),
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _writeLetter,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('미래의 나에게 편지 쓰기'),
            ),
          ),
        ],
      ),
    );
  }

  /// 챌린지 탭: 친구와 함께하는 것은 모두 여기에 모은다.
  Widget _challengeBody(BuildContext context) {
    final available = _challengeAvailable;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const Text('친구와 챌린지',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const Spacer(),
              if (available)
                IconButton(
                  tooltip: '친구 초대',
                  icon: const Icon(Icons.person_add_alt_outlined),
                  onPressed: _openChallenge,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('혼자 하기 힘든 날엔 친구랑 같이 해 봐요. 원할 때만 써도 괜찮아요.',
              style: TextStyle(fontSize: 13, color: JdColors.subtle)),
          const SizedBox(height: 16),
          if (!available)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('지금은 서버에 연결하지 못해 친구 챌린지를 쓸 수 없어요.',
                    style: TextStyle(fontSize: 13)),
              ),
            )
          else ...[
            _FriendRow(
              members: _members,
              signedIn: widget.account!.signedIn,
              onTap: _openChallenge,
            ),
            const SizedBox(height: 16),
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

/// 며칠 쉬다 돌아왔을 때. 쉰 날을 탓하지 않고 반겨 준다.
class _WelcomeBack extends StatelessWidget {
  const _WelcomeBack({required this.daysAway});

  final int daysAway;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JdColors.soloTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Text('👋', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다시 와줘서 반가워요',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: JdColors.soloText)),
                SizedBox(height: 4),
                Text('쉬었던 날도 괜찮아요. 그동안 채운 방은 그대로예요.\n오늘은 제일 쉬운 거 하나만 해 볼까요?',
                    style: TextStyle(fontSize: 13, color: JdColors.subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 미션을 하면 항상 받는 코인. 나중에 꾸미기에 쓴다.
class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: JdColors.panel, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE8C252),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC29A2E), width: 2),
            ),
          ),
          const SizedBox(width: 5),
          Text('$coins', key: const Key('coins'), style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
        ],
      ),
    );
  }
}

/// 홈 맨 위 내 공간 카드. 하나만 보기 / 벌집 보기를 오른쪽 위 아이콘으로 바꾼다.
class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.state,
    required this.shownRoom,
    required this.pinned,
    required this.hiveView,
    required this.buddy,
    required this.photo,
    required this.line,
    required this.change,
    required this.letter,
    required this.onToggleView,
    required this.onPickRoom,
    required this.onUnpin,
    required this.onTapBuddy,
    required this.onOpenLetter,
  });

  static const _bg = Color(0xFF22344A);
  static const _glass = Color(0x24FFFFFF);

  final SpaceState state;
  final String shownRoom;
  final bool pinned;
  final bool hiveView;
  final Buddy buddy;
  final List<int>? photo;
  final String line;
  final String? change;
  final FutureLetter? letter;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<String> onPickRoom;
  final VoidCallback onUnpin;
  final VoidCallback onTapBuddy;
  final ValueChanged<FutureLetter> onOpenLetter;

  @override
  Widget build(BuildContext context) {
    final room = spaceRoomById(shownRoom);
    return Container(
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: hiveView ? 340 : 240),
                    child: hiveView
                        ? HivePicture(
                            state: state,
                            buddy: buddy,
                            shownRoom: shownRoom,
                            photo: photo,
                            onTapRoom: onPickRoom,
                          )
                        : RoomPicture(
                            roomId: shownRoom,
                            stage: state.stageOf(shownRoom),
                            buddy: buddy,
                            photo: photo,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTapBuddy,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      child: Row(
                        children: [
                          Image.asset(buddy.asset, width: 22, height: 23, filterQuality: FilterQuality.none),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line, style: const TextStyle(fontSize: 13, color: JdColors.ink)),
                                if (change != null)
                                  Text(change!,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: JdColors.soloText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(hiveView ? '내 공간' : (room?.name ?? ''),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (!hiveView && pinned) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onUnpin,
                      child: const Tooltip(
                        message: '고정 풀기',
                        child: Icon(Icons.push_pin, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ViewButton(
                    tooltip: '하나만 보기',
                    selected: !hiveView,
                    hive: false,
                    onTap: () => onToggleView(false),
                  ),
                  const SizedBox(width: 2),
                  _ViewButton(
                    tooltip: '벌집 보기',
                    selected: hiveView,
                    hive: true,
                    onTap: () => onToggleView(true),
                  ),
                ],
              ),
            ),
          ),
          if (letter != null)
            Positioned(
              right: 12,
              top: 50,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpenLetter(letter!),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail, size: 14, color: Color(0xFF9A4120)),
                        SizedBox(width: 4),
                        Text('편지가 왔어요',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A4120))),
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
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.tooltip, required this.selected, required this.hive, required this.onTap});

  final String tooltip;
  final bool selected;
  final bool hive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.92) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _HexIconPainter(hive: hive, color: selected ? JdColors.solo : const Color(0xFFE8EEF5)),
          ),
        ),
      ),
    );
  }
}

/// 육각형 하나(하나만 보기) 또는 세 개(벌집 보기) 아이콘.
class _HexIconPainter extends CustomPainter {
  _HexIconPainter({required this.hive, required this.color});

  final bool hive;
  final Color color;

  void _hex(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (60.0 * i - 90) * 3.141592653589793 / 180;
      final p = c + Offset(r * _cos(a), r * _sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  static double _cos(double a) => math.cos(a);
  static double _sin(double a) => math.sin(a);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = hive ? 1.4 : 1.8;
    final c = size.center(Offset.zero);
    if (!hive) {
      _hex(canvas, c, 8, paint);
      return;
    }
    const r = 4.6;
    final w = r * 1.732;
    _hex(canvas, c + Offset(-w / 2, -r * 0.75), r, paint);
    _hex(canvas, c + Offset(w / 2, -r * 0.75), r, paint);
    _hex(canvas, c + Offset(0, r * 0.75), r, paint);
  }

  @override
  bool shouldRepaint(_HexIconPainter old) => old.hive != hive || old.color != color;
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
            full: missions >= kDailyMissionCount,
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
      {required this.mission,
      required this.completed,
      required this.onTap,
      this.subtitle,
      this.trailing});

  final Mission mission;
  final bool completed;
  final VoidCallback onTap;

  /// 제목 아래 한 줄 (예: 오늘의 발견 주제).
  final String? subtitle;

  /// 오른쪽 끝 버튼. 없으면 타이머 시간을 보여 준다.
  final Widget? trailing;

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
                        style: TextStyle(fontSize: 12, color: JdColors.faint))
                  else if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (mission.timerMinutes != null)
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
          ? '${r.challengeName} · 목표 ${r.earned} / ${r.goal ?? r.totalElements}회'
          : '${r.challengeName} · 방에 들어가서 확인해 보세요';
    } else if (invited) {
      title = '초대받은 방이 있어요';
      detail = signedIn ? '눌러서 참가해 보세요' : '로그인 없이 닉네임만으로 참가할 수 있어요';
    } else {
      title = '친구와 함께 챌린지';
      detail = signedIn ? '정리·책 읽기·운동 등 할 일과 기간을 정해 함께 해요' : '로그인 없이도 친구를 초대할 수 있어요';
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
                    if (showProgress && (r!.goal ?? r.totalElements) > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (r.earned / (r.goal ?? r.totalElements)).clamp(0.0, 1.0).toDouble(),
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          color: JdColors.together,
                        ),
                      ),
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
