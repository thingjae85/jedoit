import 'decor.dart';
import 'space_art.dart';

/// 방 안에 놓인 것 하나(가구 또는 산 소품). 위치는 바닥이면 (x, y), 왼쪽 벽이면 (y, z) 칸.
class PlacedThing {
  const PlacedThing({
    required this.key,
    required this.id,
    required this.name,
    required this.isDecor,
    required this.wall,
    required this.flat,
    required this.a,
    required this.b,
    required this.w,
    required this.d,
    required this.day,
    required this.night,
    required this.refA,
    required this.refB,
  });

  /// 'f:<가구 id>' 또는 'd:<소품 id>'
  final String key;
  final String id;
  final String name;
  final bool isDecor;
  final bool wall;

  /// 러그처럼 위에 다른 걸 올릴 수 있는지.
  final bool flat;

  final int a;
  final int b;

  /// 바닥: 너비·깊이, 벽: 너비·높이 (칸).
  final int w;
  final int d;

  final Sprite day;
  final Sprite night;

  /// 그림을 그려 둔 기준 위치.
  final int refA;
  final int refB;

  PlacedThing at(int na, int nb) => PlacedThing(
        key: key, id: id, name: name, isDecor: isDecor, wall: wall, flat: flat,
        a: na, b: nb, w: w, d: d, day: day, night: night, refA: refA, refB: refB,
      );

  /// 기준 위치에서 옮긴 만큼 그림이 움직이는 거리 (도트 픽셀).
  (int, int) get shift {
    final da = a - refA;
    final db = b - refB;
    if (wall) return (-2 * da, da - 2 * db); // 왼쪽 벽: y가 늘면 왼쪽 아래, z가 늘면 위
    return (2 * (da - db), da + db); // 바닥
  }

  /// 그림이 차지하는 사각형 (도트 픽셀): 왼쪽, 위, 너비, 높이.
  (int, int, int, int) rect({bool atNight = false}) {
    final s = atNight ? night : day;
    final (dx, dy) = shift;
    return (s.left + dx, s.top + dy, s.width, s.height);
  }

  bool overlaps(int oa, int ob, int ow, int od) => a < oa + ow && oa < a + w && b < ob + od && ob < b + d;
}

String furnitureKey(String id) => 'f:$id';
String decorKey(String id) => 'd:$id';

/// 지금 방에 놓인 것들 (보관함에 넣은 가구와 아직 안 생긴 가구는 빼고).
List<PlacedThing> thingsIn(String roomId, int stage, DecorData data) {
  final art = kRoomArt[roomId];
  if (art == null) return const [];
  final layout = data.layoutOf(roomId);
  final out = <PlacedThing>[];
  for (final f in art.furniture) {
    if (f.unlock > stage || layout.stored.contains(f.id)) continue;
    final (day, night) = f.spritesAt(stage);
    final pos = layout.furniture[f.id] ?? (f.x, f.y);
    out.add(PlacedThing(
      key: furnitureKey(f.id), id: f.id, name: f.name, isDecor: false, wall: false, flat: f.flat,
      a: pos.$1, b: pos.$2, w: f.w, d: f.d, day: day, night: night, refA: f.x, refB: f.y,
    ));
  }
  if (canDecorate(roomId, stage)) {
    for (final e in layout.decor.entries) {
      final t = decorThing(e.key, e.value.$1, e.value.$2);
      if (t != null) out.add(t);
    }
  }
  return out;
}

/// 산 소품 하나를 (a, b)에 놓았을 때.
PlacedThing? decorThing(String itemId, int a, int b) {
  final art = kDecorArt[itemId];
  final item = decorById(itemId);
  if (art == null || item == null) return null;
  final (wall, w, d, day, night) = art;
  return PlacedThing(
    key: decorKey(itemId), id: itemId, name: item.name, isDecor: true, wall: wall, flat: false,
    a: a, b: b, w: w, d: d, day: day, night: night,
    refA: wall ? kDecorRefWallY : kDecorRefFloorX,
    refB: wall ? kDecorRefWallZ : kDecorRefFloorY,
  );
}

/// 보관함에 넣은 이 방의 가구 (이미 생긴 것만).
List<FurnitureArt> storedFurniture(String roomId, int stage, DecorData data) {
  final art = kRoomArt[roomId];
  if (art == null) return const [];
  final stored = data.layoutOf(roomId).stored;
  return [for (final f in art.furniture) if (f.unlock <= stage && stored.contains(f.id)) f];
}

/// [thing]을 (a, b)에 둘 수 있는지: 방 안이어야 하고, 납작하지 않은 물건끼리는 겹치면 안 된다.
/// 벽 소품은 다른 벽 소품, 벽에 붙은 수납장·전구와 겹치면 안 된다.
bool fits(String roomId, int stage, List<PlacedThing> things, PlacedThing thing, int a, int b) {
  if (thing.wall) {
    if (a < 0 || a > kRoomCells - thing.w || b < 2 || b > kWallCells - thing.d - 1) return false;
    final blocks = kRoomArt[roomId]?.wallBlocks ?? const [];
    for (final bl in blocks) {
      if (bl.from <= stage && a < bl.y + bl.w && bl.y < a + thing.w && b < bl.z + bl.h && bl.z < b + thing.d) {
        return false;
      }
    }
    for (final o in things) {
      if (o.key != thing.key && o.wall && o.overlaps(a, b, thing.w, thing.d)) return false;
    }
    return true;
  }
  if (a < 0 || b < 0 || a > kRoomCells - thing.w || b > kRoomCells - thing.d) return false;
  if (thing.flat) return true;
  for (final o in things) {
    if (o.key != thing.key && !o.wall && !o.flat && o.overlaps(a, b, thing.w, thing.d)) return false;
  }
  return true;
}

/// 둘 수 있는 자리 중 ([preferA], [preferB])에서 가장 가까운 곳. 없으면 null.
(int, int)? freeSpot(String roomId, int stage, List<PlacedThing> things, PlacedThing thing,
    {int? preferA, int? preferB}) {
  final pa = preferA ?? (thing.wall ? (kRoomCells - thing.w) ~/ 2 : (kRoomCells - thing.w) ~/ 2);
  final pb = preferB ?? (thing.wall ? 12 : (kRoomCells - thing.d) ~/ 2);
  (int, int)? best;
  var bestDist = 1 << 30;
  final maxB = thing.wall ? kWallCells : kRoomCells;
  for (var a = 0; a <= kRoomCells; a++) {
    for (var b = 0; b <= maxB; b++) {
      final dist = (a - pa) * (a - pa) + (b - pb) * (b - pb);
      if (dist >= bestDist) continue;
      if (fits(roomId, stage, things, thing, a, b)) {
        best = (a, b);
        bestDist = dist;
      }
    }
  }
  return best;
}

/// 캐릭터가 서는 칸. 원래 자리가 막혀 있으면 가장 가까운 빈 칸. 캐릭터는 3×2칸을 차지한다.
(int, int) buddySpot(String roomId, List<PlacedThing> things) {
  final art = kRoomArt[roomId];
  final px = art?.buddyX ?? kRoomCells ~/ 2;
  final py = art?.buddyY ?? kRoomCells ~/ 2;
  bool free(int x, int y) {
    if (x < 2 || y < 2 || x > kRoomCells - 3 || y > kRoomCells - 2) return false;
    for (final o in things) {
      if (!o.wall && !o.flat && o.overlaps(x - 1, y - 1, 3, 2)) return false;
    }
    return true;
  }

  if (free(px, py)) return (px, py);
  (int, int) best = (px, py);
  var bestDist = 1 << 30;
  for (var x = 0; x < kRoomCells; x++) {
    for (var y = 0; y < kRoomCells; y++) {
      final dist = (x - px) * (x - px) + (y - py) * (y - py);
      if (dist < bestDist && free(x, y)) {
        best = (x, y);
        bestDist = dist;
      }
    }
  }
  return best;
}

/// 바닥에서 칸을 차지하는 상자 하나 (앞뒤 계산용).
class FloorBox {
  const FloorBox(this.x, this.y, this.w, this.d);
  final int x;
  final int y;
  final int w;
  final int d;
}

/// 뒤에 있는 것부터 그리는 순서. 화면에서 아래(x, y가 큰 쪽)일수록 앞이다.
/// 칸이 겹치지 않는 두 물건은 한 축에서 완전히 떨어져 있으므로 그 축으로 앞뒤를 정한다.
List<int> paintOrder(List<FloorBox> boxes) {
  final n = boxes.length;
  bool behind(FloorBox p, FloorBox q) {
    final px = p.x + p.w <= q.x;
    final py = p.y + p.d <= q.y;
    final qx = q.x + q.w <= p.x;
    final qy = q.y + q.d <= p.y;
    if ((px && !qy) || (py && !qx)) return true;
    if ((qx && !py) || (qy && !px)) return false;
    if (px || py || qx || qy) return false; // 화면에서 안 겹친다
    // 칸이 겹치면(캐릭터 등) 가운데 위치로
    return (p.x * 2 + p.w + p.y * 2 + p.d) < (q.x * 2 + q.w + q.y * 2 + q.d);
  }

  final before = List.generate(n, (_) => <int>[]);
  final indegree = List.filled(n, 0);
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      if (i != j && behind(boxes[i], boxes[j])) {
        before[i].add(j);
        indegree[j]++;
      }
    }
  }
  int key(int i) => boxes[i].x + boxes[i].y;
  final done = List.filled(n, false);
  final order = <int>[];
  while (order.length < n) {
    var pick = -1;
    for (var i = 0; i < n; i++) {
      if (done[i] || indegree[i] != 0) continue;
      if (pick < 0 || key(i) < key(pick)) pick = i;
    }
    if (pick < 0) {
      // 순환이 생기면 남은 것 중 가장 뒤에 있는 것부터
      for (var i = 0; i < n; i++) {
        if (!done[i] && (pick < 0 || key(i) < key(pick))) pick = i;
      }
    }
    done[pick] = true;
    order.add(pick);
    for (final j in before[pick]) {
      indegree[j]--;
    }
  }
  return order;
}
