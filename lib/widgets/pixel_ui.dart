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
    // 게임 창처럼 짙은 테두리와 아래 두께. 따로 테두리 색을 주면 얇은 판으로 그린다.
    if (border == null) {
      return GamePanel(
        color: color == JdColors.paperDeep ? JdColors.cream : color,
        lip: JdColors.creamLip,
        padding: padding,
        step: step,
        depth: 3,
        child: child,
      );
    }
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: color,
        shape: PixelBorder(step: step, side: BorderSide(color: border!, width: 1.5)),
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
          Text(title, style: gameText(size: 16)),
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
  Widget build(BuildContext context) => GameButton(
        small: true,
        label: label,
        icon: icon == null ? null : Icon(icon, size: 13, color: JdColors.outline),
        color: JdColors.cream,
        lip: JdColors.creamLip,
        onTap: onTap,
      );
}

// ---------- 게임 화면 부품 ----------

/// 앱 전체 글꼴 (페이퍼로지). 없는 글자는 기기 기본 글꼴로 대신 그린다.
const kAppFont = 'Paperlogy';

/// 제목·버튼·숫자에 쓰는 글꼴. 지금은 본문과 같은 앱 글꼴을 쓴다.
const kGameFont = kAppFont;

TextStyle gameText({double size = 12, Color color = JdColors.ink, double? height}) => TextStyle(
      fontFamily: kGameFont,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: height,
      letterSpacing: 0,
    );

/// 짙은 테두리를 두르고 아래에 두께가 보이는 판. 게임 창처럼 보인다.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.color = JdColors.cream,
    this.lip = JdColors.creamLip,
    this.padding = EdgeInsets.zero,
    this.depth = 4,
    this.step = 3,
  });

  final Widget child;
  final Color color;
  final Color lip;
  final EdgeInsetsGeometry padding;
  final double depth;
  final double step;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: lip,
        shape: PixelBorder(step: step, steps: 2, side: const BorderSide(color: JdColors.outline, width: 2)),
      ),
      padding: EdgeInsets.fromLTRB(2, 2, 2, 2 + depth),
      child: Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(color: color, shape: PixelBorder(step: step - 1, steps: 2)),
        child: child,
      ),
    );
  }
}

/// 누르면 쑥 들어가는 두툼한 도트 버튼.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = JdColors.woodLight,
    this.lip = JdColors.woodDeep,
    this.textColor = JdColors.outline,
    this.small = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final Color color;
  final Color lip;
  final Color textColor;
  final bool small;

  /// 가로를 꽉 채울지.
  final bool expand;

  static const green = (JdColors.leaf, JdColors.leafLip, JdColors.cream);
  static const wood = (JdColors.woodLight, JdColors.woodDeep, JdColors.outline);
  static const cream = (JdColors.cream, JdColors.creamLip, JdColors.outline);

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final depth = widget.small ? 3.0 : 4.0;
    final pressed = _down && on;
    final face = on ? widget.color : JdColors.seam;
    final lip = on ? widget.lip : JdColors.seamDark;
    final text = on ? widget.textColor : JdColors.faint;
    final label = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 5)],
        Flexible(
          child: Text(widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: gameText(size: widget.small ? 12 : 14, color: text)),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            decoration: ShapeDecoration(
              color: lip,
              shape: const PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.outline, width: 2)),
            ),
            padding: EdgeInsets.fromLTRB(2, 2 + (pressed ? depth - 1 : 0), 2, 2 + (pressed ? 1 : depth)),
            child: Container(
              constraints: BoxConstraints(minHeight: widget.small ? 26 : 34),
              alignment: widget.expand ? Alignment.center : null,
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 9 : 14, vertical: widget.small ? 4 : 7),
              decoration: ShapeDecoration(
                color: face,
                shape: const PixelBorder(step: 1, steps: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [label],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 서랍 손잡이 같은 탭 줄. 고른 탭이 아래 판과 이어져 보인다.
class GameTabs extends StatelessWidget {
  const GameTabs({super.key, required this.tabs, required this.selected, required this.onSelect});

  /// (이름, 도트 아이콘)
  final List<(String, Widget)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _tab(i)),
        ],
      ],
    );
  }

  Widget _tab(int i) {
    final on = i == selected;
    final (name, icon) = tabs[i];
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: Container(
          key: ValueKey('tab-$name'),
          height: on ? 50 : 44,
          padding: const EdgeInsets.only(top: 2),
          decoration: ShapeDecoration(
            color: on ? JdColors.cream : JdColors.woodLight,
            shape: _TabBorder(on: on),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(opacity: on ? 1 : 0.7, child: icon),
              const SizedBox(height: 3),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: gameText(size: 12, color: on ? JdColors.outline : JdColors.woodText)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 위 모서리만 계단으로 깎고, 아래는 열린 탭 테두리. 안 고른 탭은 아래도 닫는다.
class _TabBorder extends ShapeBorder {
  const _TabBorder({required this.on});
  final bool on;

  static const _s = 3.0;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);

  Path _path(Rect r) => Path()
    ..moveTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + _s * 2)
    ..lineTo(r.left + _s, r.top + _s * 2)
    ..lineTo(r.left + _s, r.top + _s)
    ..lineTo(r.left + _s * 2, r.top + _s)
    ..lineTo(r.left + _s * 2, r.top)
    ..lineTo(r.right - _s * 2, r.top)
    ..lineTo(r.right - _s * 2, r.top + _s)
    ..lineTo(r.right - _s, r.top + _s)
    ..lineTo(r.right - _s, r.top + _s * 2)
    ..lineTo(r.right, r.top + _s * 2)
    ..lineTo(r.right, r.bottom)
    ..close();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(2));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = JdColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = rect.deflate(1);
    final p = _path(r);
    if (on) {
      // 아래 변은 그리지 않는다: 열린 경로로 다시 만든다.
      final open = Path()
        ..moveTo(r.left, r.bottom + 1)
        ..lineTo(r.left, r.top + _s * 2)
        ..lineTo(r.left + _s, r.top + _s * 2)
        ..lineTo(r.left + _s, r.top + _s)
        ..lineTo(r.left + _s * 2, r.top + _s)
        ..lineTo(r.left + _s * 2, r.top)
        ..lineTo(r.right - _s * 2, r.top)
        ..lineTo(r.right - _s * 2, r.top + _s)
        ..lineTo(r.right - _s, r.top + _s)
        ..lineTo(r.right - _s, r.top + _s * 2)
        ..lineTo(r.right, r.top + _s * 2)
        ..lineTo(r.right, r.bottom + 1);
      canvas.drawPath(open, paint);
    } else {
      canvas.drawPath(p, paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// 도트 연필. 이름을 바꿀 수 있다는 표시.
class PixelPencil extends StatelessWidget {
  const PixelPencil({super.key, this.size = 14, this.light = false});
  final double size;

  /// 어두운 바탕 위에서 쓸 때.
  final bool light;

  static const rows = [
    '......oo',
    '.....oppo',
    '....oyyo.',
    '...oyyo..',
    '..oyyo...',
    '.oyyo....',
    'owwo.....',
    'oko......',
  ];

  @override
  Widget build(BuildContext context) => PixelGlyph(
        rows: rows,
        palette: {
          'o': light ? const Color(0xFF0E1822) : JdColors.outline,
          'p': const Color(0xFFE88E98),
          'y': const Color(0xFFF2C14E),
          'w': const Color(0xFFF3E1C0),
          'k': light ? JdColors.cream : JdColors.outline,
        },
        size: size,
      );
}

/// 방 이름 + 연필. 누르면 이름을 바꾼다.
class RoomNameButton extends StatelessWidget {
  const RoomNameButton({super.key, required this.name, required this.onTap, this.onDark = false, this.size = 16});

  final String name;
  final VoidCallback? onTap;
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : JdColors.ink;
    return Semantics(
      button: onTap != null,
      label: '방 이름 바꾸기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(name,
                      key: const Key('roomName'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gameText(size: size, color: color)),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: ShapeDecoration(
                      color: onDark ? JdColors.cream : JdColors.woodLight,
                      shape: const PixelBorder(
                          step: 2, steps: 1, side: BorderSide(color: JdColors.outline, width: 1.5)),
                    ),
                    child: PixelPencil(size: size * 0.75),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 방 이름 바꾸기 창. 고른 이름(빈 문자열이면 처음 이름으로)을 돌려준다. 닫으면 null.
Future<String?> showRoomNameDialog(BuildContext context, {required String current, required int max}) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GamePanel(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const PixelPencil(size: 16),
                const SizedBox(width: 8),
                Text('방 이름 바꾸기', style: gameText(size: 16)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('roomNameField'),
              controller: controller,
              autofocus: true,
              maxLength: max,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
              style: gameText(size: 16),
              decoration: const InputDecoration(
                hintText: '예: 내 작업실',
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: JdColors.outline, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: JdColors.outline, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: JdColors.wood, width: 2),
                ),
              ),
            ),
            const Text('비워 두면 처음 이름으로 돌아가요', style: TextStyle(fontSize: 12, color: JdColors.faint)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: '그만두기',
                    expand: true,
                    color: JdColors.paperDeep,
                    lip: JdColors.seamDark,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    label: '바꾸기',
                    expand: true,
                    color: JdColors.leaf,
                    lip: JdColors.leafLip,
                    textColor: JdColors.cream,
                    onTap: () => Navigator.of(ctx).pop(controller.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 꾸미기 탭 아이콘들 (8×8 도트).
abstract final class TabGlyphs {
  static const _o = JdColors.outline;

  static Widget surface({double size = 14}) => PixelGlyph(
        rows: const ['oooooooo', 'oaabbaao', 'oaabbaao', 'obbaabbo', 'obbaabbo', 'oaabbaao', 'oaabbaao', 'oooooooo'],
        palette: const {'o': _o, 'a': Color(0xFFF3EEE4), 'b': Color(0xFF8FB3CF)},
        size: size,
      );

  static Widget wall({double size = 14}) => PixelGlyph(
        rows: const ['...oo...', '..o..o..', 'oooooooo', 'osssssyo', 'osssssso', 'osgsssgo', 'oggggggo', 'oooooooo'],
        palette: const {
          'o': _o,
          's': Color(0xFF9FD0EF),
          'y': Color(0xFFF7D65A),
          'g': Color(0xFF6FB85A),
        },
        size: size,
      );

  static Widget furniture({double size = 14}) => PixelGlyph(
        rows: const ['.oooooo.', '.owwwwo.', '.owwwwo.', 'oowwwwoo', 'orrrrrro', 'oooooooo', '.o....o.', '.o....o.'],
        palette: const {'o': _o, 'w': Color(0xFFE8A87C), 'r': Color(0xFFC9734A)},
        size: size,
      );

  static Widget buddy({double size = 14}) => PixelGlyph(
        rows: const ['oo....oo', 'obo..obo', '.oooooo.', 'obbbbbbo', 'obobbobo', 'obbwwbbo', '.obbbbo.', '..oooo..'],
        palette: const {'o': _o, 'b': Color(0xFFD9985A), 'w': Color(0xFFF6E2C4)},
        size: size,
      );
}

/// 코인 수. 게임 화면 위쪽 재화 칸처럼 테두리를 두른다.
class CoinCounter extends StatelessWidget {
  const CoinCounter({super.key, required this.coins, this.textKey, this.prefix = ''});

  final int coins;
  final Key? textKey;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GamePanel(
        color: JdColors.cream,
        lip: JdColors.creamLip,
        depth: 3,
        step: 2,
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelCoin(size: 16),
            const SizedBox(width: 6),
            Text('$prefix$coins',
                key: textKey,
                style: gameText(size: 14, color: JdColors.woodText).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ),
    );
  }
}
