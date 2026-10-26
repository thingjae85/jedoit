import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/photo.dart';
import '../widgets/jd_widgets.dart';

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
      RoomStatus.active => '함께 정리하는 중',
      RoomStatus.finished => '챌린지가 끝났어요',
      RoomStatus.cancelled => '취소된 방이에요',
      RoomStatus.expired => '모집 시간이 끝났어요',
    };

/// 방 화면: 모집(초대 QR) → 예약 → 3일 인증 → 종료 결과.
/// 공동 책상 그림은 4단계에서 붙이고, 지금은 진행도를 숫자로 보여 준다.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.rooms, required this.roomId, this.now = DateTime.now});

  final RoomService rooms;
  final String roomId;
  final DateTime Function() now;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomSummary? _summary;
  List<RoomMember> _members = [];
  bool _loadFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.rooms.summary(widget.roomId);
      final m = await widget.rooms.members(widget.roomId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _members = m;
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
        '지금 참가한 ${_members.length}명으로 내일 00:00에 시작해 3일 동안 진행해요. 확정 후에는 새로 참가할 수 없어요.');
    if (ok) await _run(() => widget.rooms.confirmStart(widget.roomId), done: '내일 00:00에 시작해요');
    await _load();
  }

  Future<void> _leave() async {
    final active = _summary?.statusAt(widget.now()) == RoomStatus.active;
    final ok = await _ask(
      '방에서 나갈까요?',
      active
          ? '지금까지 정리한 요소는 방에 남고, 이후에는 인증과 방 보기가 끝나요.'
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

  Future<void> _openCheckIn() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CheckInScreen(rooms: widget.rooms, roomId: widget.roomId)),
    );
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 인증했어요. 책상 요소 하나가 정리됐어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('3일 정리 챌린지'),
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
                  label: const Text('오늘 정리 인증하기'),
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
        if (status == RoomStatus.active || status == RoomStatus.finished) _ProgressCard(summary: s),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('참가자 ${_members.length}명', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (showChecks) const Text('3일 인증', style: TextStyle(fontSize: 12, color: JdColors.faint)),
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
                if (showChecks)
                  for (var d = 0; d < 3; d++) ...[
                    const SizedBox(width: 6),
                    CheckSquare(checked: d < m.checkins, color: JdColors.togetherFill, size: 30),
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
        RoomStatus.scheduled => '${formatDateTime(s.startsAt!.toLocal())}에 시작해서 3일 동안 진행해요.',
        RoomStatus.active =>
          '하루 한 번, 내 구역을 5분 정리하고 사진으로 인증해요. ${formatDateTime(s.endsAt!.toLocal())}에 끝나요.',
        RoomStatus.finished => '마지막 책상과 획득한 배지는 그대로 남아요.',
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final RoomSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: JdColors.togetherTint, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('공동 책상 · 정리된 요소',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
              const Spacer(),
              if (s.goal != null) Text('목표 ${s.goal}개', style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${s.earned} / ${s.totalElements}',
              key: const Key('progressText'),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 12),
          if (s.totalElements > 0) ElementBar(earned: s.earned, total: s.totalElements, goal: s.goal),
          const SizedBox(height: 12),
          Text(
            s.goalReachedAt != null
                ? '공동 목표 ${s.goal}회 달성! 배지를 받았어요'
                : '공동 목표 ${s.goal}회까지 ${(s.goal ?? 0) - s.earned}회 남았어요',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4A5056)),
          ),
          if (s.startCount != null && s.activeCount < s.startCount!)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('참가자가 나가서 목표와 책상 요소를 조정했어요. 이미 정리한 요소는 그대로예요.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 4),
          Text('현재 유효 인증 ${s.validCount}회', style: const TextStyle(fontSize: 12, color: JdColors.faint)),
        ],
      ),
    );
  }
}

/// 오늘 인증: 사진 선택 → 미리보기·공유 안내 → 완료 체크·메모 → 저장.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, required this.rooms, required this.roomId, this.picker});

  final RoomService rooms;
  final String roomId;
  final Future<Uint8List?> Function()? picker;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _memo = TextEditingController();
  Uint8List? _photo;
  bool _checked = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    return file?.readAsBytes();
  }

  Future<void> _choose() async {
    setState(() => _error = null);
    try {
      final bytes = await (widget.picker ?? _pick)();
      if (bytes == null) return;
      final prepared = prepareCheckinPhoto(bytes);
      if (mounted) setState(() => _photo = prepared);
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요. 다른 사진을 골라 주세요.');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.rooms.checkIn(widget.roomId, _photo!, _memo.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = roomErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('오늘 정리 인증')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('오늘 정리한 뒤 새로 찍은 사진 한 장을 골라 주세요.', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_photo!, height: 280, fit: BoxFit.cover),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _choose,
            icon: const Icon(Icons.photo_library),
            label: Text(_photo == null ? '사진 고르기' : '다른 사진 고르기'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '· 이 방의 현재 참가자에게 공유돼요\n'
                '· 서버에 저장돼요 (위치정보는 지우고 올려요)\n'
                '· 내 기록에서 사진 삭제나 인증 취소를 할 수 있어요\n'
                '· 테스트가 끝나면 7일 안에 삭제돼요\n'
                '얼굴·주소·문서가 찍히지 않았는지 미리보기에서 확인해 주세요.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          CheckboxListTile(
            value: _checked,
            onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
            title: const Text('오늘 5분 정리를 실제로 했어요'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _memo,
            enabled: !_busy,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '메모 (선택)'),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _photo != null && _checked && !_busy ? _submit : null,
            child: Text(_busy ? '올리는 중...' : '인증 저장'),
          ),
        ],
      ),
    );
  }
}
