import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

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


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'dashboard.welcome'.tr(context)} ${user['nama'] ?? ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          if (hasClockIn) ...[
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(String label, String value, Color color) {
    return Builder(builder: (context) {
      if (!context.mounted) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    });
  }
}
