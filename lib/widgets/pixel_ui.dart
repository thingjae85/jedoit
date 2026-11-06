import 'package:flutter/material.dart';

import '../theme.dart';

/// 도트 그림과 어울리게 모서리를 계단처럼 깎은 네모.
/// [step]은 계단 한 칸 크기, [steps]는 계단 수다. 테두리는 안쪽으로 그린다.
class PixelBorder extends OutlinedBorder {
  const PixelBorder({this.step = 3, this.steps = 2, super.side});

  final double step;
  final int steps;

  @override
  PixelBorder copyWith({BorderSide? side}) => PixelBorder(step: step, steps: steps, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect r) {
    final s = step;
    final n = steps;
    final path = Path();
    final pts = <Offset>[];
    // 왼쪽 위 → 오른쪽 위 → 오른쪽 아래 → 왼쪽 아래 (시계 방향)
    for (var i = 0; i < n; i++) {
      pts.add(Offset(r.left + i * s, r.top + (n - i) * s));
      pts.add(Offset(r.left + (i + 1) * s, r.top + (n - i) * s));
    }
    pts.add(Offset(r.left + n * s, r.top));
    pts.add(Offset(r.right - n * s, r.top));
    for (var i = 0; i < n; i++) {
      pts.add(Offset(r.right - (n - i) * s, r.top + (i + 1) * s));
      pts.add(Offset(r.right - (n - i - 1) * s, r.top + (i + 1) * s));
    }
    pts.add(Offset(r.right, r.bottom - n * s));
    for (var i = 0; i < n; i++) {
      pts.add(Offset(r.right - (i + 1) * s, r.bottom - (n - i - 1) * s - s));
      pts.add(Offset(r.right - (i + 1) * s, r.bottom - (n - i - 1) * s));
    }
    pts.add(Offset(r.left + n * s, r.bottom));
    for (var i = 0; i < n; i++) {
      pts.add(Offset(r.left + (n - i) * s, r.bottom - (i + 1) * s));
      pts.add(Offset(r.left + (n - i - 1) * s, r.bottom - (i + 1) * s));
    }
    path.addPolygon(pts, true);
    return path;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), paint);
  }

  @override
  ShapeBorder scale(double t) => PixelBorder(step: step * t, steps: steps, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is PixelBorder && other.step == step && other.steps == steps && other.side == side;

  @override
  int get hashCode => Object.hash(step, steps, side);
}

/// 계단 모서리 판. 홈과 꾸미기 화면의 묶음 상자에 쓴다.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.color = JdColors.paperDeep,
    this.padding = EdgeInsets.zero,
    this.border,
    this.step = 3,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final double step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: color,
        shape: PixelBorder(
          step: step,
          side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5),
        ),
      ),
      child: child,
    );
  }
}

/// 작은 도트 그림을 칸마다 칠한다. [rows]의 글자 하나가 한 칸이고, [palette]에 없는 글자는 비운다.
class PixelGlyph extends StatelessWidget {
  const PixelGlyph({super.key, required this.rows, required this.palette, this.size = 14});

  final List<String> rows;
  final Map<String, Color> palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return SizedBox(
      width: size * cols / rows.length,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(rows, palette)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.rows, this.palette);
  final List<String> rows;
  final Map<String, Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / rows.length;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final c = palette[rows[y][x]];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.3, cell + 0.3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.rows != rows || old.palette != palette;
}

/// 도트 코인.
class PixelCoin extends StatelessWidget {
  const PixelCoin({super.key, this.size = 14});
  final double size;

  static const _rows = [
    '..oooo..',
    '.oyyyyo.',
    'oyywyyyo',
    'oywyyddo',
    'oyyyyddo',
    'oyyyddyo',
    '.oddddo.',
    '..oooo..',
  ];
  static const _palette = {
    'o': Color(0xFF8A5A1E),
    'y': Color(0xFFF2C14E),
    'w': Color(0xFFFFF1C2),
    'd': Color(0xFFD9982B),
  };

  @override
  Widget build(BuildContext context) => PixelGlyph(rows: _rows, palette: _palette, size: size);
}

/// 도트 체크 칸. 다 하면 나무색으로 채우고 도트 체크를 넣는다.
class PixelCheck extends StatelessWidget {
  const PixelCheck({super.key, required this.checked, this.size = 24});
  final bool checked;
  final double size;

  static const markRows = [
    '..........',
    '..........',
    '.......w..',
    '......ww..',
    '..w..ww...',
    '..wwww....',
    '...ww.....',
    '..........',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: checked ? JdColors.leaf : JdColors.paper,
        shape: PixelBorder(
          step: size / 12,
          steps: 1,
          side: BorderSide(color: checked ? JdColors.leafDeep : JdColors.seamDark, width: 2),
        ),
      ),
      child: checked
          ? PixelGlyph(rows: markRows, palette: const {'w': Colors.white}, size: size * 0.62)
          : null,
    );
  }
}

/// 섹션 제목: 왼쪽 굵은 제목, 오른쪽 작은 설명이나 버튼.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.note, this.trailing});

  final String title;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: JdColors.ink)),
          if (note != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: JdColors.subtle)),
              ),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 작은 테두리 버튼 (다른 걸로 같은 보조 동작).
class TinyButton extends StatelessWidget {
  const TinyButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const shape = PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.seamDark, width: 1.5));
    return Material(
      color: JdColors.paper,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: JdColors.woodText),
                const SizedBox(width: 4),
              ],
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: JdColors.woodText)),
            ],
          ),
        ),
      ),
    );
  }
}
