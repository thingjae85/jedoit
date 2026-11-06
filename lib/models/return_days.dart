import 'mission_record.dart';

/// 마지막으로 기록한 날부터 오늘까지 비운 날 수. 기록이 없거나 오늘 했으면 0.
/// 쉬다 돌아온 사람을 탓하지 않고 반겨 줄 때 쓴다.
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
