import 'package:flutter/material.dart';

/// 개인 미션 한 종류. 4개를 기본 목록으로 제공한다.
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.timerMinutes,
    this.challengeReady = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// null이면 타이머 없이 완료 체크·메모만 사용한다.
  final int? timerMinutes;

  /// 지인과 함께하는 3일 챌린지로 전환 가능한 미션인지(1차 범위는 정리만).
  final bool challengeReady;
}

const List<Mission> kMissions = [
  Mission(
    id: 'cleanup',
    title: '책상 한 구역 정리',
    description: '5분 동안 책상 한 구역을 정리해요',
    icon: Icons.cleaning_services,
    timerMinutes: 5,
    challengeReady: true,
  ),
  Mission(
    id: 'water',
    title: '물 한 잔 마시기',
    description: '물 한 잔을 천천히 마셔요',
    icon: Icons.water_drop,
  ),
  Mission(
    id: 'reading',
    title: '책 10페이지 읽기',
    description: '책을 10페이지만 읽어요',
    icon: Icons.menu_book,
  ),
  Mission(
    id: 'walking',
    title: '10분 걷기',
    description: '밖으로 나가 10분만 걸어요',
    icon: Icons.directions_walk,
  ),
];

Mission? missionById(String id) {
  for (final m in kMissions) {
    if (m.id == id) return m;
  }
  return null;
}
