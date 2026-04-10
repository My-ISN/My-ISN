import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';

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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'dashboard.working_duration'.tr(context),
                    _formatWorkingDuration(stats?['working_duration']),
                    Icons.hourglass_empty,
                    const Color(0xFF2ECC71),
                  ),
                ),
                _buildDivider(context),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'dashboard.my_leave'.tr(context),
                    '${stats?['leave_count'] ?? 0}',
                    Icons.calendar_today,
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                height: 1,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'dashboard.overtime_request'.tr(context),
                    '${stats?['overtime_count'] ?? 0}',
                    Icons.more_time,
                    const Color(0xFF7E57C2),
                  ),
                ),
                _buildDivider(context),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'dashboard.travel_request'.tr(context),
                    '${stats?['travel_count'] ?? 0}',
                    Icons.flight_takeoff,
                    const Color(0xFF2ECC71),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
          ),
        ],
      ),
    );
  }
}
