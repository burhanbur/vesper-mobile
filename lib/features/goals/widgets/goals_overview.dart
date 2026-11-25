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
    final total = progresses.length;
    final achieved = progresses.where((progress) => progress.achieved).length;
    final remaining = total - achieved;
    final isEmpty = total == 0;
    final ratio = total > 0 ? achieved / total : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F3E33),
            Color(0xFF1B5E4B),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                size: 14,
                color: AppColors.accentLight,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'IMPIAN & TARGET FINANSIAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (!isEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total Goal',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (isEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GoalIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mulai dari satu impian',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Belum ada goal. Buat target pertama kamu untuk memantau progres tabungan secara terukur.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 18,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hidden)
                  const _GoalIcon(neutral: true)
                else
                  Semantics(
                    label: 'Target tercapai: $achieved dari $total',
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 78,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CircularProgressIndicator(
                                value: ratio,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                color: const Color(0xFF34D399),
                              ),
                            ),
                            Icon(
                              achieved == total
                                  ? Icons.emoji_events_rounded
                                  : Icons.track_changes_rounded,
                              size: 28,
                              color: achieved == total
                                  ? const Color(0xFFFDE68A)
                                  : Colors.white,
                            ),
                          ],
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hidden ? '••• / $total' : '$achieved / $total',
                      semanticsLabel: hidden
                          ? 'Progres disembunyikan. Total $total goal'
                          : null,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _GoalCount(
                    label: 'Belum tercapai',
                    count: hidden ? '•••' : '$remaining',
                    color: hidden
                        ? Colors.white54
                        : const Color(0xFFFBBF24),
                  ),
                  _GoalCount(
                    label: 'Tercapai',
                    count: hidden ? '•••' : '$achieved',
                    color: hidden
                        ? Colors.white54
                        : const Color(0xFF34D399),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(
                isEmpty ? 'Buat goal pertama' : 'Buat goal baru',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: neutral ? 0.14 : 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(
        Icons.track_changes_rounded,
        size: 30,
        color: neutral ? Colors.white70 : Colors.white,
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
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      semanticsLabel: '$label: ${count == '•••' ? 'disembunyikan' : count}',
      style: const TextStyle(fontSize: 12.5),
    );
  }
}
