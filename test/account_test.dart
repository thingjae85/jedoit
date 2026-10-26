import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeoduit/app.dart';
import 'package:jeoduit/models/mission_record.dart';
import 'package:jeoduit/services/account_service.dart';
import 'package:jeoduit/services/draft_store.dart';
import 'package:jeoduit/services/session_storage/session_storage_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

MissionRecord _record(String id) => MissionRecord(
      id: id,
      missionId: 'water',
      startedAt: DateTime(2026, 10, 25, 9),
      completedAt: DateTime(2026, 10, 25, 9, 1),
      memo: '물 한 잔',
    );

class _UrlStorage extends SessionStorage {
  _UrlStorage(this.query);
  final Map<String, String> query;
  @override
  String? queryParameter(String name) => query[name];
}

/// 서버 대신 메모리에 올리는 가짜 계정.
class _FakeAccount extends AccountService {
  _FakeAccount(this.drafts);
  final DraftStore drafts;
  final uploaded = <String>{};
  bool _signedIn = false;

  @override
  bool get signedIn => _signedIn;
  @override
  String? get email => _signedIn ? 'me@example.com' : null;

  @override
  Future<void> signInWithGoogle() async {
    _signedIn = true;
    await syncDrafts();
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    notifyListeners();
  }

  @override
  Future<bool> saveRecord(MissionRecord record) async {
    if (!_signedIn) {
      drafts.addDraft(record);
      return false;
    }
    uploaded.add(record.id);
    return true;
  }

  @override
  Future<int> syncDrafts() async {
    var count = 0;
    for (final r in drafts.pendingDrafts()) {
      uploaded.add(r.id); // 같은 ID는 한 번만 저장된다
      drafts.removeDraft(r.id);
      count++;
    }
    return count;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('초안은 30분 동안 남고 그 뒤에는 버려진다', () {
    var now = DateTime(2026, 10, 25, 9);
    final store = DraftStore(storage: SessionStorage(), clock: () => now);
    store.addDraft(_record('a'));
    now = now.add(const Duration(minutes: 29));
    expect(store.pendingDrafts().map((r) => r.id), ['a']);
    now = now.add(const Duration(minutes: 2));
    expect(store.pendingDrafts(), isEmpty);
  });

  test('초안 하나를 지우면 나머지는 남는다', () {
    final store = DraftStore(storage: SessionStorage());
    store.addDraft(_record('a'));
    store.addDraft(_record('b'));
    store.removeDraft('a');
    expect(store.pendingDrafts().map((r) => r.id), ['b']);
  });

  test('주소의 invite 값만 초대 코드로 보관하고 형식이 틀리면 무시한다', () {
    final ok = DraftStore(storage: _UrlStorage({'invite': 'abcd2345', 'code': 'oauth'}));
    ok.captureInviteFromUrl();
    expect(ok.invite, 'ABCD2345');

    final bad = DraftStore(storage: _UrlStorage({'invite': '<script>'}));
    bad.captureInviteFromUrl();
    expect(bad.invite, isNull);
  });

  testWidgets('로그인 전 기록은 초안으로 보관되고 로그인하면 계정에 올라간다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final drafts = DraftStore(storage: SessionStorage());
    final account = _FakeAccount(drafts);
    await tester.pumpWidget(JeoduitApp(account: account));
    await tester.pumpAndSettle();

    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실제로 했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('30분 안에 로그인하면'), findsOneWidget);
    expect(drafts.pendingDrafts(), hasLength(1));
    expect(account.uploaded, isEmpty);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google로 로그인'));
    await tester.pumpAndSettle();
    expect(account.uploaded, hasLength(1));
    expect(drafts.pendingDrafts(), isEmpty);
    expect(find.textContaining('me@example.com'), findsOneWidget);
  });
}
