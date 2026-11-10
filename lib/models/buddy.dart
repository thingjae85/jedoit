import 'mission.dart';
import 'space.dart';

/// 같이 사는 친구(곰인형·햄스터인형·운동화 신은 상어). 돌봐 달라고 하지 않고, 해낸 일에 혼잣말로 반응만 한다.
class Buddy {
  const Buddy(this.id, this.name);
  final String id;
  final String name;

  String get asset => 'assets/space/$id.png';
}

const kBuddies = [Buddy('bear', '곰돌이'), Buddy('hamster', '햄찌'), Buddy('shark', '샤키')];

Buddy buddyById(String id) => kBuddies.firstWhere((b) => b.id == id, orElse: () => kBuddies.first);

const Map<String, List<String>> _byMission = {
  'water': ['물 마셨구나. 나도 한 모금.', '몸이 조금 촉촉해진 느낌이야.'],
  'reading': ['책 냄새 좋다. 무슨 이야기였을까.', '열 쪽이면 충분하지.'],
  'walking': ['바람 냄새가 묻어 왔네.', '다녀왔구나. 밖은 어땠어?'],
  'stretch': ['쭉— 나도 따라 했어.', '몸이 조금 풀렸겠다.'],
  'sunlight': ['햇빛 받은 얼굴이다. 따뜻해 보여.', '방까지 환해진 것 같아.'],
  'wash': ['개운해 보인다.', '찬물 한 번이면 정신이 번쩍.'],
  'fruit': ['오, 먹었구나.', '달았을까, 셨을까.'],
  'cleanup': ['책상이 조금 넓어졌다.', '한 구역이면 충분해.'],
  'bed': ['이불이 반듯하다. 괜히 기분 좋아.', '오늘 밤엔 잘 잘 것 같아.'],
  'air': ['새 공기 들어온다.', '방이 숨 쉬는 것 같아.'],
  'trash': ['하나 줄었다. 그걸로 충분해.', '방이 조금 가벼워졌어.'],
  'dishes': ['컵이 반짝반짝.', '하나 씻은 것도 해낸 거야.'],
};

/// 미션을 마쳤을 때 한마디. 사진 내용이 아니라 미션에 반응한다.
String buddyReaction(Mission mission, {required bool withPhoto, int seed = 0}) {
  final lines = switch (mission.kind) {
    MissionKind.discovery => withPhoto
        ? const ['오늘은 이런 걸 찾았구나.', '좋은 거 발견했다.']
        : const ['눈으로만 봐도 발견이야.', '찾아본 것만으로도 좋아.'],
    MissionKind.custom => const ['오늘 정한 거, 해냈네.', '스스로 정한 걸 했구나.'],
    _ => _byMission[mission.id] ?? const ['해냈구나.', '오늘 하나 했다.'],
  };
  return lines[seed.abs() % lines.length];
}

/// 방 카드에 평소 떠 있는 혼잣말. 방 상태를 따라갈 뿐, 아무것도 요구하지 않는다.
String buddyIdleLine(SpaceState state, String roomId, {required bool doneToday, bool night = false}) {
  if (night) return doneToday ? '오늘도 하나 했네. 푹 쉬자.' : '조용한 밤이다. 나도 여기 있을게.';
  if (doneToday) return '오늘 방이 조금 밝아졌어.';
  final stage = state.stageOf(roomId);
  if (roomId == kSpaceRooms.first.id && stage == 0) return '조금 어둡다. 그래도 여기 있을게.';
  if (stage <= 2) return '오늘은 어떤 날일까.';
  return '여기 꽤 아늑해졌다.';
}
