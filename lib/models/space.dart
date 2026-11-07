import 'space_art.dart';

/// '내 공간'. 미션을 할 때마다 방이 조금씩 회복되고 가구가 생긴다.
/// 몇 번 남았는지는 일부러 보여 주지 않는다. 새 방 문은 어느 날 갑자기 열린다.
class SpaceRoomDef {
  const SpaceRoomDef({required this.id, required this.name, required this.lines});

  final String id;

  /// 처음 이름. 사용자가 바꾼 이름은 [DecorData.roomName].
  final String name;

  /// 단계에 올라섰을 때 보여 줄 한 줄. lines[0]은 방이 처음 열릴 때.
  final List<String> lines;

  int get stages => kRoomArt[id]?.stages ?? lines.length;
}

const List<SpaceRoomDef> kSpaceRooms = [
  SpaceRoomDef(id: 'bedroom', name: '방1', lines: [
    '',
    '상자를 치웠어요. 이제 방을 꾸밀 수 있어요',
    '침대와 협탁이 들어왔어요',
    '침대 옆에 러그를 깔았어요',
    '책상과 의자가 생겼어요',
    '큰 화분이 들어왔어요',
    '책상에 스탠드를 켰어요',
    '벽에 수납장과 액자가 걸렸어요',
    '꼬마전구를 달았어요',
    '서랍장이 생겼어요',
    '운동 매트를 깔았어요',
  ]),
  SpaceRoomDef(id: 'study', name: '방2', lines: [
    '문이 열렸어요! 새 방이 생겼어요',
    '책장이 들어왔어요',
    '바닥에 러그를 깔았어요',
    '푹신한 안락의자가 생겼어요',
    '작은 탁자를 놓았어요',
    '화분을 하나 들였어요',
    '스탠드를 세웠어요',
  ]),
];

SpaceRoomDef? spaceRoomById(String? id) {
  for (final r in kSpaceRooms) {
    if (r.id == id) return r;
  }
  return null;
}

/// 미션을 마칠 때 일어나는 변화 하나.
class SpaceEvent {
  const SpaceEvent(this.roomId, this.stage);
  final String roomId;
  final int stage;

  bool get opensRoom => stage == 0;

  String get line {
    final room = spaceRoomById(roomId);
    if (room == null || stage >= room.lines.length) return '';
    return room.lines[stage];
  }
}

/// 변화 순서: 침실 4단계 → 새 방 열림(5번째) → 두 방이 번갈아 자란다.
final List<SpaceEvent> kSpaceTimeline = _buildTimeline();

List<SpaceEvent> _buildTimeline() {
  final bedroom = kSpaceRooms[0];
  final study = kSpaceRooms[1];
  final events = <SpaceEvent>[
    for (var s = 1; s <= 4; s++) SpaceEvent(bedroom.id, s),
    SpaceEvent(study.id, 0),
  ];
  var b = 5;
  var s = 1;
  while (b < bedroom.stages || s < study.stages) {
    if (s < study.stages) events.add(SpaceEvent(study.id, s++));
    if (b < bedroom.stages) events.add(SpaceEvent(bedroom.id, b++));
  }
  return events;
}

/// [index]번째 변화(0부터)가 일어나는 누적 미션 수.
/// 처음 다섯 번은 미션마다, 그다음부터는 두 번에 한 번.
int spaceThreshold(int index) => index < 5 ? index + 1 : 5 + 2 * (index - 4);

/// 누적 미션 수가 정확히 [count]가 될 때 일어난 변화. 없으면 null.
SpaceEvent? spaceEventAt(int count) {
  for (var i = 0; i < kSpaceTimeline.length; i++) {
    final t = spaceThreshold(i);
    if (t == count) return kSpaceTimeline[i];
    if (t > count) break;
  }
  return null;
}

/// 저녁 7시부터 아침 6시 전까지는 방이 밤 분위기가 된다.
bool isNightTime(DateTime t) => t.hour >= 19 || t.hour < 6;

/// 미션 하나에 받는 코인. 코인은 미션을 하면 항상 받는다.
const coinsPerMission = 10;

/// 누적 미션 수로 정해지는 지금 공간 상태.
class SpaceState {
  const SpaceState({required this.stages, required this.latestRoom, required this.missionCount});

  factory SpaceState.of(int count) {
    final stages = <String, int>{kSpaceRooms.first.id: 0};
    var latest = kSpaceRooms.first.id;
    for (var i = 0; i < kSpaceTimeline.length; i++) {
      if (spaceThreshold(i) > count) break;
      final e = kSpaceTimeline[i];
      stages[e.roomId] = e.stage;
      latest = e.roomId;
    }
    return SpaceState(stages: stages, latestRoom: latest, missionCount: count);
  }

  /// 열린 방의 단계. 없는 방은 아직 잠긴 방.
  final Map<String, int> stages;

  /// 가장 최근에 바뀐 방.
  final String latestRoom;

  final int missionCount;

  int get coins => missionCount * coinsPerMission;

  bool isOpen(String roomId) => stages.containsKey(roomId);

  int stageOf(String roomId) => stages[roomId] ?? 0;

  /// 하나만 보기에서 보여 줄 방: 눌러 둔 방이 있으면 그 방, 없으면 가장 최근에 바뀐 방.
  String shownRoom(String? pinned) =>
      pinned != null && isOpen(pinned) ? pinned : latestRoom;
}

/// 이름 뒤에 붙일 '이'/'가'. 받침이 있으면 '이'. 숫자는 읽는 소리로 본다 (방1 → 이, 방2 → 가).
String subjectParticle(String word) {
  if (word.isEmpty) return '이';
  final c = word.codeUnitAt(word.length - 1);
  if (c >= 0xAC00 && c <= 0xD7A3) return (c - 0xAC00) % 28 == 0 ? '가' : '이';
  if (c >= 0x30 && c <= 0x39) return '013678'.contains(word[word.length - 1]) ? '이' : '가';
  return '이(가)';
}

/// 이름 뒤에 붙일 '을'/'를'.
String objectParticle(String word) {
  final p = subjectParticle(word);
  return p == '이' ? '을' : (p == '가' ? '를' : '을(를)');
}
