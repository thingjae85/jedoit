import 'package:supabase_flutter/supabase_flutter.dart';

/// 메시지에 달 수 있는 반응.
enum MessageEmoji {
  heart('heart', '❤️'),
  like('like', '👍'),
  laugh('laugh', '😂'),
  wow('wow', '😮'),
  sad('sad', '😢'),
  clap('clap', '👏');

  const MessageEmoji(this.serverName, this.emoji);
  final String serverName;
  final String emoji;

  static MessageEmoji? fromServer(String? name) {
    for (final e in values) {
      if (e.serverName == name) return e;
    }
    return null;
  }
}

/// 한 메시지에 달린 반응 하나의 수와 내가 눌렀는지.
class ReactionCount {
  const ReactionCount(this.emoji, this.count, {this.mine = false});
  final MessageEmoji emoji;
  final int count;
  final bool mine;
}

/// 답장할 인증. 방 피드와 같이 닉네임·번호·날짜로 가리킨다.
class CheckinRef {
  const CheckinRef({required this.nickname, required this.nicknameNo, required this.date});
  final String nickname;
  final int nicknameNo;
  final DateTime date;

  /// 방 피드 카드(FeedItem.key)와 같은 모양
  String get key => '$nickname#$nicknameNo@${date.year}-${date.month}-${date.day}';

  String get serverDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 단톡방 메시지 한 개.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.nickname,
    required this.nicknameNo,
    required this.isMe,
    required this.body,
    required this.sentAt,
    this.replyTo,
    this.replyCheckin,
  });

  final int id;
  final String nickname;
  final int nicknameNo;
  final bool isMe;
  final String body;
  final DateTime sentAt;

  /// 답장한 메시지 번호
  final int? replyTo;

  /// 댓글을 단 인증
  final CheckinRef? replyCheckin;

  /// 동명 닉네임은 방 안 구분 번호를 붙인다.
  String get displayName => nicknameNo > 1 ? '$nickname $nicknameNo' : nickname;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String,
        nicknameNo: (j['nickname_no'] as num).toInt(),
        isMe: j['is_me'] as bool,
        body: j['body'] as String,
        sentAt: DateTime.parse(j['sent_at'] as String),
        replyTo: (j['reply_to'] as num?)?.toInt(),
        replyCheckin: j['reply_nick'] == null || j['reply_date'] == null
            ? null
            : CheckinRef(
                nickname: j['reply_nick'] as String,
                nicknameNo: (j['reply_nick_no'] as num?)?.toInt() ?? 1,
                date: DateTime.parse(j['reply_date'] as String),
              ),
      );
}

/// 서버 오류 코드를 단톡방 문구로 바꾼다.
String chatErrorMessage(Object error) {
  final text = error is PostgrestException ? error.message : error.toString();
  if (text.contains('not_member')) return '이 방의 참가자만 대화할 수 있어요.';
  if (text.contains('message_too_long')) return '메시지는 500자까지 보낼 수 있어요.';
  if (text.contains('empty_message')) return '메시지를 입력해 주세요.';
  if (text.contains('reply_not_found')) return '답장할 메시지를 찾지 못했어요.';
  if (text.contains('checkin_not_found')) return '취소된 인증이에요.';
  if (text.contains('message_not_found')) return '지워진 메시지예요.';
  return '메시지를 보내지 못했어요. 잠시 후 다시 시도해 주세요.';
}

/// 챌린지방 단톡방. 읽기·쓰기 규칙은 서버 DB 함수가 확인한다.
abstract class ChatService {
  /// [after]번 다음 메시지들(최근 200개까지), 오래된 순.
  Future<List<ChatMessage>> messages(String roomId, {int after = 0});

  /// [replyTo] 메시지나 [replyCheckin] 인증에 답장할 수 있다.
  Future<void> send(String roomId, String body, {int? replyTo, CheckinRef? replyCheckin});

  /// 최근 메시지들의 반응: 메시지 번호별 목록.
  Future<Map<int, List<ReactionCount>>> reactions(String roomId);

  /// 반응 누르기/취소. 눌린 상태면 true.
  Future<bool> toggleReaction(String roomId, int messageId, MessageEmoji emoji);

  /// 새 메시지가 생기면 [onNew]를, 참가자 인증이 생기거나 바뀌면 [onCheckin]을,
  /// 메시지 반응이 바뀌면 [onReaction]을 부른다. 돌려준 함수를 부르면 구독을 끝낸다.
  void Function() listen(String roomId, void Function() onNew,
      {void Function()? onCheckin, void Function()? onReaction});
}

class SupabaseChatService implements ChatService {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<ChatMessage>> messages(String roomId, {int after = 0}) async {
    final rows = await _db.rpc('room_chat', params: {'r': roomId, 'after': after}) as List;
    return rows.map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> send(String roomId, String body, {int? replyTo, CheckinRef? replyCheckin}) =>
      _db.rpc('send_room_message', params: {
        'r': roomId,
        'body': body,
        // 답장이 아닐 때는 예전 서버 함수와도 맞도록 보내지 않는다.
        if (replyTo != null) 'reply_to': replyTo,
        if (replyTo == null && replyCheckin != null) ...{
          'reply_nick': replyCheckin.nickname,
          'reply_nick_no': replyCheckin.nicknameNo,
          'reply_date': replyCheckin.serverDate,
        },
      });

  @override
  Future<Map<int, List<ReactionCount>>> reactions(String roomId) async {
    final rows = await _db.rpc('room_chat_reactions', params: {'r': roomId}) as List;
    final out = <int, List<ReactionCount>>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final e = MessageEmoji.fromServer(row['emoji'] as String?);
      if (e == null) continue;
      out.putIfAbsent((row['message_id'] as num).toInt(), () => []).add(
          ReactionCount(e, (row['count'] as num).toInt(), mine: row['mine'] as bool? ?? false));
    }
    for (final list in out.values) {
      list.sort((a, b) => a.emoji.index.compareTo(b.emoji.index));
    }
    return out;
  }

  @override
  Future<bool> toggleReaction(String roomId, int messageId, MessageEmoji emoji) async =>
      await _db.rpc('toggle_message_reaction', params: {'r': roomId, 'm': messageId, 'emoji': emoji.serverName})
          as bool;

  @override
  void Function() listen(String roomId, void Function() onNew,
      {void Function()? onCheckin, void Function()? onReaction}) {
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId);
    var channel = _db.channel('room-chat-$roomId').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_messages',
          filter: filter,
          callback: (_) => onNew(),
        );
    if (onCheckin != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'checkin_slots',
        filter: filter,
        callback: (_) => onCheckin(),
      );
    }
    if (onReaction != null) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_message_reactions',
        filter: filter,
        callback: (_) => onReaction(),
      );
    }
    channel.subscribe();
    return () {
      _db.removeChannel(channel);
    };
  }
}
