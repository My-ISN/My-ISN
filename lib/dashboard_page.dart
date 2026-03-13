import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/connectivity_wrapper.dart';

import 'widgets/custom_bottom_nav.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/side_drawer.dart';
import 'profile/profile_page.dart';
import 'attendance_page.dart';
import 'payroll/payroll_page.dart';
import 'localization/app_localizations.dart';


import 'services/version_check_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'rent_plan/rent_plan_page.dart';
import 'todo_list/todo_list_page.dart';
import 'employees/employees_page.dart';
import 'work_log/work_log_page.dart';


class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardPage({super.key, required this.userData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  int _currentIndex = 0;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _checkAppUpdate();
  }

  bool _hasPermission(String resource) {
    // Prefer data from dashboard refresh if available
    final userData = _dashboardData['user'] ?? widget.userData;
    
    // Admin has all permissions
    if (userData['role_resources'] == 'all') return true;

    final String resources = userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  Future<void> _checkAppUpdate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 1. Check for newer version (Update Popup)
    final updateInfo = await VersionCheckService.checkForUpdate();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
      return; // If update available, don't show changelog yet
    }

    // 2. Check if user just updated (Changelog/What's New)
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersionWithBuild = "${packageInfo.version}+${packageInfo.buildNumber}";
    final String? lastSeenVersion = await storage.read(key: 'last_seen_version');

    if (lastSeenVersion != null && lastSeenVersion != currentVersionWithBuild) {
      // Version changed! Show what's new if the server has notes for this current version
      final latestInfo = await VersionCheckService.getLatestVersionInfo();
      if (latestInfo != null && 
          latestInfo.version == currentVersionWithBuild && 
          latestInfo.releaseNotes != null && 
          mounted) {
        _showChangelogDialog(latestInfo);
      }
    }

    // Update last seen version
    await storage.write(key: 'last_seen_version', value: currentVersionWithBuild);
  }

  void _showChangelogDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Color(0xFF7E57C2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('dashboard.whats_new'.tr(context, args: {'version': info.version.split('+')[0]})),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dashboard.update_thanks'.tr(context),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.releaseNotes ?? 'announcement.no_description_available'.tr(context),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('dashboard.cool'.tr(context), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.isForceUpdate,
        child: AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Color(0xFF7E57C2)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('main.update_available'.tr(context)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'main.new_version'.tr(context)}: ${updateInfo.version.split('+')[0]}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (updateInfo.releaseNotes != null) ...[
                const SizedBox(height: 10),
                Text(
                  'announcement.whats_new'.tr(context),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(updateInfo.releaseNotes!),
              ],
              const SizedBox(height: 15),
              Text('main.update_desc'.tr(context)),
            ],
          ),
          actions: [
            if (!updateInfo.isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('main.later'.tr(context)),
              ),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse(updateInfo.downloadLink);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('main.update_now'.tr(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_dashboard_data?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _dashboardData = data['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (ConnectivityStatus.of(context)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('dashboard.fetch_error'.tr(context))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      AttendancePage(userData: _dashboardData['user'] ?? widget.userData),
      PayrollPage(userData: _dashboardData['user'] ?? widget.userData),
      ProfilePage(
        userData: _dashboardData['user'] ?? widget.userData,
        isTab: true,
      ),
    ];



    return Scaffold(
      appBar: CustomAppBar(
        userData: _dashboardData['user'] ?? widget.userData,
        showBackButton: false,
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      endDrawer: SideDrawer(
        userData: _dashboardData['user'] ?? widget.userData,
        activePage: _currentIndex == 0
            ? 'dashboard'
            : (_currentIndex == 1
                  ? 'attendance'
                  : (_currentIndex == 2
                        ? 'payroll'
                        : (_currentIndex == 3 ? 'profile' : ''))),


        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Future<void> _clockBreak() async {
    final activeAtt = _dashboardData['attendance'];
    if (activeAtt == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/clock_break'),
        body: {'user_id': widget.userData['id']?.toString() ?? ''},
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        _fetchDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'main.success_with_msg'.tr(
                context,
                args: {'message': data['message']?.toString() ?? ''},
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw data['message'];
      }
    } catch (e) {
      if (mounted) {
        if (ConnectivityStatus.of(context)) {
          String errorMessage = e.toString();
          if (errorMessage.contains('SocketException') ||
              errorMessage.contains('ClientException') ||
              errorMessage.contains('HandshakeException')) {
            errorMessage = 'login.conn_error'.tr(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'main.error_with_msg'.tr(
                  context,
                  args: {'message': errorMessage},
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Widget _buildHomeContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final attendance = _dashboardData['attendance'];
    final bool hasClockIn = attendance != null &&
        attendance['clock_in'] != null &&
        attendance['clock_in'].toString().isNotEmpty &&
        attendance['clock_in'].toString() != '-';
    final bool hasClockOut = attendance != null &&
        attendance['clock_out'] != null &&
        attendance['clock_out'].toString().isNotEmpty &&
        attendance['clock_out'].toString() != '-';

    final bool hasBreakIn = attendance != null &&
        attendance['break_in'] != null &&
        attendance['break_in'].toString().isNotEmpty &&
        attendance['break_in'].toString() != '-';
    final bool hasBreakOut = attendance != null &&
        attendance['break_out'] != null &&
        attendance['break_out'].toString().isNotEmpty &&
        attendance['break_out'].toString() != '-';

    String breakLabel = 'dashboard.break_time_clock'.tr(context);
    if (hasBreakIn) {
      breakLabel = 'dashboard.already_break'.tr(context);
    } else if (hasBreakOut) {
      breakLabel = 'dashboard.end_break'.tr(context);
    } else if (hasClockIn) {
      breakLabel = 'dashboard.start_break'.tr(context);
    }


    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Theme.of(context).brightness == Brightness.dark
                    ? Border.all(color: Colors.white24)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _currentIndex = 3);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Container(
                            width: 60,
                            height: 60,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFFF1F5F9)
                                : Theme.of(context).scaffoldBackgroundColor,
                            child:
                                ((_dashboardData['user']?['profile_photo'] ??
                                            widget.userData['profile_photo']) !=
                                        null &&
                                    (_dashboardData['user']?['profile_photo'] ??
                                            widget.userData['profile_photo'])
                                        .toString()
                                        .isNotEmpty)
                                ? Image.network(
                                    'https://foxgeen.com/HRIS/public/uploads/users/thumb/${_dashboardData['user']?['profile_photo'] ?? widget.userData['profile_photo']}',
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return const Icon(
                                            Icons.person,
                                            size: 36,
                                            color: Colors.white,
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              size: 36,
                                              color: Colors.white,
                                            ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dashboardData['user']?['nama'] ??
                                    widget.userData['nama'] ??
                                    'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '@${_dashboardData['user']?['username'] ?? widget.userData['username'] ?? 'username'}',
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _dashboardData['user']?['role_name'] ??
                                widget.userData['role_name'] ??
                                'Staff',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Welcome Card
            Container(
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
                    '${'dashboard.welcome'.tr(context)} ${_dashboardData['user']?['nama'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'dashboard.my_shift'.tr(
                      context,
                      args: {'shift': _dashboardData['stats']?['shift'] ?? '-'},
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
                          hasClockIn ? attendance['clock_in'] : '--:--',
                          const Color(0xFF2ECC71),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeDisplay(
                          'dashboard.clock_out'.tr(context).toUpperCase(),
                          hasClockOut ? attendance['clock_out'] : '--:--',
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
                                    'in': attendance['clock_in'],
                                    'out': attendance['clock_out'],
                                  },
                                ) +
                                (attendance['is_early'] == true
                                    ? ' (${'dashboard.early_out'.tr(context)}: ${attendance['early_time']})'
                                    : '') +
                                (hasBreakOut
                                    ? ' | Rest: ${attendance['break_out']}${hasBreakIn ? ' - ${attendance['break_in']}' : ''}'
                                    : '')
                          : 'dashboard.clock_in_only_details'.tr(
                              context,
                              args: {'in': attendance['clock_in']},
                            ),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (hasBreakIn || hasBreakOut)
                    Text(
                      'Rest: ${attendance['break_out']}${hasBreakIn ? ' - ${attendance['break_in']}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!hasClockIn || hasClockOut || hasBreakIn)
                          ? null
                          : _clockBreak,
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
            ),
            const SizedBox(height: 24),

            // Stat Row 1
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'dashboard.working_duration'.tr(context),
                    _dashboardData['stats']?['working_duration'] ?? '-',
                    Icons.hourglass_empty,
                    const Color(0xFF2ECC71),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'dashboard.my_leave'.tr(context),
                    '${_dashboardData['stats']?['leave_count'] ?? 0}',
                    Icons.calendar_today,
                    const Color(0xFF7E57C2),
                    isOutline: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat Row 2
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'dashboard.overtime_request'.tr(context),
                    '${_dashboardData['stats']?['overtime_count'] ?? 0}',
                    Icons.more_time,
                    const Color(0xFF7E57C2),
                    isOutline: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'dashboard.travel_request'.tr(context),
                    '${_dashboardData['stats']?['travel_count'] ?? 0}',
                    Icons.flight_takeoff,
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Services Menu Section
            Row(
              children: [
                Text(
                  'dashboard.quick_menu'.tr(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                if (_hasPermission('mobile_rent_plan_enable'))
                  _buildQuickMenuCard(
                    'dashboard.quick_menu_rent_plan'.tr(context),
                    Icons.house_rounded,
                    const Color(0xFF7E57C2),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RentPlanPage(
                            userData: _dashboardData['user'] ?? widget.userData,
                          ),
                        ),
                      );
                    },
                  ),
                if (_hasPermission('mobile_todo_enable'))
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationManager().unreadTodoCount,
                    builder: (context, count, child) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildQuickMenuCard(
                            'dashboard.quick_menu_todo_list'.tr(context),
                            Icons.assignment_rounded,
                            const Color(0xFF5C6BC0),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TodoListPage(
                                    userData: _dashboardData['user'] ?? widget.userData,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (count > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (_hasPermission('mobile_employees_enable'))
                  _buildQuickMenuCard(
                    'dashboard.quick_menu_employees'.tr(context),
                    Icons.people_alt_rounded,
                    const Color(0xFF2ECC71),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeesPage(
                            userData: _dashboardData['user'] ?? widget.userData,
                          ),
                        ),
                      );
                    },
                  ),
                if (_hasPermission('mobile_worklog_enable'))
                  _buildQuickMenuCard(
                    'dashboard.quick_menu_work_log'.tr(context),
                    Icons.assignment_turned_in_rounded,
                    const Color(0xFF7E57C2),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkLogPage(
                            userData: _dashboardData['user'] ?? widget.userData,
                          ),
                        ),
                      );
                    },
                  ),

              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenuCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : Border.all(color: Colors.grey.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
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

  Widget _buildTimeDisplay(String label, String value, Color color) {
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
  }
}
