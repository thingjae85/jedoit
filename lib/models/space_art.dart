// tools/space_art/export.py 가 만든 파일. 직접 고치지 말고 스크립트를 다시 돌린다.

/// 방 그림 한 장의 크기(도트 픽셀).
const double kRoomArtWidth = 176;
const double kRoomArtHeight = 192;

/// 캐릭터 그림 크기(도트 픽셀).
const double kBuddyArtWidth = 22;
const double kBuddyArtHeight = 23;

/// 벌집 보기에서 옆 칸, 아래 칸까지의 거리(도트 픽셀).
const double kHiveDx = 172;
const double kHiveDy = 136;

/// 방 그림의 원점. 벽 위 액자 칸 위치를 계산할 때 쓴다.
const double kRoomOriginX = 88;
const double kRoomOriginY = 98;

class RoomArt {
  const RoomArt({required this.stages, required this.buddySpots, required this.frameX, required this.frameZ});

  /// 단계 수. assets/space/<id>_<단계>.png
  final int stages;

  /// 단계별 캐릭터 그림의 왼쪽 위 (도트 픽셀).
  final List<(double, double)> buddySpots;

  /// 오른쪽 뒷벽 사진 액자의 시작 칸.
  final int frameX;
  final int frameZ;
}

const Map<String, RoomArt> kRoomArt = {
  'bedroom': RoomArt(stages: 11, buddySpots: [(67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0), (67.0, 120.0)], frameX: 2, frameZ: 24),
  'study': RoomArt(stages: 7, buddySpots: [(67.0, 110.0), (67.0, 110.0), (67.0, 110.0), (57.0, 95.0), (57.0, 95.0), (57.0, 95.0), (57.0, 95.0)], frameX: 13, frameZ: 26),
};
