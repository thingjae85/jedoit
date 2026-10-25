import 'dart:convert';

import '../models/mission_record.dart';
import 'session_storage/session_storage.dart';

/// 로그인 전에 끝낸 체험 기록(초안)과 초대 코드를 탭 세션에 잠시 보관한다.
/// 초안은 만든 뒤 30분이 지나면 버린다. 사진·메모는 URL에 넣지 않는다.
class DraftStore {
  DraftStore({SessionStorage? storage, DateTime Function()? clock})
      : _storage = storage ?? SessionStorage(),
        _clock = clock ?? DateTime.now;

  static const draftsKey = 'jeoduit.drafts.v1';
  static const inviteKey = 'jeoduit.invite.v1';
  static const ttl = Duration(minutes: 30);

  final SessionStorage _storage;
  final DateTime Function() _clock;

  /// 아직 서버에 올리지 않은 초안. 만료된 것은 이때 정리한다.
  List<MissionRecord> pendingDrafts() {
    final raw = _storage.read(draftsKey);
    if (raw == null) return [];
    final now = _clock();
    final kept = <Map<String, dynamic>>[];
    final drafts = <MissionRecord>[];
    try {
      for (final item in jsonDecode(raw) as List) {
        final map = item as Map<String, dynamic>;
        final expiresAt = DateTime.parse(map['expiresAt'] as String);
        if (expiresAt.isBefore(now)) continue;
        kept.add(map);
        drafts.add(MissionRecord.fromJson(map['record'] as Map<String, dynamic>));
      }
    } catch (_) {
      _storage.remove(draftsKey);
      return [];
    }
    _writeAll(kept);
    return drafts;
  }

  void addDraft(MissionRecord record) {
    final raw = _storage.read(draftsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        list.addAll((jsonDecode(raw) as List).cast<Map<String, dynamic>>());
      } catch (_) {}
    }
    list.add({
      'record': record.toJson(),
      'expiresAt': _clock().add(ttl).toIso8601String(),
    });
    _writeAll(list);
  }

  void removeDraft(String id) {
    final raw = _storage.read(draftsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .where((m) => (m['record'] as Map<String, dynamic>)['id'] != id)
          .toList();
      _writeAll(list);
    } catch (_) {
      _storage.remove(draftsKey);
    }
  }

  /// 주소의 `?invite=` 값을 보관한다. OAuth의 `code` 파라미터와는 별개다.
  void captureInviteFromUrl() {
    final code = _storage.queryParameter('invite');
    if (code != null && RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(code)) {
      _storage.write(inviteKey, code.toUpperCase());
    }
  }

  String? get invite => _storage.read(inviteKey);
  void clearInvite() => _storage.remove(inviteKey);

  void _writeAll(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      _storage.remove(draftsKey);
    } else {
      _storage.write(draftsKey, jsonEncode(list));
    }
  }
}
