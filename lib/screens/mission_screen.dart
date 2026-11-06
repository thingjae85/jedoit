import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../services/record_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/photo.dart';

/// 사진 한 장을 고른다. 고르지 않으면 null. 테스트에서 바꿔 끼운다.
typedef PhotoPicker = Future<Uint8List?> Function();

Future<Uint8List?> pickPhotoFromDevice() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080);
  return f == null ? null : await f.readAsBytes();
}

/// 혼자 하는 미션 화면. 미션을 증명하는 곳이 아니라 해낸 일을 남기는 곳이다.
/// '했어요' 버튼만 눌러도 끝나고, 타이머·사진·메모는 원할 때만 쓴다.
/// 저장에 성공하면 저장한 기록을 돌려주며 닫힌다.
class MissionScreen extends StatefulWidget {
  const MissionScreen({
    super.key,
    required this.mission,
    required this.repository,
    this.theme,
    this.pickPhoto = pickPhotoFromDevice,
  });

  final Mission mission;
  final RecordRepository repository;

  /// 오늘의 발견 주제.
  final DiscoveryTheme? theme;
  final PhotoPicker pickPhoto;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  static const int memoMaxLength = 200;

  final TextEditingController _memoController = TextEditingController();
  final DateTime _openedAt = DateTime.now();
  Timer? _timer;
  Duration? _remaining;
  String? _photo; // base64 JPEG
  bool _pickingPhoto = false;
  bool _saving = false;

  bool get _timeUp => _remaining != null && _remaining! <= Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  void _startTimer() {
    final minutes = widget.mission.timerMinutes;
    if (minutes == null) return;
    _timer?.cancel();
    setState(() => _remaining = Duration(minutes: minutes));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _remaining;
      if (left == null || !mounted) return;
      final next = left - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  Future<void> _addPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final bytes = await widget.pickPhoto();
      if (bytes == null || !mounted) return;
      final photo = makeKeepsakePhoto(bytes);
      if (mounted) setState(() => _photo = photo);
    } on PhotoException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요')));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final mission = widget.mission;
    final now = DateTime.now();
    final record = MissionRecord(
      id: '${mission.id}-${now.microsecondsSinceEpoch}',
      missionId: mission.id,
      startedAt: _openedAt,
      completedAt: now,
      memo: _memoController.text.trim(),
      title: mission.kind == MissionKind.custom ? mission.title : null,
      theme: widget.theme?.id,
      photo: _photo,
    );

    try {
      await widget.repository.add(record);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요')),
      );
      return;
    }
    if (!mounted) return;
    _timer?.cancel();
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final theme = widget.theme;
    final discovery = mission.kind == MissionKind.discovery;

    return Scaffold(
      appBar: AppBar(title: Text(mission.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: JdColors.soloTint, borderRadius: BorderRadius.circular(20)),
                child: Icon(mission.icon, size: 32, color: JdColors.solo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discovery && theme != null) ...[
                      Text('오늘의 주제: ${theme.title}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(theme.hint, style: const TextStyle(fontSize: 14, color: JdColors.subtle)),
                    ] else
                      Text(mission.description, style: const TextStyle(fontSize: 15, color: JdColors.subtle)),
                  ],
                ),
              ),
            ],
          ),
          if (mission.timerMinutes != null) ...[
            const SizedBox(height: 20),
            if (_remaining == null)
              OutlinedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.timer_outlined),
                label: Text('타이머 켜기 (${mission.timerMinutes}분)'),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                decoration: BoxDecoration(color: JdColors.soloTint, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _TimerDisplay(remaining: _remaining!),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1 - _remaining!.inSeconds / (mission.timerMinutes! * 60),
                        minHeight: 8,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _timeUp ? '시간이 끝났어요. 수고했어요.' : '먼저 끝나면 바로 완료해도 돼요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: JdColors.soloText),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          const Text('남기고 싶으면 (선택)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('사진과 메모는 나만 봐요. 사진은 방 벽 액자에 걸려요.',
              style: TextStyle(fontSize: 12, color: JdColors.subtle)),
          const SizedBox(height: 12),
          if (_photo == null)
            OutlinedButton.icon(
              onPressed: _saving || _pickingPhoto ? null : _addPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_pickingPhoto ? '사진 불러오는 중...' : (discovery ? '발견한 거 찍기' : '사진 남기기')),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(_photo!), width: 88, height: 88, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _photo = null),
                  child: const Text('사진 빼기'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            enabled: !_saving,
            maxLength: memoMaxLength,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              hintText: '어땠는지 한 줄 남겨 보세요',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중...' : '했어요'),
          ),
          const SizedBox(height: 8),
          const Text('안 남겨도 완료돼요.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: JdColors.faint)),
        ],
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        formatDuration(remaining),
        key: const Key('timerText'),
        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: JdColors.soloText,
            fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}
