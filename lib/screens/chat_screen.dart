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

  /// 보내는 중인 내 메시지. 서버 답을 기다리지 않고 바로 말풍선으로 보여 주고,
  /// 서버에서 같은 내 메시지가 내려오면 지운다.
  final _pending = <_PendingMessage>[];
  var _pendingSeq = 0;
  List<FeedItem> _feed = [];

  /// 메시지 번호별 반응
  Map<int, List<ReactionCount>> _reactions = {};

  /// 지금 쓰는 글이 답장할 대상 (메시지 또는 인증)
  _Reply? _replying;
  final _inputFocus = FocusNode();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  void Function()? _unlisten;
  Timer? _timer;
  bool _loading = true;
  bool _loadFailed = false;
  bool _fetching = false;
  bool _fetchAgain = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    try {
      _unlisten = widget.chat.listen(widget.roomId, _fetch, onCheckin: _fetchFeed, onReaction: _fetchReactions);
    } catch (_) {
      // 실시간 연결이 안 되면 주기 확인만으로 받는다.
    }
    final every = widget.poll;
    if (every != null) {
      _timer = Timer.periodic(every, (_) {
        _fetch();
        _fetchFeed();
        _fetchReactions();
      });
    }
    _fetchFeed();
    _fetchReactions();
  }

  /// 메시지 반응. 못 불러와도 대화는 그대로 쓸 수 있다.
  Future<void> _fetchReactions() async {
    try {
      final r = await widget.chat.reactions(widget.roomId);
      if (mounted) setState(() => _reactions = r);
    } catch (_) {}
  }

  /// 반응을 먼저 화면에 바꿔 두고 서버에 보낸다. 실패하면 되돌린다.
  Future<void> _toggleMessageReaction(ChatMessage m, MessageEmoji e) async {
    final before = _reactions[m.id] ?? const <ReactionCount>[];
    final had = before.any((r) => r.emoji == e && r.mine);
    final next = <ReactionCount>[
      for (final r in before)
        if (r.emoji != e) r else if (!(had && r.count <= 1)) ReactionCount(e, r.count + (had ? -1 : 1), mine: !had),
      if (!had && !before.any((r) => r.emoji == e)) ReactionCount(e, 1, mine: true),
    ]..sort((a, b) => a.emoji.index.compareTo(b.emoji.index));
    setState(() => _reactions = {..._reactions, m.id: next});
    try {
      await widget.chat.toggleReaction(widget.roomId, m.id, e);
    } catch (err) {
      if (!mounted) return;
      setState(() => _reactions = {..._reactions, m.id: before});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chatErrorMessage(err))));
    }
  }

  void _startReply(_Reply r) {
    setState(() => _replying = r);
    _inputFocus.requestFocus();
  }

  /// 메시지를 길게 누르면: 반응 고르기와 답장
  void _openMessageActions(ChatMessage m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: JdColors.paper,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in MessageEmoji.values)
                    IconButton(
                      key: Key('react-${m.id}-${e.serverName}'),
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        backgroundColor: (_reactions[m.id] ?? const []).any((r) => r.emoji == e && r.mine)
                            ? JdColors.togetherChip
                            : null,
                      ),
                      onPressed: () {
                        Navigator.of(sheet).pop();
                        _toggleMessageReaction(m, e);
                      },
                      icon: Text(e.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('답장'),
              onTap: () {
                Navigator.of(sheet).pop();
                _startReply(_Reply.message(m));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 이 인증에 달린 댓글 (인증에 답장한 메시지)
  List<ChatMessage> _commentsOf(FeedItem item) =>
      [for (final m in _messages) if (m.replyCheckin?.key == item.key) m];

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FeedCard(
                    item: current,
                    avatarIndex: _avatarIndexOf(current.nickname, current.nicknameNo),
                    onReact: (r) async {
                      final f = _react(current, r);
                      setSheet(() {});
                      await f;
                      if (sheet.mounted) setSheet(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  for (final c in _commentsOf(current))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${c.isMe ? '나' : c.displayName}  ',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: JdColors.subtle)),
                          TextSpan(text: c.body),
                        ]),
                        style: const TextStyle(fontSize: 14, height: 1.35, color: JdColors.ink),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      _startReply(_Reply.checkin(current));
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('댓글 달기'),
                  ),
                ],
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
    _inputFocus.dispose();
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
        final added = fresh.where((m) => !known.contains(m.id)).toList();
        setState(() {
          _messages.addAll(added);
          for (final m in added) {
            if (!m.isMe) continue;
            final i = _pending.indexWhere((p) => p.body == m.body);
            if (i >= 0) _pending.removeAt(i);
          }
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

  /// 입력창을 바로 비우고 말풍선을 먼저 띄운 뒤, 서버 저장은 뒤에서 기다린다.
  /// 실패하면 말풍선을 거두고 글을 입력창에 되돌려 놓는다.
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final me = widget.members.where((m) => m.isMe).firstOrNull;
    final reply = _replying;
    final pending = _PendingMessage(++_pendingSeq, text, DateTime.now(),
        nickname: me?.nickname ?? '',
        nicknameNo: me?.nicknameNo ?? 1,
        displayName: me?.displayName ?? '',
        reply: reply);
    _input.clear();
    setState(() {
      _pending.add(pending);
      _replying = null;
    });
    _toBottom();
    try {
      await widget.chat.send(widget.roomId, text,
          replyTo: reply?.message?.id, replyCheckin: reply?.checkin == null ? null : _refOf(reply!.checkin!));
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _replying ??= reply;
      });
      if (_input.text.isEmpty) _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chatErrorMessage(e))));
    }
  }

  CheckinRef _refOf(FeedItem f) => CheckinRef(nickname: f.nickname, nicknameNo: f.nicknameNo, date: f.date);

  /// 답장 말풍선 위에 붙는 인용 한 줄
  Widget? _quoteFor(_Entry e) {
    final m = e.message;
    final reply = e.pending?.reply;
    final replyTo = m?.replyTo ?? reply?.message?.id;
    final checkinKey = m?.replyCheckin?.key ?? reply?.checkin?.key;
    if (replyTo != null) {
      final target = _messages.where((x) => x.id == replyTo).firstOrNull ?? reply?.message;
      return _Quote(
        title: target == null ? '답장' : '${target.isMe ? '나' : target.displayName}에게 답장',
        text: target?.body ?? '이전 메시지',
      );
    }
    if (checkinKey != null) {
      final target = _feed.where((f) => f.key == checkinKey).firstOrNull ?? reply?.checkin;
      final who = m?.replyCheckin?.nickname ?? target?.displayName ?? '';
      final note = target?.note ?? '';
      return _Quote(
        title: target?.isMe == true ? '내 인증에 댓글' : '$who님 인증에 댓글',
        text: note.isEmpty ? '인증' : note,
        icon: Icons.check_circle,
        onTap: target == null ? null : () => _openCheckin(target),
      );
    }
    return null;
  }

  Widget? _reactionRow(ChatMessage m) {
    final list = _reactions[m.id];
    if (list == null || list.isEmpty) return null;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final r in list)
          InkWell(
            key: Key('reaction-chip-${m.id}-${r.emoji.serverName}'),
            borderRadius: BorderRadius.circular(999),
            onTap: () => _toggleMessageReaction(m, r.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: r.mine ? JdColors.togetherChip : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: r.mine ? JdColors.together : JdColors.line),
              ),
              child: Text('${r.emoji.emoji} ${r.count}', style: const TextStyle(fontSize: 12, color: JdColors.ink)),
            ),
          ),
      ],
    );
  }

  int _avatarIndexOf(String nickname, int nicknameNo) {
    final i = widget.members.indexWhere((x) => x.nickname == nickname && x.nicknameNo == nicknameNo);
    return i >= 0 ? i : nickname.hashCode.abs();
  }

  /// 메시지와 인증을 시간순으로 섞는다. 보내는 중인 메시지는 늘 맨 아래.
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
    return [...list, for (final p in _pending) _Entry.pending(p)];
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
              showTime: lastOfGroup && m.pending == null,
              child: checkin != null
                  ? _CheckinBubble(
                      key: ValueKey('chat-checkin-${checkin.key}'),
                      item: checkin,
                      comments: _commentsOf(checkin).length,
                      onTap: () => _openCheckin(checkin),
                      onLongPress: () => _startReply(_Reply.checkin(checkin)),
                    )
                  : _messageBubble(m),
            ),
          ],
        );
      },
    );
  }

  Widget _messageBubble(_Entry e) {
    final message = e.message;
    final reactions = message == null ? null : _reactionRow(message);
    final bubble = GestureDetector(
      onLongPress: message == null ? null : () => _openMessageActions(message),
      child: _TextBubble(text: e.body!, isMe: e.isMe, sending: e.pending != null, quote: _quoteFor(e)),
    );
    if (reactions == null) return bubble;
    return Column(
      crossAxisAlignment: e.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [bubble, const SizedBox(height: 4), reactions],
    );
  }

  Widget _replyBanner(_Reply r) {
    final m = r.message;
    final c = r.checkin;
    final title = m != null
        ? '${m.isMe ? '나' : m.displayName}에게 답장'
        : (c!.isMe ? '내 인증에 댓글' : '${c.displayName}님 인증에 댓글');
    final text = m?.body ?? ((c?.note ?? '').isEmpty ? '인증' : c!.note!);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: const BoxDecoration(
        color: JdColors.paper,
        border: Border(top: BorderSide(color: JdColors.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: JdColors.together),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
              ],
            ),
          ),
          IconButton(
            tooltip: '답장 취소',
            onPressed: () => setState(() => _replying = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final reply = _replying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reply != null) _replyBanner(reply),
        _inputRow(),
      ],
    );
  }

  Widget _inputRow() {
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
              focusNode: _inputFocus,
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
            onPressed: _send,
            icon: const Icon(Icons.send_rounded, color: Colors.white),
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

/// 보내는 중인 내 메시지.
class _PendingMessage {
  _PendingMessage(this.seq, this.body, this.at,
      {required this.nickname, required this.nicknameNo, required this.displayName, this.reply});
  final int seq;
  final String body;
  final DateTime at;

  /// 바로 앞 내 메시지와 한 묶음으로 보이도록 내 이름을 같이 들고 있다.
  final String nickname;
  final int nicknameNo;
  final String displayName;
  final _Reply? reply;
}

/// 답장 대상: 메시지 하나 또는 인증 하나.
class _Reply {
  _Reply.message(ChatMessage this.message) : checkin = null;
  _Reply.checkin(FeedItem this.checkin) : message = null;
  final ChatMessage? message;
  final FeedItem? checkin;
}

/// 단톡방 한 줄: 메시지, 인증, 또는 보내는 중인 내 메시지.
class _Entry {
  _Entry.message(ChatMessage this.message)
      : checkin = null,
        pending = null;
  _Entry.checkin(FeedItem this.checkin)
      : message = null,
        pending = null;
  _Entry.pending(_PendingMessage this.pending)
      : message = null,
        checkin = null;

  final ChatMessage? message;
  final FeedItem? checkin;
  final _PendingMessage? pending;

  DateTime get at => message?.sentAt ?? checkin?.checkedAt ?? pending!.at;
  bool get isMe => message?.isMe ?? checkin?.isMe ?? true;
  String get nickname => message?.nickname ?? checkin?.nickname ?? pending!.nickname;
  int get nicknameNo => message?.nicknameNo ?? checkin?.nicknameNo ?? pending!.nicknameNo;
  String get displayName => message?.displayName ?? checkin?.displayName ?? pending!.displayName;
  String? get body => message?.body ?? pending?.body;
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
  const _TextBubble({required this.text, required this.isMe, this.sending = false, this.quote});

  final String text;
  final bool isMe;

  /// 답장이면 말풍선 위쪽에 원래 메시지를 한 줄로 보여 준다.
  final Widget? quote;

  /// 아직 서버에 저장되기 전이면 흐리게 보여 준다.
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? JdColors.togetherChip : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? null : Border.all(color: JdColors.line),
      ),
      child: quote == null
          ? Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: JdColors.ink))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                quote!,
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 15, height: 1.35, color: JdColors.ink)),
              ],
            ),
    );
    return sending ? Opacity(opacity: 0.55, child: bubble) : bubble;
  }
}

/// 답장 말풍선 안의 인용: 누구에게 답장했는지와 원래 글 한 줄.
class _Quote extends StatelessWidget {
  const _Quote({required this.title, required this.text, this.icon = Icons.reply_rounded, this.onTap});

  final String title;
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: JdColors.together, width: 2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: JdColors.together),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: JdColors.togetherText)),
                ),
              ],
            ),
            Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
          ],
        ),
      ),
    );
  }
}

/// "인증했어요" 알림 카드. 사진(또는 동영상 표시)·한 줄·응원 수를 작게 보여 주고, 누르면 크게 연다.
class _CheckinBubble extends StatelessWidget {
  const _CheckinBubble(
      {super.key, required this.item, required this.onTap, this.onLongPress, this.comments = 0});

  final FeedItem item;
  final VoidCallback onTap;

  /// 길게 누르면 바로 댓글 쓰기
  final VoidCallback? onLongPress;

  /// 이 인증에 달린 댓글 수
  final int comments;

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
        onLongPress: onLongPress,
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
                    if (comments > 0) ...[
                      if (reactions.isNotEmpty) const SizedBox(width: 8),
                      Text('💬 $comments', style: const TextStyle(fontSize: 13, color: JdColors.subtle)),
                    ],
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
