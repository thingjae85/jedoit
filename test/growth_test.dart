import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeoduit/app.dart';
import 'package:jeoduit/models/growth.dart';
import 'package:jeoduit/models/mission.dart';
import 'package:jeoduit/models/mission_record.dart';
import 'package:jeoduit/services/record_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

MissionRecord _record(String id, String missionId, DateTime completedAt) {
  return MissionRecord(
    id: id,
    missionId: missionId,
    startedAt: completedAt.subtract(const Duration(minutes: 5)),
    completedAt: completedAt,
  );
}

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

  test('미션마다 능력치가 하나씩 있다', () {
    for (final m in kMissions) {
      expect(growthStatFor(m.id), isNotNull, reason: m.id);
    }
  });

  test('레벨은 3, 4, 5... 점씩 모이면 오르고 남은 점수를 보여 준다', () {
    expect(GrowthLevel.of(0).level, 1);
    expect(GrowthLevel.of(2).level, 1);
    expect(GrowthLevel.of(3).level, 2);
    expect(GrowthLevel.of(3).inLevel, 0);
    expect(GrowthLevel.of(3).needed, 4);
    expect(GrowthLevel.of(6).level, 2);
    expect(GrowthLevel.of(7).level, 3);
    expect(GrowthLevel.of(12).level, 4);
    expect(GrowthLevel.of(-1).level, 1);
  });

  test('해낸 양을 실제 단위로 보여 준다', () {
    expect(growthAmounts({}), isEmpty);
    expect(growthAmounts({'water': 3, 'reading': 20, 'walking': 7, 'cleanup': 2}),
        ['물 3잔', '책 200쪽 (얇은 책 1권)', '걷기 1시간 10분', '정리 10분']);
    expect(growthAmounts({'reading': 25}), ['책 250쪽 (얇은 책 1.3권)']);
    expect(growthAmounts({'reading': 4}), ['책 40쪽']);
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

  testWidgets('홈에는 친구 챌린지가 없고 챌린지 탭에 따로 있다', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(JeoduitApp(repository: LocalRecordRepository()));
    await tester.pumpAndSettle();

    expect(find.text('내 능력치'), findsOneWidget);
    expect(find.text('오늘은 하나만 해도 충분해요.'), findsOneWidget);
    expect(find.text('친구와 챌린지'), findsNothing);

    await tester.tap(find.text('챌린지'));
    await tester.pumpAndSettle();
    expect(find.text('친구와 챌린지'), findsOneWidget);
    expect(find.text('내 능력치'), findsNothing);
  });

  testWidgets('며칠 쉬다 오면 반겨 주고 능력치는 그대로다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    final old = DateTime(now.year, now.month, now.day - 5, 10);
    for (var i = 0; i < 3; i++) {
      await repo.add(_record('w$i', 'water', old));
    }
    await tester.pumpWidget(JeoduitApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('다시 와줘서 반가워요'), findsOneWidget);
    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.textContaining('물 3잔'), findsOneWidget);
  });

  testWidgets('미션을 마치면 능력치가 오르고 레벨이 오르면 축하한다', (tester) async {
    _useTallScreen(tester);
    final repo = LocalRecordRepository();
    final now = DateTime.now();
    await repo.add(_record('w1', 'water', now));
    await repo.add(_record('w2', 'water', now));
    await tester.pumpWidget(JeoduitApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '기록 저장'));
    await tester.pumpAndSettle();

    expect(find.text('건강 레벨 2!'), findsOneWidget);
    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('건강 +1'), findsOneWidget);
    expect(find.text('Lv.2'), findsOneWidget);
  });
}
