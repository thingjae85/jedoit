import 'package:flutter/material.dart';

import 'mission_record.dart';

/// 미션 종류. 홈에는 매일 몸·마음 하나, 공간 하나, 오늘의 발견 하나가 나온다.
enum MissionKind { care, space, discovery, custom }

/// 혼자 하는 미션 한 종류. 모든 미션은 버튼 하나로 끝낼 수 있고,
/// 사진·메모·타이머는 남기고 싶을 때만 쓰는 기록이다.
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.kind = MissionKind.care,
    this.timerMinutes,
    this.challengeReady = false,
  });

  /// 사용자가 직접 추가한 미션. 날마다 홈에 그대로 나온다.
  factory Mission.custom(String id, String title) => Mission(
        id: id,
        title: title,
        description: '내가 정한 미션이에요',
        icon: Icons.star_outline_rounded,
        kind: MissionKind.custom,
      );

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final MissionKind kind;

  /// null이면 타이머 없이 완료만. 타이머가 있어도 먼저 끝내도 된다.
  final int? timerMinutes;

  /// 지인과 함께하는 3일 챌린지로 전환 가능한 미션인지(1차 범위는 정리만).
  final bool challengeReady;
}

/// 홈에 날마다 나오는 기본 미션 수 (몸·마음, 공간, 오늘의 발견).
const kDailyMissionCount = 3;

/// 사용자가 직접 만든 미션의 id 앞부분.
const customMissionPrefix = 'custom:';

/// 매일 돌아가며 나오는 기본 미션. 앞의 4개는 예전부터 있던 미션이라 id를 바꾸지 않는다.
const List<Mission> kMissions = [
  Mission(
    id: 'cleanup',
    title: '책상 한 구역 정리',
    description: '5분 동안 책상 한 구역만 정리해요',
    icon: Icons.cleaning_services,
    kind: MissionKind.space,
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
    timerMinutes: 10,
  ),
  Mission(
    id: 'stretch',
    title: '기지개 1분',
    description: '자리에서 일어나 쭉 늘려요',
    icon: Icons.accessibility_new,
    timerMinutes: 1,
  ),
  Mission(
    id: 'sunlight',
    title: '햇빛 쬐기',
    description: '창가나 밖에서 5분만 햇빛을 쬐어요',
    icon: Icons.wb_sunny_outlined,
    timerMinutes: 5,
  ),
  Mission(
    id: 'wash',
    title: '세수하기',
    description: '찬물로 얼굴을 한 번 씻어요',
    icon: Icons.face_retouching_natural,
  ),
  Mission(
    id: 'fruit',
    title: '과일 하나 먹기',
    description: '과일이나 채소를 하나 챙겨 먹어요',
    icon: Icons.apple,
  ),
  Mission(
    id: 'bed',
    title: '이불 정리하기',
    description: '이불을 한 번 펴서 정리해요',
    icon: Icons.bed_outlined,
    kind: MissionKind.space,
  ),
  Mission(
    id: 'air',
    title: '창문 열고 환기',
    description: '창문을 열고 3분만 바람을 들여요',
    icon: Icons.air,
    kind: MissionKind.space,
    timerMinutes: 3,
  ),
  Mission(
    id: 'trash',
    title: '쓰레기 하나 버리기',
    description: '눈에 보이는 쓰레기 하나만 버려요',
    icon: Icons.delete_outline,
    kind: MissionKind.space,
  ),
  Mission(
    id: 'dishes',
    title: '컵 하나 씻기',
    description: '쌓인 컵이나 그릇 하나만 씻어요',
    icon: Icons.local_cafe_outlined,
    kind: MissionKind.space,
  ),
];

/// 오늘의 발견. 주제에 맞는 걸 아무거나 찍으면 끝이다. 사진을 검사하지 않는다.
const Mission kDiscoveryMission = Mission(
  id: 'discovery',
  title: '오늘의 발견',
  description: '주제에 맞는 걸 하나 찾아서 찍어 봐요',
  icon: Icons.camera_alt_outlined,
  kind: MissionKind.discovery,
);

/// 오늘의 발견 주제.
class DiscoveryTheme {
  const DiscoveryTheme(this.id, this.title, this.hint);
  final String id;
  final String title;
  final String hint;
}

const List<DiscoveryTheme> kDiscoveryThemes = [
  DiscoveryTheme('green', '초록색', '초록색이 들어간 걸 아무거나 찾아봐요'),
  DiscoveryTheme('yellow', '노란색', '노란색 물건 하나'),
  DiscoveryTheme('blue', '파란색', '파란 게 어디 있을까요'),
  DiscoveryTheme('red', '빨간색', '빨간색을 하나 찾아봐요'),
  DiscoveryTheme('white', '하얀 것', '하얀 걸 하나 찍어 봐요'),
  DiscoveryTheme('pink', '분홍색', '분홍빛이 도는 것'),
  DiscoveryTheme('round', '동그란 것', '동그란 모양을 찾아봐요'),
  DiscoveryTheme('square', '네모난 것', '네모난 걸 하나'),
  DiscoveryTheme('stripe', '줄무늬', '줄무늬가 있는 것'),
  DiscoveryTheme('shiny', '반짝이는 것', '빛을 받아 반짝이는 것'),
  DiscoveryTheme('cup', '컵', '지금 눈에 띄는 컵'),
  DiscoveryTheme('shoes', '신발', '현관에 있는 신발'),
  DiscoveryTheme('plant', '식물', '화분이든 잎사귀든'),
  DiscoveryTheme('outfit', '오늘 입은 옷', '오늘 고른 옷 한 부분'),
  DiscoveryTheme('favorite', '좋아하는 물건', '보면 기분 좋은 물건'),
  DiscoveryTheme('old', '오래된 물건', '오래 함께한 물건'),
  DiscoveryTheme('window', '창밖 풍경', '지금 창밖은 어때요'),
  DiscoveryTheme('desk', '내 책상 위', '책상 위 그대로'),
  DiscoveryTheme('shadow', '그림자', '오늘 본 그림자'),
  DiscoveryTheme('light', '빛이 드는 곳', '빛이 머무는 자리'),
  DiscoveryTheme('cozy', '포근한 것', '만지면 포근한 것'),
  DiscoveryTheme('cute', '귀여운 것', '보고 웃음이 난 것'),
  DiscoveryTheme('quiet', '조용한 것', '조용해 보이는 장면'),
  DiscoveryTheme('mood', '오늘 기분의 색', '지금 기분이랑 닮은 색'),
  DiscoveryTheme('snack', '오늘의 간식', '먹은 것도 좋아요'),
  DiscoveryTheme('sky', '오늘의 하늘', '밖에 나갔다면 하늘 한 장'),
  DiscoveryTheme('flower', '길에서 본 꽃', '나갔다면 꽃이나 풀 한 포기'),
];

/// 2026-01-01부터 며칠째인지. 날마다 바뀌는 선택에 쓴다.
int dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;

int _wrap(int v, int n) => ((v % n) + n) % n;

/// 그날 홈에 나오는 기본 미션 3개: 몸·마음 하나, 공간 하나, 오늘의 발견.
List<Mission> dailyMissions(DateTime day) {
  final n = dayNumber(day);
  final care = kMissions.where((m) => m.kind == MissionKind.care).toList();
  final space = kMissions.where((m) => m.kind == MissionKind.space).toList();
  return [
    care[_wrap(n * 3 + 1, care.length)],
    space[_wrap(n, space.length)],
    kDiscoveryMission,
  ];
}

/// 그날의 발견 주제. [rerolled]면 '다른 걸로'를 한 번 누른 뒤의 주제.
DiscoveryTheme discoveryThemeFor(DateTime day, {bool rerolled = false}) {
  final n = dayNumber(day);
  return kDiscoveryThemes[_wrap(n * 7 + (rerolled ? 11 : 0), kDiscoveryThemes.length)];
}

DiscoveryTheme? discoveryThemeById(String? id) {
  for (final t in kDiscoveryThemes) {
    if (t.id == id) return t;
  }
  return null;
}

/// 기본 미션과 오늘의 발견에서 찾는다. 직접 만든 미션은 null.
Mission? missionById(String id) {
  if (id == kDiscoveryMission.id) return kDiscoveryMission;
  for (final m in kMissions) {
    if (m.id == id) return m;
  }
  return null;
}

/// 기록에 보여 줄 미션 이름.
String recordTitle(MissionRecord record) {
  if (record.missionId == kDiscoveryMission.id) {
    final theme = discoveryThemeById(record.theme);
    return theme == null ? kDiscoveryMission.title : '${kDiscoveryMission.title} · ${theme.title}';
  }
  return missionById(record.missionId)?.title ?? record.title ?? '내 미션';
}
