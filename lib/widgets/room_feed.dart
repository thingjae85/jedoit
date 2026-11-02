import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/room.dart';
import '../theme.dart';
import 'jd_widgets.dart';

/// 방 피드의 인증 카드. 결과 사진·동영상, 전후 넘겨 보기, 가벼운 한 줄을 한 모양으로 보여 준다.
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item, required this.avatarIndex, this.onReact});

  final FeedItem item;
  final int avatarIndex;

  /// 친구 인증에 응원 누르기. 내 인증이면 개수만 보여 준다.
  final void Function(Reaction reaction)? onReact;

  @override
  Widget build(BuildContext context) {
    final t = item.checkedAt.toLocal();
    final time = '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JdColors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                FriendAvatar(name: item.nickname, index: avatarIndex, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${item.displayName}${item.isMe ? ' (나)' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text(time, style: const TextStyle(fontSize: 12, color: JdColors.faint)),
              ],
            ),
          ),
          if (item.isBeforeAfter)
            BeforeAfterPager(item: item)
          else if (item.media == FeedMedia.video && item.mediaUrl != null)
            FeedVideo(url: item.mediaUrl!)
          else if (item.media == FeedMedia.photo && item.mediaUrl != null)
            AspectRatio(aspectRatio: 4 / 3, child: _NetImage(item.mediaUrl!))
          else if (item.media == FeedMedia.none)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: JdColors.togetherTint, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: JdColors.together),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.note ?? '했어요',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          if (!item.isBeforeAfter && item.media != FeedMedia.none && (item.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(item.note!, style: const TextStyle(fontSize: 15)),
            ),
          if (item.mediaUrl == null && item.media != FeedMedia.none)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Text('사진을 삭제한 인증이에요', style: TextStyle(fontSize: 13, color: JdColors.faint)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                for (final r in Reaction.values)
                  ReactionButton(
                    key: Key('reaction-${item.key}-${r.serverName}'),
                    reaction: r,
                    count: item.count(r),
                    pressed: item.mine(r),
                    onTap: item.isMe || onReact == null ? null : () => onReact!(r),
                  ),
                if (item.isMe && item.claps + item.fires > 0) ...[
                  const SizedBox(width: 4),
                  const Text('친구들이 응원했어요', style: TextStyle(fontSize: 12, color: JdColors.faint)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 👏 3 같은 응원 버튼. 누르면 살짝 튀어 오른다.
class ReactionButton extends StatefulWidget {
  const ReactionButton({super.key, required this.reaction, required this.count, required this.pressed, this.onTap});

  final Reaction reaction;
  final int count;
  final bool pressed;
  final VoidCallback? onTap;

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.pressed;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: on ? JdColors.togetherChip : JdColors.panel,
        shape: StadiumBorder(side: BorderSide(color: on ? JdColors.togetherFill : JdColors.line, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onTap == null
              ? null
              : () {
                  _bounce.forward(from: 0);
                  widget.onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: TweenSequence([
                    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 1),
                    TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 1),
                  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut)),
                  child: Text(widget.reaction.emoji, style: const TextStyle(fontSize: 17)),
                ),
                if (widget.count > 0) ...[
                  const SizedBox(width: 5),
                  Text('${widget.count}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: on ? JdColors.togetherText : JdColors.subtle)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘의 콜라주: 오늘 인증한 친구들의 사진을 한 장처럼 모아 보여 준다.
class TodayCollage extends StatelessWidget {
  const TodayCollage({super.key, required this.items, required this.memberCount, required this.avatarIndexOf});

  final List<FeedItem> items;
  final int memberCount;
  final int Function(FeedItem) avatarIndexOf;

  @override
  Widget build(BuildContext context) {
    final done = items.length;
    final all = memberCount > 0 && done >= memberCount;
    final cols = done <= 1 ? 1 : 2;
    return Container(
      key: const Key('todayCollage'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: all ? JdColors.together : JdColors.togetherTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            all ? '🎉 오늘 모두 정리 완료!' : '오늘 $memberCount명 중 $done명이 정리했어요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: all ? Colors.white : JdColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            all ? '같은 날, 각자의 자리에서 함께 정리했어요' : '아직 안 한 친구를 기다리고 있어요',
            style: TextStyle(fontSize: 13, color: all ? Colors.white70 : JdColors.subtle),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: cols == 1 ? 4 / 3 : 1,
              children: [for (final item in items) _CollageTile(item: item, avatarIndex: avatarIndexOf(item))],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile({required this.item, required this.avatarIndex});
  final FeedItem item;
  final int avatarIndex;

  @override
  Widget build(BuildContext context) {
    final Widget back;
    if (item.media == FeedMedia.photo && item.mediaUrl != null) {
      back = _NetImage(item.mediaUrl!);
    } else if (item.media == FeedMedia.video && item.mediaUrl != null) {
      back = const ColoredBox(
        color: Colors.black87,
        child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
      );
    } else {
      back = ColoredBox(
        color: JdColors.avatars[avatarIndex % JdColors.avatars.length],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              (item.note ?? '').isEmpty ? '✓ 했어요' : item.note!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        back,
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(item.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// 전후 인증: 옆으로 넘겨 전·후 사진과 각자의 한 줄을 본다.
class BeforeAfterPager extends StatefulWidget {
  const BeforeAfterPager({super.key, required this.item});
  final FeedItem item;

  @override
  State<BeforeAfterPager> createState() => _BeforeAfterPagerState();
}

class _BeforeAfterPagerState extends State<BeforeAfterPager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ('전', widget.item.beforeUrl!, widget.item.beforeNote),
      ('후', widget.item.mediaUrl!, widget.item.note),
    ];
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              PageView(
                key: const Key('beforeAfterPager'),
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final (label, url, _) in pages)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        _NetImage(url),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: Text(label,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page ? Colors.white : Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${pages[_page].$1}  ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: JdColors.together)),
              Expanded(
                child: Text(
                  (pages[_page].$3 ?? '').isEmpty ? (_page == 0 ? '옆으로 넘겨서 후 사진을 보세요' : '') : pages[_page].$3!,
                  key: const Key('beforeAfterNote'),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 5초 미만 동영상: 눌러서 재생, 소리 없이 반복.
class FeedVideo extends StatefulWidget {
  const FeedVideo({super.key, required this.url});
  final String url;

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null) {
      final created = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      setState(() => _controller = created);
      try {
        await created.initialize();
        await created.setVolume(0);
        await created.setLooping(true);
        await created.play();
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
      if (mounted) setState(() {});
      return;
    }
    c.value.isPlaying ? await c.pause() : await c.play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return GestureDetector(
      onTap: _failed ? null : _toggle,
      child: AspectRatio(
        aspectRatio: ready ? c.value.aspectRatio : 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready) VideoPlayer(c) else const ColoredBox(color: Colors.black87),
            if (!ready || !c.value.isPlaying)
              Center(
                child: _failed
                    ? const Text('동영상을 재생하지 못했어요', style: TextStyle(color: Colors.white))
                    : const Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
              ),
          ],
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage(this.url);
  final String url;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: JdColors.empty,
          child: Center(child: Icon(Icons.broken_image_outlined, color: JdColors.faint)),
        ),
      );
}
