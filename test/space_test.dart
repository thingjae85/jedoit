import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jeoduit/app.dart';
import 'package:jeoduit/models/decor.dart';
import 'package:jeoduit/models/mission.dart';
import 'package:jeoduit/models/mission_record.dart';
import 'package:jeoduit/models/return_days.dart';
import 'package:jeoduit/models/space.dart';
import 'package:jeoduit/models/space_art.dart';
import 'package:jeoduit/services/record_repository.dart';
import 'package:jeoduit/services/space_store.dart';
import 'package:jeoduit/utils/photo.dart';
import 'package:shared_preferences/shared_preferences.dart';

MissionRecord _record(String id, String missionId, DateTime completedAt, {String? photo}) {
  return MissionRecord(
    id: id,
    missionId: missionId,
    startedAt: completedAt.subtract(const Duration(minutes: 5)),
    completedAt: completedAt,
    photo: photo,
  );
}

List<Mission> _fixed(DateTime _) => [missionById('water')!, missionById('cleanup')!, kDiscoveryMission];

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 초록색 한 장짜리 작은 PNG.
Uint8List _greenPng() {
  final image = img.Image(width: 40, height: 30);
  img.fill(image, color: img.ColorRgb8(40, 180, 60));
  return img.encodePng(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('방 그림 단계 수가 방 정의와 맞다', () {
    for (final room in kSpaceRooms) {
      final art = kRoomArt[room.id];
      expect(art, isNotNull, reason: room.id);
      expect(room.lines.length, art!.stages, reason: room.id);
      expect(art.buddySpots.length, art.stages, reason: room.id);
    }
  });

  test('처음엔 어두운 침실 하나, 미션마다 바뀌고 다섯 번째에 새 방 문이 열린다', () {
    final empty = SpaceState.of(0);
    expect(empty.isOpen('bedroom'), isTrue);
    expect(empty.stageOf('bedroom'), 0);
    expect(empty.isOpen('study'), isFalse);
    expect(empty.coins, 0);

    for (var n = 1; n <= 4; n++) {
      expect(spaceEventAt(n)?.roomId, 'bedroom', reason: '$n번째');
      expect(SpaceState.of(n).stageOf('bedroom'), n);
    }
    final opened = spaceEventAt(5)!;
    expect(opened.roomId, 'study');
    expect(opened.opensRoom, isTrue);
    expect(SpaceState.of(5).isOpen('study'), isTrue);
    expect(SpaceState.of(5).latestRoom, 'study');
    expect(SpaceState.of(5).coins, 5 * coinsPerMission);
  });

  test('새 방이 열린 뒤에는 두 번에 한 번씩 두 방이 번갈아 자라고, 마지막엔 둘 다 다 찬다', () {
    expect(spaceEventAt(6), isNull);
    expect(spaceEventAt(7)?.roomId, 'study');
    expect(spaceEventAt(9)?.roomId, 'bedroom');
    final last = spaceThreshold(kSpaceTimeline.length - 1);
    final full = SpaceState.of(last + 100);
    for (final room in kSpaceRooms) {
      expect(full.stageOf(room.id), room.stages - 1, reason: room.id);
    }
    // 단계는 한 번씩만, 순서대로 오른다.
    final seen = <String, int>{};
    for (final e in kSpaceTimeline) {
      expect(e.stage, (seen[e.roomId] ?? (e.roomId == 'bedroom' ? 0 : -1)) + 1);
      seen[e.roomId] = e.stage;
    }
  });

  test('하나만 보기: 고정한 방이 있으면 그 방, 없으면 가장 최근에 바뀐 방', () {
    final s = SpaceState.of(7); // 7번째에 책 읽는 방이 자란다
    expect(s.shownRoom(null), 'study');
    expect(s.shownRoom('bedroom'), 'bedroom');
    expect(SpaceState.of(2).shownRoom('study'), 'bedroom', reason: '안 열린 방은 고정해도 무시');
  });

  test('쉰 날 수: 어제 했으면 0, 사흘 전이 마지막이면 2', () {
    final today = DateTime(2026, 11, 4);
    expect(daysAway([], today), 0);
    expect(daysAway([_record('a', 'water', DateTime(2026, 11, 4, 9))], today), 0);
    expect(daysAway([_record('a', 'water', DateTime(2026, 11, 3, 23))], today), 0);
    expect(
        daysAway([
          _record('a', 'water', DateTime(2026, 10, 20)),
          _record('b', 'water', DateTime(2026, 11, 1, 8)),
        ], today),
        2);
  });

  test('추억 사진은 작게 줄이고, 액자용 8×8 도트 색을 뽑을 수 있다', () {
    final photo = makeKeepsakePhoto(_greenPng());
    final decoded = img.decodeImage(base64Decode(photo))!;
    expect(decoded.width, 40);
    final pixels = photoPixels(photo)!;
    expect(pixels.length, 64);
    final c = pixels.first;
    expect((c >> 8) & 0xFF, greaterThan(150), reason: '초록이 강하다');
    expect(photoPixels('이건 사진이 아님'), isNull);
  });

  test('편지는 쓴 날로부터 일주일 뒤에 도착한다', () {
    final letter = FutureLetter(id: 'l', text: '안녕', writtenAt: DateTime(2026, 11, 1, 9));
    expect(letter.arrived(DateTime(2026, 11, 8, 8)), isFalse);
    expect(letter.arrived(DateTime(2026, 11, 8, 9)), isTrue);
    final back = FutureLetter.fromJson(letter.open().toJson());
    expect(back.opened, isTrue);
    expect(back.text, '안녕');
  });

  test('내 미션은 2개까지 저장되고 깨진 값은 무시한다', () async {
    final store = SpaceStore();
    await store.saveCustomMissions([
      Mission.custom('custom:1', '영양제 먹기'),
      Mission.custom('custom:2', '일기 한 줄'),
      Mission.custom('custom:3', '세 번째'),
    ]);
    final prefs = await store.load();
    expect(prefs.customMissions.map((m) => m.title), ['영양제 먹기', '일기 한 줄']);
    expect(prefs.customMissions.first.kind, MissionKind.custom);

    SharedPreferences.setMockInitialValues({SpaceStore.customKey: '깨진 값', SpaceStore.buddyKey: '고양이'});
    final broken = await SpaceStore().load();
    expect(broken.customMissions, isEmpty);
    expect(broken.buddy, 'bear');
  });

  test('밤은 저녁 7시부터 아침 6시 전까지', () {
    expect(isNightTime(DateTime(2026, 11, 6, 18, 59)), isFalse);
    expect(isNightTime(DateTime(2026, 11, 6, 19)), isTrue);
    expect(isNightTime(DateTime(2026, 11, 7, 5, 59)), isTrue);
    expect(isNightTime(DateTime(2026, 11, 7, 6)), isFalse);
  });

  test('꾸미기: 코인이 있어야 사고, 벽 하나·바닥 둘에 놓고, 치우면 보관함으로', () {
    final clock = decorById('clock')!;
    final poster = decorById('poster')!;
    final lamp = decorById('moodlamp')!;
    final cactus = decorById('cactus')!;
    final books = decorById('books')!;

    var d = const DecorData();
    expect(d.buy(lamp, 30), same(d), reason: '40코인짜리는 30코인으로 못 산다');
    d = d.buy(clock, 100).buy(poster, 100).buy(lamp, 100);
    expect(d.spent, 90);
    expect(d.available(100), 10);
    expect(d.buy(clock, 100), same(d), reason: '이미 있는 건 다시 안 산다');
    expect(d.buy(cactus, 100), same(d), reason: '남은 10코인으로는 못 산다');

    d = d.place(clock, 'bedroom');
    expect(d.slotsOf('bedroom'), {'wall': 'clock'});
    d = d.place(poster, 'bedroom');
    expect(d.slotsOf('bedroom'), {'wall': 'poster'}, reason: '벽은 하나뿐이라 시계는 보관함으로');
    expect(d.roomOf('clock'), isNull);

    d = d.place(lamp, 'bedroom');
    expect(d.slotsOf('bedroom')['floor1'], 'moodlamp');
    d = d.place(lamp, 'study');
    expect(d.roomOf('moodlamp'), 'study', reason: '다른 방으로 옮긴다');
    expect(d.slotsOf('bedroom').containsValue('moodlamp'), isFalse);

    d = d.remove('poster');
    expect(d.roomOf('poster'), isNull);
    expect(d.owned, contains('poster'));
    expect(d.place(books, 'study'), same(d), reason: '안 산 건 놓을 수 없다');

    final back = DecorData.fromJson(d.toJson());
    expect(back.owned, d.owned);
    expect(back.spent, d.spent);
    expect(back.slotsOf('study'), d.slotsOf('study'));
    expect(DecorData.fromJson({'owned': ['없는것', 'clock'], 'placements': {'bedroom': {'wall': '없는것', 'floor9': 'clock'}}, 'spent': -5}).spent, 0);
  });

  test('침실은 상자를 풀고 나서(2단계)부터 꾸밀 수 있다', () {
    expect(canDecorate('bedroom', 1), isFalse);
    expect(canDecorate('bedroom', 2), isTrue);
    expect(canDecorate('study', 0), isTrue);
    expect(decorAsset('bedroom', 'wall', 'clock', night: true), 'assets/space/decor/bedroom_wall_clock_n.png');
  });

  testWidgets('꾸미기에서 코인으로 소품을 사면 방에 놓이고 남은 코인이 줄어든다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await repo.add(_record('r$i', 'water', now.subtract(Duration(minutes: i))));
    }
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('coins'))).data, '30');

    await tester.tap(find.text('꾸미기'));
    await tester.pumpAndSettle();
    expect(find.text('코인 30'), findsOneWidget);
    final buyClock = find.descendant(of: find.widgetWithText(ListTile, '벽시계'), matching: find.text('사기'));
    await tester.tap(buyClock);
    await tester.pumpAndSettle();
    expect(find.text('코인 10'), findsOneWidget);
    expect(find.text('이 방에 놓여 있어요'), findsOneWidget);
    // 40코인짜리 무드등은 못 산다.
    final lampButton = find.ancestor(
        of: find.descendant(of: find.widgetWithText(ListTile, '무드등'), matching: find.text('사기')),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(tester.widget<ButtonStyleButton>(lampButton).onPressed, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('coins'))).data, '10');
    expect((await SpaceStore().load()).decor.slotsOf('bedroom'), {'wall': 'clock'});
  });

  testWidgets('홈에는 내 공간과 미션만 있고 친구 챌린지는 챌린지 탭에 따로 있다', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();

    expect(find.text('작은 침실'), findsOneWidget);
    expect(find.text('하나만 해도 충분해요'), findsOneWidget);
    expect(find.text('친구와 챌린지'), findsNothing);

    await tester.tap(find.text('챌린지'));
    await tester.pumpAndSettle();
    expect(find.text('친구와 챌린지'), findsOneWidget);
    expect(find.text('작은 침실'), findsNothing);
  });

  testWidgets('벌집 보기에서는 안 열린 칸이 닫힌 문으로 보이고, 방을 누르면 그 방이 고정된다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      await repo.add(_record('r$i', 'water', now.subtract(Duration(minutes: i))));
    }
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();

    // 다섯 번 했으면 새 방이 열려 있고, 가장 최근에 바뀐 그 방이 보인다.
    expect(find.text('책 읽는 방'), findsOneWidget);

    await tester.tap(find.byTooltip('벌집 보기'));
    await tester.pumpAndSettle();
    expect(find.text('내 공간'), findsOneWidget);
    expect(find.text('문 너머에 뭔가 있어요'), findsOneWidget);

    // 아래 가운데 칸(침실)을 누른다.
    await tester.tapAt(_bottomCell(tester));
    await tester.pumpAndSettle();
    expect(find.text('작은 침실'), findsOneWidget);
    expect(find.byTooltip('고정 풀기'), findsOneWidget);
    expect((await SpaceStore().load()).pinnedRoom, 'bedroom');
  });

  testWidgets('며칠 쉬다 오면 반겨 주고 채운 방은 그대로다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    final old = DateTime(now.year, now.month, now.day - 5, 10);
    for (var i = 0; i < 3; i++) {
      await repo.add(_record('w$i', 'water', old));
    }
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();

    expect(find.text('다시 와줘서 반가워요'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('coins'))).data, '30', reason: '코인 3번 × 10');
  });

  testWidgets('오늘의 발견: 사진을 남기면 기록에 사진과 주제가 남고 벽 액자에 걸린다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    await tester.pumpWidget(JeoduitApp(
        repository: repo, missionsFor: _fixed, pickPhoto: () async => _greenPng()));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final theme = discoveryThemeFor(today);
    expect(find.text('주제: ${theme.title}'), findsOneWidget);

    // 다른 걸로는 하루 한 번만.
    await tester.tap(find.text('다른 걸로'));
    await tester.pumpAndSettle();
    final rerolled = discoveryThemeFor(today, rerolled: true);
    expect(find.text('주제: ${rerolled.title}'), findsOneWidget);
    expect(find.text('다른 걸로'), findsNothing);

    await tester.tap(find.text('오늘의 발견'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 주제: ${rerolled.title}'), findsOneWidget);
    await tester.tap(find.text('발견한 거 찍기'));
    await tester.pumpAndSettle();
    expect(find.text('사진 빼기'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '했어요'));
    await tester.pumpAndSettle();

    final saved = (await repo.loadAll()).single;
    expect(saved.missionId, 'discovery');
    expect(saved.theme, rerolled.id);
    expect(saved.hasPhoto, isTrue);
    expect(find.textContaining('창문으로 햇빛이 들어와요'), findsOneWidget);
    expect(find.textContaining('사진이 벽 액자에 걸렸어요'), findsOneWidget);
  });

  testWidgets('내 미션을 추가하면 홈에 매일 나오고, 빼도 기록은 남는다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();

    await tester.tap(find.text('내 미션 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '영양제 먹기');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('영양제 먹기'), findsOneWidget);

    await tester.tap(find.text('영양제 먹기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '했어요'));
    await tester.pumpAndSettle();
    expect((await repo.loadAll()).single.title, '영양제 먹기');

    await tester.tap(find.byTooltip('내 미션 빼기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('빼기'));
    await tester.pumpAndSettle();
    expect(find.text('영양제 먹기'), findsNothing);
    expect((await repo.loadAll()).length, 1);
  });

  testWidgets('일주일 지난 편지는 방 카드에 도착해 있고 열면 사라진다', (tester) async {
    _useTallScreen(tester);
    final old = DateTime.now().subtract(const Duration(days: 8));
    await SpaceStore().saveLetters([FutureLetter(id: 'l1', text: '잘 지내고 있지?', writtenAt: old)]);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();

    await tester.tap(find.text('편지가 왔어요'));
    await tester.pumpAndSettle();
    expect(find.text('잘 지내고 있지?'), findsOneWidget);
    await tester.tap(find.text('간직하기'));
    await tester.pumpAndSettle();
    expect(find.text('편지가 왔어요'), findsNothing);
  });
}

/// 벌집 그림의 아래 가운데 칸(첫 방) 한가운데 화면 좌표.
Offset _bottomCell(WidgetTester tester) {
  final rect = tester.getRect(find.byType(AspectRatio).first);
  const w = kRoomArtWidth + kHiveDx;
  final s = rect.width / w;
  return rect.topLeft + Offset((kHiveDx / 2 + kRoomArtWidth / 2) * s, (kHiveDy + kRoomArtHeight / 2) * s);
}
