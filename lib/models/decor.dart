import 'package:flutter/material.dart';

/// 꾸미기 소품. 코인으로 사서 방의 정해진 자리(벽 1, 바닥 2)에 놓는다.
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

/// 방마다 같은 자리 이름. 벽은 하나, 바닥은 둘.
const Map<DecorSpot, List<String>> kDecorSlots = {
  DecorSpot.wall: ['wall'],
  DecorSpot.floor: ['floor1', 'floor2'],
};

/// 방이 이만큼 회복돼야 꾸밀 수 있다. 침실은 처음에 상자가 쌓여 있어서 2단계부터.
const Map<String, int> kDecorMinStage = {'bedroom': 2, 'study': 0};

bool canDecorate(String roomId, int stage) => stage >= (kDecorMinStage[roomId] ?? 0);

String decorAsset(String roomId, String slot, String itemId, {bool night = false}) =>
    'assets/space/decor/${roomId}_${slot}_$itemId${night ? '_n' : ''}.png';

/// 산 소품과 놓은 자리, 쓴 코인. 바꿀 때마다 새 값을 돌려준다.
class DecorData {
  const DecorData({this.owned = const {}, this.placements = const {}, this.spent = 0});

  /// 산 소품 id. 소품은 하나씩만 산다.
  final Set<String> owned;

  /// 방 id → (자리 → 소품 id). 놓지 않은 소품은 보관함에 있다.
  final Map<String, Map<String, String>> placements;

  /// 지금까지 쓴 코인.
  final int spent;

  int available(int earned) => earned - spent;

  /// 소품이 놓인 방. 보관함에 있으면 null.
  String? roomOf(String itemId) {
    for (final e in placements.entries) {
      if (e.value.containsValue(itemId)) return e.key;
    }
    return null;
  }

  Map<String, String> slotsOf(String roomId) => placements[roomId] ?? const {};

  /// 코인이 모자라거나 이미 있으면 그대로.
  DecorData buy(DecorItem item, int earned) {
    if (owned.contains(item.id) || available(earned) < item.price) return this;
    return DecorData(owned: {...owned, item.id}, placements: placements, spent: spent + item.price);
  }

  /// 방에 놓는다. 다른 방에 있었으면 옮기고, 빈 자리가 없으면 첫 자리의 소품을 보관함으로 보낸다.
  DecorData place(DecorItem item, String roomId) {
    if (!owned.contains(item.id)) return this;
    final next = _without(item.id);
    final slots = Map<String, String>.of(next[roomId] ?? const {});
    final candidates = kDecorSlots[item.spot]!;
    final slot = candidates.firstWhere((s) => !slots.containsKey(s), orElse: () => candidates.first);
    slots[slot] = item.id;
    next[roomId] = slots;
    return DecorData(owned: owned, placements: next, spent: spent);
  }

  /// 보관함으로 치운다.
  DecorData remove(String itemId) => DecorData(owned: owned, placements: _without(itemId), spent: spent);

  Map<String, Map<String, String>> _without(String itemId) => {
        for (final e in placements.entries)
          e.key: {
            for (final s in e.value.entries)
              if (s.value != itemId) s.key: s.value
          },
      };

  Map<String, dynamic> toJson() => {'owned': owned.toList(), 'placements': placements, 'spent': spent};

  /// 모르는 소품·자리는 버린다.
  factory DecorData.fromJson(Map<String, dynamic> j) {
    final owned = <String>{
      for (final id in (j['owned'] as List? ?? const []))
        if (id is String && decorById(id) != null) id
    };
    final placements = <String, Map<String, String>>{};
    final raw = j['placements'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final slots = <String, String>{};
        if (e.value is Map) {
          for (final s in (e.value as Map).entries) {
            final item = s.value is String ? decorById(s.value as String) : null;
            if (item != null && owned.contains(item.id) && kDecorSlots[item.spot]!.contains(s.key)) {
              slots[s.key as String] = item.id;
            }
          }
        }
        if (e.key is String) placements[e.key as String] = slots;
      }
    }
    final spent = j['spent'];
    return DecorData(owned: owned, placements: placements, spent: spent is int && spent > 0 ? spent : 0);
  }
}
