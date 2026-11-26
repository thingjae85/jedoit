import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'pixel_ui.dart';

/// 지금 고른 스킨과 바꾸는 방법을 아래 화면에 알려 준다.
class JdSkinScope extends InheritedWidget {
  const JdSkinScope({super.key, required this.skin, required this.onChange, required super.child});

  final JdSkin skin;
  final ValueChanged<JdSkin> onChange;

  static JdSkinScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<JdSkinScope>();

  @override
  bool updateShouldNotify(JdSkinScope old) => old.skin != skin;
}

/// 바다 스킨 움직임. 테스트처럼 화면이 멈춰 있어야 할 때 끈다.
abstract final class SeaMotion {
  static bool enabled = true;
}

// ---------- 바다 스킨 도트 그림 ----------

/// 바다 스킨 그림. 한 글자가 한 칸이고, 점(.)은 비운다.
abstract final class SeaArt {
  static const blue = Color(0xFF5C80C6);
  static const blueDeep = Color(0xFF3E5A99);
  static const blueLight = Color(0xFFA0C4EC);
  static const coral = Color(0xFFFF8559);
  static const coralDeep = Color(0xFFD65E36);
  static const foam = Color(0xFFE9FAFD);
  static const water = [Color(0xFF7CCBDD), Color(0xFF5BB8CF), Color(0xFF47A8C2), Color(0xFF3896B2), Color(0xFF2D85A2)];
  static const waterBack = Color(0xFFA6DDEA);
  static const sand = Color(0xFFEFD9A2);
  static const sandDeep = Color(0xFFD9BC78);
  static const weed = Color(0xFF3E9A6A);
  static const weedDeep = Color(0xFF2C7550);

  static const sharkPalette = {'m': blue, 'd': blueDeep, 'l': blueLight, 'e': Color(0xFF141824)};

  /// 오른쪽을 보고 헤엄치는 상어 옆모습.
  static const shark = [
    '...............dd...........',
    '...............dmm..........',
    '..dd...........dmmm.........',
    '..dmm.........dmmmmmmmmm....',
    '...dmm....mmmmmmmmmmmmmmmm..',
    '...dmmm.mmmmmmmmmmmmmmmmmmm.',
    '....dmmmmmmmmmdmdmmmmmmmmemm',
    '....dmmmmmmmmmdmdmmmmmmmmmmm',
    '...dmm.dmmmmmmmmmmmmlllllldd',
    '..dmm...ddmmmmmmmmllllllldd.',
    '..dd.......dddddmmmm.dddd...',
    '.................ddm........',
  ];

  /// 물 위로 나온 등지느러미.
  static const fin = ['.....d', '....md', '...mmd', '..mmmd', '..mmmmd', '.mmmmmd', '.mmmmmmd', 'mmmmmmmd'];

  /// 인증 완료 도장 물고기.
  static const fish = ['...cc...c', '.ccccc.cc', 'ccKcccccc', 'cccccccc.', '.ccCcc.cc', '...cc...c'];
  static const fishPalette = {'c': coral, 'C': coralDeep, 'K': Color(0xFF12303D)};

  static const shell = [
    '...BBBB...',
    '..BbBBbB..',
    '.BbBbBbBb.',
    'BbBbBbBbBB',
    'BbBbBbBbBB',
    '.BBBBBBBB.',
    '...BBBB...'
  ];
  static const star = ['....y....', '...yy....', 'yyyyyyyyy', '.yyyyyyy.', '..yyyyy..', '.yyy.yyy.', 'yy.....yy'];
  static const crab = ['r.r...r.r', 'rr.....rr', '.rrwKwKr.', '.rrrrrrr.', 'rrRrrrRrr', 'r.r...r.r'];
  static const tabFish = ['...BB...B', '.BBBBB.BB', 'BBKBBBBBB', 'BBBBBBBB.', '.BBBBB.BB', '...BB...B'];
  static const weedRows = ['..g..', '..gG.', '.gG..', '.g...', '..g..', '..gG.', '.gG..', '.g...', '..g..', '..G..'];

  static Map<String, Color> tabPalette(bool on) => {
        'B': on ? const Color(0xFF1D6A86) : const Color(0xFF5C8C9C),
        'b': on ? const Color(0xFF7DBACA) : const Color(0xFFB4D3DB),
        'y': on ? const Color(0xFFF2B53A) : const Color(0xFFD9C48E),
        'r': on ? const Color(0xFFE0603F) : const Color(0xFFD99C8A),
        'R': on ? const Color(0xFFA8432B) : const Color(0xFFB98576),
        'K': const Color(0xFF12303D),
        'w': Colors.white,
      };
}

/// 상어 옆모습.
class SeaShark extends StatelessWidget {
  const SeaShark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => PixelGlyph(rows: SeaArt.shark, palette: SeaArt.sharkPalette, size: size);
}

/// 인증 완료 물고기 도장.
class SeaFish extends StatelessWidget {
  const SeaFish({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) => PixelGlyph(rows: SeaArt.fish, palette: SeaArt.fishPalette, size: size);
}

/// 아래 탭 아이콘 (홈 조개, 챌린지 물고기, 기록 불가사리, 마이 게).
class SeaTabIcon extends StatelessWidget {
  const SeaTabIcon({super.key, required this.index, this.selected = false});
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final rows = switch (index) { 0 => SeaArt.shell, 1 => SeaArt.tabFish, 2 => SeaArt.star, _ => SeaArt.crab };
    return SizedBox(
      width: 28,
      height: 24,
      child: Center(child: PixelGlyph(rows: rows, palette: SeaArt.tabPalette(selected), size: rows.length * 2.6)),
    );
  }
}

/// 제목 아래 물결 줄.
class SeaWaves extends StatelessWidget {
  const SeaWaves({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 6,
        width: double.infinity,
        child: CustomPaint(painter: _WavesPainter(color ?? JdColors.edgeStrong)),
      );
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..isAntiAlias = false;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x + 6, 0, 6, 3), p);
      canvas.drawRect(Rect.fromLTWH(x, 3, 6, 3), p);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => old.color != color;
}

/// 바다 바탕: 옅은 거품과 바닥 해초. 화면 내용 뒤에 깐다.
class SeaBackdrop extends StatelessWidget {
  const SeaBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!JdColors.ocean) return child;
    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _BackdropPainter()))),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF6F8), Color(0xFFD5ECF1)],
        ).createShader(Offset.zero & size),
    );
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..isAntiAlias = false;
    final spots = [(0.08, 0.14), (0.9, 0.1), (0.86, 0.36), (0.05, 0.58), (0.93, 0.64), (0.78, 0.82), (0.15, 0.88)];
    for (var i = 0; i < spots.length; i++) {
      final c = Offset(size.width * spots[i].$1, size.height * spots[i].$2);
      final u = i.isOdd ? 3.0 : 2.0;
      for (final o in const [(1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)]) {
        canvas.drawRect(Rect.fromLTWH(c.dx + o.$1 * u, c.dy + o.$2 * u, u, u), ring);
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

// ---------- 출렁이는 물 ----------

/// 계속 도는 물결 시계. 움직임을 끄면 한 장면에 멈춘다.
mixin _WaveClock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (SeaMotion.enabled) {
      clock.repeat();
    } else {
      clock.value = 0.2;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && clock.isAnimating) clock.stop();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

/// 물이 [value]만큼 차오르는 수조. 상어가 그 안에서 헤엄친다. 방의 함께 진행도에 쓴다.
class SeaTank extends StatefulWidget {
  const SeaTank({
    super.key,
    required this.value,
    required this.label,
    this.size = const Size(150, 118),
    this.sharkWidth,
    this.decorative = false,
  });

  final double value;
  final String label;
  final Size size;

  /// 상어 너비. 없으면 수조 너비의 절반쯤.
  final double? sharkWidth;

  /// 꾸밈 그림으로만 쓸 때. 읽어 주는 글을 붙이지 않는다.
  final bool decorative;

  @override
  State<SeaTank> createState() => _SeaTankState();
}

class _SeaTankState extends State<SeaTank> with SingleTickerProviderStateMixin, _WaveClock {
  @override
  Widget build(BuildContext context) {
    final v = widget.value.clamp(0.0, 1.0).toDouble();
    final tank = SizedBox.fromSize(
      size: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7FCFD),
          border: Border.all(color: JdColors.edgeStrong, width: 2),
        ),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: clock,
            builder: (context, _) {
              final t = clock.value * 2 * math.pi;
              final inner = Size(widget.size.width - 4, widget.size.height - 4);
              final surfaceY = inner.height - 10 - (inner.height - 22) * v;
              final sharkW = widget.sharkWidth ?? inner.width * 0.47;
              final sharkH = sharkW * SeaArt.shark.length / SeaArt.shark.first.length;
              // 물마루 아래부터 모래 위까지가 상어가 들어갈 만큼 깊을 때만 상어를 띄운다.
              final depth = inner.height - 10 - surfaceY - 6;
              final roomy = depth >= sharkH + 4;
              final bob = math.min(3.0, (depth - sharkH) / 2) * math.sin(t);
              final sharkTop = surfaceY + 6 + (depth - sharkH) / 2 + bob;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _TankPainter(t: t, level: v))),
                  if (roomy)
                    Positioned(
                      left: (inner.width - sharkW) / 2,
                      top: sharkTop,
                      child: ExcludeSemantics(child: SeaShark(size: sharkH)),
                    ),
                  if (widget.label.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 4,
                      child: ExcludeSemantics(
                        child: Text(widget.label,
                            style: gameText(size: 18, color: JdColors.woodText).copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (widget.decorative) return ExcludeSemantics(child: tank);
    return Semantics(label: '함께 진행도 ${widget.label}', child: tank);
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter({required this.t, required this.level});
  final double t;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const u = 2.0;
    final w = (size.width / u).floor();
    final h = (size.height / u).floor();
    final p = Paint()..isAntiAlias = false;
    void dot(int x, int y, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x * u, y * u, u, u), p);
    }

    final base = (h - 5 - (h - 11) * level).round();
    int surf(int i) => base + (2.2 * math.sin(i * 0.17 + t)).round();
    for (var i = 0; i < w; i++) {
      final b = base + (1.6 * math.sin(i * 0.21 - t + 2)).round() - 1;
      for (var y = b; y < h; y++) {
        dot(i, y, SeaArt.waterBack);
      }
      final s = surf(i);
      for (var y = s; y < h; y++) {
        dot(i, y, SeaArt.water[((y - base) / 9).floor().clamp(0, 4)]);
      }
      dot(i, s, SeaArt.foam);
      if ((i + (t / (2 * math.pi) * 11).floor()) % 11 < 3) dot(i, s + 1, const Color(0xFFC8EEF5));
    }
    // 빛줄기
    p.color = Colors.white.withValues(alpha: 0.13);
    for (var r = 0; r < 3; r++) {
      final ox = 10 + r * 24 + (2 * math.sin(t + r)).round();
      for (var y = base + 3; y < h - 6; y++) {
        canvas.drawRect(Rect.fromLTWH((ox + ((y - base) / 3).floor()) * u, y * u, u * 3, u), p);
      }
    }
    // 모래
    for (var i = 0; i < w; i++) {
      final sy = h - 5 + (i % 9 < 4 ? 0 : 1);
      for (var y = sy; y < h; y++) {
        dot(i, y, y == sy ? SeaArt.sandDeep : SeaArt.sand);
      }
    }
    // 해초
    for (final (x0, scale) in [(4, 1), (w - 8, 1)]) {
      for (var y = 0; y < SeaArt.weedRows.length; y++) {
        final row = SeaArt.weedRows[y];
        for (var x = 0; x < row.length; x++) {
          if (row[x] == '.') continue;
          dot(x0 + x * scale, h - 5 - SeaArt.weedRows.length + y, row[x] == 'g' ? SeaArt.weed : SeaArt.weedDeep);
        }
      }
    }
    // 올라오는 거품
    for (final (bx, o) in [(0.2, 0.0), (0.7, 1.7), (0.82, 3.1), (0.33, 4.4)]) {
      final prog = (t / (2 * math.pi) + o / 5) % 1;
      final by = ((h - 8) - prog * (h - 8 - base - 3)).round();
      final x = (w * bx).round() + math.sin(t * 2 + o).round();
      dot(x, by, SeaArt.foam);
      dot(x + 1, by - 1, SeaArt.foam);
      dot(x - 1, by - 1, SeaArt.foam);
      dot(x, by - 2, SeaArt.foam);
    }
  }

  @override
  bool shouldRepaint(_TankPainter old) => old.t != t || old.level != level;
}

/// 물이 반쯤 든 유리관 버튼. 상어 지느러미가 물 위로 지나간다. 바다 스킨의 핵심 버튼.
class SeaTubeButton extends StatefulWidget {
  const SeaTubeButton({super.key, required this.onPressed, required this.label, this.icon, this.height = 58});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double height;

  @override
  State<SeaTubeButton> createState() => _SeaTubeButtonState();
}

class _SeaTubeButtonState extends State<SeaTubeButton> with SingleTickerProviderStateMixin, _WaveClock {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    const ink = Color(0xFF12303D);
    const glow = [Shadow(color: Colors.white, blurRadius: 3), Shadow(color: Colors.white, blurRadius: 2)];
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 80),
          offset: Offset(0, _down ? 0.04 : 0),
          child: Opacity(
            opacity: on ? 1 : 0.5,
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: clock,
                builder: (context, child) => CustomPaint(
                  painter: _TubePainter(t: clock.value * 2 * math.pi, edge: const Color(0xFF4E93A6)),
                  child: child,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: ink, shadows: glow),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.label,
                          style: const TextStyle(
                              fontFamily: kGameFont,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              shadows: glow)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TubePainter extends CustomPainter {
  _TubePainter({required this.t, required this.edge});
  final double t;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    const u = 2.0;
    final w = (size.width / u).floor();
    final h = (size.height / u).floor();
    final p = Paint()..isAntiAlias = false;
    void dot(int x, int y, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x * u, y * u, u, u), p);
    }

    int ins(int y) {
      final e = math.min(y, h - 1 - y);
      return e == 0
          ? 4
          : e == 1
              ? 2
              : e == 2
                  ? 1
                  : 0;
    }

    bool inside(int x, int y) => y >= 0 && y < h && x >= ins(y) && x < w - ins(y);
    final base = (h * 0.56).round();
    int surf(int i) => base + (1.3 * math.sin(i * 0.16 + t)).round() + (math.sin(i * 0.05 - t) > 0.6 ? -1 : 0);

    // 유리
    for (var y = 0; y < h; y++) {
      for (var x = ins(y); x < w - ins(y); x++) {
        dot(x, y, const Color(0xEBE9F7FA));
      }
    }
    // 뒤 물결
    for (var i = 0; i < w; i++) {
      final b = base + (1.1 * math.sin(i * 0.22 - t + 2)).round() - 1;
      for (var y = b; y < h; y++) {
        if (inside(i, y)) dot(i, y, SeaArt.waterBack);
      }
    }
    // 지느러미 (앞 물결 뒤)
    final fx = ((t / (2 * math.pi)) % 1 * (w - 30)).round() + 10;
    final fs = surf(fx + 3);
    for (var ry = 0; ry < SeaArt.fin.length; ry++) {
      final row = SeaArt.fin[ry];
      for (var rx = 0; rx < row.length; rx++) {
        if (row[rx] == '.') continue;
        dot(fx + rx, fs - SeaArt.fin.length + ry + 1, row[rx] == 'm' ? SeaArt.blue : SeaArt.blueDeep);
      }
    }
    // 앞 물결
    for (var i = 0; i < w; i++) {
      final s = surf(i);
      for (var y = s; y < h; y++) {
        if (inside(i, y)) dot(i, y, SeaArt.water[((y - s) / 4).floor().clamp(0, 3)]);
      }
      if (inside(i, s)) {
        dot(i, s, SeaArt.foam);
        if ((i + (t / (2 * math.pi) * 14).floor()) % 13 < 2) dot(i, s + 1, const Color(0xFFC8EEF5));
      }
    }
    for (final d in [-2, -1, 9, 10]) {
      dot(fx + d, surf(fx + d) - 1, Colors.white);
    }
    // 거품
    for (final (bx, o) in [(0.2, 0.0), (0.55, 2.0), (0.8, 4.0)]) {
      final prog = ((t / (2 * math.pi)) * 2 + o / 5) % 1;
      dot((w * bx).round(), (h - 3 - prog * (h - 3 - base - 2)).round(), SeaArt.foam);
    }
    // 유리 반사광과 테두리
    for (var i = 6; i < w - 6; i++) {
      if (i % 23 < 15) dot(i, 2, const Color(0xF2FFFFFF));
    }
    for (var y = 0; y < h; y++) {
      for (var x = ins(y); x < w - ins(y); x++) {
        if (!inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1)) dot(x, y, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_TubePainter old) => old.t != t;
}

/// 화면의 핵심 버튼. 바다 스킨이면 유리관, 아니면 채운 버튼.
class SkinPrimaryButton extends StatelessWidget {
  const SkinPrimaryButton({super.key, required this.onPressed, required this.label, this.icon, this.color});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  /// 기본 스킨에서 버튼 색. 없으면 테마 색.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (JdColors.ocean) return SeaTubeButton(onPressed: onPressed, label: label, icon: icon);
    final style = color == null ? null : FilledButton.styleFrom(backgroundColor: color);
    if (icon == null) return FilledButton(style: style, onPressed: onPressed, child: Text(label));
    return FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon), label: Text(label));
  }
}

/// 빈 화면 그림: 작은 수조에서 상어가 헤엄친다.
class SeaEmptyArt extends StatelessWidget {
  const SeaEmptyArt({super.key});

  @override
  Widget build(BuildContext context) =>
      const SeaTank(value: 0.78, label: '', size: Size(132, 92), sharkWidth: 64, decorative: true);
}

/// 판 아래쪽에 까는 얕은 물 띠. 상어가 지나간다.
class SeaStrip extends StatelessWidget {
  const SeaStrip({super.key, this.height = 52});
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SeaTank(
          value: 1,
          label: '',
          size: Size(c.maxWidth, height),
          sharkWidth: 34,
          decorative: true,
        ),
      );
}

/// 빈 기록 그림: 안경 쓴 꽃게가 양피지를 들여다본다.
class SeaCrabReader extends StatelessWidget {
  const SeaCrabReader({super.key, this.size = 96});
  final double size;

  static const rows = [
    '......................................',
    '......................................',
    '.............KKK......KKK.............',
    '............KgggK....KgggK............',
    '...........KgwwwgKKKKgwwwgK...........',
    '..........KgwwwwwggggwwwwwgK..........',
    '..........KgwwKKwgKKgwwKKwgK..........',
    '...........KgwKKgK..KgwKKgK...........',
    '............KgggKKKKKKgggK............',
    '...........KKKrrrrrrrrrrKKK...........',
    '..........KrroooooooooooorrK..........',
    '.........KrooooorrrrrrrrrrrrK.........',
    '........KrrrrrrrrrrrrrrrrrrrrK........',
    '.......KKrrccrrrrKrrKrrrrccrrKK.......',
    '....KKKqqKrrrrrrrrKKrrrrrrrrKqqKKK....',
    '...KqqqqqKPPPPPPPPPPPPPPPPPPKqqqqqK...',
    '..KqqoqqqKPPPPPPPPPPPPPPPPPPKqqqoqqK..',
    '.KqqoqqqqKrpppppppppppppppprKqqqqoqqK.',
    '.KqqqqqKKKrpplllllplllllppprKKKqqqqqK.',
    '..KqqqqqqKKppppppppppppppppKKqqqqqqK..',
    '...KqqqqKKKpplllllpllllppppKKKqqqqK...',
    '....KKKKKKRppppppppppppppppRKKKKKK....',
    '.....KRKKRKpplllllplllllplpKRKKRK.....',
    '......KKRKKppppppppppppppppKKRKK......',
    '........K.KpplllllplpppppppK.K........',
    '..........KppppppppppppppppK..........',
    '.........KPPPPPPPPPPPPPPPPPPK.........',
    '.........KPPPPPPPPPPPPPPPPPPK.........',
    '..........KKKKKKKKKKKKKKKKKK..........',
    '......................................',
  ];

  static const palette = {
    'r': Color(0xFFE0603F),
    'q': Color(0xFFEA6A48),
    'R': Color(0xFFB84A30),
    'o': Color(0xFFFAA587),
    'w': Color(0xFFFFFFFF),
    'K': Color(0xFF3A2A26),
    'g': Color(0xFF2B3A55),
    'p': Color(0xFFF3E2B8),
    'P': Color(0xFFD9BE86),
    'l': Color(0xFFA88B5A),
    'c': Color(0xFFFFAAB4),
  };

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: PixelGlyph(rows: rows, palette: palette, size: size));
}
