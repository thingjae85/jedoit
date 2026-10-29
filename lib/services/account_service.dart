import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mission_record.dart';
import 'draft_store.dart';

/// 로그인 상태와 서버 저장을 다룬다. 테스트에서는 가짜 구현으로 바꿔 끼운다.
abstract class AccountService extends ChangeNotifier {
  bool get signedIn;
  String? get email;

  /// 회원가입 없이 들어온 게스트(테스트용 익명 계정)인지.
  bool get isGuest;
  Future<void> signInWithGoogle();

  /// 회원가입 없이 바로 참여한다. 같은 브라우저에서만 이어서 쓸 수 있다.
  Future<void> signInAsGuest();
  Future<void> signOut();

  /// 체험 기록을 서버에 올린다. 로그인 전이면 초안으로 보관하고 false를 반환한다.
  Future<bool> saveRecord(MissionRecord record);

  /// 로그인 직후 보관된 초안을 서버에 올린다. 올린 개수를 반환한다.
  Future<int> syncDrafts();

  /// 계정 삭제를 접수하고 처리 예정일(접수 후 7일 이내)을 반환한다.
  Future<DateTime> requestDeletion();
}

class SupabaseAccountService extends AccountService {
  SupabaseAccountService({required this.drafts}) {
    _sub = _auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.signedIn) {
        try {
          await syncDrafts();
        } catch (_) {
          // 초안은 남아 있으므로 다음 로그인·저장 때 다시 시도한다.
        }
      }
      notifyListeners();
    });
  }

  final DraftStore drafts;
  late final StreamSubscription<AuthState> _sub;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  bool get signedIn => _auth.currentSession != null;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  @override
  Future<void> signInAsGuest() => _auth.signInAnonymously();

  @override
  Future<void> signInWithGoogle() async {
    // 웹에서는 같은 탭이 Google로 이동했다가 현재 주소로 돌아온다.
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.removeFragment().toString() : null,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<bool> saveRecord(MissionRecord record) async {
    if (!signedIn) {
      drafts.addDraft(record);
      return false;
    }
    await _upload(record);
    return true;
  }

  @override
  Future<int> syncDrafts() async {
    if (!signedIn) return 0;
    var count = 0;
    for (final record in drafts.pendingDrafts()) {
      await _upload(record);
      drafts.removeDraft(record.id); // 서버 저장 성공 후에만 지운다.
      count++;
    }
    return count;
  }

  @override
  Future<DateTime> requestDeletion() async {
    final due = await Supabase.instance.client.rpc('request_account_deletion') as String;
    await signOut();
    return DateTime.parse(due);
  }

  Future<void> _upload(MissionRecord record) {
    return Supabase.instance.client.rpc('save_personal_record', params: {
      'p_draft_id': record.id,
      'p_mission': record.missionId,
      'p_completed_at': record.completedAt.toUtc().toIso8601String(),
      'p_memo': record.memo,
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
