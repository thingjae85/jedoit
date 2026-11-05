import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/space.dart';
import '../models/space_art.dart';

/// 방 하나. 미리 그린 단계 그림 위에 액자 사진과 캐릭터를 얹는다.
class RoomPicture extends StatelessWidget {
  const RoomPicture(
      {super.key, required this.roomId, required this.stage, required this.buddy, this.photo, this.showBuddy = true});

  final String roomId;
  final int stage;
  final Buddy buddy;

  /// 벽 액자에 걸 8×8 도트 사진 (0xAARRGGBB). 없으면 액자도 없다.
  final List<int>? photo;
  final bool showBuddy;

  @override
  Widget build(BuildContext context) {
    final art = kRoomArt[roomId]!;
    final st = stage < 0 ? 0 : (stage >= art.stages ? art.stages - 1 : stage);
    final spot = art.buddySpots[st];
    return AspectRatio(
      aspectRatio: kRoomArtWidth / kRoomArtHeight,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth / kRoomArtWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/space/${roomId}_$st.png',
                  filterQuality: FilterQuality.none, fit: BoxFit.fill, gaplessPlayback: true),
            ),
            if (photo != null)
              Positioned.fill(
                child: CustomPaint(painter: _FramePainter(photo!, art.frameX, art.frameZ, s)),
              ),
            if (showBuddy)
              Positioned(
                left: spot.$1 * s,
                top: spot.$2 * s,
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
  const HivePicture({super.key, required this.state, required this.buddy, required this.shownRoom, this.photo, this.onTapRoom});

  final SpaceState state;
  final Buddy buddy;

  /// 캐릭터와 액자는 이 방에만 둔다.
  final String shownRoom;
  final List<int>? photo;
  final ValueChanged<String>? onTapRoom;

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
                        ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
