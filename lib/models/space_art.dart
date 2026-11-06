// tools/space_art/export.py 가 만든 파일. 직접 고치지 말고 스크립트를 다시 돌린다.

/// 방 그림 한 장의 크기(도트 픽셀).
const double kRoomArtWidth = 176;
const double kRoomArtHeight = 192;

/// 방 바닥 칸 수(가로·세로)와 벽 높이 칸 수.
const int kRoomCells = 40;
const int kWallCells = 44;

/// 캐릭터 그림 크기(도트 픽셀).
const double kBuddyArtWidth = 22;
const double kBuddyArtHeight = 23;

/// 벌집 보기에서 옆 칸, 아래 칸까지의 거리(도트 픽셀).
const double kHiveDx = 172;
const double kHiveDy = 136;

/// 방 그림의 원점. 칸 위치를 화면 위치로 바꿀 때 쓴다.
const double kRoomOriginX = 88;
const double kRoomOriginY = 98;

/// 산 소품을 그려 둔 기준 자리 (바닥 x, y / 왼쪽 벽 y, z).
const int kDecorRefFloorX = 20;
const int kDecorRefFloorY = 20;
const int kDecorRefWallY = 20;
const int kDecorRefWallZ = 12;

/// 잘라 낸 그림 한 장과, 기준 자리에 놓였을 때의 왼쪽 위 (도트 픽셀).
class Sprite {
  const Sprite(this.asset, this.left, this.top, this.width, this.height);
  final String asset;
  final int left;
  final int top;
  final int width;
  final int height;
}

/// 가구 그림. 단계에 따라 그림이 바뀔 수 있다 (예: 책상 위에 모니터가 생김).
class FurnitureArt {
  const FurnitureArt(this.id, this.name, this.unlock, this.x, this.y, this.w, this.d, this.flat, this.variants);
  final String id;
  final String name;

  /// 이 단계부터 방에 생긴다.
  final int unlock;

  /// 처음 놓이는 바닥 칸과 크기.
  final int x;
  final int y;
  final int w;
  final int d;

  /// 러그처럼 납작해서 위에 다른 물건을 올릴 수 있는지.
  final bool flat;

  /// (이 단계부터, 낮 그림, 밤 그림). 단계 순서대로.
  final List<(int, Sprite, Sprite)> variants;

  (Sprite, Sprite) spritesAt(int stage) {
    var pick = variants.first;
    for (final v in variants) {
      if (v.$1 <= stage) pick = v;
    }
    return (pick.$2, pick.$3);
  }
}

/// 왼쪽 벽에서 소품을 걸 수 없는 곳 (y, z, 너비, 높이, 생기는 단계).
class WallBlock {
  const WallBlock(this.y, this.z, this.w, this.h, this.from);
  final int y;
  final int z;
  final int w;
  final int h;
  final int from;
}

class RoomArt {
  const RoomArt({
    required this.stages,
    required this.shells,
    required this.furniture,
    required this.wallBlocks,
    required this.buddyX,
    required this.buddyY,
    required this.frameX,
    required this.frameZ,
    required this.litFrom,
    required this.surfaces,
  });

  final int stages;

  /// 단계별 껍데기(창문·벽에 붙은 것) 그림 (낮, 밤). 바닥과 벽 자리는 비어 있고 [surfaces]가 채운다.
  final List<(String, String)> shells;

  final List<FurnitureArt> furniture;
  final List<WallBlock> wallBlocks;

  /// 캐릭터가 서고 싶은 바닥 칸. 막혀 있으면 가까운 빈 칸에 선다.
  final int buddyX;
  final int buddyY;

  /// 오른쪽 뒷벽 사진 액자의 시작 칸.
  final int frameX;
  final int frameZ;

  /// 이 단계부터 낮 그림이 밝다. 그 전에는 낮에도 어두운 방이라 밤 벽지·바닥을 쓴다.
  final int litFrom;

  /// 벽지·바닥 그림: 'wall_basic', 'floor_oak' 같은 id → (낮, 밤).
  final Map<String, (String, String)> surfaces;
}

const Map<String, RoomArt> kRoomArt = {
  'bedroom': RoomArt(
    stages: 11,
    shells: [
      ('assets/space/bedroom_shell_0.png', 'assets/space/bedroom_shell_0.png'),
      ('assets/space/bedroom_shell_1.png', 'assets/space/bedroom_shell_0.png'),
      ('assets/space/bedroom_shell_2.png', 'assets/space/bedroom_shell_2_n.png'),
      ('assets/space/bedroom_shell_2.png', 'assets/space/bedroom_shell_2_n.png'),
      ('assets/space/bedroom_shell_2.png', 'assets/space/bedroom_shell_2_n.png'),
      ('assets/space/bedroom_shell_2.png', 'assets/space/bedroom_shell_2_n.png'),
      ('assets/space/bedroom_shell_2.png', 'assets/space/bedroom_shell_2_n.png'),
      ('assets/space/bedroom_shell_7.png', 'assets/space/bedroom_shell_7_n.png'),
      ('assets/space/bedroom_shell_8.png', 'assets/space/bedroom_shell_8_n.png'),
      ('assets/space/bedroom_shell_8.png', 'assets/space/bedroom_shell_8_n.png'),
      ('assets/space/bedroom_shell_8.png', 'assets/space/bedroom_shell_8_n.png'),
    ],
    furniture: [
      FurnitureArt('nightstand', '협탁', 2, 0, 8, 5, 5, false, [(2, Sprite('assets/space/furniture/bedroom_nightstand_2.png', 62, 92, 20, 25), Sprite('assets/space/furniture/bedroom_nightstand_2_n.png', 59, 85, 26, 32))]),
      FurnitureArt('bed', '침대', 2, 0, 14, 10, 17, false, [(2, Sprite('assets/space/furniture/bedroom_bed_2.png', 26, 92, 54, 48), Sprite('assets/space/furniture/bedroom_bed_2_n.png', 26, 92, 54, 48))]),
      FurnitureArt('rug', '러그', 3, 12, 19, 15, 12, true, [(3, Sprite('assets/space/furniture/bedroom_rug_3.png', 50, 127, 54, 30), Sprite('assets/space/furniture/bedroom_rug_3_n.png', 50, 127, 54, 30))]),
      FurnitureArt('desk', '책상', 4, 12, 0, 19, 7, false, [(4, Sprite('assets/space/furniture/bedroom_desk_4.png', 98, 84, 52, 53), Sprite('assets/space/furniture/bedroom_desk_4_n.png', 98, 84, 52, 53)), (6, Sprite('assets/space/furniture/bedroom_desk_6.png', 98, 84, 52, 53), Sprite('assets/space/furniture/bedroom_desk_6_n.png', 98, 83, 59, 54))]),
      FurnitureArt('chair', '의자', 4, 21, 9, 5, 5, false, [(4, Sprite('assets/space/furniture/bedroom_chair_4.png', 102, 106, 20, 31), Sprite('assets/space/furniture/bedroom_chair_4_n.png', 102, 106, 20, 31))]),
      FurnitureArt('plant_big', '큰 화분', 5, 31, 29, 8, 7, false, [(5, Sprite('assets/space/furniture/bedroom_plant_big_5.png', 82, 146, 22, 26), Sprite('assets/space/furniture/bedroom_plant_big_5_n.png', 82, 146, 22, 26))]),
      FurnitureArt('plant_small', '작은 화분', 8, 35, 13, 3, 3, false, [(8, Sprite('assets/space/furniture/bedroom_plant_small_8.png', 126, 132, 12, 21), Sprite('assets/space/furniture/bedroom_plant_small_8_n.png', 126, 132, 12, 21))]),
      FurnitureArt('drawer', '서랍장', 9, 32, 0, 7, 5, false, [(9, Sprite('assets/space/furniture/bedroom_drawer_9.png', 142, 110, 24, 33), Sprite('assets/space/furniture/bedroom_drawer_9_n.png', 142, 110, 24, 33))]),
      FurnitureArt('bin', '휴지통', 9, 32, 8, 3, 3, false, [(9, Sprite('assets/space/furniture/bedroom_bin_9.png', 130, 128, 12, 17), Sprite('assets/space/furniture/bedroom_bin_9_n.png', 130, 128, 12, 17))]),
      FurnitureArt('mat', '운동 매트', 10, 13, 33, 10, 5, true, [(10, Sprite('assets/space/furniture/bedroom_mat_10.png', 38, 142, 30, 18), Sprite('assets/space/furniture/bedroom_mat_10_n.png', 38, 142, 30, 18))]),
      FurnitureArt('dumbbell', '아령', 10, 26, 34, 2, 5, false, [(10, Sprite('assets/space/furniture/bedroom_dumbbell_10.png', 62, 154, 14, 12), Sprite('assets/space/furniture/bedroom_dumbbell_10_n.png', 62, 154, 14, 12))]),
      FurnitureArt('shoes', '운동화', 10, 4, 34, 3, 5, false, [(10, Sprite('assets/space/furniture/bedroom_shoes_10.png', 18, 132, 16, 13), Sprite('assets/space/furniture/bedroom_shoes_10_n.png', 18, 132, 16, 13))]),
    ],
    wallBlocks: [
      WallBlock(3, 22, 18, 10, 7),
      WallBlock(3, 28, 34, 8, 8),
    ],
    buddyX: 20,
    buddyY: 25,
    frameX: 2,
    frameZ: 24,
    litFrom: 1,
    surfaces: {
      'wall_basic': ('assets/space/surface/bedroom_wall_basic.png', 'assets/space/surface/bedroom_wall_basic_n.png'),
      'wall_cream': ('assets/space/surface/bedroom_wall_cream.png', 'assets/space/surface/bedroom_wall_cream_n.png'),
      'wall_mint': ('assets/space/surface/bedroom_wall_mint.png', 'assets/space/surface/bedroom_wall_mint_n.png'),
      'wall_sky': ('assets/space/surface/bedroom_wall_sky.png', 'assets/space/surface/bedroom_wall_sky_n.png'),
      'wall_rose': ('assets/space/surface/bedroom_wall_rose.png', 'assets/space/surface/bedroom_wall_rose_n.png'),
      'wall_brick': ('assets/space/surface/bedroom_wall_brick.png', 'assets/space/surface/bedroom_wall_brick_n.png'),
      'floor_basic': ('assets/space/surface/bedroom_floor_basic.png', 'assets/space/surface/bedroom_floor_basic_n.png'),
      'floor_oak': ('assets/space/surface/bedroom_floor_oak.png', 'assets/space/surface/bedroom_floor_oak_n.png'),
      'floor_walnut': ('assets/space/surface/bedroom_floor_walnut.png', 'assets/space/surface/bedroom_floor_walnut_n.png'),
      'floor_tile': ('assets/space/surface/bedroom_floor_tile.png', 'assets/space/surface/bedroom_floor_tile_n.png'),
      'floor_green': ('assets/space/surface/bedroom_floor_green.png', 'assets/space/surface/bedroom_floor_green_n.png'),
      'floor_pink': ('assets/space/surface/bedroom_floor_pink.png', 'assets/space/surface/bedroom_floor_pink_n.png'),
    },
  ),
  'study': RoomArt(
    stages: 7,
    shells: [
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
      ('assets/space/study_shell_0.png', 'assets/space/study_shell_0_n.png'),
    ],
    furniture: [
      FurnitureArt('bookshelf', '책장', 1, 4, 0, 10, 4, false, [(1, Sprite('assets/space/furniture/study_bookshelf_1.png', 88, 66, 28, 51), Sprite('assets/space/furniture/study_bookshelf_1_n.png', 88, 66, 28, 51))]),
      FurnitureArt('rug', '러그', 2, 10, 14, 12, 10, true, [(2, Sprite('assets/space/furniture/study_rug_2.png', 60, 120, 44, 25), Sprite('assets/space/furniture/study_rug_2_n.png', 60, 120, 44, 25))]),
      FurnitureArt('armchair', '안락의자', 3, 6, 16, 7, 6, false, [(3, Sprite('assets/space/furniture/study_armchair_3.png', 56, 102, 26, 32), Sprite('assets/space/furniture/study_armchair_3_n.png', 56, 102, 26, 32))]),
      FurnitureArt('side_table', '작은 탁자', 4, 14, 18, 4, 4, false, [(4, Sprite('assets/space/furniture/study_side_table_4.png', 72, 118, 16, 21), Sprite('assets/space/furniture/study_side_table_4_n.png', 72, 118, 16, 21))]),
      FurnitureArt('plant_small', '작은 화분', 5, 2, 26, 3, 3, false, [(5, Sprite('assets/space/furniture/study_plant_small_5.png', 34, 112, 12, 21), Sprite('assets/space/furniture/study_plant_small_5_n.png', 34, 112, 12, 21))]),
      FurnitureArt('floor_lamp', '스탠드', 6, 16, 2, 3, 3, false, [(6, Sprite('assets/space/furniture/study_floor_lamp_6.png', 110, 80, 12, 43), Sprite('assets/space/furniture/study_floor_lamp_6_n.png', 99, 73, 34, 50))]),
    ],
    wallBlocks: [
    ],
    buddyX: 16,
    buddyY: 26,
    frameX: 13,
    frameZ: 26,
    litFrom: 0,
    surfaces: {
      'wall_basic': ('assets/space/surface/study_wall_basic.png', 'assets/space/surface/study_wall_basic_n.png'),
      'wall_cream': ('assets/space/surface/study_wall_cream.png', 'assets/space/surface/study_wall_cream_n.png'),
      'wall_mint': ('assets/space/surface/study_wall_mint.png', 'assets/space/surface/study_wall_mint_n.png'),
      'wall_sky': ('assets/space/surface/study_wall_sky.png', 'assets/space/surface/study_wall_sky_n.png'),
      'wall_rose': ('assets/space/surface/study_wall_rose.png', 'assets/space/surface/study_wall_rose_n.png'),
      'wall_brick': ('assets/space/surface/study_wall_brick.png', 'assets/space/surface/study_wall_brick_n.png'),
      'floor_basic': ('assets/space/surface/study_floor_basic.png', 'assets/space/surface/study_floor_basic_n.png'),
      'floor_oak': ('assets/space/surface/study_floor_oak.png', 'assets/space/surface/study_floor_oak_n.png'),
      'floor_walnut': ('assets/space/surface/study_floor_walnut.png', 'assets/space/surface/study_floor_walnut_n.png'),
      'floor_tile': ('assets/space/surface/study_floor_tile.png', 'assets/space/surface/study_floor_tile_n.png'),
      'floor_green': ('assets/space/surface/study_floor_green.png', 'assets/space/surface/study_floor_green_n.png'),
      'floor_pink': ('assets/space/surface/study_floor_pink.png', 'assets/space/surface/study_floor_pink_n.png'),
    },
  ),
};

/// 산 소품 그림: id → (벽 소품인지, 너비, 깊이(바닥)/높이(벽), 낮 그림, 밤 그림).
const Map<String, (bool, int, int, Sprite, Sprite)> kDecorArt = {
  'poster': (true, 6, 8, Sprite('assets/space/decor/poster.png', 36, 81, 12, 22), Sprite('assets/space/decor/poster_n.png', 36, 81, 12, 22)),
  'clock': (true, 5, 5, Sprite('assets/space/decor/clock.png', 38, 88, 10, 13), Sprite('assets/space/decor/clock_n.png', 38, 88, 10, 13)),
  'garland': (true, 12, 4, Sprite('assets/space/decor/garland.png', 24, 89, 24, 17), Sprite('assets/space/decor/garland_n.png', 24, 89, 24, 17)),
  'cushion': (false, 5, 5, Sprite('assets/space/decor/cushion.png', 78, 134, 20, 15), Sprite('assets/space/decor/cushion_n.png', 78, 134, 20, 15)),
  'moodlamp': (false, 3, 3, Sprite('assets/space/decor/moodlamp.png', 82, 124, 12, 21), Sprite('assets/space/decor/moodlamp_n.png', 71, 117, 34, 28)),
  'cactus': (false, 3, 3, Sprite('assets/space/decor/cactus.png', 82, 120, 12, 25), Sprite('assets/space/decor/cactus_n.png', 82, 120, 12, 25)),
  'books': (false, 5, 3, Sprite('assets/space/decor/books.png', 82, 133, 16, 14), Sprite('assets/space/decor/books_n.png', 82, 133, 16, 14)),
};

/// 고를 수 있는 벽지와 바닥 (id, 이름). 기본(basic)은 방마다 처음 모습이다.
const List<(String, String)> kWallpaperArt = [
  ('cream', '크림 벽지'),
  ('mint', '민트 줄무늬'),
  ('sky', '하늘 물방울'),
  ('rose', '분홍 체크'),
  ('brick', '벽돌'),
];
const List<(String, String)> kFloorArt = [
  ('oak', '밝은 원목'),
  ('walnut', '짙은 원목'),
  ('tile', '체크 타일'),
  ('green', '초록 카펫'),
  ('pink', '분홍 카펫'),
];
