import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/layout.dart';
import '../models/space.dart';
import '../models/space_art.dart';

/// 방 하나. 껍데기(바닥·벽·창문) 위에 벽 소품과 액자, 그다음 가구·소품·캐릭터를
/// 바닥 칸 위치로 계산한 앞뒤 순서대로 얹는다.
class RoomPicture extends StatelessWidget {
  const RoomPicture({
    super.key,
    required this.roomId,
    required this.stage,
    required this.buddy,
    this.photo,
    this.showBuddy = true,
    this.night = false,
    this.decor = const DecorData(),
    this.things,
    this.selectedKey,
    this.selectionValid = true,
    this.buddyAt,
    this.lifted = false,
  });

  final String roomId;
  final int stage;
  final Buddy buddy;

  /// 벽 액자에 걸 8×8 도트 사진 (0xAARRGGBB). 없으면 액자도 없다.
  final List<int>? photo;
  final bool showBuddy;

  /// 밤 그림(불 켜진 스탠드·무드등)을 쓸지.
  final bool night;

  /// 산 소품과 배치.
  final DecorData decor;

  /// 옮기는 중일 때 미리 계산한 배치. 없으면 [decor]로 계산한다.
  final List<PlacedThing>? things;

  /// 고른 물건. 바닥(또는 벽)에 차지하는 칸을 표시한다.
  final String? selectedKey;
  final bool selectionValid;

  /// 옮기는 중인 캐릭터 자리. 없으면 [decor]에 저장된 자리.
  final (int, int)? buddyAt;

  /// 고른 물건을 손으로 들어 올린 것처럼 조금 띄워 그린다 (끄는 중).
  final bool lifted;

  /// 캐릭터를 가리키는 [selectedKey].
  static const buddyKey = 'buddy';

  int get _stage {
    final art = kRoomArt[roomId]!;
    return stage < 0 ? 0 : (stage >= art.stages ? art.stages - 1 : stage);
  }

  @override
  Widget build(BuildContext context) {
    final art = kRoomArt[roomId]!;
    final st = _stage;
    final list = things ?? thingsIn(roomId, st, decor);
    final walls = [for (final t in list) if (t.wall) t];
    final flats = [for (final t in list) if (!t.wall && t.flat) t]..sort((p, q) => (p.a + p.b).compareTo(q.a + q.b));
    final blockers = [for (final t in list) if (!t.wall && !t.flat) t];
    final (bx, by) = buddyAt ?? buddySpot(roomId, list, prefer: decor.layoutOf(roomId).buddy);
    final order = paintOrder([
      for (final t in blockers) FloorBox(t.a, t.b, t.w, t.d),
      if (showBuddy) FloorBox(bx - 1, by - 1, 3, 2),
    ]);
    _Footprint? selected;
    for (final t in list) {
      if (t.key == selectedKey) selected = _Footprint(t.wall, t.a, t.b, t.w, t.d);
    }
    if (selectedKey == buddyKey && showBuddy) selected = _Footprint(false, bx - 1, by - 1, 3, 2);
    const lift = 3; // 들어 올린 높이 (도트 픽셀)
    final shell = art.shells[st];
    return AspectRatio(
      aspectRatio: kRoomArtWidth / kRoomArtHeight,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth / kRoomArtWidth;
        Widget sprite(PlacedThing t) {
          final (l, top, w, h) = t.rect(atNight: night);
          final up = lifted && t.key == selectedKey ? lift : 0;
          return Positioned(
            key: ValueKey(t.key),
            left: l * s,
            top: (top - up) * s,
            width: w * s,
            height: h * s,
            child: Image.asset(night ? t.night.asset : t.day.asset,
                filterQuality: FilterQuality.none, fit: BoxFit.fill, gaplessPlayback: true),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(night ? shell.$2 : shell.$1,
                  filterQuality: FilterQuality.none, fit: BoxFit.fill, gaplessPlayback: true),
            ),
            for (final t in walls) sprite(t),
            if (photo != null)
              Positioned.fill(
                child: CustomPaint(painter: _FramePainter(photo!, art.frameX, art.frameZ, s)),
              ),
            for (final t in flats) sprite(t),
            if (selected != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _FootprintPainter(selected, s, selectionValid)),
                ),
              ),
            for (final i in order)
              if (i < blockers.length)
                sprite(blockers[i])
              else
                Positioned(
                  key: const ValueKey(buddyKey),
                  left: (kRoomOriginX + (bx - by) * 2 - 11) * s,
                  top: (kRoomOriginY + bx + by - kBuddyArtHeight - (lifted && selectedKey == buddyKey ? lift : 0)) * s,
                  width: kBuddyArtWidth * s,
                  height: kBuddyArtHeight * s,
                  child: Image.asset(buddy.asset, filterQuality: FilterQuality.none, fit: BoxFit.fill),
                ),
          ],
        );
      }),
    );
  }
}

/// 칸 위치: 바닥이면 (x, y, 너비, 깊이), 벽이면 (y, z, 너비, 높이).
class _Footprint {
  const _Footprint(this.wall, this.a, this.b, this.w, this.d);
  final bool wall;
  final int a;
  final int b;
  final int w;
  final int d;
}

/// 고른 물건이 차지하는 칸: 바닥이면 마름모, 벽이면 비스듬한 사각형.
class _FootprintPainter extends CustomPainter {
  _FootprintPainter(this.thing, this.scale, this.valid);

  final _Footprint thing;
  final double scale;
  final bool valid;

  Offset _floor(int x, int y) =>
      Offset((kRoomOriginX + 2 * (x - y)) * scale, (kRoomOriginY + x + y) * scale);

  Offset _wall(int y, int z) =>
      Offset((kRoomOriginX - 2 * y - 2) * scale, (kRoomOriginY + y - 2 * z + 1) * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final t = thing;
    final pts = t.wall
        ? [_wall(t.a, t.b + t.d), _wall(t.a + t.w, t.b + t.d), _wall(t.a + t.w, t.b), _wall(t.a, t.b)]
        : [_floor(t.a, t.b), _floor(t.a + t.w, t.b), _floor(t.a + t.w, t.b + t.d), _floor(t.a, t.b + t.d)];
    final path = Path()..addPolygon(pts, true);
    final color = valid ? const Color(0xFF4FD18B) : const Color(0xFFFF5A5A);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FootprintPainter old) =>
      old.thing.wall != thing.wall || old.thing.a != thing.a || old.thing.b != thing.b ||
      old.scale != scale || old.valid != valid;
}

/// 오른쪽 뒷벽에 거는 10×10칸 액자(테두리 1칸 + 사진 8×8). 벽 기울기에 맞춰 칸을 비스듬히 그린다.
class _FramePainter extends CustomPainter {
  _FramePainter(this.pixels, this.x0, this.z0, this.scale);

  final List<int> pixels;
  final int x0;
  final int z0;
  final double scale;

  static const _edge = Color(0xFFF3E6CC);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < 10; i++) {
      for (var k = 0; k < 10; k++) {
        final edge = i == 0 || i == 9 || k == 0 || k == 9;
        paint.color = edge ? _edge : Color(pixels[(8 - k) * 8 + (i - 1)]);
        final x = x0 + i;
        final z = z0 + k;
        final px = kRoomOriginX + 2 * x;
        final py = kRoomOriginY + (x - 1) - 2 * z + 2;
        final path = Path()
          ..moveTo(px * scale, py * scale)
          ..lineTo((px + 2) * scale, (py + 1) * scale)
          ..lineTo((px + 2) * scale, (py + 3) * scale)
          ..lineTo(px * scale, (py + 2) * scale)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.pixels != pixels || old.scale != scale || old.x0 != x0 || old.z0 != z0;
}

/// 벌집 보기: 방들이 육각형으로 붙어 있다. 아직 안 열린 칸은 닫힌 문.
class HivePicture extends StatelessWidget {
  const HivePicture({
    super.key,
    required this.state,
    required this.buddy,
    required this.shownRoom,
    this.photo,
    this.onTapRoom,
    this.night = false,
    this.decor = const DecorData(),
  });

  final SpaceState state;
  final Buddy buddy;

  /// 캐릭터와 액자는 이 방에만 둔다.
  final String shownRoom;
  final List<int>? photo;
  final ValueChanged<String>? onTapRoom;
  final bool night;
  final DecorData decor;

  static const lockedText = '문 너머에 뭔가 있어요';

  /// 칸 위치(도트 픽셀): 첫 방은 아래 가운데, 두 번째 방은 오른쪽 위, 그다음은 왼쪽 위.
  static const _cells = [(kHiveDx / 2, kHiveDy), (kHiveDx, 0.0), (0.0, 0.0)];

  @override
  Widget build(BuildContext context) {
    const w = kRoomArtWidth + kHiveDx;
    const h = kRoomArtHeight + kHiveDy;
    return AspectRatio(
      aspectRatio: w / h,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth / w;
        final slots = <(String?, (double, double))>[
          for (var i = 0; i < _cells.length; i++)
            (i < kSpaceRooms.length && state.isOpen(kSpaceRooms[i].id) ? kSpaceRooms[i].id : null, _cells[i]),
        ];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onTapRoom == null
              ? null
              : (d) {
                  final p = d.localPosition / s;
                  String? best;
                  var bestDist = double.infinity;
                  for (final (id, (x, y)) in slots) {
                    final cx = x + kRoomArtWidth / 2;
                    final cy = y + kRoomArtHeight / 2;
                    final dist = (p.dx - cx) * (p.dx - cx) + (p.dy - cy) * (p.dy - cy);
                    if (dist < bestDist) {
                      bestDist = dist;
                      best = id;
                    }
                  }
                  if (best != null) onTapRoom!(best);
                },
          child: Stack(
            children: [
              for (final (id, (x, y)) in slots)
                Positioned(
                  left: x * s,
                  top: y * s,
                  width: kRoomArtWidth * s,
                  height: kRoomArtHeight * s,
                  child: id == null
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset('assets/space/locked.png',
                                  filterQuality: FilterQuality.none, fit: BoxFit.fill),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: kRoomArtHeight * s * 0.62,
                              child: const Text(lockedText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Color(0xFFAAB9CC))),
                            ),
                          ],
                        )
                      : RoomPicture(
                          roomId: id,
                          stage: state.stageOf(id),
                          buddy: buddy,
                          photo: id == shownRoom ? photo : null,
                          showBuddy: id == shownRoom,
                          night: night,
                          decor: decor,
                        ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
