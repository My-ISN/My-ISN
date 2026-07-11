import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';

class DashboardWelcomeCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? attendance;

  const DashboardWelcomeCard({
    super.key,
    required this.user,
    this.stats,
    this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasClockIn = attendance != null &&
        attendance!['clock_in'] != null &&
        attendance!['clock_in'].toString().isNotEmpty &&
        attendance!['clock_in'].toString() != '-';
    final bool hasClockOut = attendance != null &&
        attendance!['clock_out'] != null &&
        attendance!['clock_out'].toString().isNotEmpty &&
        attendance!['clock_out'].toString() != '-';

    final bool hasBreakIn = attendance != null &&
        attendance!['break_in'] != null &&
        attendance!['break_in'].toString().isNotEmpty &&
        attendance!['break_in'].toString() != '-';
    final bool hasBreakOut = attendance != null &&
        attendance!['break_out'] != null &&
        attendance!['break_out'].toString().isNotEmpty &&
        attendance!['break_out'].toString() != '-';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'dashboard.welcome'.tr(context)} ${user['nama'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF7E57C2).withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFF7E57C2),
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'dashboard.my_shift'.tr(
                                    context,
                                    args: {'shift': stats?['shift'] ?? '-'},
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF7E57C2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeDisplay(
                    context: context,
                    label: 'dashboard.clock_in'.tr(context).toUpperCase(),
                    value: hasClockIn ? attendance!['clock_in'] : '--:--',
                    icon: Icons.login_rounded,
                    color: const Color(0xFF10B981), // Emerald Green
                    isActive: hasClockIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeDisplay(
                    context: context,
                    label: 'dashboard.clock_out'.tr(context).toUpperCase(),
                    value: hasClockOut ? attendance!['clock_out'] : '--:--',
                    icon: Icons.logout_rounded,
                    color: const Color(0xFFEF4444), // Crimson Red
                    isActive: hasClockOut,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeDisplay(
                    context: context,
                    label: 'dashboard.start_break'.tr(context).toUpperCase(),
                    value: hasBreakOut ? attendance!['break_out'] : '--:--',
                    icon: Icons.coffee_rounded,
                    color: const Color(0xFFF59E0B), // Amber Orange
                    isActive: hasBreakOut,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeDisplay(
                    context: context,
                    label: 'dashboard.end_break'.tr(context).toUpperCase(),
                    value: hasBreakIn ? attendance!['break_in'] : '--:--',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF3B82F6), // Indigo Blue
                    isActive: hasBreakIn,
                  ),
                ),
              ],
            ),
            if (hasClockIn) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasClockOut
                            ? 'dashboard.clock_in_out_details'.tr(
                                  context,
                                  args: {
                                    'in': attendance!['clock_in'],
                                    'out': attendance!['clock_out'],
                                  },
                                ) +
                                (attendance!['is_early'] == true
                                    ? ' (${'dashboard.early_out'.tr(context)}: ${attendance!['early_time']})'
                                    : '')
                            : 'dashboard.clock_in_only_details'.tr(
                                context,
                                args: {'in': attendance!['clock_in']},
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDisplay({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final cardBgColor = isActive 
        ? color.withValues(alpha: isDark ? 0.15 : 0.08) 
        : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.03));
        
    final cardBorderColor = isActive 
        ? color.withValues(alpha: isDark ? 0.3 : 0.15) 
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08));

    final textColor = isActive 
        ? (isDark ? color.withValues(alpha: 0.9) : color)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: isActive ? [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isActive 
                      ? color.withValues(alpha: 0.12) 
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 13,
                  color: isActive ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive 
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
