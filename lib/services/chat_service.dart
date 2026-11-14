import 'package:supabase_flutter/supabase_flutter.dart';

/// 단톡방 메시지 한 개.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.nickname,
    required this.nicknameNo,
    required this.isMe,
    required this.body,
    required this.sentAt,
  });

  final int id;
  final String nickname;
  final int nicknameNo;
  final bool isMe;
  final String body;
  final DateTime sentAt;

  /// 동명 닉네임은 방 안 구분 번호를 붙인다.
  String get displayName => nicknameNo > 1 ? '$nickname $nicknameNo' : nickname;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String,
        nicknameNo: (j['nickname_no'] as num).toInt(),
        isMe: j['is_me'] as bool,
        body: j['body'] as String,
        sentAt: DateTime.parse(j['sent_at'] as String),
      );
}

/// 서버 오류 코드를 단톡방 문구로 바꾼다.
String chatErrorMessage(Object error) {
  final text = error is PostgrestException ? error.message : error.toString();
  if (text.contains('not_member')) return '이 방의 참가자만 대화할 수 있어요.';
  if (text.contains('message_too_long')) return '메시지는 500자까지 보낼 수 있어요.';
  if (text.contains('empty_message')) return '메시지를 입력해 주세요.';
  return '메시지를 보내지 못했어요. 잠시 후 다시 시도해 주세요.';
}

/// 챌린지방 단톡방. 읽기·쓰기 규칙은 서버 DB 함수가 확인한다.
abstract class ChatService {
  /// [after]번 다음 메시지들(최근 200개까지), 오래된 순.
  Future<List<ChatMessage>> messages(String roomId, {int after = 0});

  Future<void> send(String roomId, String body);

  /// 새 메시지가 생기면 [onNew]를, 참가자 인증이 생기거나 바뀌면 [onCheckin]을 부른다.
  /// 돌려준 함수를 부르면 구독을 끝낸다.
  void Function() listen(String roomId, void Function() onNew, {void Function()? onCheckin});
}

class SupabaseChatService implements ChatService {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<ChatMessage>> messages(String roomId, {int after = 0}) async {
    final rows = await _db.rpc('room_chat', params: {'r': roomId, 'after': after}) as List;
    return rows.map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> send(String roomId, String body) =>
      _db.rpc('send_room_message', params: {'r': roomId, 'body': body});

  @override
  void Function() listen(String roomId, void Function() onNew, {void Function()? onCheckin}) {
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
    channel.subscribe();
    return () {
      _db.removeChannel(channel);
    };
  }
}
