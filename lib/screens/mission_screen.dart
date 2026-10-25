import 'dart:async';

import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../services/record_repository.dart';
import '../utils/format.dart';

/// 개인 미션 실행 화면: 시작 → 실제 활동(타이머) → 완료 체크·메모 → 저장.
/// 저장에 성공하면 저장한 기록을 반환하며 닫힌다.
class MissionScreen extends StatefulWidget {
  const MissionScreen({
    super.key,
    required this.mission,
    required this.repository,
  });

  final Mission mission;
  final RecordRepository repository;

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  static const int memoMaxLength = 200;

  final TextEditingController _memoController = TextEditingController();
  Timer? _timer;
  DateTime? _startedAt;
  Duration? _remaining;
  bool _checked = false;
  bool _saving = false;

  bool get _started => _startedAt != null;
  bool get _timeUp => _remaining != null && _remaining! <= Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  void _start() {
    final minutes = widget.mission.timerMinutes;
    setState(() {
      _startedAt = DateTime.now();
      _remaining = minutes == null ? null : Duration(minutes: minutes);
    });
    if (minutes != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final left = _remaining;
        if (left == null) return;
        final next = left - const Duration(seconds: 1);
        if (next <= Duration.zero) {
          timer.cancel();
          setState(() => _remaining = Duration.zero);
        } else {
          setState(() => _remaining = next);
        }
      });
    }
  }

  Future<void> _save() async {
    final startedAt = _startedAt;
    if (startedAt == null || !_checked || _saving) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final record = MissionRecord(
      id: '${widget.mission.id}-${now.microsecondsSinceEpoch}',
      missionId: widget.mission.id,
      startedAt: startedAt,
      completedAt: now,
      memo: _memoController.text.trim(),
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
    final theme = Theme.of(context);
    final mission = widget.mission;

    return Scaffold(
      appBar: AppBar(title: Text(mission.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(mission.icon, size: 36, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(_started ? '02  실천하고 기록하기' : '01  작은 미션 시작하기',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text(mission.description, style: theme.textTheme.titleMedium),
          const SizedBox(height: 24),
          if (!_started)
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('시작하기'),
            )
          else ...[
            if (_remaining != null) _TimerDisplay(remaining: _remaining!),
            if (_remaining != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: 1 - _remaining!.inSeconds / (mission.timerMinutes! * 60),
                minHeight: 8,
              ),
              const SizedBox(height: 12),
              const Text('5분은 권장 시간이에요. 정리를 마쳤다면 먼저 기록해도 돼요.',
                  textAlign: TextAlign.center),
            ],
            if (_timeUp)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '시간이 끝났어요. 마무리하고 기록을 남겨요.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _checked,
              onChanged: _saving ? null : (v) => setState(() => _checked = v ?? false),
              title: const Text('실제로 했어요'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              enabled: !_saving,
              maxLength: memoMaxLength,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '어땠는지 한 줄 남겨 보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_checked && !_saving) ? _save : null,
              child: Text(_saving ? '저장 중...' : '기록 저장'),
            ),
          ],
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
        style: Theme.of(context).textTheme.displayLarge,
      ),
    );
  }
}
