import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/layout.dart';
import '../models/space.dart';
import '../models/space_art.dart';
import '../services/space_store.dart';
import '../theme.dart';
import '../widgets/space_view.dart';

/// 꾸미기: 방 안 가구와 소품을 눌러 고르고, 끌어서 아무 데나 옮긴다.
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

class _DecorScreenState extends State<DecorScreen> {
  late DecorData _decor = widget.decor;
  String? _selected;

  /// 끌고 있는 중의 위치. 놓을 수 없는 자리면 손을 떼면 원래 자리로 돌아간다.
  (int, int)? _drag;
  final _roomKey = GlobalKey();

  int get _coins => _decor.available(widget.state.coins);
  int get _stage => widget.state.stageOf(widget.roomId);
  bool get _canPlace => canDecorate(widget.roomId, _stage);
  List<PlacedThing> get _things => thingsIn(widget.roomId, _stage, _decor);

  PlacedThing? get _selectedThing {
    for (final t in _things) {
      if (t.key == _selected) return t;
    }
    return null;
  }

  Future<void> _update(DecorData next) async {
    setState(() => _decor = next);
    try {
      await widget.store.saveDecor(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요')),
      );
    }
  }

  /// 물건을 (a, b)로 옮긴다. 놓을 수 없는 자리면 false.
  Future<bool> _moveTo(PlacedThing t, int a, int b) async {
    if (!fits(widget.roomId, _stage, _things, t, a, b)) return false;
    await _update(t.isDecor
        ? _decor.placeDecor(t.id, widget.roomId, a, b)
        : _decor.moveFurniture(widget.roomId, t.id, a, b));
    return true;
  }

  Future<void> _nudge(int da, int db) async {
    final t = _selectedThing;
    if (t == null) return;
    if (!await _moveTo(t, t.a + da, t.b + db) && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거기엔 놓을 수 없어요'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _store(PlacedThing t) async {
    setState(() => _selected = null);
    await _update(t.isDecor ? _decor.removeDecor(t.id) : _decor.storeFurniture(widget.roomId, t.id));
  }

  /// 보관함에서 꺼내 빈 자리에 놓는다.
  Future<void> _takeOut(PlacedThing t) async {
    final spot = freeSpot(widget.roomId, _stage, _things, t);
    if (spot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('놓을 빈 자리가 없어요')));
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_decor.roomOf(item.id) == widget.roomId
            ? '${item.name}을(를) 놓았어요. 끌어서 옮겨 보세요'
            : '${item.name}을(를) 보관함에 넣었어요'),
      ),
    );
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

  /// 손가락 아래에서 가장 앞에 그려진 물건.
  PlacedThing? _hit(Offset art) {
    final things = _things;
    PlacedThing? hit;
    var hitDepth = -1 << 30;
    for (final t in things) {
      final (l, top, w, h) = t.rect(atNight: widget.night);
      if (art.dx < l || art.dx > l + w || art.dy < top || art.dy > top + h) continue;
      // 벽 < 납작한 것 < 서 있는 것, 그 안에서는 앞(아래)에 있는 것
      final depth = (t.wall ? 0 : (t.flat ? 1000 : 2000)) + t.a + t.b + t.w + t.d;
      if (depth > hitDepth) {
        hit = t;
        hitDepth = depth;
      }
    }
    return hit;
  }

  /// 손가락 위치에 물건 가운데가 오도록 하는 칸.
  (int, int) _cellFor(PlacedThing t, Offset art) {
    if (t.wall) {
      final y = (kRoomOriginX - 2 - art.dx) / 2;
      final z = (kRoomOriginY + y + 1 - art.dy) / 2;
      return ((y - t.w / 2).round(), (z - t.d / 2).round());
    }
    final u = (art.dx - kRoomOriginX) / 2;
    final v = art.dy - kRoomOriginY;
    final x = (u + v) / 2;
    final y = (v - u) / 2;
    return ((x - t.w / 2).round(), (y - t.d / 2).round());
  }

  void _onTapUp(TapUpDetails d) {
    final art = _toArt(d.globalPosition);
    if (art == null) return;
    setState(() => _selected = _hit(art)?.key);
  }

  void _onPanStart(DragStartDetails d) {
    final art = _toArt(d.globalPosition);
    if (art == null) return;
    final hit = _hit(art);
    if (hit == null) return;
    setState(() {
      _selected = hit.key;
      _drag = (hit.a, hit.b);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final t = _selectedThing;
    final art = _toArt(d.globalPosition);
    if (t == null || art == null || _drag == null) return;
    final cell = _cellFor(t, art);
    if (cell != _drag) setState(() => _drag = cell);
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    final t = _selectedThing;
    final cell = _drag;
    setState(() => _drag = null);
    if (t == null || cell == null || (cell.$1 == t.a && cell.$2 == t.b)) return;
    if (!await _moveTo(t, cell.$1, cell.$2) && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 물건과 겹쳐서 원래 자리로 돌아갔어요'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = spaceRoomById(widget.roomId);
    var things = _things;
    final sel = _selectedThing;
    var valid = true;
    if (sel != null && _drag != null) {
      final (a, b) = _drag!;
      valid = fits(widget.roomId, _stage, things, sel, a, b);
      things = [for (final t in things) t.key == sel.key ? t.at(a, b) : t];
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
                  onTapUp: _onTapUp,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: RoomPicture(
                    key: _roomKey,
                    roomId: widget.roomId,
                    stage: _stage,
                    buddy: widget.buddy,
                    photo: widget.photo,
                    night: widget.night,
                    decor: _decor,
                    things: things,
                    selectedKey: _selected,
                    selectionValid: valid,
                  ),
                ),
              ),
            ),
          ),
          _selectionBar(sel),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (stored.isNotEmpty) ...[
                  const Text('보관함', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  for (final t in stored)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _icon(t.isDecor ? decorById(t.id)?.icon : Icons.chair_outlined),
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
                const Text('상점', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                for (final item in kDecorItems)
                  if (!_decor.owned.contains(item.id))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _icon(item.icon),
                      title: Text(item.name),
                      subtitle: Text('${item.price} 코인 · ${item.spot == DecorSpot.wall ? '벽' : '바닥'}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: FilledButton.tonal(
                        // 앱 기본 버튼은 가로를 꽉 채우므로, 목록 오른쪽에 들어가게 크기를 정한다.
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

  Widget _icon(IconData? icon) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: JdColors.soloTint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon ?? Icons.category_outlined, color: JdColors.solo, size: 22),
      );

  /// 고른 물건 이름, 한 칸씩 옮기기 버튼, 보관함에 넣기.
  Widget _selectionBar(PlacedThing? sel) {
    if (sel == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text('가구나 소품을 눌러서 고르고, 끌어서 옮겨 보세요.',
            style: TextStyle(fontSize: 13, color: JdColors.subtle)),
      );
    }
    // 바닥: x는 오른쪽 아래, y는 왼쪽 아래. 벽: y는 왼쪽 아래, z는 위.
    final moves = sel.wall
        ? [
            ('위로', Icons.north, 0, 1),
            ('아래로', Icons.south, 0, -1),
            ('왼쪽으로', Icons.south_west, 1, 0),
            ('오른쪽으로', Icons.north_east, -1, 0),
          ]
        : [
            ('왼쪽 위로', Icons.north_west, -1, 0),
            ('오른쪽 위로', Icons.north_east, 0, -1),
            ('왼쪽 아래로', Icons.south_west, 0, 1),
            ('오른쪽 아래로', Icons.south_east, 1, 0),
          ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(sel.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          for (final (label, icon, da, db) in moves)
            IconButton(
              tooltip: label,
              visualDensity: VisualDensity.compact,
              icon: Icon(icon, size: 20),
              onPressed: () => _nudge(da, db),
            ),
          TextButton(onPressed: () => _store(sel), child: const Text('보관함에')),
        ],
      ),
    );
  }
}
