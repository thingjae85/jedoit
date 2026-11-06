import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/layout.dart';
import '../models/space.dart';
import '../models/space_art.dart';
import '../services/space_store.dart';
import '../theme.dart';
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
          ? '${item.name}을(를) 놓았어요. 끌어서 옮겨 보세요'
          : '${item.name}을(를) 보관함에 넣었어요',
      duration: const Duration(seconds: 3),
    );
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
    final room = spaceRoomById(widget.roomId);
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
    final stored = [
      for (final f in storedFurniture(widget.roomId, _stage, _decor))
        thingsIn(widget.roomId, _stage, _decor.moveFurniture(widget.roomId, f.id, f.x, f.y))
            .firstWhere((t) => t.key == furnitureKey(f.id)),
      for (final id in _decor.owned)
        if (_decor.roomOf(id) == null) decorThing(id, 0, 0),
    ].whereType<PlacedThing>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('꾸미기 · ${room?.name ?? ''}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('코인 $_coins',
                  key: const Key('decorCoins'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFC29A2E))),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.night ? const Color(0xFF141F2E) : const Color(0xFF22344A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
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
          ),
          _selectionBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _header('캐릭터'),
                Row(
                  children: [
                    for (final b in kBuddies)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: ChoiceChip(
                          avatar: Image.asset(b.asset, filterQuality: FilterQuality.none),
                          label: Text(b.name),
                          selected: b.id == _buddy.id,
                          onSelected: (_) => _pickBuddy(b),
                        ),
                      ),
                  ],
                ),
                if (stored.isNotEmpty) ...[
                  _header('보관함'),
                  for (final t in stored)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _thumb(t.day),
                      title: Text(t.name),
                      subtitle: Text(
                          t.isDecor && !_canPlace ? '방이 조금 더 회복되면 놓을 수 있어요' : '보관함에 있어요',
                          style: const TextStyle(fontSize: 12)),
                      trailing: FilledButton.tonal(
                        // 앱 기본 버튼은 가로를 꽉 채우므로, 목록 오른쪽에 들어가게 크기를 정한다.
                        style: _tileButton,
                        onPressed: t.isDecor && !_canPlace ? null : () => _takeOut(t),
                        child: const Text('놓기'),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                _header('상점'),
                for (final item in kDecorItems)
                  if (!_decor.owned.contains(item.id))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _thumb(kDecorArt[item.id]?.$4),
                      title: Text(item.name),
                      subtitle: Text('${item.price} 코인 · ${item.spot == DecorSpot.wall ? '벽' : '바닥'}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: FilledButton.tonal(
                        style: _tileButton,
                        onPressed: _coins >= item.price ? () => _buy(item) : null,
                        child: const Text('사기'),
                      ),
                    ),
                if (kDecorItems.every((i) => _decor.owned.contains(i.id)))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('소품을 다 모았어요!', style: TextStyle(color: JdColors.subtle)),
                  ),
                const SizedBox(height: 12),
                const Text('코인은 미션을 하면 10개씩 생겨요. 방이 자라는 건 코인과 상관없어요.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: JdColors.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final _tileButton = FilledButton.styleFrom(minimumSize: const Size(64, 40));

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );

  /// 목록 왼쪽의 생김새 미리보기: 방에 놓았을 때 그림을 그대로 줄여서 보여 준다.
  Widget _thumb(Sprite? sprite) => Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFFEDE6D8), borderRadius: BorderRadius.circular(12)),
        child: sprite == null
            ? const Icon(Icons.category_outlined, color: JdColors.solo, size: 22)
            : Image.asset(sprite.asset, filterQuality: FilterQuality.none, fit: BoxFit.contain),
      );

  /// 고른 것 이름과 보관함에 넣기. 아무것도 안 골랐으면 쓰는 법.
  Widget _selectionBar() {
    final key = _selected;
    final t = _thing(key);
    if (key == null || (t == null && key != _buddyKey)) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text('가구·소품·캐릭터를 손가락으로 집어서 끌어다 놓아 보세요.',
            style: TextStyle(fontSize: 13, color: JdColors.subtle)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(t?.name ?? _buddy.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (t != null) TextButton(onPressed: () => _store(t), child: const Text('보관함에')),
          if (t == null) const SizedBox(height: 48),
        ],
      ),
    );
  }
}
