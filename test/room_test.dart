import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jeoduit/models/room.dart';
import 'package:jeoduit/screens/checkin_screen.dart';
import 'package:jeoduit/screens/room_entry_screen.dart';
import 'package:jeoduit/screens/room_screen.dart';
import 'package:jeoduit/services/room_service.dart';
import 'package:jeoduit/utils/photo.dart';
import 'package:jeoduit/utils/video.dart';
import 'package:jeoduit/widgets/room_feed.dart';
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
  Future<String> create(
    String nickname, {
    CheckinMode mode = CheckinMode.result,
    ChallengeKind kind = ChallengeKind.tidy,
    String title = '책상 한 구역 정리',
    int days = 3,
  }) async {
    created.add(kind == ChallengeKind.tidy && days == 3
        ? '$nickname:${mode.serverName}'
        : '$nickname:${mode.serverName}:${kind.serverName}:$title:$days');
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
  Future<void> checkIn(String roomId, {Uint8List? photo, CheckinVideo? video, required String note}) async {
    uploaded = photo;
    uploadedVideo = video;
    notes.add(note);
  }

  CheckinVideo? uploadedVideo;
  final notes = <String>[];
  List<FeedItem> feedItems = [];
  BeforeShot? before;
  Uint8List? savedBefore;

  @override
  Future<void> saveBefore(String roomId, Uint8List jpeg, String note) async {
    savedBefore = jpeg;
    notes.add('before:$note');
  }

  @override
  Future<BeforeShot?> beforeToday(String roomId) async => before;

  @override
  Future<List<FeedItem>> feed(String roomId) async => feedItems;

  final reactions = <String>[];

  @override
  Future<bool> toggleReaction(String roomId, FeedItem item, Reaction reaction) async {
    reactions.add('${item.nickname}:${reaction.serverName}');
    return !item.mine(reaction);
  }

  List<MyCheckin> mine = [];
  final actions = <String>[];

  bool failMine = false;

  @override
  Future<List<MyCheckin>> myCheckins(String roomId) async {
    if (failMine) throw StateError('my_checkins 없음');
    return mine;
  }

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

/// 'mvhd' 상자만 있는 가짜 MP4. [version] 1이면 64비트 길이를 쓴다.
Uint8List _fakeMp4(double seconds, {int version = 0}) {
  const timescale = 600;
  final duration = (seconds * timescale).round();
  final b = BytesBuilder()
    ..add([0, 0, 0, 0, 0x66, 0x74, 0x79, 0x70]) // ftyp 머리 흉내
    ..add([0, 0, 0, 120])
    ..add('mvhd'.codeUnits)
    ..add([version, 0, 0, 0]);
  final d = ByteData(version == 1 ? 28 : 16);
  if (version == 1) {
    d.setUint32(16, timescale);
    d.setUint32(20, 0);
    d.setUint32(24, duration);
  } else {
    d.setUint32(8, timescale);
    d.setUint32(12, duration);
  }
  b.add(d.buffer.asUint8List());
  b.add(List.filled(64, 0));
  return b.toBytes();
}

FeedItem _feedItem(
        {String nick = '철수',
        FeedMedia media = FeedMedia.photo,
        String? url,
        String? note,
        String? beforeUrl,
        String? beforeNote,
        bool isMe = false,
        int claps = 0}) =>
    FeedItem(
      nickname: nick,
      nicknameNo: 1,
      isMe: isMe,
      claps: claps,
      date: DateTime(2026, 11, 11),
      checkedAt: DateTime(2026, 11, 11, 21, 5),
      media: media,
      mediaUrl: url,
      note: note,
      beforeUrl: beforeUrl,
      beforeNote: beforeNote,
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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
    _tall(tester);
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

    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '명');
    await tester.pump();
    expect(find.text('닉네임은 2~10자로 정해 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '명재');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '방 만들기'));
    await tester.pumpAndSettle();
    expect(rooms.created, ['명재:result']);
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

    expect(find.text('오늘 인증하기'), findsOneWidget);
  });

  testWidgets('인증 화면: 사진·완료 체크가 있어야 저장되고 압축한 JPEG을 올린다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rooms = _FakeRooms();
    final photo = img.encodePng(img.Image(width: 40, height: 30));
    await tester.pumpWidget(_wrap(CheckInScreen(rooms: rooms, roomId: 'room-1', picker: () async => PickedFile(photo, 'a.png'))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '사진'));
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

  testWidgets('진행 중인 방에 진행도가 보이고, 사진 삭제와 인증 취소는 확인 후 진행된다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 11, 11);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 1, active: 3, n0: 4, goal: 7, total: 10)
      ..mine = [MyCheckin(date: day, valid: true, hasPhoto: true)];
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('11/11 인증 완료'), findsOneWidget);

    await tester.tap(find.byTooltip('인증 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('완료 체크와 이미 쌓인 진행도는 그대로'), findsOneWidget);
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

  testWidgets('내 인증 목록을 못 불러와도 방 진행도는 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 1, active: 3, n0: 4, goal: 7, total: 10)
      ..failMine = true;
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.text('내 인증'), findsNothing);
  });

  testWidgets('이탈로 요소가 줄어도 정리된 요소는 남는다', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(width: 400, child: DeskView(total: 3, tidied: 5))));
    expect(find.bySemanticsLabel('공동 책상, 물건 5개 중 5개 정리됨'), findsOneWidget);
  });

  test('동영상 길이를 MP4·MOV 머리에서 읽고 5초 이상이면 막는다', () {
    expect(mp4DurationSeconds(_fakeMp4(3.2)), closeTo(3.2, 0.01));
    expect(mp4DurationSeconds(_fakeMp4(4.5, version: 1)), closeTo(4.5, 0.01));
    expect(mp4DurationSeconds(Uint8List.fromList(List.filled(100, 0))), isNull);

    final ok = prepareCheckinVideo(_fakeMp4(4.9), 'IMG_0001.MOV');
    expect(ok.ext, 'mov');
    expect(ok.contentType, 'video/quicktime');
    expect(() => prepareCheckinVideo(_fakeMp4(5.0), 'a.mp4'), throwsA(isA<PhotoException>()));
    expect(() => prepareCheckinVideo(_fakeMp4(2), 'a.webm'), throwsA(isA<PhotoException>()));
  });

  testWidgets('방을 만들 때 인증 방식을 고른다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms();
    await tester.pumpWidget(_wrap(RoomEntryScreen(rooms: rooms)));
    await tester.pumpAndSettle();
    expect(find.text('결과 인증'), findsOneWidget);
    expect(find.text('가벼운 인증'), findsOneWidget);
    await tester.tap(find.text('전후 인증'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '명재');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '방 만들기'));
    await tester.pumpAndSettle();
    expect(rooms.created, ['명재:before_after']);
  });

  testWidgets('가벼운 인증: 한 줄을 적어야 "했어요"를 누를 수 있다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms();
    await tester.pumpWidget(_wrap(CheckInScreen(rooms: rooms, roomId: 'room-1', mode: CheckinMode.light)));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, '했어요');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '서랍 정리 끝');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(rooms.notes, ['서랍 정리 끝']);
    expect(rooms.uploaded, isNull);
  });

  testWidgets('결과 인증: 5초 미만 동영상과 한 줄을 올리고, 5초 이상은 막는다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms();
    var clip = _fakeMp4(6);
    await tester.pumpWidget(_wrap(CheckInScreen(
      rooms: rooms,
      roomId: 'room-1',
      videoPicker: () async => PickedFile(clip, 'clip.mp4'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동영상 (5초 미만)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5초 미만 동영상만'), findsOneWidget);

    clip = _fakeMp4(3);
    await tester.tap(find.text('동영상 (5초 미만)'));
    await tester.pumpAndSettle();
    expect(find.text('동영상 3.0초 선택됨'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '한 줄 (선택)'), '책상 위 싹 비움');
    await tester.tap(find.text('오늘 5분 정리를 실제로 했어요'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '인증 저장'));
    await tester.pumpAndSettle();
    expect(rooms.uploadedVideo?.seconds, closeTo(3, 0.01));
    expect(rooms.notes, ['책상 위 싹 비움']);
  });

  testWidgets('전후 인증: 전 사진과 한 줄을 먼저 올리고, 후 사진과 한 줄로 인증한다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms();
    final photo = img.encodePng(img.Image(width: 40, height: 30));
    await tester.pumpWidget(_wrap(CheckInScreen(
      rooms: rooms,
      roomId: 'room-1',
      mode: CheckinMode.beforeAfter,
      picker: () async => PickedFile(photo, 'a.png'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('정리 전 사진'), findsOneWidget);

    await tester.tap(find.text('전 사진 고르기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '전 한 줄 (선택)'), '폭탄 맞은 책상');
    await tester.tap(find.widgetWithText(FilledButton, '전 사진 올리기'));
    await tester.pumpAndSettle();
    expect(rooms.savedBefore, isNotNull);
    expect(find.text('정리 후 사진'), findsOneWidget);
    expect(find.text('폭탄 맞은 책상'), findsOneWidget);

    await tester.tap(find.text('후 사진 고르기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '후 한 줄 (선택)'), '이제 공부 가능');
    await tester.ensureVisible(find.text('오늘 5분 정리를 실제로 했어요'));
    await tester.tap(find.text('오늘 5분 정리를 실제로 했어요'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '인증 저장'));
    await tester.tap(find.widgetWithText(FilledButton, '인증 저장'));
    await tester.pumpAndSettle();
    expect(rooms.notes, ['before:폭탄 맞은 책상', '이제 공부 가능']);
    expect(rooms.uploaded, isNotNull);
  });

  testWidgets('전 사진을 이미 올렸으면 바로 후 단계로 시작한다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms()..before = const BeforeShot(url: '', note: '아침의 책상');
    await tester.pumpWidget(_wrap(CheckInScreen(rooms: rooms, roomId: 'room-1', mode: CheckinMode.beforeAfter)));
    await tester.pumpAndSettle();
    expect(find.text('정리 후 사진'), findsOneWidget);
    expect(find.text('아침의 책상'), findsOneWidget);
  });

  testWidgets('방 피드: 전후 카드는 넘겨서 후 한 줄을 보고, 가벼운 인증은 한 줄 카드로 보인다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 2, active: 2, n0: 2, goal: 4, total: 6)
      ..feedItems = [
        _feedItem(url: 'https://x/after.jpg', note: '깨끗!', beforeUrl: 'https://x/before.jpg', beforeNote: '엉망'),
        _feedItem(nick: '영희', media: FeedMedia.none, note: '서랍 정리 끝'),
      ];
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now)));
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsNWidgets(2));
    expect(find.text('서랍 정리 끝'), findsWidgets);
    Text note() => tester.widget<Text>(find.byKey(const Key('beforeAfterNote')));
    expect(note().data, '엉망');
    await tester.drag(find.byKey(const Key('beforeAfterPager')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(note().data, '깨끗!');
  });

  testWidgets('응원: 친구 인증에 👏를 누르면 바로 1이 되고, 내 인증에는 누를 수 없다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 2, active: 2, n0: 2, goal: 4, total: 6)
      ..feedItems = [
        _feedItem(nick: '영희', media: FeedMedia.none, note: '서랍 정리 끝'),
        _feedItem(nick: '명재', media: FeedMedia.none, note: '책상 끝', isMe: true, claps: 2),
      ];
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now, autoRefresh: null)));
    await tester.pumpAndSettle();

    final friendClap = find.byKey(const Key('reaction-영희#1@2026-11-11-clap'));
    await tester.tap(friendClap);
    await tester.pumpAndSettle();
    expect(rooms.reactions, ['영희:clap']);
    expect(find.descendant(of: friendClap, matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reaction-명재#1@2026-11-11-clap')));
    await tester.pumpAndSettle();
    expect(rooms.reactions, ['영희:clap']);
    expect(find.text('친구들이 응원했어요'), findsOneWidget);
  });

  testWidgets('오늘의 콜라주: 모두 인증하면 완료 문구로 바뀐다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 1, active: 2, n0: 2, goal: 4, total: 6)
      ..people = [
        const RoomMember(nickname: '명재', nicknameNo: 1, isMe: true, isHost: true, checkins: 0),
        const RoomMember(nickname: '영희', nicknameNo: 1, isMe: false, isHost: false, checkins: 1),
      ]
      ..feedItems = [_feedItem(nick: '영희', media: FeedMedia.none, note: '서랍 정리 끝')];
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now, autoRefresh: null)));
    await tester.pumpAndSettle();
    expect(find.text('오늘 2명 중 1명이 인증했어요'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('day0')), matching: find.text('1/2명')), findsOneWidget);
    expect(find.text('1일차 · 오늘'), findsOneWidget);

    rooms.feedItems = [
      _feedItem(nick: '명재', media: FeedMedia.none, note: '책상 끝', isMe: true),
      ...rooms.feedItems,
    ];
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('🎉 오늘 모두 인증 완료!'), findsOneWidget);
  });

  testWidgets('자동 새로고침: 친구가 인증하면 피드에 나타나고 알림이 뜬다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms()
      ..current = _summary(status: RoomStatus.active, earned: 0, active: 2, n0: 2, goal: 4, total: 6);
    await tester.pumpWidget(_wrap(
        RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now, autoRefresh: const Duration(seconds: 5))));
    await tester.pumpAndSettle();
    expect(find.byType(FeedCard), findsNothing);

    rooms.feedItems = [_feedItem(nick: '영희', media: FeedMedia.none, note: '서랍 정리 끝')];
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FeedCard), findsOneWidget);
    expect(find.text('영희님이 방금 인증했어요! 응원해 주세요 👏'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('받침에 맞게 을/를을 붙인다', () {
    expect(withObject('책 10쪽 읽기'), '책 10쪽 읽기를');
    expect(withObject('30분 공부'), '30분 공부를');
    expect(withObject('스트레칭'), '스트레칭을');
    expect(withObject('Run'), 'Run를');
  });

  testWidgets('챌린지 커스텀: 종류를 고르면 이름이 채워지고, 직접 만들기는 이름을 적어야 한다', (tester) async {
    _tall(tester);
    final rooms = _FakeRooms();
    await tester.pumpWidget(_wrap(RoomEntryScreen(rooms: rooms)));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이 방에서 쓸 닉네임'), '명재');

    await tester.tap(find.text('책 읽기'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '책 10쪽 읽기'), findsOneWidget);
    await tester.tap(find.text('5일'));
    await tester.pump();
    expect(find.textContaining('5일 동안'), findsOneWidget);

    await tester.tap(find.text('직접 만들기'));
    await tester.pump();
    final create = find.widgetWithText(FilledButton, '방 만들기');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '챌린지 이름'), '물 2L 마시기');
    await tester.pump();
    await tester.tap(find.text('가벼운 인증'));
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(rooms.created, ['명재:light:custom:물 2L 마시기:5']);
  });

  testWidgets('5일 챌린지 방은 이름과 5일 칸을 보여 주고, 인증 화면도 챌린지 이름을 쓴다', (tester) async {
    _tall(tester);
    final base = _summary(status: RoomStatus.active, earned: 1, active: 2, n0: 2, goal: 8, total: 10);
    final rooms = _FakeRooms()
      ..current = RoomSummary(
        id: base.id,
        status: base.status,
        inviteCode: base.inviteCode,
        isHost: true,
        recruitExpiresAt: base.recruitExpiresAt,
        startsAt: base.startsAt,
        endsAt: base.startsAt!.add(const Duration(days: 5)),
        startCount: 2,
        activeCount: 2,
        totalElements: 10,
        goal: 8,
        earned: 1,
        validCount: 1,
        kind: ChallengeKind.reading,
        title: '책 10쪽 읽기',
        days: 5,
      );
    await tester.pumpWidget(_wrap(RoomScreen(rooms: rooms, roomId: 'room-1', now: () => _now, autoRefresh: null)));
    await tester.pumpAndSettle();
    expect(find.text('5일 책 10쪽 읽기 챌린지'), findsOneWidget);
    expect(find.text('5일 인증'), findsOneWidget);
    expect(find.byKey(const Key('day4')), findsOneWidget);
    expect(find.textContaining('책 10쪽 읽기를 하고'), findsOneWidget);

    await tester.tap(find.text('오늘 인증하기'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 인증'), findsOneWidget);
    expect(find.text('오늘 책 10쪽 읽기를 실제로 했어요'), findsOneWidget);
  });
}
