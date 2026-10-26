import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../services/account_service.dart';
import '../services/draft_store.dart';
import '../services/room_service.dart';
import '../services/record_repository.dart';
import 'design_compare_screen.dart';
import 'mission_screen.dart';
import 'records_screen.dart';
import 'room_entry_screen.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, this.account, this.rooms, this.drafts});

  final RecordRepository repository;
  final AccountService? account;
  final RoomService? rooms;
  final DraftStore? drafts;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _recordCount = 0;
  int _todayCount = 0;
  Set<String> _todayMissions = {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    widget.account?.addListener(_onAccountChanged);
    _refreshCount();
  }

  @override
  void dispose() {
    widget.account?.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
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

  /// 함께하기: 로그인 → (참여 중인 방이 없으면) 방 만들기·참가 → 방 화면.
  Future<void> _openChallenge() async {
    final account = widget.account!;
    final rooms = widget.rooms!;
    if (!account.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('친구와 함께하려면 먼저 로그인해 주세요'),
          action: SnackBarAction(label: 'Google 로그인', onPressed: _signIn),
        ),
      );
      return;
    }
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
          builder: (_) => RoomEntryScreen(rooms: rooms, inviteCode: widget.drafts?.invite),
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
      MaterialPageRoute(builder: (_) => RoomScreen(rooms: rooms, roomId: roomId!)),
    );
    if (mounted) setState(() {});
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
      final now = DateTime.now();
      final today = records.where((record) {
        final date = record.completedAt.toLocal();
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
      setState(() {
        _recordCount = records.length;
        _todayCount = today.length;
        _todayMissions = today.map((r) => r.missionId).toSet();
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

  Future<void> _openRecords() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordsScreen(repository: widget.repository),
      ),
    );
    await _refreshCount();
  }

  void _openDesignCompare() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DesignCompareScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('저두잇'),
        actions: [
          IconButton(
            tooltip: '시안 비교',
            icon: const Icon(Icons.compare),
            onPressed: _openDesignCompare,
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.history),
            onPressed: _openRecords,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('오늘 하나만 해볼까요?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '작은 미션 하나를 골라 먼저 혼자 체험해 보세요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘의 작은 실천', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_loadFailed ? '기록을 불러오지 못했어요' : '오늘 $_todayCount번 완료',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(_todayCount == 0 ? '하나만 해도 좋은 시작이에요.' : '작은 실천이 쌓이고 있어요.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadFailed ? _refreshCount : _openRecords,
                    icon: Icon(_loadFailed ? Icons.refresh : Icons.arrow_forward),
                    label: Text(_loadFailed ? '다시 불러오기' : '전체 기록 $_recordCount개 보기'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.account != null && widget.rooms != null) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.groups),
                title: Text(widget.drafts?.invite != null ? '초대받은 방이 있어요' : '친구와 3일 정리 챌린지'),
                subtitle: Text(widget.drafts?.invite != null
                    ? '로그인하고 참가해 보세요'
                    : '함께 정리할수록 공동 책상이 정돈돼요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openChallenge,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('오늘 할 미션', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final mission in kMissions) ...[
            _MissionCard(mission: mission, completed: _todayMissions.contains(mission.id), onTap: () => _openMission(mission)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          if (widget.account == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '기록은 이 기기·브라우저에만 저장돼요.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else
            _AccountCard(account: widget.account!, onSignIn: _signIn),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.completed, required this.onTap});

  final Mission mission;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: mission.challengeReady ? 3 : 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(mission.icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(mission.title),
        subtitle: Text('${mission.description}${completed ? '\n오늘 완료했어요 · 다시 해도 좋아요' : ''}'),
        trailing: completed ? const Icon(Icons.check_circle, color: Color(0xFF3E7C6B)) : mission.challengeReady
            ? Chip(
                label: const Text('추천'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.secondaryContainer,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onSignIn});

  final AccountService account;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: account.signedIn
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      '${account.email ?? 'Google 계정'}로 로그인했어요.\n기록이 내 계정에도 저장돼요.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: account.signOut, child: const Text('로그아웃')),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '로그인하면 기록을 계정에 저장하고 친구와 방을 만들 수 있어요.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
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
