import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/goals_repository.dart';

/// A currency-independent summary of active and achieved goals.
class GoalsOverview extends StatelessWidget {
  const GoalsOverview({
    super.key,
    required this.progresses,
    required this.hidden,
    required this.onCreate,
  });

  final List<GoalProgress> progresses;
  final bool hidden;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = progresses.length;
    final achieved = progresses.where((progress) => progress.achieved).length;
    final isEmpty = total == 0;

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impian & target',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (isEmpty) ...[
              const _GoalIcon(),
              const SizedBox(height: 16),
              Text(
                'Mulai dari satu impian',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada goal. Buat target pertama kamu.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              Wrap(
                spacing: 20,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hidden)
                    const _GoalIcon(neutral: true)
                  else
                    Semantics(
                      label: 'Target tercapai: $achieved dari $total',
                      child: ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 88,
                          child: CircularProgressIndicator(
                            value: achieved / total,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: AppColors.surfaceVariant,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Target tercapai',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hidden ? '••• / $total' : '$achieved / $total',
                        semanticsLabel: hidden
                            ? 'Progres disembunyikan. Total $total goal'
                            : null,
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _GoalCount(
                    label: 'Belum tercapai',
                    count: hidden ? '•••' : '${total - achieved}',
                    color: hidden ? AppColors.textMuted : AppColors.sageMuted,
                  ),
                  _GoalCount(
                    label: 'Tercapai',
                    count: hidden ? '•••' : '$achieved',
                    color: hidden ? AppColors.textMuted : AppColors.accentDark,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(isEmpty ? 'Buat goal pertama' : 'Buat goal baru'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalIcon extends StatelessWidget {
  const _GoalIcon({this.neutral = false});

  final bool neutral;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: neutral ? AppColors.surfaceVariant : AppColors.accentLight,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.track_changes_rounded,
        size: 36,
        color: neutral ? AppColors.textMuted : AppColors.accentDark,
      ),
    );
  }
}

class _GoalCount extends StatelessWidget {
  const _GoalCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '● ',
            style: TextStyle(color: color),
          ),
          TextSpan(text: '$label: $count'),
        ],
      ),
      semanticsLabel: '$label: ${count == '•••' ? 'disembunyikan' : count}',
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}
