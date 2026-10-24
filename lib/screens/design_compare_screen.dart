import 'package:flutter/material.dart';

/// 시안 비교 인터뷰용 정적 화면(기능 아님).
/// 같은 상황(3명 방, 정리된 요소 5 / 9, 목표 6)을 두 가지 방식으로 보여 준다.
class DesignCompareScreen extends StatelessWidget {
  const DesignCompareScreen({super.key});

  static const int total = 9; // 3명 × 3일
  static const int done = 5;
  static const int goal = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('시안 비교')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '인터뷰용 정적 시안입니다. 같은 상황을 두 가지로 보여 드려요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const _SketchCard(label: '시안 A · 숫자 진행률', child: _ProgressSketch()),
          const SizedBox(height: 16),
          const _SketchCard(label: '시안 B · 공동 책상', child: _DeskSketch()),
        ],
      ),
    );
  }
}

class _SketchCard extends StatelessWidget {
  const _SketchCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProgressSketch extends StatelessWidget {
  const _ProgressSketch();

  @override
  Widget build(BuildContext context) {
    final percent = (DesignCompareScreen.done * 100 / DesignCompareScreen.total)
        .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '인증 ${DesignCompareScreen.done} / ${DesignCompareScreen.total}  ($percent%)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: DesignCompareScreen.done / DesignCompareScreen.total,
          minHeight: 12,
        ),
        const SizedBox(height: 8),
        Text('목표 ${DesignCompareScreen.goal}회까지 ${DesignCompareScreen.goal - DesignCompareScreen.done}회 남음'),
      ],
    );
  }
}

class _DeskSketch extends StatelessWidget {
  const _DeskSketch();

  static const List<IconData> _items = [
    Icons.menu_book,
    Icons.coffee,
    Icons.laptop_mac,
    Icons.lightbulb,
    Icons.edit,
    Icons.local_florist,
    Icons.access_time,
    Icons.note,
    Icons.headphones,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '정리된 요소 ${DesignCompareScreen.done} / ${DesignCompareScreen.total}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < _items.length; i++)
              _DeskItem(icon: _items[i], tidy: i < DesignCompareScreen.done, index: i),
          ],
        ),
        const SizedBox(height: 8),
        Text('목표 ${DesignCompareScreen.goal}개까지 ${DesignCompareScreen.goal - DesignCompareScreen.done}개 남음'),
      ],
    );
  }
}

class _DeskItem extends StatelessWidget {
  const _DeskItem({required this.icon, required this.tidy, required this.index});

  final IconData icon;
  final bool tidy;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 어질러진 물건은 약간씩 다르게 기울여 흐트러진 느낌을 준다.
    final angle = tidy ? 0.0 : (index.isEven ? 0.35 : -0.35);
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: tidy ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tidy ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Icon(
          icon,
          color: tidy ? scheme.onPrimaryContainer : scheme.outline,
        ),
      ),
    );
  }
}
