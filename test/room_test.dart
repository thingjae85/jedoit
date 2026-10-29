import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jeoduit/models/room.dart';
import 'package:jeoduit/screens/room_entry_screen.dart';
import 'package:jeoduit/screens/room_screen.dart';
import 'package:jeoduit/services/room_service.dart';
import 'package:jeoduit/utils/photo.dart';
import 'package:jeoduit/widgets/desk_view.dart';

final _now = DateTime.utc(2026, 11, 11, 3); // 11/11 12:00 KST

RoomSummary _summary({
  RoomStatus status = RoomStatus.recruiting,
  int earned = 0,
  int active = 1,
  int? n0,
  int? goal,
  int total = 3,
}) =>
    RoomSummary(
      id: 'room-1',
      status: status,
      inviteCode: 'ABCD2345',
      isHost: true,
      recruitExpiresAt: _now.add(const Duration(hours: 20)),
      startsAt: status == RoomStatus.recruiting ? null : _now.subtract(const Duration(hours: 12)),
      endsAt: status == RoomStatus.recruiting ? null : _now.add(const Duration(days: 2, hours: 12)),
      startCount: n0,
      activeCount: active,
      totalElements: total,
      goal: goal,
      earned: earned,
      validCount: earned,
    );

class _FakeRooms implements RoomService {
  RoomSummary current = _summary();
  List<RoomMember> people = [
    const RoomMember(nickname: '명재', nicknameNo: 1, isMe: true, isHost: true, checkins: 0),
  ];
  final created = <String>[];
  final joined = <String>[];
  Uint8List? uploaded;
  Object? joinError;

  @override
  Future<String?> myRoomId() async => null;
  @override
  Future<RoomSummary> summary(String roomId) async => current;
  @override
  Future<List<RoomMember>> members(String roomId) async => people;
  @override
  Future<InvitePreview?> preview(String code) async => code == 'ABCD2345'
      ? InvitePreview(status: RoomStatus.recruiting, memberCount: 2, recruitExpiresAt: DateTime.now().add(const Duration(hours: 3)))
      : null;
  @override
  Future<String> create(String nickname) async {
    created.add(nickname);
    return 'room-1';
  }

  @override
  Future<String> join(String code, String nickname) async {
    if (joinError != null) throw joinError!;
    joined.add('$code:$nickname');
    return 'room-1';
  }

  @override
  Future<void> confirmStart(String roomId) async {}
  @override
  Future<void> leave(String roomId) async {}
  @override
  Future<void> checkIn(String roomId, Uint8List jpeg, String memo) async => uploaded = jpeg;

  List<MyCheckin> mine = [];
  final actions = <String>[];

  @override
  Future<List<MyCheckin>> myCheckins(String roomId) async => mine;

  @override
  Future<void> deletePhoto(String roomId, DateTime date) async {
    actions.add('photo ${date.day}');
    mine = [for (final c in mine) c.date == date ? MyCheckin(date: c.date, valid: c.valid, hasPhoto: false) : c];
    current = _summary(status: RoomStatus.active, earned: current.earned, active: 3, n0: 4, goal: 7, total: 10);
  }

  @override
  Future<void> cancelCheckin(String roomId, DateTime date) async {
    actions.add('cancel ${date.day}');
    mine = [for (final c in mine) c.date == date ? MyCheckin(date: c.date, valid: false, hasPhoto: false) : c];
  }
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  test('초대 링크는 앱 주소에 invite 값만 붙인다', () {
    final link = inviteLink(Uri.parse('https://thingjae85.github.io/jedoit/?code=abc#/x'), 'ABCD2345');
    expect(link, 'https://thingjae85.github.io/jedoit/?invite=ABCD2345');
  });

  test('예약 방은 시작 시각이 지나면 진행 중, 종료 시각이 지나면 끝난 것으로 본다', () {
    final s = _summary(status: RoomStatus.scheduled);
    expect(s.statusAt(_now), RoomStatus.active);
    expect(s.statusAt(_now.add(const Duration(days: 3))), RoomStatus.finished);
    expect(_summary().statusAt(_now.add(const Duration(days: 1))), RoomStatus.expired);
  });

  test('서버 오류 코드를 사용자 문구로 바꾼다', () {
    expect(roomErrorMessage(Exception('date_changed')), contains('날짜가 바뀌어'));
    expect(roomErrorMessage(Exception('???')), '잠시 후 다시 시도해 주세요.');
  });

  test('인증 사진은 긴 변 1280px 이하 JPEG로 다시 만들고 1MiB를 넘지 않는다', () {
    final big = img.Image(width: 3000, height: 2000);
    img.fill(big, color: img.ColorRgb8(120, 160, 140));
    final png = img.encodePng(big);
    final out = prepareCheckinPhoto(png);
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1280);
    expect(out.length, lessThanOrEqualTo(maxOutputBytes));
    expect(decoded.exif.isEmpty, isTrue);
    expect(() => prepareCheckinPhoto(Uint8List.fromList([1, 2, 3])), throwsA(isA<PhotoException>()));
  });

  testWidgets('방 만들기: 닉네임 2~10자를 확인한 뒤 만든다', (tester) async {
    final rooms = _FakeRooms();
    String? result;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await Navigator.of(context)
            .push<String>(MaterialPageRoute(builder: (_) => RoomEntryScreen(rooms: rooms))),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '명');
    await tester.pump();
    expect(find.text('닉네임은 2~10자로 정해 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '명재');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '방 만들기'));
    await tester.pumpAndSettle();
    expect(rooms.created, ['명재']);
    expect(result, 'room-1');
  });

  testWidgets('초대 링크로 들어오면 코드가 채워진 참가 화면이 열린다', (tester) async {
    final rooms = _FakeRooms();
    await tester.pumpWidget(_wrap(RoomEntryScreen(rooms: rooms, inviteCode: 'ABCD2345')));
    await tester.pumpAndSettle();
    expect(find.textContaining('모집 중인 방이에요 · 지금 2명'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '철수');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '참가하기'));
    await tester.pumpAndSettle();
    expect(rooms.joined, ['ABCD2345:철수']);
  });

  testWidgets('참가 실패 이유를 보여 준다', (tester) async {
    final rooms = _FakeRooms()..joinError = Exception('already_in_room');
    await tester.pumpWidget(_wrap(RoomEntryScreen(rooms: rooms, inviteCode: 'ABCD2345')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '철수');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '참가하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이미 참여 중인 방'), findsOneWidget);
  });

  testWidgets('모집 중인 방은 초대 QR·코드를 보여 주고 혼자면 시작할 수 없다', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rooms = _FakeRooms();
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inviteQr')), findsOneWidget);
    expect(find.text('ABCD2345'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, '2명 이상 모이면 시작할 수 있어요');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
  });

  testWidgets('진행 중인 방은 H/T·목표를 보여 주고 사진 인증을 저장한다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 1, active: 3, n0: 4, goal: 7, total: 10);

    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.textContaining('공동 목표 7회까지 6회'), findsOneWidget);
    expect(find.textContaining('참가자가 나가서'), findsOneWidget);

    expect(find.text('오늘 정리 인증하기'), findsOneWidget);
  });

  testWidgets('인증 화면: 사진·완료 체크가 있어야 저장되고 압축한 JPEG을 올린다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rooms = _FakeRooms();
    final photo = img.encodePng(img.Image(width: 40, height: 30));
    await tester.pumpWidget(_wrap(CheckInScreen(rooms: rooms, roomId: 'room-1', picker: () async => photo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 고르기'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '인증 저장')).onPressed, isNull);
    await tester.ensureVisible(find.text('오늘 5분 정리를 실제로 했어요'));
    await tester.tap(find.text('오늘 5분 정리를 실제로 했어요'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '인증 저장'));
    await tester.tap(find.widgetWithText(FilledButton, '인증 저장'));
    await tester.pumpAndSettle();
    expect(rooms.uploaded, isNotNull);
    expect(img.decodeJpg(rooms.uploaded!), isNotNull);
  });

  testWidgets('진행 중인 방에 공동 책상이 보이고, 사진 삭제와 인증 취소는 확인 후 진행된다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 11, 11);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 1, active: 3, n0: 4, goal: 7, total: 10)
      ..mine = [MyCheckin(date: day, valid: true, hasPhoto: true)];
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();

    final desk = tester.widget<DeskView>(find.byType(DeskView));
    expect(desk.total, 10);
    expect(desk.tidied, 1);
    expect(find.text('11/11 인증 완료'), findsOneWidget);

    await tester.tap(find.byTooltip('인증 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('완료 체크와 이미 정리된 책상 요소는 그대로'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(rooms.actions, ['photo 11']);
    expect(find.text('사진 삭제됨 · 완료 체크 유지'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);

    await tester.tap(find.byTooltip('인증 관리'));
    await tester.pumpAndSettle();
    expect(find.text('사진 삭제'), findsNothing);
    await tester.tap(find.text('인증 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(rooms.actions, ['photo 11', 'cancel 11']);
    expect(find.text('11/11 인증 취소됨'), findsOneWidget);
    expect(find.byTooltip('인증 관리'), findsNothing);
  });

  testWidgets('이탈로 요소가 줄어도 정리된 요소는 남는다', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(width: 400, child: DeskView(total: 3, tidied: 5))));
    expect(find.bySemanticsLabel('공동 책상, 물건 5개 중 5개 정리됨'), findsOneWidget);
  });
}
