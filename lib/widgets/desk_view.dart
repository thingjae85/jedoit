import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 공동 책상: 책상 위 물건 T개 중 정리된 H개는 가지런히, 나머지는 흐트러져 보인다.
/// 이탈로 T가 줄어도 이미 정리된 요소는 남는다(H가 T보다 많아질 수 있음).
class DeskView extends StatelessWidget {
  const DeskView({super.key, required this.total, required this.tidied});

  final int total;
  final int tidied;

  @override
  Widget build(BuildContext context) {
    final count = math.max(total, tidied);
    return Semantics(
      label: '공동 책상, 물건 $count개 중 ${math.min(tidied, count)}개 정리됨',
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: CustomPaint(
          painter: _DeskPainter(
            count: count,
            tidied: math.min(tidied, count),
            colors: Theme.of(context).colorScheme,
          ),
        ),
      ),
    );
  }
}

class _DeskPainter extends CustomPainter {
  _DeskPainter({required this.count, required this.tidied, required this.colors});

  final int count;
  final int tidied;
  final ColorScheme colors;

  static const _itemColors = [
    Color(0xFFE8C56C), Color(0xFF7FB3A3), Color(0xFFE59B8B), Color(0xFF8FA7D6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 벽과 책상
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF3EFE6));
    final top = Rect.fromLTWH(w * 0.04, h * 0.62, w * 0.92, h * 0.08);
    canvas.drawRRect(RRect.fromRectAndRadius(top, const Radius.circular(6)), Paint()..color = const Color(0xFFB98B5E));
    final leg = Paint()..color = const Color(0xFF9A7049);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.70, w * 0.04, h * 0.3), leg);
    canvas.drawRect(Rect.fromLTWH(w * 0.86, h * 0.70, w * 0.04, h * 0.3), leg);
    if (count == 0) return;

    // 정리된 물건은 책상 위에 한 줄로, 흐트러진 물건은 기울어져 겹친다
    final slot = (w * 0.86) / math.max(count, 6);
    final itemW = slot * 0.7;
    for (var i = 0; i < count; i++) {
      final color = _itemColors[i % _itemColors.length];
      final itemH = h * (0.18 + (i % 3) * 0.05);
      final done = i < tidied;
      canvas.save();
      if (done) {
        final x = w * 0.07 + slot * i;
        canvas.translate(x + itemW / 2, top.top);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-itemW / 2, -itemH, itemW, itemH), const Radius.circular(3)),
          Paint()..color = color,
        );
      } else {
        // 위치·각도는 순서로 정해 매번 같은 모양이 나오게 한다
        // 정리된 줄 오른쪽 빈자리에만 흩어 놓아 정리된 물건과 겹치지 않게 한다
        final rnd = math.Random(i * 7919 + 13);
        final from = w * 0.07 + slot * tidied + itemW / 2;
        final to = w * 0.93 - itemW / 2;
        final x = from + rnd.nextDouble() * math.max(0, to - from);
        final y = top.top - h * (0.02 + rnd.nextDouble() * 0.06);
        canvas.translate(x, y);
        canvas.rotate((rnd.nextDouble() - 0.5) * 1.6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-itemW / 2, -itemH * 0.4, itemW, itemH * 0.6), const Radius.circular(3)),
          Paint()..color = color.withValues(alpha: 0.55),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DeskPainter old) => old.count != count || old.tidied != tidied;
}
