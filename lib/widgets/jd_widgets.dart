import 'package:flutter/material.dart';

import '../models/mission_record.dart';
import '../theme.dart';

/// 기기 시간 기준 날짜(시각 제거).
DateTime dayOf(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 날짜별 기록. 키는 [dayOf] 값이다.
Map<DateTime, List<MissionRecord>> recordsByDay(Iterable<MissionRecord> records) {
  final map = <DateTime, List<MissionRecord>>{};
  for (final r in records) {
    map.putIfAbsent(dayOf(r.completedAt), () => []).add(r);
  }
  return map;
}

/// "● 혼자 미션"처럼 색 점이 붙은 분류 이름표.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, required this.dot, required this.background, required this.foreground});

  const CategoryChip.solo({super.key, required this.label})
      : dot = JdColors.solo,
        background = JdColors.soloTint,
        foreground = JdColors.soloText;

  const CategoryChip.together({super.key, required this.label})
      : dot = JdColors.togetherFill,
        background = JdColors.togetherChip,
        foreground = JdColors.togetherText;

  final String label;
  final Color dot;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: foreground)),
        ],
      ),
    );
  }
}

/// 둥근 네모 체크 표시(누르는 동작 없음).
class CheckSquare extends StatelessWidget {
  const CheckSquare({super.key, required this.checked, this.color = JdColors.solo, this.size = 24});

  final bool checked;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? color : Colors.white,
        borderRadius: BorderRadius.circular(size / 3),
        border: checked ? null : Border.all(color: JdColors.box, width: 2),
      ),
      child: checked ? Icon(Icons.check_rounded, size: size * 0.7, color: Colors.white) : null,
    );
  }
}

/// 달력의 날짜 칸. 완료 개수에 따라 색이 진해지고, 다 하면 체크가 된다.
class DayBlob extends StatelessWidget {
  const DayBlob({
    super.key,
    required this.count,
    this.full = false,
    this.today = false,
    this.future = false,
    this.selected = false,
    this.size = 36,
  });

  final int count;

  /// 오늘 할 미션을 모두 마친 날.
  final bool full;
  final bool today;
  final bool future;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    Color fg = JdColors.soloText;
    if (future || count == 0) {
      bg = today ? Colors.white : JdColors.empty;
    } else if (full) {
      bg = JdColors.solo;
      fg = Colors.white;
    } else {
      bg = count >= 2 ? JdColors.soloMid : JdColors.soloTint;
    }
    final outlined = today || selected;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.36),
        border: outlined ? Border.all(color: JdColors.ink, width: 2) : null,
      ),
      child: full && !future
          ? Icon(Icons.check_rounded, size: size * 0.55, color: fg)
          : count > 0 && !future
              ? Text('$count', style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: fg))
              : null,
    );
  }
}

/// 이름 첫 글자를 넣은 친구 동그라미.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.name, required this.index, this.ring, this.size = 52});

  final String name;
  final int index;
  final Color? ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring ?? const Color(0xFFE4E6E9), width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: JdColors.avatars[index % JdColors.avatars.length],
        child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700, color: JdColors.ink)),
      ),
    );
  }
}

/// 공동 책상 요소 칸. 정리된 요소만큼 채운다.
class ElementBar extends StatelessWidget {
  const ElementBar({super.key, required this.earned, required this.total, this.goal, this.height = 22});

  final int earned;
  final int total;

  /// 목표 칸은 진한 테두리로 표시한다.
  final int? goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i < earned ? JdColors.togetherFill : Colors.white,
                borderRadius: BorderRadius.circular(height < 10 ? height / 2 : 6),
                border: i < earned
                    ? null
                    : Border.all(
                        color: goal != null && i == goal! - 1 ? JdColors.together : JdColors.togetherEmpty,
                        width: 2,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
