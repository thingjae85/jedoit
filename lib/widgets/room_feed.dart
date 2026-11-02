import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/room.dart';
import '../theme.dart';
import 'jd_widgets.dart';

/// 방 피드의 인증 카드. 결과 사진·동영상, 전후 넘겨 보기, 가벼운 한 줄을 한 모양으로 보여 준다.
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item, required this.avatarIndex});

  final FeedItem item;
  final int avatarIndex;

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
          const SizedBox(height: 14),
        ],
      ),
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
