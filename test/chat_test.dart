import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeoduit/models/room.dart';
import 'package:jeoduit/screens/chat_screen.dart';
import 'package:jeoduit/services/chat_service.dart';

class _FakeChat implements ChatService {
  final stored = <ChatMessage>[];
  void Function()? onNew;
  var unlistened = false;
  var _id = 0;

  void friendSays(String text) {
    stored.add(ChatMessage(
      id: ++_id,
      nickname: '민지',
      nicknameNo: 1,
      isMe: false,
      body: text,
      sentAt: DateTime.utc(2026, 11, 14, 3, _id),
    ));
    onNew?.call();
  }

  @override
  Future<List<ChatMessage>> messages(String roomId, {int after = 0}) async =>
      stored.where((m) => m.id > after).toList();

  @override
  Future<void> send(String roomId, String body) async {
    stored.add(ChatMessage(
      id: ++_id,
      nickname: '명재',
      nicknameNo: 1,
      isMe: true,
      body: body,
      sentAt: DateTime.utc(2026, 11, 14, 3, _id),
    ));
  }

  @override
  void Function() listen(String roomId, void Function() onNew) {
    this.onNew = onNew;
    return () => unlistened = true;
  }
}

void main() {
  const members = [
    RoomMember(nickname: '명재', nicknameNo: 1, isMe: true, isHost: true, checkins: 0),
    RoomMember(nickname: '민지', nicknameNo: 1, isMe: false, isHost: false, checkins: 0),
  ];

  testWidgets('단톡방: 친구 메시지는 이름과 함께, 새 메시지는 바로, 내 메시지는 보내면 보인다', (tester) async {
    final chat = _FakeChat()..friendSays('다들 오늘 인증했어?');
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, roomId: 'room-1', title: '3일 책상 정리 챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('다들 오늘 인증했어?'), findsOneWidget);
    expect(find.text('민지'), findsOneWidget);

    chat.friendSays('나는 했어!');
    await tester.pumpAndSettle();
    expect(find.text('나는 했어!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  나도 방금 했어  ');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();
    expect(find.text('나도 방금 했어'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.pumpWidget(const SizedBox());
    expect(chat.unlistened, isTrue);
  });

  testWidgets('단톡방: 대화가 없으면 첫 인사를 권한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: _FakeChat(), roomId: 'room-1', title: '챌린지', poll: null),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 인사'), findsOneWidget);
  });
}
