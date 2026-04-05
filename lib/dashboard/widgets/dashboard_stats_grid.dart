import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class DashboardStatsGrid extends StatelessWidget {
  final Map<String, dynamic>? stats;

  const DashboardStatsGrid({super.key, this.stats});

  String _formatWorkingDuration(String? duration) {
    if (duration == null || duration.isEmpty || duration == '-') return '0h 0m';
    
    // Simple logic from dashboard_page
    if (duration.contains('Day') || 
        duration.contains('Days') || 
        duration.contains('Month') || 
        duration.contains('Months') || 
        duration.contains('Year') || 
        duration.contains('Years')) {
      final regExpID = RegExp(r'\s*\d+\s+Hari$');
      final regExpEN = RegExp(r'\s*\d+\s+Day(s)?$');
      return duration.replaceAll(regExpID, '').replaceAll(regExpEN, '').trim();
    }
    return duration;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'dashboard.working_duration'.tr(context),
                _formatWorkingDuration(stats?['working_duration']),
                Icons.hourglass_empty,
                const Color(0xFF2ECC71),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'dashboard.my_leave'.tr(context),
                '${stats?['leave_count'] ?? 0}',
                Icons.calendar_today,
                const Color(0xFF7E57C2),
                isOutline: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'dashboard.overtime_request'.tr(context),
                '${stats?['overtime_count'] ?? 0}',
                Icons.more_time,
                const Color(0xFF7E57C2),
                isOutline: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'dashboard.travel_request'.tr(context),
                '${stats?['travel_count'] ?? 0}',
                Icons.flight_takeoff,
                const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isOutline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOutline ? Theme.of(context).cardColor : color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : (isOutline
                    ? Theme.of(context).dividerColor
                    : Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isOutline ? Colors.grey : Colors.white,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: isOutline ? color : Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isOutline
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
