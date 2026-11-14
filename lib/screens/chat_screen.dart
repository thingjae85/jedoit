import 'dart:async';

import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import '../widgets/jd_widgets.dart';

/// 챌린지방 단톡방. 내 메시지는 오른쪽, 친구 메시지는 왼쪽에 이름·동그라미와 함께 보여 준다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.roomId,
    required this.title,
    this.members = const [],
    this.poll = const Duration(seconds: 10),
  });

  final ChatService chat;
  final String roomId;
  final String title;

  /// 친구 동그라미 색을 방 화면과 맞추는 데 쓴다.
  final List<RoomMember> members;

  /// 실시간 연결이 끊겨도 새 메시지를 받도록 한 번 더 확인하는 간격. null이면 끈다.
  final Duration? poll;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  void Function()? _unlisten;
  Timer? _timer;
  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;
  bool _fetching = false;
  bool _fetchAgain = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    try {
      _unlisten = widget.chat.listen(widget.roomId, _fetch);
    } catch (_) {
      // 실시간 연결이 안 되면 주기 확인만으로 받는다.
    }
    final every = widget.poll;
    if (every != null) _timer = Timer.periodic(every, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unlisten?.call();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _lastId => _messages.isEmpty ? 0 : _messages.last.id;

  /// 마지막으로 받은 메시지 다음 것만 가져와 붙인다.
  Future<void> _fetch() async {
    if (_fetching) {
      _fetchAgain = true;
      return;
    }
    _fetching = true;
    try {
      do {
        _fetchAgain = false;
        final fresh = await widget.chat.messages(widget.roomId, after: _lastId);
        if (!mounted) return;
        final atBottom = !_scroll.hasClients || _scroll.position.pixels <= 80;
        final known = {for (final m in _messages) m.id};
        setState(() {
          _messages.addAll(fresh.where((m) => !known.contains(m.id)));
          _messages.sort((a, b) => a.id.compareTo(b.id));
          _loading = false;
          _loadFailed = false;
        });
        if (fresh.isNotEmpty && atBottom) _toBottom();
      } while (_fetchAgain);
    } catch (_) {
      if (mounted && _messages.isEmpty) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.chat.send(widget.roomId, text);
      _input.clear();
      await _fetch();
      _toBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chatErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int _avatarIndexOf(ChatMessage m) {
    final i = widget.members.indexWhere((x) => x.nickname == m.nickname && x.nicknameNo == m.nicknameNo);
    return i >= 0 ? i : m.nickname.hashCode.abs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('단톡방'),
            Text(
              widget.members.isEmpty ? widget.title : '${widget.title} · ${widget.members.length}명',
              style: const TextStyle(fontSize: 12, color: JdColors.subtle, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _list()),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() => _loading = true);
            _fetch();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('대화를 다시 불러오기'),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('아직 대화가 없어요.\n첫 인사를 건네 보세요!',
              textAlign: TextAlign.center, style: TextStyle(color: JdColors.faint, height: 1.5)),
        ),
      );
    }
    // 아래에서 위로 쌓아서, 새 메시지가 늘 맨 아래에 보이게 한다.
    final items = _messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final older = i + 1 < items.length ? items[i + 1] : null;
        final newer = i > 0 ? items[i - 1] : null;
        final day = _dayOf(m.sentAt);
        final newDay = older == null || _dayOf(older.sentAt) != day;
        // 같은 사람이 같은 분에 이어서 보내면 이름·시간을 한 번만 보여 준다.
        final firstOfGroup = newDay || older.isMe != m.isMe || older.displayName != m.displayName;
        final lastOfGroup = newer == null ||
            newer.isMe != m.isMe ||
            newer.displayName != m.displayName ||
            _minuteOf(newer.sentAt) != _minuteOf(m.sentAt) ||
            _dayOf(newer.sentAt) != day;
        return Column(
          children: [
            if (newDay) _DayDivider(day: day),
            _Bubble(
              message: m,
              avatarIndex: _avatarIndexOf(m),
              showName: firstOfGroup,
              showTime: lastOfGroup,
            ),
          ],
        );
      },
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: JdColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '메시지 보내기',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: JdColors.paper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: '보내기',
            style: IconButton.styleFrom(backgroundColor: JdColors.together),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

DateTime _dayOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _minuteOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day, l.hour, l.minute);
}

String _time(DateTime t) {
  final l = t.toLocal();
  final ampm = l.hour < 12 ? '오전' : '오후';
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$ampm $h:${l.minute.toString().padLeft(2, '0')}';
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: JdColors.paperDeep, borderRadius: BorderRadius.circular(999)),
          child: Text('${day.month}월 ${day.day}일 ${weekdays[day.weekday - 1]}요일',
              style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.avatarIndex, required this.showName, required this.showTime});

  final ChatMessage message;
  final int avatarIndex;
  final bool showName;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.68;
    final time = showTime
        ? Text(_time(m.sentAt), style: const TextStyle(fontSize: 11, color: JdColors.faint))
        : const SizedBox.shrink();
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: m.isMe ? JdColors.togetherChip : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: m.isMe ? null : Border.all(color: JdColors.line),
      ),
      child: Text(m.body, style: const TextStyle(fontSize: 15, height: 1.35, color: JdColors.ink)),
    );

    if (m.isMe) {
      return Padding(
        padding: EdgeInsets.only(top: showName ? 8 : 3, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [time, const SizedBox(width: 6), Flexible(child: bubble)],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: showName ? 10 : 3, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: showName ? FriendAvatar(name: m.nickname, index: avatarIndex, size: 36) : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(m.displayName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.subtle)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [Flexible(child: bubble), const SizedBox(width: 6), time],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
