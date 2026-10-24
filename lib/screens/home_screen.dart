import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../services/record_repository.dart';
import 'design_compare_screen.dart';
import 'mission_screen.dart';
import 'records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _recordCount = 0;
  int _todayCount = 0;
  Set<String> _todayMissions = {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final records = await widget.repository.loadAll();
      if (!mounted) return;
      final now = DateTime.now();
      final today = records.where((record) {
        final date = record.completedAt.toLocal();
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
      setState(() {
        _recordCount = records.length;
        _todayCount = today.length;
        _todayMissions = today.map((r) => r.missionId).toSet();
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _openMission(Mission mission) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MissionScreen(mission: mission, repository: widget.repository),
      ),
    );
    await _refreshCount();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록을 이 기기에 저장했어요')),
      );
    }
  }

  Future<void> _openRecords() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordsScreen(repository: widget.repository),
      ),
    );
    await _refreshCount();
  }

  void _openDesignCompare() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const DesignCompareScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('저두잇'),
        actions: [
          IconButton(
            tooltip: '시안 비교',
            icon: const Icon(Icons.compare),
            onPressed: _openDesignCompare,
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.history),
            onPressed: _openRecords,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('오늘 하나만 해볼까요?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '작은 미션 하나를 골라 먼저 혼자 체험해 보세요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘의 작은 실천', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_loadFailed ? '기록을 불러오지 못했어요' : '오늘 $_todayCount번 완료',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(_todayCount == 0 ? '하나만 해도 좋은 시작이에요.' : '작은 실천이 쌓이고 있어요.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadFailed ? _refreshCount : _openRecords,
                    icon: Icon(_loadFailed ? Icons.refresh : Icons.arrow_forward),
                    label: Text(_loadFailed ? '다시 불러오기' : '전체 기록 $_recordCount개 보기'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('오늘 할 미션', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final mission in kMissions) ...[
            _MissionCard(mission: mission, completed: _todayMissions.contains(mission.id), onTap: () => _openMission(mission)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '기록은 이 기기·브라우저에만 저장돼요.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.completed, required this.onTap});

  final Mission mission;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: mission.challengeReady ? 3 : 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(mission.icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(mission.title),
        subtitle: Text('${mission.description}${completed ? '\n오늘 완료했어요 · 다시 해도 좋아요' : ''}'),
        trailing: completed ? const Icon(Icons.check_circle, color: Color(0xFF3E7C6B)) : mission.challengeReady
            ? Chip(
                label: const Text('추천'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.secondaryContainer,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
