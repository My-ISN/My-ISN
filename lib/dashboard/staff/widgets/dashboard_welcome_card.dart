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
            Text(
              '${'dashboard.welcome'.tr(context)} ${user['nama'] ?? ''}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'dashboard.my_shift'.tr(
                context,
                args: {'shift': stats?['shift'] ?? '-'},
              ),
              style: const TextStyle(
                color: Color(0xFF7E57C2),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeDisplay(
                    'dashboard.clock_in'.tr(context).toUpperCase(),
                    hasClockIn ? attendance!['clock_in'] : '--:--',
                    const Color(0xFF7E57C2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeDisplay(
                    'dashboard.clock_out'.tr(context).toUpperCase(),
                    hasClockOut ? attendance!['clock_out'] : '--:--',
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeDisplay(
                    'dashboard.start_break'.tr(context).toUpperCase(),
                    hasBreakOut ? attendance!['break_out'] : '--:--',
                    const Color(0xFF7E57C2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeDisplay(
                    'dashboard.end_break'.tr(context).toUpperCase(),
                    hasBreakIn ? attendance!['break_in'] : '--:--',
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            if (hasClockIn) ...[
              const SizedBox(height: 16),
              Text(
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
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(String label, String value, Color color) {
    return Builder(builder: (context) {
      if (!context.mounted) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    });
  }
}
