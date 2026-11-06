import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jeoduit/app.dart';
import 'package:jeoduit/models/decor.dart';
import 'package:jeoduit/models/layout.dart';
import 'package:jeoduit/models/mission.dart';
import 'package:jeoduit/models/mission_record.dart';
import 'package:jeoduit/models/return_days.dart';
import 'package:jeoduit/models/space.dart';
import 'package:jeoduit/models/space_art.dart';
import 'package:jeoduit/services/record_repository.dart';
import 'package:jeoduit/services/space_store.dart';
import 'package:jeoduit/utils/photo.dart';
import 'package:jeoduit/widgets/space_view.dart';
import 'package:jeoduit/widgets/pixel_ui.dart';
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
      expect(art.shells.length, art.stages, reason: room.id);
      for (final f in art.furniture) {
        expect(f.unlock, lessThan(art.stages), reason: f.id);
      }
    }
  });

  test('처음 자리의 가구들은 서로 겹치지 않고 방 안에 있다', () {
    for (final room in kSpaceRooms) {
      final last = room.stages - 1;
      final things = thingsIn(room.id, last, const DecorData());
      for (final t in things) {
        expect(fits(room.id, last, things, t, t.a, t.b), isTrue, reason: '${room.id} ${t.id}');
      }
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
    final s = SpaceState.of(7); // 7번째에 방2가 자란다
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

  test('꾸미기: 코인이 있어야 사고, 아무 칸에나 놓고, 다른 방으로 옮기고, 치우면 보관함으로', () {
    shopIsFree = false;
    addTearDown(() => shopIsFree = true);
    final clock = decorById('clock')!;
    final lamp = decorById('moodlamp')!;
    final cactus = decorById('cactus')!;

    var d = const DecorData();
    expect(d.buy(lamp, 30), same(d), reason: '40코인짜리는 30코인으로 못 산다');
    d = d.buy(clock, 100).buy(lamp, 100);
    expect(d.spent, 60);
    expect(d.available(100), 40);
    expect(d.buy(clock, 100), same(d), reason: '이미 있는 건 다시 안 산다');
    expect(d.placeDecor('cactus', 'bedroom', 1, 1), same(d), reason: '안 산 건 놓을 수 없다');
    expect(d.buy(cactus, 100).spent, 90);

    d = d.placeDecor('moodlamp', 'bedroom', 20, 22);
    expect(d.layoutOf('bedroom').decor['moodlamp'], (20, 22));
    d = d.placeDecor('moodlamp', 'study', 5, 30);
    expect(d.roomOf('moodlamp'), 'study', reason: '다른 방으로 옮긴다');
    expect(d.layoutOf('bedroom').decor.containsKey('moodlamp'), isFalse);
    d = d.removeDecor('moodlamp');
    expect(d.roomOf('moodlamp'), isNull);
    expect(d.owned, contains('moodlamp'));

    d = d.moveFurniture('bedroom', 'bed', 25, 2).storeFurniture('bedroom', 'rug');
    expect(d.layoutOf('bedroom').furniture['bed'], (25, 2));
    expect(d.layoutOf('bedroom').stored, {'rug'});
    d = d.moveFurniture('bedroom', 'rug', 3, 3);
    expect(d.layoutOf('bedroom').stored, isEmpty, reason: '옮기면 보관함에서 나온다');

    d = d.placeDecor('clock', 'bedroom', 20, 10).moveBuddy('bedroom', 12, 30);
    final back = DecorData.fromJson(d.toJson());
    expect(back.layoutOf('bedroom').buddy, (12, 30));
    expect(back.layoutOf('study').buddy, isNull);
    expect(back.owned, d.owned);
    expect(back.spent, d.spent);
    expect(back.layoutOf('bedroom').furniture, d.layoutOf('bedroom').furniture);
    expect(back.layoutOf('bedroom').decor, {'clock': (20, 10)});
    final broken = DecorData.fromJson({
      'owned': ['없는것', 'clock'],
      'layouts': {
        'bedroom': {'f': {'bed': 'x'}, 'd': {'없는것': [1, 2], 'clock': [3, 4]}}
      },
      'spent': -5,
    });
    expect(broken.spent, 0);
    expect(broken.owned, {'clock'});
    expect(broken.layoutOf('bedroom').decor, {'clock': (3, 4)});
    expect(broken.layoutOf('bedroom').furniture, isEmpty);
  });

  test('자리 검사: 방 밖이나 다른 가구와 겹치면 안 되고, 러그 위에는 올릴 수 있다', () {
    const stage = 10;
    final things = thingsIn('bedroom', stage, const DecorData());
    final bed = things.firstWhere((t) => t.id == 'bed');
    expect(fits('bedroom', stage, things, bed, -1, 14), isFalse);
    expect(fits('bedroom', stage, things, bed, 35, 14), isFalse, reason: '오른쪽 벽 밖');
    expect(fits('bedroom', stage, things, bed, 12, 0), isFalse, reason: '책상과 겹친다');

    final lamp = decorThing('moodlamp', 0, 0)!;
    final rug = things.firstWhere((t) => t.id == 'rug');
    expect(fits('bedroom', stage, things, lamp, rug.a + 2, rug.b + 2), isTrue, reason: '러그 위');
    expect(freeSpot('bedroom', stage, things, lamp), isNotNull);

    final clock = decorThing('clock', 0, 0)!;
    expect(fits('bedroom', stage, things, clock, 10, 24), isFalse, reason: '수납장 자리');
    expect(fits('bedroom', stage, things, clock, 24, 12), isTrue);
    expect(fits('bedroom', 6, thingsIn('bedroom', 6, const DecorData()), clock, 10, 24), isTrue,
        reason: '수납장이 생기기 전');
  });

  test('앞뒤 순서: 화면 아래(앞)에 있는 것이 나중에 그려진다', () {
    const back = FloorBox(0, 0, 5, 5);
    const front = FloorBox(10, 10, 3, 3);
    const right = FloorBox(10, 0, 4, 4); // 뒤쪽과 x로 떨어짐
    final order = paintOrder([front, back, right]);
    expect(order.indexOf(1), lessThan(order.indexOf(0)));
    expect(order.indexOf(1), lessThan(order.indexOf(2)));
    expect(order.indexOf(2), lessThan(order.indexOf(0)), reason: 'right는 front보다 y가 작다');
    // 긴 침대 옆 작은 물건: 침대 오른쪽(x가 큼)에 붙은 물건이 앞
    const bed = FloorBox(0, 14, 10, 17);
    const box = FloorBox(10, 14, 3, 3);
    expect(paintOrder([box, bed]), [1, 0]);
  });

  test('캐릭터는 막힌 자리를 피해 가까운 빈 칸에 선다', () {
    final things = thingsIn('bedroom', 10, const DecorData());
    final spot = buddySpot('bedroom', things);
    for (final t in things) {
      if (!t.wall && !t.flat) {
        expect(t.overlaps(spot.$1 - 1, spot.$2 - 1, 3, 2), isFalse, reason: t.id);
      }
    }
    expect(buddySpot('bedroom', things, prefer: (30, 22)), (30, 22), reason: '옮겨 둔 자리에 선다');
    final blocked = thingsIn('bedroom', 10, const DecorData().moveFurniture('bedroom', 'chair', 19, 24));
    final moved = buddySpot('bedroom', blocked);
    expect(moved, isNot((20, 25)));
  });

  test('침실은 상자를 풀고 나서(2단계)부터 꾸밀 수 있다', () {
    expect(canDecorate('bedroom', 1), isFalse);
    expect(canDecorate('bedroom', 2), isTrue);
    expect(canDecorate('study', 0), isTrue);
    expect(thingsIn('bedroom', 1, const DecorData()), isEmpty, reason: '상자 단계엔 옮길 가구가 없다');
  });

  testWidgets('꾸미기에서 코인으로 소품을 사면 방에 놓이고 남은 코인이 줄어든다', (tester) async {
    shopIsFree = false;
    addTearDown(() => shopIsFree = true);
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
    await tester.tap(find.text('벽 장식'));
    await tester.pumpAndSettle();
    final buyClock = find.descendant(of: find.byKey(const ValueKey('shop-clock')), matching: find.text('사기'));
    await tester.tap(buyClock);
    await tester.pumpAndSettle();
    expect(find.text('코인 10'), findsOneWidget);
    // 산 소품은 바로 빈 자리에 놓이고 골라진 상태가 된다.
    expect(find.text('벽시계'), findsOneWidget);
    final placed = (await SpaceStore().load()).decor.layoutOf('bedroom').decor['clock'];
    expect(placed, isNotNull);

    // 손가락으로 집어서 위로 끌면 그만큼 올라간다 (벽에서 한 칸 = 세로 2 도트 픽셀).
    final room = find.byType(RoomPicture);
    final origin = tester.getTopLeft(room);
    final s = tester.getSize(room).width / kRoomArtWidth;
    final (l, top, w, h) = decorThing('clock', placed!.$1, placed.$2)!.rect();
    final grab = origin + Offset((l + w / 2) * s, (top + h / 2) * s);
    await tester.dragFrom(grab, Offset(0, -10 * s));
    await tester.pumpAndSettle();
    expect((await SpaceStore().load()).decor.layoutOf('bedroom').decor['clock'], (placed.$1, placed.$2 + 5));

    // 캐릭터도 끌어서 옮긴다 (바닥에서 오른쪽 아래로 = x+).
    final (bx, by) = buddySpot('bedroom', thingsIn('bedroom', 3, (await SpaceStore().load()).decor));
    final (bl, bt, bw, bh) = buddyRect(bx, by);
    await tester.dragFrom(origin + Offset((bl + bw / 2) * s, (bt + bh / 2) * s), Offset(16 * s, 8 * s));
    await tester.pumpAndSettle();
    expect((await SpaceStore().load()).decor.layoutOf('bedroom').buddy, (bx + 8, by));

    // 시계를 다시 눌러 고르고, 보관함에 넣었다가 다시 놓기
    final (l2, top2, w2, h2) = decorThing('clock', placed.$1, placed.$2 + 5)!.rect();
    await tester.tapAt(origin + Offset((l2 + w2 / 2) * s, (top2 + h2 / 2) * s));
    await tester.pumpAndSettle();
    expect(find.text('벽시계'), findsOneWidget);
    await tester.tap(find.text('보관함에'));
    await tester.pumpAndSettle();
    expect((await SpaceStore().load()).decor.roomOf('clock'), isNull);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('stored-d:clock')), matching: find.text('놓기')));
    await tester.pumpAndSettle();
    expect((await SpaceStore().load()).decor.roomOf('clock'), 'bedroom');
    // 40코인짜리 무드등은 못 산다 (가구 탭).
    await tester.tap(find.text('가구'));
    await tester.pumpAndSettle();
    final lampButton = find.ancestor(
        of: find.descendant(of: find.byKey(const ValueKey('shop-moodlamp')), matching: find.text('사기')),
        matching: find.byType(GameButton));
    expect(tester.widget<GameButton>(lampButton).onTap, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('coins'))).data, '10');
    expect((await SpaceStore().load()).decor.roomOf('clock'), 'bedroom');
  });

  testWidgets('홈에는 내 공간과 미션만 있고 친구 챌린지는 챌린지 탭에 따로 있다', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();

    expect(find.text('방1'), findsOneWidget);
    expect(find.text('하나만 해도 충분해요'), findsOneWidget);
    expect(find.text('친구와 챌린지'), findsNothing);

    await tester.tap(find.text('챌린지'));
    await tester.pumpAndSettle();
    expect(find.text('친구와 챌린지'), findsOneWidget);
    expect(find.text('방1'), findsNothing);
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
    expect(find.text('방2'), findsOneWidget);

    await tester.tap(find.byTooltip('벌집 보기'));
    await tester.pumpAndSettle();
    expect(find.text('내 공간'), findsOneWidget);
    expect(find.text('문 너머에 뭔가 있어요'), findsOneWidget);

    // 아래 가운데 칸(침실)을 누른다.
    await tester.tapAt(_bottomCell(tester));
    await tester.pumpAndSettle();
    expect(find.text('방1'), findsOneWidget);
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

  test('벽지·바닥: 사서 방마다 바르고, 저장했다 다시 읽어도 그대로다', () {
    final mint = kWallpapers.firstWhere((w) => w.id == 'mint');
    final tile = kFloors.firstWhere((f) => f.id == 'tile');
    expect(mint.price, 0, reason: '시험 기간에는 0코인');
    var d = const DecorData();
    expect(d.applySurface('bedroom', mint), same(d), reason: '안 산 건 못 바른다');
    d = d.buySurface(mint, 0).applySurface('bedroom', mint).buySurface(tile, 0).applySurface('study', tile);
    expect(d.layoutOf('bedroom').wallKey, 'wall_mint');
    expect(d.layoutOf('bedroom').floorKey, 'floor_basic');
    expect(d.layoutOf('study').floorKey, 'floor_tile');
    d = d.applySurface('bedroom', kWallpapers.first);
    expect(d.layoutOf('bedroom').wallKey, 'wall_basic', reason: '처음 벽지는 언제든 다시 바를 수 있다');
    d = d.applySurface('bedroom', mint);
    final back = DecorData.fromJson(d.toJson());
    expect(back.layoutOf('bedroom').wallKey, 'wall_mint');
    expect(back.layoutOf('study').floorKey, 'floor_tile');
    expect(back.owned, containsAll(['wall_mint', 'floor_tile']));
    final broken = DecorData.fromJson({
      'owned': ['wall_없는것'],
      'layouts': {
        'bedroom': {'w': 'wall_rose', 'fl': 'floor_없는것'}
      },
    });
    expect(broken.layoutOf('bedroom').wallKey, 'wall_basic', reason: '안 산 벽지는 버린다');
    expect(broken.layoutOf('bedroom').floorKey, 'floor_basic');
    for (final room in kSpaceRooms) {
      for (final s in [...kWallpapers, ...kFloors]) {
        expect(kRoomArt[room.id]!.surfaces[s.key], isNotNull, reason: '${room.id} ${s.key} 그림');
      }
    }
  });

  test('방 이름: 처음엔 방1·방2, 바꾸면 저장되고 비우면 처음 이름으로', () {
    var d = const DecorData();
    expect(d.roomName('bedroom'), '방1');
    expect(d.roomName('study'), '방2');
    d = d.rename('bedroom', '  내 작업실  ');
    expect(d.roomName('bedroom'), '내 작업실');
    expect(DecorData.fromJson(d.toJson()).roomName('bedroom'), '내 작업실');
    expect(d.rename('bedroom', '열한글자가넘는아주긴이름').roomName('bedroom').length, roomNameMax);
    expect(d.rename('bedroom', '   ').roomName('bedroom'), '방1');
    expect(subjectParticle('방1'), '이');
    expect(subjectParticle('방2'), '가');
    expect(objectParticle('크림 벽지'), '를');
    expect(objectParticle('벽돌'), '을');
  });

  testWidgets('홈에서 방 이름 옆 연필을 누르면 이름을 바꿀 수 있다', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();
    expect(find.text('방1'), findsOneWidget);
    await tester.tap(find.byType(RoomNameButton));
    await tester.pumpAndSettle();
    expect(find.text('방 이름 바꾸기'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('roomNameField')), '햇살 방');
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('햇살 방'), findsOneWidget);
    expect((await SpaceStore().load()).decor.roomName('bedroom'), '햇살 방');
  });

  testWidgets('꾸미기 탭: 벽지를 0코인에 사서 바르면 방 벽이 바뀌고 캐릭터 탭에서 캐릭터를 고른다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await repo.add(_record('r$i', 'water', now.subtract(Duration(minutes: i))));
    }
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('꾸미기'));
    await tester.pumpAndSettle();
    expect(find.text('벽지·바닥'), findsOneWidget);
    final buyMint = find.descendant(of: find.byKey(const ValueKey('surface-wall_mint')), matching: find.text('사기'));
    await tester.ensureVisible(buyMint);
    await tester.tap(buyMint);
    await tester.pumpAndSettle();
    expect(find.text('코인 30'), findsOneWidget, reason: '시험 기간이라 코인이 그대로');
    expect((await SpaceStore().load()).decor.layoutOf('bedroom').wallKey, 'wall_mint');
    expect(
      find.descendant(of: find.byType(RoomPicture), matching: find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('wall_mint'))),
      findsOneWidget,
    );

    await tester.tap(find.text('캐릭터'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('buddy-hamster')), matching: find.text('함께하기')));
    await tester.pumpAndSettle();
    expect((await SpaceStore().load()).buddy, 'hamster');
  });
}

/// 벌집 그림의 아래 가운데 칸(첫 방) 한가운데 화면 좌표.
Offset _bottomCell(WidgetTester tester) {
  final rect = tester.getRect(find.byType(AspectRatio).first);
  const w = kRoomArtWidth + kHiveDx;
  final s = rect.width / w;
  return rect.topLeft + Offset((kHiveDx / 2 + kRoomArtWidth / 2) * s, (kHiveDy + kRoomArtHeight / 2) * s);
}
