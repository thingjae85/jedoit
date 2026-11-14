import 'dart:async';

import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/chat_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import '../widgets/jd_widgets.dart';
import '../widgets/room_feed.dart';

/// 챌린지방 단톡방. 내 메시지는 오른쪽, 친구 메시지는 왼쪽에 이름·동그라미와 함께 보여 준다.
/// [rooms]가 있으면 참가자의 인증도 "인증했어요" 카드로 대화 사이에 끼워 보여 주고,
/// 카드를 누르면 인증을 크게 보고 응원을 남길 수 있다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    required this.roomId,
    required this.title,
    this.rooms,
    this.members = const [],
    this.poll = const Duration(seconds: 10),
  });

  final ChatService chat;
  final String roomId;
  final String title;

  /// 방 피드(인증)를 불러오고 응원을 남기는 데 쓴다. 없으면 메시지만 보여 준다.
  final RoomService? rooms;

  /// 친구 동그라미 색을 방 화면과 맞추는 데 쓴다.
  final List<RoomMember> members;

  /// 실시간 연결이 끊겨도 새 메시지를 받도록 한 번 더 확인하는 간격. null이면 끈다.
  final Duration? poll;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  List<FeedItem> _feed = [];
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
      _unlisten = widget.chat.listen(widget.roomId, _fetch, onCheckin: _fetchFeed);
    } catch (_) {
      // 실시간 연결이 안 되면 주기 확인만으로 받는다.
    }
    final every = widget.poll;
    if (every != null) {
      _timer = Timer.periodic(every, (_) {
        _fetch();
        _fetchFeed();
      });
    }
    _fetchFeed();
  }

  /// 참가자 인증 목록. 못 불러와도 대화는 그대로 쓸 수 있다.
  Future<void> _fetchFeed() async {
    final rooms = widget.rooms;
    if (rooms == null) return;
    try {
      final feed = await rooms.feed(widget.roomId);
      if (!mounted) return;
      final atBottom = !_scroll.hasClients || _scroll.position.pixels <= 80;
      final grew = feed.any((f) => !_feed.any((o) => o.key == f.key));
      setState(() => _feed = feed);
      if (grew && atBottom) _toBottom();
    } catch (_) {}
  }

  Future<void> _react(FeedItem item, Reaction r) async {
    final rooms = widget.rooms;
    if (rooms == null) return;
    void put(FeedItem next) {
      final i = _feed.indexWhere((f) => f.key == item.key);
      if (i >= 0 && mounted) setState(() => _feed = [..._feed]..[i] = next);
    }

    put(item.withReaction(r, !item.mine(r)));
    try {
      put(item.withReaction(r, await rooms.toggleReaction(widget.roomId, item, r)));
    } catch (e) {
      put(item);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(roomErrorMessage(e))));
    }
  }

  /// 인증 카드를 누르면 방 피드와 같은 카드로 크게 보여 주고, 응원을 누를 수 있게 한다.
  void _openCheckin(FeedItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JdColors.paper,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final current = _feed.firstWhere((f) => f.key == item.key, orElse: () => item);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FeedCard(
                item: current,
                avatarIndex: _avatarIndexOf(current.nickname, current.nicknameNo),
                onReact: (r) async {
                  final f = _react(current, r);
                  setSheet(() {});
                  await f;
                  if (sheet.mounted) setSheet(() {});
                },
              ),
            ),
          );
        },
      ),
    );
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

  int _avatarIndexOf(String nickname, int nicknameNo) {
    final i = widget.members.indexWhere((x) => x.nickname == nickname && x.nicknameNo == nicknameNo);
    return i >= 0 ? i : nickname.hashCode.abs();
  }

  /// 메시지와 인증을 시간순으로 섞는다.
  List<_Entry> _entries() {
    final list = [
      for (final m in _messages) _Entry.message(m),
      for (final f in _feed) _Entry.checkin(f),
    ];
    list.sort((a, b) {
      final t = a.at.compareTo(b.at);
      if (t != 0) return t;
      return (a.message?.id ?? 0).compareTo(b.message?.id ?? 0);
    });
    return list;
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
    final entries = _entries();
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('아직 대화가 없어요.\n첫 인사를 건네 보세요!',
              textAlign: TextAlign.center, style: TextStyle(color: JdColors.faint, height: 1.5)),
        ),
      );
    }
    // 아래에서 위로 쌓아서, 새 메시지가 늘 맨 아래에 보이게 한다.
    final items = entries.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final older = i + 1 < items.length ? items[i + 1] : null;
        final newer = i > 0 ? items[i - 1] : null;
        final day = _dayOf(m.at);
        final newDay = older == null || _dayOf(older.at) != day;
        // 같은 사람이 같은 분에 이어서 보내면 이름·시간을 한 번만 보여 준다. 인증 카드는 늘 따로 보여 준다.
        final firstOfGroup = newDay ||
            m.checkin != null ||
            older.checkin != null ||
            older.isMe != m.isMe ||
            older.displayName != m.displayName;
        final lastOfGroup = newer == null ||
            m.checkin != null ||
            newer.checkin != null ||
            newer.isMe != m.isMe ||
            newer.displayName != m.displayName ||
            _minuteOf(newer.at) != _minuteOf(m.at) ||
            _dayOf(newer.at) != day;
        final checkin = m.checkin;
        return Column(
          children: [
            if (newDay) _DayDivider(day: day),
            _Row(
              isMe: m.isMe,
              nickname: m.nickname,
              displayName: m.displayName,
              at: m.at,
              avatarIndex: _avatarIndexOf(m.nickname, m.nicknameNo),
              showName: firstOfGroup,
              showTime: lastOfGroup,
              child: checkin != null
                  ? _CheckinBubble(
                      key: ValueKey('chat-checkin-${checkin.key}'),
                      item: checkin,
                      onTap: () => _openCheckin(checkin),
                    )
                  : _TextBubble(text: m.message!.body, isMe: m.isMe),
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

/// 단톡방 한 줄: 메시지 또는 인증.
class _Entry {
  _Entry.message(ChatMessage this.message) : checkin = null;
  _Entry.checkin(FeedItem this.checkin) : message = null;

  final ChatMessage? message;
  final FeedItem? checkin;

  DateTime get at => message?.sentAt ?? checkin!.checkedAt;
  bool get isMe => message?.isMe ?? checkin!.isMe;
  String get nickname => message?.nickname ?? checkin!.nickname;
  int get nicknameNo => message?.nicknameNo ?? checkin!.nicknameNo;
  String get displayName => message?.displayName ?? checkin!.displayName;
}

/// 말풍선을 내 쪽(오른쪽) 또는 친구 쪽(왼쪽, 동그라미·이름)으로 놓는다.
class _Row extends StatelessWidget {
  const _Row({
    required this.isMe,
    required this.nickname,
    required this.displayName,
    required this.at,
    required this.avatarIndex,
    required this.showName,
    required this.showTime,
    required this.child,
  });

  final bool isMe;
  final String nickname;
  final String displayName;
  final DateTime at;
  final int avatarIndex;
  final bool showName;
  final bool showTime;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final time = showTime
        ? Text(_time(at), style: const TextStyle(fontSize: 11, color: JdColors.faint))
        : const SizedBox.shrink();

    if (isMe) {
      return Padding(
        padding: EdgeInsets.only(top: showName ? 8 : 3, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [time, const SizedBox(width: 6), Flexible(child: child)],
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
            child: showName ? FriendAvatar(name: nickname, index: avatarIndex, size: 36) : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(displayName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.subtle)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [Flexible(child: child), const SizedBox(width: 6), time],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? JdColors.togetherChip : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? null : Border.all(color: JdColors.line),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: JdColors.ink)),
    );
  }
}

/// "인증했어요" 알림 카드. 사진(또는 동영상 표시)·한 줄·응원 수를 작게 보여 주고, 누르면 크게 연다.
class _CheckinBubble extends StatelessWidget {
  const _CheckinBubble({super.key, required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.62;
    final note = item.note ?? '';
    final reactions = [
      for (final r in Reaction.values)
        if (item.count(r) > 0) '${r.emoji} ${item.count(r)}',
    ].join('  ');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: JdColors.togetherFill, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width.clamp(200, 320).toDouble(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: JdColors.togetherTint,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: JdColors.together),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.isMe ? '오늘 인증을 올렸어요' : '${item.displayName}님이 인증했어요',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
                    ),
                  ],
                ),
              ),
              if (item.mediaUrl != null && item.media == FeedMedia.photo)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    item.mediaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: JdColors.empty,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: JdColors.faint)),
                    ),
                  ),
                )
              else if (item.mediaUrl != null && item.media == FeedMedia.video)
                const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(
                    color: JdColors.roomNavy,
                    child: Center(child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white)),
                  ),
                ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.35, color: JdColors.ink)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    if (reactions.isNotEmpty)
                      Text(reactions, style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
                    const Spacer(),
                    Text(item.isMe ? '눌러서 보기' : '눌러서 응원하기',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: JdColors.together)),
                    const Icon(Icons.chevron_right, size: 16, color: JdColors.together),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
