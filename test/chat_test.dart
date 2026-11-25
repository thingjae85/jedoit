import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeoduit/models/room.dart';
import 'package:jeoduit/screens/chat_screen.dart';
import 'package:jeoduit/services/chat_service.dart';
import 'package:jeoduit/services/room_service.dart';
import 'package:jeoduit/widgets/room_feed.dart';

class _FakeChat implements ChatService {
  final stored = <ChatMessage>[];
  void Function()? onNew;
  var unlistened = false;
  var _id = 0;

  /// 설정하면 send가 이 Completer가 끝날 때까지 기다린다 (느린 서버 흉내).
  Completer<void>? gate;
  Object? failWith;

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
  Future<void> send(String roomId, String body, {int? replyTo, CheckinRef? replyCheckin}) async {
    await gate?.future;
    if (failWith != null) throw failWith!;
    stored.add(ChatMessage(
      id: ++_id,
      nickname: '명재',
      nicknameNo: 1,
      isMe: true,
      body: body,
      sentAt: DateTime.utc(2026, 11, 14, 3, _id),
      replyTo: replyTo,
      replyCheckin: replyCheckin,
    ));
  }

  /// 서버에 저장된 반응: 메시지 번호 → (이모지 → 누른 사람 수, 내가 눌렀는지)
  final storedReactions = <int, Map<MessageEmoji, (int, bool)>>{};
  final toggled = <String>[];

  @override
  Future<Map<int, List<ReactionCount>>> reactions(String roomId) async => {
        for (final e in storedReactions.entries)
          e.key: [for (final r in e.value.entries) ReactionCount(r.key, r.value.$1, mine: r.value.$2)],
      };

  @override
  Future<bool> toggleReaction(String roomId, int messageId, MessageEmoji emoji) async {
    toggled.add('$messageId:${emoji.serverName}');
    final map = storedReactions.putIfAbsent(messageId, () => {});
    final (count, mine) = map[emoji] ?? (0, false);
    final next = mine ? count - 1 : count + 1;
    if (next == 0) {
      map.remove(emoji);
    } else {
      map[emoji] = (next, !mine);
    }
    return !mine;
  }

  @override
  void Function() listen(String roomId, void Function() onNew,
      {void Function()? onCheckin, void Function()? onReaction}) {
    this.onNew = onNew;
    return () => unlistened = true;
  }
}

class _FakeRooms implements RoomService {
  List<FeedItem> items = [];
  final reacted = <String>[];

  @override
  Future<List<FeedItem>> feed(String roomId) async => items;

  @override
  Future<bool> toggleReaction(String roomId, FeedItem item, Reaction reaction) async {
    reacted.add('${item.nickname}:${reaction.serverName}');
    return !item.mine(reaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  testWidgets('단톡방: 친구 인증이 "인증했어요" 카드로 뜨고, 누르면 크게 보고 응원할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final chat = _FakeChat()..friendSays('나 지금 정리 시작!');
    final rooms = _FakeRooms()
      ..items = [
        FeedItem(
          nickname: '민지',
          nicknameNo: 1,
          isMe: false,
          date: DateTime(2026, 11, 14),
          checkedAt: DateTime.utc(2026, 11, 14, 3, 30),
          media: FeedMedia.none,
          note: '책상 위 컵 치웠어요',
          claps: 1,
        ),
      ];
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, rooms: rooms, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('민지님이 인증했어요'), findsOneWidget);
    expect(find.text('👏 1'), findsOneWidget);

    await tester.tap(find.text('민지님이 인증했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reaction-민지#1@2026-11-14-fire')));
    await tester.pumpAndSettle();
    expect(rooms.reacted, ['민지:fire']);

    Navigator.of(tester.element(find.byType(FeedCard))).pop();
    await tester.pumpAndSettle();
    expect(find.text('👏 1  🔥 1'), findsOneWidget);
  });

  testWidgets('단톡방: 보내기를 누르면 서버 답을 기다리지 않고 바로 말풍선이 뜬다', (tester) async {
    final chat = _FakeChat()..gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '바로 보여?');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();
    expect(find.text('바로 보여?'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    chat.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('바로 보여?'), findsOneWidget);
    expect(chat.stored.where((m) => m.body == '바로 보여?'), hasLength(1));
  });

  testWidgets('단톡방: 보내기에 실패하면 말풍선을 거두고 글을 입력창에 되돌린다', (tester) async {
    final chat = _FakeChat()..failWith = Exception('network');
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '안 갈 메시지');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('보내지 못했어요'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '안 갈 메시지');
    expect(find.text('안 갈 메시지'), findsOneWidget); // 입력창 안의 글만 남는다
  });

  testWidgets('단톡방: 메시지를 길게 눌러 반응을 달고, 반응을 다시 누르면 취소된다', (tester) async {
    final chat = _FakeChat()..friendSays('오늘 다 했다!');
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('오늘 다 했다!'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react-1-heart')));
    await tester.pumpAndSettle();
    expect(chat.toggled, ['1:heart']);
    expect(find.text('❤️ 1'), findsOneWidget);

    await tester.tap(find.text('❤️ 1'));
    await tester.pumpAndSettle();
    expect(chat.toggled, ['1:heart', '1:heart']);
    expect(find.text('❤️ 1'), findsNothing);
  });

  testWidgets('단톡방: 메시지에 답장하면 원래 메시지가 인용으로 붙는다', (tester) async {
    final chat = _FakeChat()..friendSays('내일 몇 시에 해?');
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('내일 몇 시에 해?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('답장'));
    await tester.pumpAndSettle();
    expect(find.text('민지에게 답장'), findsOneWidget); // 입력창 위 표시

    await tester.enterText(find.byType(TextField), '9시!');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();
    expect(chat.stored.last.replyTo, 1);
    expect(find.text('9시!'), findsOneWidget);
    expect(find.text('민지에게 답장'), findsOneWidget); // 말풍선 안 인용 (입력창 위 표시는 사라짐)
    expect(find.byTooltip('답장 취소'), findsNothing);
  });

  testWidgets('단톡방: 인증 카드에 댓글을 달면 카드에 댓글 수가 보이고, 열면 댓글이 모여 있다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final chat = _FakeChat();
    final rooms = _FakeRooms()
      ..items = [
        FeedItem(
          nickname: '민지',
          nicknameNo: 1,
          isMe: false,
          date: DateTime(2026, 11, 14),
          checkedAt: DateTime.utc(2026, 11, 14, 3, 30),
          media: FeedMedia.none,
          note: '책상 위 컵 치웠어요',
        ),
      ];
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(chat: chat, rooms: rooms, roomId: 'room-1', title: '챌린지', members: members, poll: null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('민지님이 인증했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('댓글 달기'));
    await tester.pumpAndSettle();
    expect(find.text('민지님 인증에 댓글'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '깔끔하다');
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();
    expect(chat.stored.last.replyCheckin?.key, '민지#1@2026-11-14');
    expect(find.text('💬 1'), findsOneWidget);

    await tester.tap(find.text('민지님이 인증했어요'));
    await tester.pumpAndSettle();
    expect(find.text('나  깔끔하다'), findsOneWidget); // 카드 아래 댓글
  });
}
