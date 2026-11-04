import 'package:flutter/material.dart';

import 'mission_record.dart';

/// 작은 미션이 나를 키운다는 걸 보여 주는 능력치. 기록 수로만 계산하고 절대 줄지 않는다.
/// (기록을 직접 지우면 그만큼만 빠진다.)
class GrowthStat {
  const GrowthStat({
    required this.missionId,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String missionId;
  final String name;
  final IconData icon;
  final Color color;
}

const List<GrowthStat> kGrowthStats = [
  GrowthStat(
      missionId: 'cleanup',
      name: '정돈력',
      icon: Icons.cleaning_services,
      color: Color(0xFF2E8566)),
  GrowthStat(
      missionId: 'water',
      name: '건강',
      icon: Icons.water_drop,
      color: Color(0xFF3A7BD5)),
  GrowthStat(
      missionId: 'reading',
      name: '집중력',
      icon: Icons.menu_book,
      color: Color(0xFF8A5CD6)),
  GrowthStat(
      missionId: 'walking',
      name: '활력',
      icon: Icons.directions_walk,
      color: Color(0xFFD9822B)),
];

GrowthStat? growthStatFor(String missionId) {
  for (final s in kGrowthStats) {
    if (s.missionId == missionId) return s;
  }
  return null;
}

/// 점수 하나가 어느 레벨인지. 레벨이 오를수록 필요한 점수가 1씩 늘어난다 (3, 4, 5, ...).
/// 처음 레벨업은 미션 3번이면 돼서 금방 성장을 느낄 수 있다.
class GrowthLevel {
  const GrowthLevel(
      {required this.level, required this.inLevel, required this.needed});

  factory GrowthLevel.of(int points) {
    var level = 1;
    var need = 3;
    var left = points < 0 ? 0 : points;
    while (left >= need) {
      left -= need;
      level++;
      need++;
    }
    return GrowthLevel(level: level, inLevel: left, needed: need);
  }

  final int level;

  /// 이번 레벨에서 모은 점수
  final int inLevel;

  /// 다음 레벨까지 필요한 전체 점수
  final int needed;

  double get progress => needed == 0 ? 0 : inLevel / needed;
}

/// 미션별 완료 횟수
Map<String, int> growthPoints(Iterable<MissionRecord> records) {
  final points = <String, int>{};
  for (final r in records) {
    points[r.missionId] = (points[r.missionId] ?? 0) + 1;
  }
  return points;
}

/// 지금까지 해낸 양을 실제 단위로. 기록이 없으면 빈 목록.
List<String> growthAmounts(Map<String, int> points) {
  final out = <String>[];
  final cleanup = points['cleanup'] ?? 0;
  final water = points['water'] ?? 0;
  final reading = points['reading'] ?? 0;
  final walking = points['walking'] ?? 0;
  if (water > 0) out.add('물 $water잔');
  if (reading > 0) {
    final pages = reading * 10;
    final books = pages / 200;
    out.add(books >= 1
        ? '책 $pages쪽 (얇은 책 ${_trim(books)}권)'
        : '책 $pages쪽');
  }
  if (walking > 0) out.add('걷기 ${_minutes(walking * 10)}');
  if (cleanup > 0) out.add('정리 ${_minutes(cleanup * 5)}');
  return out;
}

String _minutes(int m) {
  if (m < 60) return '$m분';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h시간' : '$h시간 $rest분';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// 마지막으로 기록한 날부터 오늘까지 비운 날 수. 기록이 없거나 오늘 했으면 0.
int daysAway(Iterable<MissionRecord> records, DateTime today) {
  DateTime? last;
  for (final r in records) {
    final t = r.completedAt;
    final d = DateTime(t.year, t.month, t.day);
    if (last == null || d.isAfter(last)) last = d;
  }
  if (last == null) return 0;
  final gap = DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(last.year, last.month, last.day))
          .inDays -
      1;
  return gap < 0 ? 0 : gap;
}
