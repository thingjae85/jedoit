import 'package:flutter/material.dart';

/// 꾸미기 소품. 코인으로 사서 방 바닥이나 왼쪽 벽 아무 데나 놓는다.
/// 성장(방 회복)을 대신하지 않고, 바뀐 방을 내 취향으로 표현하는 보조 장치다.
enum DecorSpot { wall, floor }

class DecorItem {
  const DecorItem(this.id, this.name, this.price, this.spot, this.icon);
  final String id;
  final String name;
  final int price;
  final DecorSpot spot;
  final IconData icon;
}

/// tools/space_art/decor.py 의 ITEMS 와 id가 같아야 한다.
const List<DecorItem> kDecorItems = [
  DecorItem('poster', '산 포스터', 30, DecorSpot.wall, Icons.landscape_outlined),
  DecorItem('clock', '벽시계', 20, DecorSpot.wall, Icons.schedule),
  DecorItem('garland', '깃발 가랜드', 25, DecorSpot.wall, Icons.flag_outlined),
  DecorItem('cushion', '분홍 방석', 20, DecorSpot.floor, Icons.weekend_outlined),
  DecorItem('moodlamp', '무드등', 40, DecorSpot.floor, Icons.lightbulb_outline),
  DecorItem('cactus', '선인장 화분', 30, DecorSpot.floor, Icons.local_florist_outlined),
  DecorItem('books', '책 더미', 20, DecorSpot.floor, Icons.auto_stories_outlined),
];

DecorItem? decorById(String id) {
  for (final d in kDecorItems) {
    if (d.id == id) return d;
  }
  return null;
}

/// 방이 이만큼 회복돼야 꾸밀 수 있다. 침실은 처음에 상자가 쌓여 있어서 2단계부터.
const Map<String, int> kDecorMinStage = {'bedroom': 2, 'study': 0};

bool canDecorate(String roomId, int stage) => stage >= (kDecorMinStage[roomId] ?? 0);

/// 방 하나의 배치. 위치는 바닥이면 (x, y), 벽이면 (y, z) 칸.
class RoomLayout {
  const RoomLayout({this.furniture = const {}, this.stored = const {}, this.decor = const {}, this.buddy});

  /// 옮긴 가구의 위치. 없으면 처음 자리.
  final Map<String, (int, int)> furniture;

  /// 보관함에 넣은 가구.
  final Set<String> stored;

  /// 이 방에 놓은 산 소품의 위치.
  final Map<String, (int, int)> decor;

  /// 캐릭터가 서는 칸. 없으면 방마다 정해 둔 자리.
  final (int, int)? buddy;

  RoomLayout copyWith({
    Map<String, (int, int)>? furniture,
    Set<String>? stored,
    Map<String, (int, int)>? decor,
    (int, int)? buddy,
  }) =>
      RoomLayout(
        furniture: furniture ?? this.furniture,
        stored: stored ?? this.stored,
        decor: decor ?? this.decor,
        buddy: buddy ?? this.buddy,
      );

  Map<String, dynamic> toJson() => {
        'f': {for (final e in furniture.entries) e.key: [e.value.$1, e.value.$2]},
        's': stored.toList(),
        'd': {for (final e in decor.entries) e.key: [e.value.$1, e.value.$2]},
        if (buddy != null) 'b': [buddy!.$1, buddy!.$2],
      };

  static Map<String, (int, int)> _positions(Object? raw) {
    final out = <String, (int, int)>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value;
        if (e.key is String && v is List && v.length == 2 && v[0] is int && v[1] is int) {
          out[e.key as String] = (v[0] as int, v[1] as int);
        }
      }
    }
    return out;
  }

  factory RoomLayout.fromJson(Object? raw) {
    if (raw is! Map) return const RoomLayout();
    final stored = raw['s'];
    return RoomLayout(
      furniture: _positions(raw['f']),
      stored: {
        if (stored is List)
          for (final s in stored)
            if (s is String) s
      },
      decor: _positions(raw['d']),
      buddy: _positions({'b': raw['b']})['b'],
    );
  }
}

/// 산 소품, 방마다 배치, 쓴 코인. 바꿀 때마다 새 값을 돌려준다.
class DecorData {
  const DecorData({this.owned = const {}, this.layouts = const {}, this.spent = 0});

  /// 산 소품 id. 소품은 하나씩만 산다.
  final Set<String> owned;

  final Map<String, RoomLayout> layouts;

  /// 지금까지 쓴 코인.
  final int spent;

  int available(int earned) => earned - spent;

  RoomLayout layoutOf(String roomId) => layouts[roomId] ?? const RoomLayout();

  /// 소품이 놓인 방. 보관함에 있으면 null.
  String? roomOf(String itemId) {
    for (final e in layouts.entries) {
      if (e.value.decor.containsKey(itemId)) return e.key;
    }
    return null;
  }

  DecorData _with(String roomId, RoomLayout layout, {Set<String>? owned, int? spent}) => DecorData(
        owned: owned ?? this.owned,
        layouts: {...layouts, roomId: layout},
        spent: spent ?? this.spent,
      );

  /// 코인이 모자라거나 이미 있으면 그대로.
  DecorData buy(DecorItem item, int earned) {
    if (owned.contains(item.id) || available(earned) < item.price) return this;
    return DecorData(owned: {...owned, item.id}, layouts: layouts, spent: spent + item.price);
  }

  /// 산 소품을 방의 (a, b) 칸에 놓는다. 다른 방에 있었으면 옮긴다. 자리 검사는 부르는 쪽에서 한다.
  DecorData placeDecor(String itemId, String roomId, int a, int b) {
    if (!owned.contains(itemId)) return this;
    final cleared = removeDecor(itemId);
    final layout = cleared.layoutOf(roomId);
    return cleared._with(roomId, layout.copyWith(decor: {...layout.decor, itemId: (a, b)}));
  }

  /// 소품을 보관함으로.
  DecorData removeDecor(String itemId) => DecorData(
        owned: owned,
        layouts: {
          for (final e in layouts.entries)
            e.key: e.value.decor.containsKey(itemId)
                ? e.value.copyWith(decor: {...e.value.decor}..remove(itemId))
                : e.value,
        },
        spent: spent,
      );

  /// 가구를 (x, y)로 옮긴다. 보관함에 있었으면 꺼낸다.
  DecorData moveFurniture(String roomId, String id, int x, int y) {
    final layout = layoutOf(roomId);
    return _with(
      roomId,
      layout.copyWith(furniture: {...layout.furniture, id: (x, y)}, stored: {...layout.stored}..remove(id)),
    );
  }

  /// 캐릭터를 (x, y)에 세운다.
  DecorData moveBuddy(String roomId, int x, int y) => _with(roomId, layoutOf(roomId).copyWith(buddy: (x, y)));

  /// 가구를 보관함에 넣는다.
  DecorData storeFurniture(String roomId, String id) {
    final layout = layoutOf(roomId);
    return _with(roomId, layout.copyWith(stored: {...layout.stored, id}));
  }

  Map<String, dynamic> toJson() => {
        'owned': owned.toList(),
        'layouts': {for (final e in layouts.entries) e.key: e.value.toJson()},
        'spent': spent,
      };

  /// 모르는 소품, 사지 않은 소품은 버린다.
  factory DecorData.fromJson(Map<String, dynamic> j) {
    final owned = <String>{
      for (final id in (j['owned'] as List? ?? const []))
        if (id is String && decorById(id) != null) id
    };
    final layouts = <String, RoomLayout>{};
    final raw = j['layouts'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.key is! String) continue;
        final l = RoomLayout.fromJson(e.value);
        layouts[e.key as String] =
            l.copyWith(decor: {for (final d in l.decor.entries) if (owned.contains(d.key)) d.key: d.value});
      }
    }
    final spent = j['spent'];
    return DecorData(owned: owned, layouts: layouts, spent: spent is int && spent > 0 ? spent : 0);
  }
}
