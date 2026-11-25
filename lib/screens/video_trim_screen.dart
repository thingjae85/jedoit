import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trim/video_trim.dart';

import '../theme.dart';

/// 잘라 낼 구간 길이. 인증 동영상은 5초 미만이어야 해서 조금 짧게 둔다.
const trimWindowSeconds = 4.8;

/// 5초가 넘는 동영상에서 올릴 구간을 고른다. 고른 구간을 잘라 만든 MP4 바이트를 돌려준다.
/// 아이폰 앱에서만 쓴다 (자르기는 기기가 한다).
class VideoTrimScreen extends StatefulWidget {
  const VideoTrimScreen({super.key, required this.path});

  final String path;

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  late final VideoPlayerController _player;
  bool _ready = false;
  bool _failed = false;
  bool _busy = false;
  double _start = 0;
  String? _error;

  double get _total => _player.value.duration.inMilliseconds / 1000;
  double get _maxStart => (_total - trimWindowSeconds).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.path));
    _player.initialize().then((_) async {
      if (!mounted) return;
      _player.addListener(_loopWindow);
      await _player.setVolume(0);
      await _player.play();
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  /// 고른 구간만 반복해서 보여 준다.
  void _loopWindow() {
    final pos = _player.value.position.inMilliseconds / 1000;
    if (pos >= _start + trimWindowSeconds || pos < _start - 0.3) {
      _player.seekTo(Duration(milliseconds: (_start * 1000).round()));
    }
  }

  @override
  void dispose() {
    _player.removeListener(_loopWindow);
    _player.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await _player.pause();
    try {
      final bytes = await trimVideo(widget.path, start: _start, seconds: trimWindowSeconds);
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '동영상을 자르지 못했어요. 다른 구간이나 다른 동영상으로 해 주세요.';
      });
      unawaited(_player.play());
    }
  }

  String _sec(double s) => '${s.toStringAsFixed(1)}초';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('올릴 구간 고르기')),
      body: SafeArea(
        child: _failed
            ? const Center(child: Text('동영상을 열지 못했어요. 다른 동영상을 골라 주세요.'))
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text('${_sec(_total)} 동영상이에요. 올릴 ${_sec(trimWindowSeconds)}를 골라 주세요.',
                          style: const TextStyle(fontSize: 15, color: JdColors.subtle)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                          color: JdColors.roomNavy,
                          child: AspectRatio(
                            aspectRatio: _player.value.aspectRatio,
                            child: VideoPlayer(_player),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _start.clamp(0, _maxStart).toDouble(),
                        max: _maxStart <= 0 ? 1 : _maxStart,
                        onChanged: _busy || _maxStart <= 0
                            ? null
                            : (v) {
                                setState(() => _start = v);
                                _player.seekTo(Duration(milliseconds: (v * 1000).round()));
                              },
                      ),
                      Center(
                        child: Text('${_sec(_start)} ~ ${_sec(_start + trimWindowSeconds)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: JdColors.together),
                        onPressed: _busy ? null : _use,
                        child: Text(_busy ? '자르는 중...' : '이 구간 쓰기'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
