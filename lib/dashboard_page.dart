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
import 'rent_plan/staff/rent_plan_page.dart' as staff_rp;
import 'rent_plan/client/rent_plan_page.dart' as client_rp;
import 'todo_list/todo_list_page.dart';
import 'employees/employees_page.dart';
import 'work_log/work_log_page.dart';
import 'finance/finance_page.dart';


class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardPage({super.key, required this.userData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  Map<String, dynamic> _customerDashboardData = {};
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration, color: Color(0xFF7E57C2), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'dashboard.whats_new'.tr(context, args: {'version': info.version.split('+')[0]}),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Content (scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.update_thanks'.tr(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        info.releaseNotes ?? 'announcement.no_description_available'.tr(context),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'dashboard.cool'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(AppUpdateInfo updateInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !updateInfo.isForceUpdate,
      enableDrag: !updateInfo.isForceUpdate,
      backgroundColor: Colors.transparent,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.isForceUpdate,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update, color: Color(0xFF7E57C2), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'main.update_available'.tr(context),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Content (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'main.new_version'.tr(context)}: ${updateInfo.version.split('+')[0]}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      if (updateInfo.releaseNotes != null) ...[
                        Text(
                          'announcement.whats_new'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          updateInfo.releaseNotes!,
                          style: TextStyle(
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'main.update_desc'.tr(context),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    if (!updateInfo.isForceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'main.later'.tr(context),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final url = Uri.parse(updateInfo.downloadLink);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'main.update_now'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'http://17.5.45.192/KODINGAN/PKL/mobileapi/get_dashboard_data?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _dashboardData = data['data'];
            // If customer, also fetch customer specific dashboard info
            final user = _dashboardData['user'] ?? widget.userData;
            if (user['user_type'] == 'customer' || user['user_role_id'] == 21 || user['user_role_id'] == '21') {
              _fetchCustomerDashboard();
            } else {
              _isLoading = false;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'dashboard.fetch_error'.tr(context))),
          );
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

  Future<void> _fetchCustomerDashboard() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'http://17.5.45.192/KODINGAN/PKL/mobileapi/get_customer_dashboard?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _customerDashboardData = data['data'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'dashboard.fetch_error'.tr(context))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _dashboardData['user'] ?? widget.userData;
    final bool isCustomer = user['user_type'] == 'customer' || 
                           user['user_role_id'] == 21 || 
                           user['user_role_id'] == '21';
    final bool hasPayroll = _hasPermission('mobile_payroll_enable');

    final List<Widget> pages = isCustomer ? [
      _buildHomeContent(),
      client_rp.RentPlanPage(userData: user, isTab: true),
      ProfilePage(userData: user, isTab: true),
    ] : [
      _buildHomeContent(),
      AttendancePage(userData: user),
      if (hasPayroll)
        PayrollPage(userData: user),
      ProfilePage(userData: user, isTab: true),
    ];

    // Ensure _currentIndex is within bounds if pages list changed
    if (_currentIndex >= pages.length) {
      _currentIndex = pages.length - 1;
    }

    // Determine activePage for Drawer
    String activePage = '';
    if (isCustomer) {
      switch (_currentIndex) {
        case 0: activePage = 'dashboard'; break;
        case 1: activePage = 'rent_plan'; break;
        case 2: activePage = 'invoice'; break;
        case 3: activePage = 'profile'; break;
      }
    } else {
      if (_currentIndex == 0) activePage = 'dashboard';
      else if (_currentIndex == 1) activePage = 'attendance';
      else if (hasPayroll && _currentIndex == 2) activePage = 'payroll';
      else if (_currentIndex == (hasPayroll ? 3 : 2)) activePage = 'profile';
    }

    return Scaffold(
      appBar: CustomAppBar(
        userData: user,
        showBackButton: false,
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      endDrawer: SideDrawer(
        userData: user,
        activePage: activePage,
        onTabSelected: (index) {
          int targetIndex = index;
          if (!isCustomer) {
            if (!hasPayroll && index > 2) {
              targetIndex = index - 1;
            }
          }
          setState(() {
            _currentIndex = targetIndex;
          });
        },
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        userData: user,
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
        Uri.parse('http://17.5.45.192/KODINGAN/PKL/mobileapi/clock_break'),
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

    final user = _dashboardData['user'] ?? widget.userData;
    if (user['user_type'] == 'customer' || user['user_role_id'] == 21 || user['user_role_id'] == '21') {
      return _buildCustomerContent();
    }

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
                            (_dashboardData['user']?['role_name'] ??
                                widget.userData['role_name'] ??
                                'Staff').toString().roleTr(context),
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

            _buildDynamicQuickMenu([
              if (_hasPermission('mobile_rent_plan_enable'))
                _buildQuickMenuCard(
                  'dashboard.quick_menu_rent_plan'.tr(context),
                  Icons.house_rounded,
                  const Color(0xFF7E57C2),
                  () {
                    final user = _dashboardData['user'] ?? widget.userData;
                    final bool isCustomer = user['user_type'] == 'customer' || 
                                           user['user_role_id'] == 21 || 
                                           user['user_role_id'] == '21';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => isCustomer 
                          ? client_rp.RentPlanPage(userData: user)
                          : staff_rp.RentPlanPage(userData: user),
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
                          const Color(0xFF7E57C2),
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
                  const Color(0xFF7E57C2),
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
              if (_hasPermission('mobile_finance_enable'))
                _buildQuickMenuCard(
                  'dashboard.quick_menu_finance'.tr(context),
                Icons.account_balance_wallet_rounded,
                const Color(0xFF7E57C2),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinancePage(
                        userData: _dashboardData['user'] ?? widget.userData,
                      ),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicQuickMenu(List<Widget> items) {
    if (items.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reduced gap: 10 is spacing between items
        final double itemWidth = (constraints.maxWidth - (10 * 2)) / 3;
        // Make height more compact (1.0 means square, 1.1 means slightly taller)
        // Since text is now single line, 1.05 is a good balance.
        final double fixedHeight = itemWidth * 1.05;

        final List<List<Widget>> rows = [];
        for (var i = 0; i < items.length; i += 3) {
          rows.add(items.sublist(i, i + 3 > items.length ? items.length : i + 3));
        }

        return Column(
          children: rows.map((rowItems) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ...rowItems.map((item) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: SizedBox(
                          height: fixedHeight,
                          child: item,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        );
      },
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _buildCustomerContent() {
    final stats = _customerDashboardData['stats'] ?? {};
    final products = _customerDashboardData['products'] ?? [];
    final contact = _customerDashboardData['contact'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section (reuse existing style)
            _buildProfileCard(),
            const SizedBox(height: 24),

            // Customer Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'dashboard.rental_active'.tr(context),
                    '${stats['active_rentals'] ?? 0}',
                    Icons.laptop_mac_rounded,
                    const Color(0xFF2ECC71),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'dashboard.total_paid'.tr(context),
                    'Rp ${_formatPrice(stats['total_paid'] ?? 0)}',
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF2ECC71),
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
                    'dashboard.total_unpaid'.tr(context),
                    'Rp ${_formatPrice(stats['total_unpaid'] ?? 0)}',
                    Icons.error_outline_rounded,
                    const Color(0xFFE74C3C),
                    isOutline: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'dashboard.total_invoice'.tr(context),
                    '${stats['total_invoice'] ?? 0}',
                    Icons.receipt_long_rounded,
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Help Section
            _buildHelpSection(contact),
            const SizedBox(height: 16),

            // Products Available
            _buildProductList(products),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
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
            setState(() => _currentIndex = (_hasPermission('mobile_payroll_enable') ? 3 : 2));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 60, height: 60,
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFFF1F5F9)
                        : Theme.of(context).scaffoldBackgroundColor,
                    child: ((_dashboardData['user']?['profile_photo'] ?? widget.userData['profile_photo']) != null && 
                            (_dashboardData['user']?['profile_photo'] ?? widget.userData['profile_photo']).toString().isNotEmpty)
                        ? Image.network(
                            'https://foxgeen.com/HRIS/public/uploads/users/thumb/${_dashboardData['user']?['profile_photo'] ?? widget.userData['profile_photo']}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 36, color: Colors.white),
                          )
                        : const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dashboardData['user']?['nama'] ?? widget.userData['nama'] ?? 'User',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                _buildRoleBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Text(
        (_dashboardData['user']?['role_name'] ?? widget.userData['role_name'] ?? 'Staff').toString().roleTr(context),
        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF7E57C2)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }


  Widget _buildHelpSection(Map contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3F51B5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BUTUH BANTUAN?', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(contact['company_name'] ?? 'PT. ISKOM SARANA NUSANTARA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(contact['address'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                            onPressed: () => _launchWhatsApp(
                '0895384314416',
                'dashboard.dashboard_help_msg'.tr(context),
              ),
              icon: const Icon(Icons.chat, color: Colors.white, size: 18),
              label: Text('dashboard.contact_via_wa'.tr(context), style: const TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List products) {
    final String laptopBaseUrl = 'https://foxgeen.com/HRIS/uploads/products/';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('dashboard.available_products'.tr(context), Icons.laptop_windows_rounded),
        const SizedBox(height: 12),
        ...products.map((p) => InkWell(
          onTap: () => _showProductSpecs(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    '$laptopBaseUrl${p['gambar']}',
                    width: 40, height: 40, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 40, height: 40, color: Colors.grey.withOpacity(0.1),
                      child: const Icon(Icons.laptop, size: 24, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['nama_laptop'] ?? 'Laptop', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                      Text('${p['procesor'] ?? 'Core'} - ${p['ram'] ?? '8GB'}', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.withOpacity(0.5)),
              ],
            ),
          ),
        )).toList(),
      ],
    );
  }

  void _showProductSpecs(Map p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('dashboard.available_products'.tr(context).toUpperCase(), 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://foxgeen.com/HRIS/uploads/products/${p['gambar']}',
                        height: 200, width: double.infinity, fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200, width: double.infinity, color: Colors.grey.withOpacity(0.1),
                          child: const Icon(Icons.laptop, size: 80, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(p['nama_laptop'] ?? 'Laptop', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (p['catatan'] != null && p['catatan'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(p['catatan'], style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                    const SizedBox(height: 32),
                    Text('dashboard.specification'.tr(context), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    _buildSpecItem('dashboard.processor'.tr(context), p['procesor'] ?? '-'),
                    _buildSpecItem('dashboard.ram'.tr(context), p['ram'] ?? '-'),
                    _buildSpecItem('dashboard.storage'.tr(context), p['hardisk'] ?? '-'),
                    _buildSpecItem('dashboard.stock'.tr(context), '${p['stok'] ?? 0} ${'dashboard.unit'.tr(context)}'),
                    _buildSpecItem('dashboard.condition'.tr(context), (p['kondisi'] ?? '-').toString().toUpperCase()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }


  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    String s = price.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    // Remove leading 0 and replace with 62
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '62${phone.substring(1)}';
    }

    final String urlString =
        "whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}";
    final Uri url = Uri.parse(urlString);

    try {
      if (!await launchUrl(url)) {
        // Fallback to web link if whatsapp app is not installed
        final String webUrlString =
            "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}";
        final Uri webUrl = Uri.parse(webUrlString);
        if (!await launchUrl(webUrl, mode: LaunchMode.externalApplication)) {
          throw Exception('Could troubleshoot launch WhatsApp');
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('settings.wa_error'.tr(context, args: {'error': e.toString()}))),
        );
      }
    }
  }
}
