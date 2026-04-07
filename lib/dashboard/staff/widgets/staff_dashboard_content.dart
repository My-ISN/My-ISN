import 'package:flutter/material.dart';
import 'dashboard_profile_header.dart';
import 'dashboard_welcome_card.dart';
import 'dashboard_stats_grid.dart';
import 'dashboard_quick_menu.dart';

class StaffDashboardContent extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> dashboardData;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;
  final bool Function(String) hasPermission;

  const StaffDashboardContent({
    super.key,
    required this.userData,
    required this.dashboardData,
    required this.onRefresh,
    required this.onProfileTap,
    required this.hasPermission,
  });

  @override
  Widget build(BuildContext context) {
    final user = dashboardData['user'] ?? userData;
    final attendance = dashboardData['attendance'];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            DashboardProfileHeader(
              user: user,
              onTap: onProfileTap,
            ),
            const SizedBox(height: 24),
            DashboardWelcomeCard(
              user: user,
              stats: dashboardData['stats'],
              attendance: attendance,
            ),
            const SizedBox(height: 24),
            DashboardStatsGrid(stats: dashboardData['stats']),
            const SizedBox(height: 32),
            DashboardQuickMenu(
              userData: userData,
              dashboardData: dashboardData,
              hasPermission: hasPermission,
            ),
          ],
        ),
      ),
    );
  }
}
