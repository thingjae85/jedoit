import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/mission_record.dart';
import '../services/record_repository.dart';
import '../utils/format.dart';

/// 개인 기록 목록. 기록 하나 삭제·전체 삭제는 확인창을 거친다.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<MissionRecord>? _records; // null이면 불러오는 중
  bool _loadFailed = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _remove(Future<void> Function() action) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteOne(MissionRecord record) async {
    final ok = await _confirm(
      title: '이 기록을 삭제할까요?',
      message: '삭제하면 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok) return;
    await _remove(() => widget.repository.delete(record.id));
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: '모든 기록을 삭제할까요?',
      message: '이 기기에 저장된 기록이 모두 지워지며 되돌릴 수 없어요.',
      confirmLabel: '전체 삭제',
    );
    if (!ok) return;
    await _remove(widget.repository.deleteAll);
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 기록'),
        actions: [
          if (records != null && records.isNotEmpty)
            IconButton(
              tooltip: '전체 삭제',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleting ? null : _deleteAll,
            ),
        ],
      ),
      body: _loadFailed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('기록을 불러오지 못했어요'),
              TextButton(onPressed: _load, child: const Text('다시 불러오기')),
            ]))
          : records == null
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.spa_outlined, size: 56, color: Color(0xFF3E7C6B)),
                  const SizedBox(height: 16),
                  const Text('아직 기록이 없어요'),
                  const SizedBox(height: 8),
                  const Text('미션 하나를 완료하고 첫 기록을 남겨 보세요.'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => Navigator.of(context).pop(),
                      child: const Text('미션 고르기')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RecordTile(
                    record: records[i],
                    onDelete: _deleting ? null : () => _deleteOne(records[i]),
                  ),
                ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final MissionRecord record;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final mission = missionById(record.missionId);
    return Card(
      child: ListTile(
        leading: Icon(mission?.icon ?? Icons.check_circle),
        title: Text(mission?.title ?? '알 수 없는 미션'),
        subtitle: Text(
          record.memo.isEmpty
              ? formatDateTime(record.completedAt)
              : '${formatDateTime(record.completedAt)}\n${record.memo}',
        ),
        isThreeLine: record.memo.isNotEmpty,
        trailing: IconButton(
          tooltip: '삭제',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
