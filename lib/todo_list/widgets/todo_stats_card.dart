import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class TodoStatsCard extends StatelessWidget {
  final int totalCount;
  final int completedCount;
  final int pendingCount;
  final int completedTodayCount;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Color primaryColor;

  const TodoStatsCard({
    super.key,
    required this.totalCount,
    required this.completedCount,
    required this.pendingCount,
    required this.completedTodayCount,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    double progress = totalCount > 0 ? (completedCount / totalCount) : 0;
    if (progress > 1.0) progress = 1.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).primaryColor.withValues(alpha: 0.04)
          : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'todo_list.stats_title'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'todo_list.general_accumulation'.tr(context),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatMiniRow(
                                context,
                                'main.total'.tr(context),
                                totalCount.toString(),
                                Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              _buildStatMiniRow(
                                context,
                                'todo_list.completed_today'.tr(context),
                                completedTodayCount.toString(),
                                Colors.purple,
                              ),
                              const SizedBox(height: 12),
                              _buildStatMiniRow(
                                context,
                                'todo_list.complete'.tr(context),
                                completedCount.toString(),
                                Colors.green,
                              ),
                              const SizedBox(height: 12),
                              _buildStatMiniRow(
                                context,
                                'todo_list.pending'.tr(context),
                                pendingCount.toString(),
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 10,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(value * 100).toInt()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      'todo_list.completed'
                                          .tr(context)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniRow(BuildContext context, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
