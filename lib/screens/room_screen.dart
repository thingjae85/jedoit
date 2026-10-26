import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/room.dart';
import '../services/room_service.dart';
import '../utils/format.dart';
import '../utils/photo.dart';
import '../widgets/desk_view.dart';

/// 초대 링크: 앱 주소에 `?invite=코드`를 붙인다. OAuth의 `code` 파라미터와 겹치지 않는다.
String inviteLink(Uri base, String code) => Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
      queryParameters: {'invite': code},
    ).toString();

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
  List<MyCheckin> _mine = [];
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
      final mine = s.status == RoomStatus.recruiting ? <MyCheckin>[] : await widget.rooms.myCheckins(widget.roomId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _members = m;
        _mine = mine;
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

  Future<void> _deletePhoto(MyCheckin c) async {
    final ok = await _ask('사진을 삭제할까요?',
        '사진과 메모가 지워져요. 완료 체크와 이미 정리된 책상 요소는 그대로 남아요.');
    if (!ok) return;
    await _run(() => widget.rooms.deletePhoto(widget.roomId, c.date), done: '사진을 삭제했어요');
    await _load();
  }

  Future<void> _cancelCheckin(MyCheckin c) async {
    final ok = await _ask('인증을 취소할까요?',
        '완료 체크가 취소되고 사진·메모가 지워져요. 현재 인증 수는 줄지만, 이미 정리된 책상 요소는 남아요. '
        '오늘 인증이라면 남은 사진 올리기 횟수 안에서 다시 인증할 수 있어요.');
    if (!ok) return;
    await _run(() => widget.rooms.cancelCheckin(widget.roomId, c.date), done: '인증을 취소했어요');
    await _load();
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
    );
  }

  Widget _body(BuildContext context, RoomSummary s) {
    final theme = Theme.of(context);
    final now = widget.now();
    final status = s.statusAt(now);
    final me = _members.where((m) => m.isMe).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_statusTitle(status), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(_statusDetail(s, status), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (status == RoomStatus.recruiting) _InviteCard(code: s.inviteCode, link: inviteLink(Uri.base, s.inviteCode)),
        if (status == RoomStatus.active || status == RoomStatus.finished) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DeskView(total: s.totalElements, tidied: s.earned),
          ),
          const SizedBox(height: 12),
          _ProgressCard(summary: s),
        ],
        if (status == RoomStatus.active) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _openCheckIn,
            icon: const Icon(Icons.photo_camera),
            label: const Text('오늘 정리 인증하기'),
          ),
        ],
        if (_mine.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('내 인증', style: theme.textTheme.titleMedium),
          for (final c in _mine)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.valid ? Icons.check_circle : Icons.remove_circle_outline,
                  color: c.valid ? theme.colorScheme.primary : theme.colorScheme.outline),
              title: Text('${c.date.month}/${c.date.day} ${c.valid ? '인증 완료' : '인증 취소됨'}'),
              subtitle: Text(c.valid ? (c.hasPhoto ? '사진 있음' : '사진 삭제됨 · 완료 체크 유지') : '정리된 요소는 남아 있어요'),
              trailing: c.valid
                  ? PopupMenuButton<String>(
                      tooltip: '인증 관리',
                      onSelected: (v) => v == 'photo' ? _deletePhoto(c) : _cancelCheckin(c),
                      itemBuilder: (_) => [
                        if (c.hasPhoto) const PopupMenuItem(value: 'photo', child: Text('사진 삭제')),
                        const PopupMenuItem(value: 'cancel', child: Text('인증 취소')),
                      ],
                    )
                  : null,
            ),
        ],
        const SizedBox(height: 20),
        Text('참가자 ${_members.length}명', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final m in _members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(m.nickname.characters.first)),
            title: Text('${m.displayName}${m.isMe ? ' (나)' : ''}'),
            subtitle: Text(m.isHost ? '방장' : '참가자'),
            trailing: status == RoomStatus.recruiting ? null : Text('인증 ${m.checkins}회'),
          ),
        const SizedBox(height: 12),
        if (status == RoomStatus.recruiting && s.isHost)
          FilledButton(
            onPressed: _busy || _members.length < 2 ? null : _confirmStart,
            child: Text(_members.length < 2 ? '2명 이상 모이면 시작할 수 있어요' : '이 인원으로 시작 확정'),
          ),
        if (status != RoomStatus.finished && me != null)
          TextButton(onPressed: _busy ? null : _leave, child: const Text('방 나가기')),
      ],
    );
  }

  String _statusTitle(RoomStatus status) => switch (status) {
        RoomStatus.recruiting => '친구를 기다리고 있어요',
        RoomStatus.scheduled => '시작을 기다리고 있어요',
        RoomStatus.active => '함께 정리하는 중',
        RoomStatus.finished => '챌린지가 끝났어요',
        RoomStatus.cancelled => '취소된 방이에요',
        RoomStatus.expired => '모집 시간이 끝났어요',
      };

  String _statusDetail(RoomSummary s, RoomStatus status) => switch (status) {
        RoomStatus.recruiting =>
          '2~4명이 모이면 방장이 시작을 확정해요. ${formatDateTime(s.recruitExpiresAt.toLocal())}까지 모집해요.',
        RoomStatus.scheduled => '${formatDateTime(s.startsAt!.toLocal())}에 시작해서 3일 동안 진행해요.',
        RoomStatus.active =>
          '하루 한 번, 내 구역을 5분 정리하고 사진으로 인증해요. ${formatDateTime(s.endsAt!.toLocal())}에 끝나요.',
        RoomStatus.finished => s.goalReachedAt != null
            ? '공동 목표를 달성했어요! 마지막 책상과 배지는 그대로 남아요.'
            : '마지막 책상과 정리한 요소는 그대로 남아요.',
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('친구가 카메라로 찍으면 바로 참가 화면이 열려요', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QrImageView(key: const Key('inviteQr'), data: link, size: 200),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(code, style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
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
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final RoomSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    final total = s.totalElements == 0 ? 1 : s.totalElements;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정리된 요소', style: theme.textTheme.titleMedium),
            Text('${s.earned} / ${s.totalElements}', key: const Key('progressText'), style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (s.earned / total).clamp(0, 1), minHeight: 10),
            const SizedBox(height: 12),
            Text(
              s.goalReachedAt != null
                  ? '공동 목표 ${s.goal}회 달성! 배지를 받았어요'
                  : '공동 목표 ${s.goal}회까지 ${(s.goal ?? 0) - s.earned}회 남았어요',
            ),
            if (s.startCount != null && s.activeCount < s.startCount!)
              Text('참가자가 나가서 목표와 책상 요소를 조정했어요. 이미 정리한 요소는 그대로예요.',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('현재 유효 인증 ${s.validCount}회', style: theme.textTheme.bodySmall),
          ],
        ),
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
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
            decoration: const InputDecoration(labelText: '메모 (선택)', border: OutlineInputBorder()),
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
