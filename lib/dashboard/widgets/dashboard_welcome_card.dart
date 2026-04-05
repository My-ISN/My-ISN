import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class DashboardWelcomeCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? attendance;
  final VoidCallback onClockBreak;

  const DashboardWelcomeCard({
    super.key,
    required this.user,
    this.stats,
    this.attendance,
    required this.onClockBreak,
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

    String breakLabel = 'dashboard.break_time_clock'.tr(context);
    if (hasBreakIn) {
      breakLabel = 'dashboard.already_break'.tr(context);
    } else if (hasBreakOut) {
      breakLabel = 'dashboard.end_break'.tr(context);
    } else if (hasClockIn) {
      breakLabel = 'dashboard.start_break'.tr(context);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  const Color(0xFF2ECC71),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeDisplay(
                  'dashboard.clock_out'.tr(context).toUpperCase(),
                  hasClockOut ? attendance!['clock_out'] : '--:--',
                  const Color(0xFFE74C3C),
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
                          : '') +
                      (hasBreakOut
                          ? ' | Rest: ${attendance!['break_out']}${hasBreakIn ? ' - ${attendance!['break_in']}' : ''}'
                          : '')
                  : 'dashboard.clock_in_only_details'.tr(
                      context,
                      args: {'in': attendance!['clock_in']},
                    ),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          if (hasBreakIn || hasBreakOut)
            Text(
              'Rest: ${attendance!['break_out']}${hasBreakIn ? ' - ${attendance!['break_in']}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!hasClockIn || hasClockOut || hasBreakIn)
                  ? null
                  : onClockBreak,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                breakLabel,
                style: TextStyle(
                  color: (!hasClockIn || hasClockOut || hasBreakIn)
                      ? Colors.grey
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(String label, String value, Color color) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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
