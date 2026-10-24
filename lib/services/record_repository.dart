import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_record.dart';

/// 개인 기록 저장소 인터페이스.
/// 1주차는 기기·브라우저 로컬 저장, 3주차 이후 서버(Supabase) 구현으로 교체한다.
abstract class RecordRepository {
  /// 최신 완료 순으로 반환한다.
  Future<List<MissionRecord>> loadAll();
  Future<void> add(MissionRecord record);
  Future<void> delete(String id);
  Future<void> deleteAll();
}

/// SharedPreferences 기반 로컬 저장.
/// Android는 앱 내부 저장소, 웹은 브라우저 localStorage에 저장된다.
class LocalRecordRepository implements RecordRepository {
  static const storageKey = 'jeoduit.records.v1';

  @override
  Future<List<MissionRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded;
    try {
      final value = jsonDecode(raw);
      if (value is! List) return [];
      decoded = value;
    } catch (_) {
      return []; // 저장값이 깨졌어도 앱이 멈추지 않게 한다.
    }

    final records = <MissionRecord>[];
    for (final item in decoded) {
      try {
        records.add(MissionRecord.fromJson(item as Map<String, dynamic>));
      } catch (_) {
        // 형식이 맞지 않는 기록 하나만 건너뛴다.
      }
    }
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return records;
  }

  @override
  Future<void> add(MissionRecord record) async {
    final records = await loadAll();
    records.add(record);
    await _save(records);
  }

  @override
  Future<void> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await _save(records);
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(storageKey)) {
      throw StateError('기록을 삭제하지 못했습니다.');
    }
  }

  Future<void> _save(List<MissionRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    if (!await prefs.setString(storageKey, encoded)) {
      throw StateError('기록을 저장하지 못했습니다.');
    }
  }
}
