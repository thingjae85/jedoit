import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/layout.dart';
import '../models/space.dart';
import '../models/space_art.dart';
import '../services/space_store.dart';
import '../theme.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/space_view.dart';

/// 꾸미기: 방 안 가구·소품·캐릭터를 손가락으로 집어서 아무 데나 끌어다 놓는다.
/// 코인으로 소품을 사고, 안 쓰는 건 보관함에 넣는다.
/// 방이 자라는 건 미션 덕분이고, 코인은 그 방을 내 취향으로 꾸미는 데만 쓴다.
class DecorScreen extends StatefulWidget {
  const DecorScreen({
    super.key,
    required this.store,
    required this.decor,
    required this.state,
    required this.roomId,
    required this.buddy,
    this.night = false,
    this.photo,
  });

  final SpaceStore store;
  final DecorData decor;
  final SpaceState state;
  final String roomId;
  final Buddy buddy;
  final bool night;
  final List<int>? photo;

  @override
  State<DecorScreen> createState() => _DecorScreenState();
}

/// 끄는 중인 것: 집은 곳(도트 픽셀), 집었을 때 칸, 지금 칸.
class _Drag {
  _Drag(this.key, this.grab, this.from) : at = from;
  final String key;
  final Offset grab;
  final (int, int) from;
  (int, int) at;
}

class _DecorScreenState extends State<DecorScreen> {
  late DecorData _decor = widget.decor;
  late Buddy _buddy = widget.buddy;
  String? _selected;
  _Drag? _drag;

  /// 0 벽지·바닥, 1 벽 장식, 2 가구, 3 캐릭터
  int _tab = 0;
  final _roomKey = GlobalKey();

  static const _buddyKey = RoomPicture.buddyKey;

  int get _coins => _decor.available(widget.state.coins);
  int get _stage => widget.state.stageOf(widget.roomId);
  bool get _canPlace => canDecorate(widget.roomId, _stage);
  List<PlacedThing> get _things => thingsIn(widget.roomId, _stage, _decor);
  (int, int) get _buddySpot => buddySpot(widget.roomId, _things, prefer: _decor.layoutOf(widget.roomId).buddy);

  PlacedThing? _thing(String? key) {
    for (final t in _things) {
      if (t.key == key) return t;
    }
    return null;
  }

  Future<void> _update(DecorData next) async {
    setState(() => _decor = next);
    try {
      await widget.store.saveDecor(next);
    } catch (_) {
      _snack('저장하지 못했어요. 잠시 후 다시 시도해 주세요');
    }
  }

  void _snack(String text, {Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  Future<void> _store(PlacedThing t) async {
    setState(() => _selected = null);
    await _update(t.isDecor ? _decor.removeDecor(t.id) : _decor.storeFurniture(widget.roomId, t.id));
  }

  /// 보관함에서 꺼내 빈 자리에 놓는다.
  Future<void> _takeOut(PlacedThing t) async {
    final spot = freeSpot(widget.roomId, _stage, _things, t);
    if (spot == null) {
      _snack('놓을 빈 자리가 없어요');
      return;
    }
    await _update(t.isDecor
        ? _decor.placeDecor(t.id, widget.roomId, spot.$1, spot.$2)
        : _decor.moveFurniture(widget.roomId, t.id, spot.$1, spot.$2));
    setState(() => _selected = t.key);
  }

  Future<void> _buy(DecorItem item) async {
    final next = _decor.buy(item, widget.state.coins);
    if (identical(next, _decor)) return;
    await _update(next);
    if (!mounted) return;
    if (_canPlace) {
      final t = decorThing(item.id, 0, 0);
      if (t != null) await _takeOut(t);
    }
    _snack(
      _decor.roomOf(item.id) == widget.roomId
          ? '${item.name}${objectParticle(item.name)} 놓았어요. 끌어서 옮겨 보세요'
          : '${item.name}${objectParticle(item.name)} 보관함에 넣었어요',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _surface(SurfaceItem item) async {
    var next = _decor.buySurface(item, widget.state.coins);
    if (!next.hasSurface(item)) return;
    next = next.applySurface(widget.roomId, item);
    await _update(next);
    final o = objectParticle(item.name);
    _snack(item.kind == SurfaceKind.wall ? '${item.name}$o 발랐어요' : '${item.name}$o 깔았어요');
  }

  Future<void> _rename() async {
    final name = await showRoomNameDialog(context, current: _decor.roomName(widget.roomId), max: roomNameMax);
    if (name == null || !mounted) return;
    await _update(_decor.rename(widget.roomId, name));
  }

  Future<void> _pickBuddy(Buddy b) async {
    setState(() => _buddy = b);
    await widget.store.setBuddy(b.id);
  }

  // ---------- 방 위 손가락 ----------

  /// 화면 좌표 → 도트 픽셀 좌표.
  Offset? _toArt(Offset global) {
    final box = _roomKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final s = box.size.width / kRoomArtWidth;
    return local / s;
  }

  /// 손가락 아래에서 가장 앞에 그려진 것 (가구·소품의 key 또는 캐릭터).
  /// 작은 물건도 집기 쉽게 그림보다 조금 넓게 본다.
  String? _hit(Offset art) {
    const pad = 3;
    String? hit;
    // 웹에서는 정수 비트 연산이 부호 없는 32비트라 `-1 << 30`이 양수가 된다. 그냥 작은 수를 쓴다.
    var hitDepth = -1000000;
    void consider(String key, (int, int, int, int) rect, int depth) {
      final (l, top, w, h) = rect;
      if (art.dx < l - pad || art.dx > l + w + pad || art.dy < top - pad || art.dy > top + h + pad) return;
      // 이미 고른 건 다른 것에 살짝 가려 있어도 다시 집을 수 있게.
      if (key == _selected) depth += 10000;
      if (depth > hitDepth) {
        hit = key;
        hitDepth = depth;
      }
    }

    for (final t in _things) {
      // 벽 < 납작한 것 < 서 있는 것, 그 안에서는 앞(아래)에 있는 것
      consider(t.key, t.rect(atNight: widget.night), (t.wall ? 0 : (t.flat ? 1000 : 2000)) + t.a + t.b + t.w + t.d);
    }
    final (bx, by) = _buddySpot;
    consider(_buddyKey, buddyRect(bx, by), 2000 + bx + by + 4);
    return hit;
  }

  /// 집은 뒤 손가락이 움직인 만큼(도트 픽셀) 칸을 옮긴다. 방 밖으로는 나가지 않게 벽에 붙인다.
  (int, int) _cellAfter(_Drag d, Offset art) {
    final dx = art.dx - d.grab.dx;
    final dy = art.dy - d.grab.dy;
    final (a0, b0) = d.from;
    if (d.key == _buddyKey) {
      // 바닥: 화면 오른쪽 아래가 x+, 왼쪽 아래가 y+ (한 칸 = 가로 2, 세로 1)
      final x = (a0 + (dx / 2 + dy) / 2).round().clamp(2, kRoomCells - 3);
      final y = (b0 + (dy - dx / 2) / 2).round().clamp(2, kRoomCells - 2);
      return (x, y);
    }
    final t = _thing(d.key)!;
    if (t.wall) {
      // 왼쪽 벽: y가 늘면 왼쪽 아래(가로 -2, 세로 +1), z가 늘면 위(세로 -2)
      final dyc = -dx / 2;
      final a = (a0 + dyc).round().clamp(0, kRoomCells - t.w);
      final b = (b0 + (dyc - dy) / 2).round().clamp(2, kWallCells - t.d - 1);
      return (a, b);
    }
    final a = (a0 + (dx / 2 + dy) / 2).round().clamp(0, kRoomCells - t.w);
    final b = (b0 + (dy - dx / 2) / 2).round().clamp(0, kRoomCells - t.d);
    return (a, b);
  }

  bool _fitsAt(String key, (int, int) cell) {
    final things = _things;
    if (key == _buddyKey) return buddyFits(things, cell.$1, cell.$2);
    final t = _thing(key);
    return t != null && fits(widget.roomId, _stage, things, t, cell.$1, cell.$2);
  }

  void _onTapUp(TapUpDetails d) {
    final art = _toArt(d.globalPosition);
    if (art == null) return;
    setState(() => _selected = _hit(art));
  }

  void _onPanStart(DragStartDetails d) {
    final art = _toArt(d.globalPosition);
    if (art == null) return;
    final key = _hit(art);
    if (key == null) {
      setState(() => _selected = null);
      return;
    }
    final t = _thing(key);
    final from = key == _buddyKey ? _buddySpot : (t!.a, t.b);
    setState(() {
      _selected = key;
      _drag = _Drag(key, art, from);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final drag = _drag;
    final art = _toArt(d.globalPosition);
    if (drag == null || art == null) return;
    final cell = _cellAfter(drag, art);
    if (cell != drag.at) setState(() => drag.at = cell);
  }

  Future<void> _onPanEnd([DragEndDetails? _]) async {
    final drag = _drag;
    setState(() => _drag = null);
    if (drag == null || drag.at == drag.from) return;
    final (a, b) = drag.at;
    if (!_fitsAt(drag.key, drag.at)) {
      _snack('다른 물건과 겹쳐서 원래 자리로 돌아갔어요');
      return;
    }
    if (drag.key == _buddyKey) {
      await _update(_decor.moveBuddy(widget.roomId, a, b));
      return;
    }
    final t = _thing(drag.key)!;
    await _update(t.isDecor
        ? _decor.placeDecor(t.id, widget.roomId, a, b)
        : _decor.moveFurniture(widget.roomId, t.id, a, b));
  }

  @override
  Widget build(BuildContext context) {
    var things = _things;
    final drag = _drag;
    var valid = true;
    (int, int)? buddyAt;
    if (drag != null) {
      valid = _fitsAt(drag.key, drag.at);
      if (drag.key == _buddyKey) {
        buddyAt = drag.at;
      } else {
        things = [for (final t in things) t.key == drag.key ? t.at(drag.at.$1, drag.at.$2) : t];
      }
    }
    final storedThings = [
      for (final f in storedFurniture(widget.roomId, _stage, _decor))
        thingsIn(widget.roomId, _stage, _decor.moveFurniture(widget.roomId, f.id, f.x, f.y))
            .firstWhere((t) => t.key == furnitureKey(f.id)),
      for (final id in _decor.owned)
        if (decorById(id) != null && _decor.roomOf(id) == null) decorThing(id, 0, 0),
    ].whereType<PlacedThing>().toList();

    final bg = widget.night ? JdColors.roomNavyDeep : JdColors.roomNavy;
    final roomW = math.min(340.0, MediaQuery.sizeOf(context).height * 0.30);

    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸미기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CoinCounter(coins: _coins, textKey: const Key('decorCoins'), prefix: '코인 '),
          ),
        ],
      ),
      body: Column(
        children: [
          // 방 + 아래 작업대 (고른 것 이름, 보관함에 넣기)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: GamePanel(
              color: bg,
              lip: JdColors.roomNavyDeep,
              step: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        Flexible(
                          child: RoomNameButton(
                            name: _decor.roomName(widget.roomId),
                            onDark: true,
                            size: 14,
                            onTap: _rename,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      // 화면이 낮으면 방을 조금 줄여서 아래 목록이 보이게 한다.
                      constraints: BoxConstraints(maxWidth: roomW),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // 손가락을 댄 곳에서 바로 집는다 (조금 움직인 뒤가 아니라).
                        dragStartBehavior: DragStartBehavior.down,
                        onTapUp: _onTapUp,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        onPanCancel: _onPanEnd,
                        child: RoomPicture(
                          key: _roomKey,
                          roomId: widget.roomId,
                          stage: _stage,
                          buddy: _buddy,
                          photo: widget.photo,
                          night: widget.night,
                          decor: _decor,
                          things: things,
                          buddyAt: buddyAt,
                          selectedKey: _selected,
                          selectionValid: valid,
                          lifted: drag != null,
                        ),
                      ),
                    ),
                  ),
                  _selectionBar(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  GameTabs(
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                    tabs: [
                      ('벽지·바닥', TabGlyphs.surface()),
                      ('벽 장식', TabGlyphs.wall()),
                      ('가구', TabGlyphs.furniture()),
                      ('캐릭터', TabGlyphs.buddy()),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: JdColors.cream,
                        border: Border(
                          left: BorderSide(color: JdColors.outline, width: 2),
                          right: BorderSide(color: JdColors.outline, width: 2),
                          top: BorderSide(color: JdColors.outline, width: 2),
                        ),
                      ),
                      child: ListView(
                        key: ValueKey('decorTab$_tab'),
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                        children: switch (_tab) {
                          0 => _surfaceTab(),
                          1 => _thingTab(storedThings.where((t) => t.wall).toList(), DecorSpot.wall),
                          2 => _thingTab(storedThings.where((t) => !t.wall).toList(), DecorSpot.floor),
                          _ => _buddyTab(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 판 안의 작은 제목.
  Widget _label(String text, {String? note}) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text, style: gameText(size: 14, color: JdColors.woodText)),
            if (note != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: JdColors.faint)),
              ),
            ],
          ],
        ),
      );

  List<Widget> _surfaceTab() {
    final layout = _decor.layoutOf(widget.roomId);
    final art = kRoomArt[widget.roomId]!;
    final dark = widget.night || _stage < art.litFrom;
    Widget card(SurfaceItem item, String current) {
      final owned = _decor.hasSurface(item);
      final using = item.key == current;
      final pics = art.surfaces[item.key];
      return _ItemCard(
        key: ValueKey('surface-${item.key}'),
        picture: pics == null
            ? null
            : Image.asset(dark ? pics.$2 : pics.$1,
                filterQuality: FilterQuality.none,
                fit: BoxFit.cover,
                alignment: item.kind == SurfaceKind.wall ? const Alignment(0, -0.55) : const Alignment(0, 0.8)),
        pictureBleed: true,
        name: item.name,
        price: owned ? null : item.price,
        note: owned ? (using ? '지금 쓰는 중' : '가지고 있어요') : null,
        action: using ? '쓰는 중' : (owned ? (item.kind == SurfaceKind.wall ? '바르기' : '깔기') : '사기'),
        green: !owned,
        onPressed: using || (!owned && _coins < item.price) ? null : () => _surface(item),
      );
    }

    return [
      _label('벽지', note: '방 벽 전체에 발라요'),
      _grid([for (final w in kWallpapers) card(w, layout.wallKey)]),
      const SizedBox(height: 18),
      _label('바닥', note: '가구 밑 바닥까지 바뀌어요'),
      _grid([for (final f in kFloors) card(f, layout.floorKey)]),
      ..._footer(),
    ];
  }

  List<Widget> _thingTab(List<PlacedThing> stored, DecorSpot spot) {
    final shop = [
      for (final item in kDecorItems)
        if (item.spot == spot && !_decor.owned.contains(item.id)) item
    ];
    return [
      if (stored.isNotEmpty) ...[
        _label('보관함', note: '${stored.length}개 · 놓으면 빈 자리에 놓여요'),
        _grid([
          for (final t in stored)
            _ItemCard(
              key: ValueKey('stored-${t.key}'),
              picture: Image.asset(t.day.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
              name: t.name,
              note: t.isDecor && !_canPlace ? '방이 조금 더 회복되면 놓을 수 있어요' : '보관함에 있어요',
              action: '놓기',
              onPressed: t.isDecor && !_canPlace ? null : () => _takeOut(t),
            ),
        ]),
        const SizedBox(height: 18),
      ],
      _label('상점', note: '하나씩만 살 수 있어요'),
      if (shop.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('여기 있는 건 다 모았어요!', style: TextStyle(color: JdColors.subtle)),
        )
      else
        _grid([
          for (final item in shop)
            _ItemCard(
              key: ValueKey('shop-${item.id}'),
              picture: kDecorArt[item.id] == null
                  ? null
                  : Image.asset(kDecorArt[item.id]!.$4.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
              name: item.name,
              price: item.price,
              action: '사기',
              green: true,
              onPressed: _coins >= item.price ? () => _buy(item) : null,
            ),
        ]),
      if (spot == DecorSpot.floor && stored.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text('방에 있는 가구는 방에서 눌러 고른 뒤 보관함에 넣을 수 있어요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: JdColors.faint)),
        ),
      ..._footer(),
    ];
  }

  List<Widget> _buddyTab() => [
        _label('캐릭터', note: '방에서 끌어서 자리를 옮길 수 있어요'),
        _grid([
          for (final b in kBuddies)
            _ItemCard(
              key: ValueKey('buddy-${b.id}'),
              picture: Image.asset(b.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
              name: b.name,
              note: b.id == _buddy.id ? '지금 함께 있어요' : null,
              action: b.id == _buddy.id ? '함께하는 중' : '함께하기',
              onPressed: b.id == _buddy.id ? null : () => _pickBuddy(b),
            ),
        ]),
      ];

  List<Widget> _footer() => [
        const SizedBox(height: 18),
        Text(
          shopIsFree ? '지금은 시험 기간이라 상점이 모두 0코인이에요.' : '코인은 미션을 하면 10개씩 생겨요. 방이 자라는 건 코인과 상관없어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: JdColors.faint),
        ),
      ];

  /// 카드를 두 줄(넓으면 세 줄)로 늘어놓는다.
  Widget _grid(List<Widget> cards) => LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final cols = c.maxWidth >= 500 ? 3 : 2;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      });

  /// 방 아래 작업대: 고른 것 이름과 보관함에 넣기. 아무것도 안 골랐으면 쓰는 법.
  Widget _selectionBar() {
    final key = _selected;
    final t = _thing(key);
    final picked = key != null && (t != null || key == _buddyKey);
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      color: Colors.black.withValues(alpha: 0.22),
      child: Row(
        children: [
          if (!picked)
            const Expanded(
              child: Text('가구·소품·캐릭터를 손가락으로 집어서 끌어다 놓아 보세요.',
                  maxLines: 2, style: TextStyle(fontSize: 12, height: 1.3, color: Color(0xFFD5DEE8))),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Image.asset(t?.day.asset ?? _buddy.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
              ),
            ),
            Expanded(
              child: Text(t?.name ?? _buddy.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: gameText(size: 14, color: Colors.white)),
            ),
            if (t != null)
              GameButton(
                small: true,
                label: '보관함에',
                color: JdColors.cream,
                lip: JdColors.creamLip,
                onTap: () => _store(t),
              ),
          ],
        ],
      ),
    );
  }
}

/// 상점·보관함·캐릭터 카드: 위에 그림 칸, 아래에 이름·값·버튼.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.picture,
    required this.name,
    required this.action,
    required this.onPressed,
    this.price,
    this.note,
    this.green = false,
    this.pictureBleed = false,
  });

  final Widget? picture;
  final String name;
  final String action;
  final VoidCallback? onPressed;

  /// 값. 없으면 [note]를 보여 준다.
  final int? price;
  final String? note;

  /// 사기 버튼처럼 초록.
  final bool green;

  /// 벽지·바닥 그림처럼 칸을 꽉 채울지.
  final bool pictureBleed;

  @override
  Widget build(BuildContext context) {
    final (face, lip, text) = green ? GameButton.green : GameButton.wood;
    return GamePanel(
      color: JdColors.paper,
      lip: JdColors.seamDark,
      depth: 3,
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 72,
            padding: pictureBleed ? EdgeInsets.zero : const EdgeInsets.all(9),
            clipBehavior: Clip.antiAlias,
            decoration: const ShapeDecoration(
              color: JdColors.woodLight,
              shape: PixelBorder(step: 2, steps: 1, side: BorderSide(color: JdColors.wood, width: 1.5)),
            ),
            child: picture ?? const SizedBox(),
          ),
          const SizedBox(height: 7),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gameText(size: 13)),
          const SizedBox(height: 3),
          SizedBox(
            height: 16,
            child: price != null
                ? Row(
                    children: [
                      const PixelCoin(size: 12),
                      const SizedBox(width: 4),
                      Text('$price', style: gameText(size: 12, color: JdColors.woodText)),
                    ],
                  )
                : Text(note ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: JdColors.faint)),
          ),
          const SizedBox(height: 6),
          GameButton(
            label: action,
            expand: true,
            small: true,
            color: face,
            lip: lip,
            textColor: text,
            onTap: onPressed,
          ),
        ],
      ),
    );
  }
}
