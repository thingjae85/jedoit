import 'package:flutter/material.dart';

import '../models/buddy.dart';
import '../models/decor.dart';
import '../models/space.dart';
import '../services/space_store.dart';
import '../theme.dart';
import '../widgets/space_view.dart';

/// 꾸미기: 코인으로 소품을 사서 지금 보는 방에 놓거나 보관함에 넣는다.
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

  int get _coins => _decor.available(widget.state.coins);
  int get _stage => widget.state.stageOf(widget.roomId);
  bool get _canPlace => canDecorate(widget.roomId, _stage);

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

  Future<void> _buy(DecorItem item) async {
    var next = _decor.buy(item, widget.state.coins);
    if (identical(next, _decor)) return;
    if (_canPlace) next = next.place(item, widget.roomId);
    await _update(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_canPlace ? '${item.name}을(를) 방에 놓았어요' : '${item.name}을(를) 보관함에 넣었어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = spaceRoomById(widget.roomId);
    final here = _decor.slotsOf(widget.roomId);
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.night ? const Color(0xFF141F2E) : const Color(0xFF22344A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: RoomPicture(
                  roomId: widget.roomId,
                  stage: _stage,
                  buddy: widget.buddy,
                  photo: widget.photo,
                  night: widget.night,
                  decor: here,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _canPlace
                ? '벽에 하나, 바닥에 둘까지 놓을 수 있어요. 산 소품은 치워도 보관함에 남아요.'
                : '방이 조금 더 회복되면 소품을 놓을 수 있어요. 사 두는 건 지금도 돼요.',
            style: const TextStyle(fontSize: 12, color: JdColors.subtle),
          ),
          const SizedBox(height: 8),
          for (final item in kDecorItems) _row(item, here),
          const SizedBox(height: 12),
          const Text('코인은 미션을 하면 10개씩 생겨요. 방이 자라는 건 코인과 상관없어요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: JdColors.faint)),
        ],
      ),
    );
  }

  Widget _row(DecorItem item, Map<String, String> here) {
    final owned = _decor.owned.contains(item.id);
    final where = _decor.roomOf(item.id);
    final String status;
    final Widget action;
    if (!owned) {
      status = '${item.price} 코인 · ${item.spot == DecorSpot.wall ? '벽' : '바닥'}';
      action = FilledButton.tonal(
        onPressed: _coins >= item.price ? () => _buy(item) : null,
        child: const Text('사기'),
      );
    } else if (here.containsValue(item.id)) {
      status = '이 방에 놓여 있어요';
      action = TextButton(onPressed: () => _update(_decor.remove(item.id)), child: const Text('치우기'));
    } else {
      status = where == null ? '보관함에 있어요' : '${spaceRoomById(where)?.name ?? '다른 방'}에 있어요';
      action = FilledButton.tonal(
        onPressed: _canPlace ? () => _update(_decor.place(item, widget.roomId)) : null,
        child: Text(where == null ? '놓기' : '여기로'),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: JdColors.soloTint, borderRadius: BorderRadius.circular(12)),
        child: Icon(item.icon, color: JdColors.solo, size: 22),
      ),
      title: Text(item.name),
      subtitle: Text(status, style: const TextStyle(fontSize: 12)),
      trailing: action,
    );
  }
}
