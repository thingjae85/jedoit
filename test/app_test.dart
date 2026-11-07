import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeoduit/app.dart';
import 'package:jeoduit/models/mission.dart';
import 'package:jeoduit/models/mission_record.dart';
import 'package:jeoduit/services/record_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

MissionRecord _record(String id, String missionId, DateTime completedAt,
    {String memo = ''}) {
  return MissionRecord(
    id: id,
    missionId: missionId,
    startedAt: completedAt.subtract(const Duration(minutes: 5)),
    completedAt: completedAt,
    memo: memo,
  );
}

/// 날마다 바뀌는 기본 미션 대신 테스트에서 쓰는 고정 미션.
List<Mission> _fixed(DateTime _) => [missionById('water')!, missionById('cleanup')!, kDiscoveryMission];

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // 1
  test('기본 미션: 예전 4개 id는 그대로이고 정리 미션만 챌린지 전환 대상이다', () {
    expect(kMissions.take(4).map((m) => m.id), ['cleanup', 'water', 'reading', 'walking']);
    expect(kMissions.first.timerMinutes, 5);
    expect(kMissions.where((m) => m.challengeReady).map((m) => m.id), ['cleanup']);
    expect(kMissions.map((m) => m.id).toSet().length, kMissions.length);
    expect(missionById('water')?.title, '물 한 잔 마시기');
    expect(missionById('discovery'), kDiscoveryMission);
    expect(missionById('custom:1'), isNull);
    expect(missionById('없는-미션'), isNull);
  });

  test('홈 기본 미션은 날마다 몸·마음 하나, 공간 하나, 오늘의 발견', () {
    final seen = <String>{};
    for (var d = 0; d < 14; d++) {
      final day = DateTime(2026, 11, 1 + d);
      final daily = dailyMissions(day);
      expect(daily.map((m) => m.kind), [MissionKind.care, MissionKind.space, MissionKind.discovery]);
      expect(dailyMissions(day).map((m) => m.id), daily.map((m) => m.id), reason: '같은 날은 같은 미션');
      seen.addAll(daily.map((m) => m.id));
    }
    expect(seen.length, greaterThan(6), reason: '날마다 돌아가며 나온다');
  });

  test('오늘의 발견: 다른 걸로 바꾸면 다른 주제가 나온다', () {
    for (var d = 0; d < 30; d++) {
      final day = DateTime(2026, 11, 1 + d);
      expect(discoveryThemeFor(day, rerolled: true).id, isNot(discoveryThemeFor(day).id));
    }
  });

  test('기록 이름: 기본 미션, 오늘의 발견 주제, 직접 만든 미션', () {
    final now = DateTime(2026, 11, 5);
    expect(recordTitle(_record('a', 'water', now)), '물 한 잔 마시기');
    expect(
        recordTitle(MissionRecord(id: 'b', missionId: 'discovery', startedAt: now, completedAt: now, theme: 'green')),
        '오늘의 발견 · 초록색');
    expect(
        recordTitle(MissionRecord(id: 'c', missionId: 'custom:1', startedAt: now, completedAt: now, title: '영양제 먹기')),
        '영양제 먹기');
  });

  // 2
  test('MissionRecord는 JSON으로 저장·복원해도 같은 값이다', () {
    final original = _record('r1', 'cleanup', DateTime(2026, 10, 13, 21, 30),
        memo: '책상 왼쪽 정리');
    final restored = MissionRecord.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.missionId, original.missionId);
    expect(restored.startedAt, original.startedAt);
    expect(restored.completedAt, original.completedAt);
    expect(restored.memo, original.memo);

    final withPhoto = MissionRecord(
        id: 'p', missionId: 'discovery', startedAt: original.startedAt, completedAt: original.completedAt,
        theme: 'green', photo: 'AAAA', title: null);
    final back = MissionRecord.fromJson(withPhoto.toJson());
    expect(back.theme, 'green');
    expect(back.photo, 'AAAA');
    expect(back.hasPhoto, isTrue);
    expect(withPhoto.withoutPhoto().photo, isNull);
    expect(withPhoto.withoutPhoto().theme, 'green');
  });

  // 3
  test('저장소: 비어 있으면 빈 목록, 추가하면 최신순이며 새 인스턴스에서도 유지된다', () async {
    final repo = LocalRecordRepository();
    expect(await repo.loadAll(), isEmpty);

    await repo.add(_record('old', 'water', DateTime(2026, 10, 12, 9)));
    await repo.add(_record('new', 'cleanup', DateTime(2026, 10, 14, 9)));

    final loaded = await LocalRecordRepository().loadAll();
    expect(loaded.map((r) => r.id), ['new', 'old']);
  });

  // 4
  test('저장소: 기록 하나 삭제는 그 기록만, 전체 삭제는 모두 지운다', () async {
    final repo = LocalRecordRepository();
    await repo.add(_record('a', 'water', DateTime(2026, 10, 12)));
    await repo.add(_record('b', 'reading', DateTime(2026, 10, 13)));

    await repo.delete('a');
    expect((await repo.loadAll()).map((r) => r.id), ['b']);

    await repo.deleteAll();
    expect(await repo.loadAll(), isEmpty);
  });

  // 5
  test('저장소: 저장값이 깨져 있어도 멈추지 않고 정상 기록만 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      LocalRecordRepository.storageKey: '이건 JSON이 아님',
    });
    expect(await LocalRecordRepository().loadAll(), isEmpty);

    final good = _record('good', 'cleanup', DateTime(2026, 10, 13));
    SharedPreferences.setMockInitialValues({
      LocalRecordRepository.storageKey:
          '[${_encode(good)}, {"id": 1}, "문자열"]',
    });
    final loaded = await LocalRecordRepository().loadAll();
    expect(loaded.map((r) => r.id), ['good']);
  });

  // 6
  testWidgets('홈 화면에 오늘의 미션 3개와 내 공간이 보이고 마이 탭에 로컬 저장 안내가 있다', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();

    for (final m in _fixed(DateTime.now())) {
      expect(find.text(m.title), findsOneWidget);
    }
    expect(find.text('하나만 해도 충분해요'), findsOneWidget);
    expect(find.text('방1'), findsOneWidget);
    expect(find.text('오늘 0번 완료'), findsOneWidget);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이 기기·브라우저에만 저장'), findsOneWidget);
  });

  // 7
  testWidgets('정리 미션: 타이머는 원할 때만, 메모 남기고 했어요로 저장', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();

    await tester.tap(find.text('책상 한 구역 정리'));
    await tester.pumpAndSettle();

    // 타이머를 켜지 않아도 바로 완료할 수 있다.
    final doneFinder = find.widgetWithText(FilledButton, '했어요');
    expect(tester.widget<FilledButton>(doneFinder).onPressed, isNotNull);

    await tester.tap(find.text('타이머 켜기 (5분)'));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:59'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '왼쪽 서랍 정리');
    await tester.pump();

    await tester.tap(doneFinder);
    await tester.pumpAndSettle();
    // 첫 미션이면 꾸미기가 열렸다고 알려 준다.
    expect(find.text('꾸미기가 열렸어요!'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    final saved = await repo.loadAll();
    expect(saved.length, 1);
    expect(saved.first.missionId, 'cleanup');
    expect(saved.first.memo, '왼쪽 서랍 정리');
    expect(saved.first.photo, isNull);
    expect(find.textContaining('기록을 이 기기에 저장했어요'), findsOneWidget);
    expect(find.textContaining('+10 코인'), findsOneWidget);
    expect(find.text('오늘 1번 완료'), findsOneWidget);
    // 첫 미션이면 침실 상자를 치우고 꾸미기가 열린다.
    expect(find.textContaining('상자를 치웠어요'), findsOneWidget);

  });

  // 8
  testWidgets('기록 삭제는 확인창을 거치며 취소하면 남고 삭제하면 지워진다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    await repo.add(_record('a', 'water', now));
    await repo.add(_record('b', 'cleanup', now, memo: '정리함'));

    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    // 기록 탭은 오늘 날짜가 선택된 달력으로 열린다.
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // 취소하면 그대로 남는다.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('이 기록을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // 삭제를 확인하면 지워진다.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect((await repo.loadAll()).length, 1);
  });

  testWidgets('홈의 이번 주 날짜를 누르면 그날 기록이 골라진 달력이 열린다', (tester) async {
    _useTallScreen(tester);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1), 9);
    final repo = LocalRecordRepository();
    await repo.add(_record('mon', 'reading', monday, memo: '월요일 독서'));

    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    // 위쪽 코인 숫자와 겹칠 수 있어 아래쪽 이번 주 줄의 날짜를 누른다.
    await tester.tap(find.text('${monday.day}').last);
    await tester.pumpAndSettle();
    expect(find.text('내 기록'), findsOneWidget);
    expect(find.text('월요일 독서'), findsOneWidget);
  });

  testWidgets('기록 달력은 고른 날의 기록만 보여 주고 달을 넘길 수 있다', (tester) async {
    _useTallScreen(tester);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15, 9);
    final repo = LocalRecordRepository();
    await repo.add(_record('old', 'reading', lastMonth, memo: '지난달 기록'));
    await repo.add(_record('new', 'water', now));

    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year}년 ${now.month}월'), findsWidgets);
    expect(find.text('물 한 잔 마시기'), findsOneWidget);
    expect(find.text('지난달 기록'), findsNothing);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('${lastMonth.year}년 ${lastMonth.month}월'), findsOneWidget);
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();
    expect(find.text('지난달 기록'), findsOneWidget);
  });
  testWidgets('오늘 집계는 어제 기록을 제외하고 같은 미션의 반복도 센다', (tester) async {
    _useTallScreen(tester);
    final now = DateTime.now();
    final repo = LocalRecordRepository();
    await repo.add(_record('yesterday', 'cleanup', DateTime(now.year, now.month, now.day).subtract(const Duration(minutes: 1))));
    await repo.add(_record('today1', 'water', now));
    await repo.add(_record('today2', 'water', now));
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    expect(find.text('오늘 2번 완료'), findsOneWidget);
    expect(find.text('전체 기록 3개 보기'), findsOneWidget);
    expect(find.textContaining('오늘 완료했어요'), findsOneWidget);
  });

  testWidgets('좁은 휴대폰 화면에서도 홈과 미션을 사용할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository(), missionsFor: _fixed));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('책상 한 구역 정리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('타이머 켜기 (5분)'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('홈 기록 불러오기에 실패하면 다시 시도할 수 있다', (tester) async {
    _useTallScreen(tester);
    final repo = _FailingRepository();
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 0번 완료'), findsOneWidget);
  });

  testWidgets('저장에 실패하면 메모를 유지하고 재시도할 수 있다', (tester) async {
    _useTallScreen(tester);
    final repo = _FailingRepository()..failLoad = false;
    await tester.pumpWidget(JeoduitApp(repository: repo, missionsFor: _fixed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '아침에 실천');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '했어요'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했어요. 잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('아침에 실천'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '했어요')).onPressed, isNotNull);
  });
}

class _FailingRepository implements RecordRepository {
  bool failLoad = true;
  @override
  Future<List<MissionRecord>> loadAll() async {
    if (failLoad) throw StateError('test read failure');
    return [];
  }
  @override
  Future<void> add(MissionRecord record) async => throw StateError('test write failure');
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteAll() async {}
}

String _encode(MissionRecord r) {
  final j = r.toJson();
  return '{"id":"${j['id']}","missionId":"${j['missionId']}",'
      '"startedAt":"${j['startedAt']}","completedAt":"${j['completedAt']}",'
      '"memo":"${j['memo']}"}';
}
