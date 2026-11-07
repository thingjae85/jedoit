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
  int _tab = 2;

  /// 아래 서랍을 펼쳤는지. 접으면 탭 줄만 남고 방이 커진다.
  bool _open = true;

  /// 되돌리기용 이전 배치들 (최근 것이 끝).
  final List<DecorData> _history = [];
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

  Future<void> _update(DecorData next, {bool undoable = true}) async {
    if (identical(next, _decor)) return;
    setState(() {
      if (undoable) {
        _history.add(_decor);
        if (_history.length > 30) _history.removeAt(0);
      }
      _decor = next;
    });
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

  /// 칸을 눌렀을 때: 방에 있으면 고르고, 보관함에 있으면 꺼내 놓는다.
  Future<void> _tapThing(PlacedThing t, {required bool placed}) async {
    if (placed) {
      setState(() => _selected = t.key);
      return;
    }
    if (t.isDecor && !_canPlace) {
      _snack('방이 조금 더 회복되면 놓을 수 있어요');
      return;
    }
    await _takeOut(t);
  }

  Future<void> _buy(DecorItem item) async {
    if (!await _confirmBuy(item.name, item.price) || !mounted) return;
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
    if (!_decor.hasSurface(item) && (!await _confirmBuy(item.name, item.price) || !mounted)) return;
    var next = _decor.buySurface(item, widget.state.coins);
    if (!next.hasSurface(item)) return;
    next = next.applySurface(widget.roomId, item);
    await _update(next);
    final o = objectParticle(item.name);
    _snack(item.kind == SurfaceKind.wall ? '${item.name}$o 발랐어요' : '${item.name}$o 깔았어요');
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    await _update(prev, undoable: false);
    // 고른 게 되돌린 뒤에도 방에 있으면 그대로 고른 채로 둔다.
    if (_selected != _buddyKey && _thing(_selected) == null) setState(() => _selected = null);
  }

  /// 값이 있는 물건은 한 번 묻고 산다. 0코인이면 바로.
  Future<bool> _confirmBuy(String name, int price) async {
    if (price == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name${objectParticle(name)} 살까요?'),
        content: Row(children: [const PixelCoin(size: 16), const SizedBox(width: 6), Text('$price코인')]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('그만두기')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('사기')),
        ],
      ),
    );
    return ok ?? false;
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
    await _update(
        t.isDecor ? _decor.placeDecor(t.id, widget.roomId, a, b) : _decor.moveFurniture(widget.roomId, t.id, a, b));
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
    final size = MediaQuery.sizeOf(context);
    final sheetH = _open ? math.max(300.0, size.height * 0.46) : 96.0;
    final picked = _thing(_selected);

    return Scaffold(
      backgroundColor: widget.night ? JdColors.roomNavyDeep : const Color(0xFFCDEBF4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 하늘색 바탕 위 방
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.night
                      ? const [JdColors.roomNavy, JdColors.roomNavyDeep]
                      : const [Color(0xFFB7E2F1), Color(0xFFE6F6F8)],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: 0,
            bottom: sheetH - 18,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 56, 12, 8),
                child: LayoutBuilder(builder: (context, c) {
                  final w = math.min(c.maxWidth, c.maxHeight * kRoomArtWidth / kRoomArtHeight);
                  return Center(
                    child: SizedBox(
                      width: w,
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
                  );
                }),
              ),
            ),
          ),
          // 위쪽: 뒤로, 방 이름, 코인
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _RoundTool(
                      tooltip: '뒤로',
                      size: 42,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(Icons.arrow_back_rounded, color: _Soft.brown, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _SoftChip(
                        child: RoomNameButton(name: _decor.roomName(widget.roomId), size: 14, onTap: _rename),
                      ),
                    ),
                    const Spacer(),
                    _SoftChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PixelCoin(size: 16),
                          const SizedBox(width: 6),
                          Text('코인 $_coins',
                              key: const Key('decorCoins'), style: gameText(size: 14, color: _Soft.brown)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 고른 물건 이름 / 쓰는 법
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            left: 136,
            right: 66,
            bottom: sheetH + 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: _SoftChip(
                child: _selected == null
                    ? const Text('눌러서 고르고 끌어서 옮겨요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: _Soft.brown, fontWeight: FontWeight.w600))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Image.asset(picked?.day.asset ?? _buddy.asset,
                                filterQuality: FilterQuality.none, fit: BoxFit.contain),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(picked?.name ?? _buddy.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: gameText(size: 13, color: _Soft.brown)),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          // 방 위 동그란 도구: 되돌리기, 보관함에 넣기
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            left: 14,
            bottom: sheetH + 6,
            child: Row(
              children: [
                _RoundTool(
                  tooltip: '되돌리기',
                  onTap: _history.isEmpty ? null : _undo,
                  child: const Icon(Icons.undo_rounded, color: _Soft.brown, size: 26),
                ),
                const SizedBox(width: 10),
                _RoundTool(
                  tooltip: '보관함에 넣기',
                  onTap: picked == null ? null : () => _store(picked),
                  child: const Icon(Icons.move_to_inbox_rounded, color: Color(0xFFE0634F), size: 26),
                ),
              ],
            ),
          ),
          // 아래 서랍
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: 0,
            height: sheetH,
            child: _sheet(),
          ),
          // 서랍 접기·펴기 (서랍 위 가장자리에 걸쳐 있다)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            right: 14,
            bottom: sheetH - 22,
            child: _RoundTool(
              tooltip: _open ? '목록 접기' : '목록 펴기',
              size: 44,
              onTap: () => setState(() => _open = !_open),
              child: Icon(_open ? Icons.keyboard_double_arrow_down_rounded : Icons.keyboard_double_arrow_up_rounded,
                  color: _Soft.brown, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet() {
    final tabs = [
      ('벽지·바닥', TabGlyphs.surface(size: 16)),
      ('벽 장식', TabGlyphs.wall(size: 16)),
      ('가구', TabGlyphs.furniture(size: 16)),
      ('캐릭터', TabGlyphs.buddy(size: 16)),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              color: _Soft.sheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: _Soft.rim, width: 3)),
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                  child: _SoftTabs(
                      tabs: tabs,
                      selected: _tab,
                      onSelect: (i) => setState(() {
                            _tab = i;
                            _open = true;
                          })),
                ),
                if (_open)
                  Expanded(
                    child: ListView(
                      key: ValueKey('decorTab$_tab'),
                      padding: EdgeInsets.fromLTRB(14, 4, 14, 20 + MediaQuery.paddingOf(context).bottom),
                      children: switch (_tab) {
                        0 => _surfaceTab(),
                        1 => _thingTab(true),
                        2 => _thingTab(false),
                        _ => _buddyTab(),
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(text, style: gameText(size: 13, color: _Soft.brown)),
      );

  List<Widget> _surfaceTab() {
    final layout = _decor.layoutOf(widget.roomId);
    final art = kRoomArt[widget.roomId]!;
    final dark = widget.night || _stage < art.litFrom;
    Widget slot(SurfaceItem item, String current) {
      final owned = _decor.hasSurface(item);
      final using = item.key == current;
      final pics = art.surfaces[item.key];
      return DecorSlot(
        key: ValueKey('surface-${item.key}'),
        name: item.name,
        bleed: true,
        picture: pics == null
            ? null
            : Image.asset(dark ? pics.$2 : pics.$1,
                filterQuality: FilterQuality.none,
                fit: BoxFit.cover,
                alignment: item.kind == SurfaceKind.wall ? const Alignment(0, -0.55) : const Alignment(0, 0.8)),
        price: owned ? null : item.price,
        count: owned ? (using ? 1 : 0, 1) : null,
        selected: using,
        onTap: using || (!owned && _coins < item.price) ? null : () => _surface(item),
      );
    }

    return [
      _label('벽지'),
      _grid([for (final w in kWallpapers) slot(w, layout.wallKey)]),
      const SizedBox(height: 8),
      _label('바닥'),
      _grid([for (final f in kFloors) slot(f, layout.floorKey)]),
      ..._footer(),
    ];
  }

  /// 벽 장식(wall) 또는 가구·바닥 소품. 가진 것 먼저, 그다음 상점.
  List<Widget> _thingTab(bool wall) {
    final placed = [
      for (final t in _things)
        if (t.wall == wall) t
    ];
    final stored = [
      if (!wall)
        for (final f in storedFurniture(widget.roomId, _stage, _decor))
          thingsIn(widget.roomId, _stage, _decor.moveFurniture(widget.roomId, f.id, f.x, f.y))
              .firstWhere((t) => t.key == furnitureKey(f.id)),
      for (final id in _decor.owned)
        if (decorById(id) != null && _decor.roomOf(id) != widget.roomId) decorThing(id, 0, 0),
    ].whereType<PlacedThing>().where((t) => t.wall == wall).toList();
    final spot = wall ? DecorSpot.wall : DecorSpot.floor;
    final shop = [
      for (final item in kDecorItems)
        if (item.spot == spot && !_decor.owned.contains(item.id)) item
    ];
    Widget thing(PlacedThing t, bool inRoom) => DecorSlot(
          key: ValueKey(inRoom ? 'placed-${t.key}' : 'stored-${t.key}'),
          name: t.name,
          picture: Image.asset(t.day.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
          count: (inRoom ? 1 : 0, 1),
          selected: t.key == _selected,
          onTap: () => _tapThing(t, placed: inRoom),
        );
    return [
      _grid([
        for (final t in placed) thing(t, true),
        for (final t in stored) thing(t, false),
        for (final item in shop)
          DecorSlot(
            key: ValueKey('shop-${item.id}'),
            name: item.name,
            picture: kDecorArt[item.id] == null
                ? null
                : Image.asset(kDecorArt[item.id]!.$4.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
            price: item.price,
            onTap: _coins >= item.price ? () => _buy(item) : null,
          ),
      ]),
      ..._footer(),
    ];
  }

  List<Widget> _buddyTab() => [
        _grid([
          for (final b in kBuddies)
            DecorSlot(
              key: ValueKey('buddy-${b.id}'),
              name: b.name,
              picture: Image.asset(b.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
              label: b.id == _buddy.id ? '함께' : '고르기',
              selected: b.id == _buddy.id,
              onTap: b.id == _buddy.id ? () => setState(() => _selected = _buddyKey) : () => _pickBuddy(b),
            ),
        ]),
        const SizedBox(height: 12),
        const Text('캐릭터도 방에서 끌어서 자리를 옮길 수 있어요.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _Soft.brownSoft)),
      ];

  List<Widget> _footer() => [
        const SizedBox(height: 14),
        Text(
          shopIsFree ? '지금은 시험 기간이라 상점이 모두 0코인이에요.' : '코인은 미션을 하면 10개씩 생겨요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _Soft.brownSoft),
        ),
      ];

  /// 칸을 한 줄에 4개(넓으면 5개) 늘어놓는다.
  Widget _grid(List<Widget> slots) => LayoutBuilder(builder: (context, c) {
        const gap = 8.0;
        final cols = c.maxWidth >= 440 ? 5 : 4;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final s in slots) SizedBox(width: w, child: s)],
        );
      });
}

/// 꾸미기 화면의 부드러운 크림·갈색.
abstract final class _Soft {
  static const sheet = Color(0xFFFBF1E2);
  static const tile = Color(0xFFFFF9F1);
  static const rim = Color(0xFFC7AE9C);
  static const rimDeep = Color(0xFFA58B7C);
  static const brown = Color(0xFF6E5547);
  static const brownSoft = Color(0xFF8C7466);
  static const orange = Color(0xFFF2994A);
  static const orangeLight = Color(0xFFF8C77E);
}

/// 동그란 도구 버튼.
class _RoundTool extends StatelessWidget {
  const _RoundTool({required this.tooltip, required this.onTap, required this.child, this.size = 52});

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: on ? 1 : 0.45,
        child: Material(
          color: _Soft.tile,
          shape: const CircleBorder(side: BorderSide(color: _Soft.rim, width: 3)),
          elevation: 2,
          shadowColor: const Color(0x55000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// 방 위에 뜨는 크림색 알약.
class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _Soft.tile.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _Soft.rim, width: 2),
        ),
        child: child,
      );
}

/// 둥근 탭 줄. 고른 탭은 주황 알약에 이름까지, 나머지는 아이콘만.
class _SoftTabs extends StatelessWidget {
  const _SoftTabs({required this.tabs, required this.selected, required this.onSelect});

  final List<(String, Widget)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7D2),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _Soft.rim, width: 2),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              flex: i == selected ? 5 : 3,
              child: Tooltip(
                message: tabs[i].$1,
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: tabs[i].$1,
                  child: GestureDetector(
                    key: ValueKey('tab-${tabs[i].$1}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: i == selected
                          ? BoxDecoration(
                              color: _Soft.orange,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _Soft.orangeLight, width: 3),
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          tabs[i].$2,
                          if (i == selected) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(tabs[i].$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: gameText(size: 13, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 꾸미기 칸 하나: 위에 그림, 아래 띠에 값(코인) 또는 놓은 수/가진 수.
class DecorSlot extends StatelessWidget {
  const DecorSlot({
    super.key,
    required this.name,
    required this.picture,
    required this.onTap,
    this.price,
    this.count,
    this.label,
    this.selected = false,
    this.bleed = false,
  });

  final String name;
  final Widget? picture;
  final VoidCallback? onTap;

  /// 아직 안 산 것의 값.
  final int? price;

  /// (방에 놓은 수, 가진 수)
  final (int, int)? count;

  /// 값·개수 대신 띠에 쓸 말.
  final String? label;

  /// 주황 테두리로 표시 (방에서 고른 것, 쓰는 벽지).
  final bool selected;

  /// 그림을 칸 가득 채울지 (벽지·바닥).
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final Widget footer;
    if (price != null) {
      footer = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PixelCoin(size: 13),
          const SizedBox(width: 4),
          Text('$price', style: gameText(size: 13, color: Colors.white)),
        ],
      );
    } else if (count != null) {
      footer = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_rounded, size: 14, color: Color(0xFFEBDCCD)),
          const SizedBox(width: 4),
          Text('${count!.$1}/${count!.$2}', style: gameText(size: 13, color: Colors.white)),
        ],
      );
    } else {
      footer = Text(label ?? '', style: gameText(size: 12, color: Colors.white));
    }
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        enabled: on,
        label: name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: selected ? _Soft.orangeLight : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Opacity(
              opacity: on || selected ? 1 : 0.55,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _Soft.rimDeep,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: selected ? _Soft.orange : _Soft.rim, width: 2.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                        padding: bleed ? EdgeInsets.zero : const EdgeInsets.all(10),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _Soft.tile,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: picture ?? const SizedBox(),
                      ),
                    ),
                    SizedBox(height: 24, child: Center(child: footer)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
