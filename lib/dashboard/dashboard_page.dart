import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/connectivity_wrapper.dart';

import '../widgets/custom_bottom_nav.dart';
import '../widgets/custom_app_bar.dart';

import '../widgets/side_drawer.dart';
import '../profile/profile_page.dart';
import '../attendance_page.dart';
import '../payroll/payroll_page.dart';
import '../localization/app_localizations.dart';
import '../services/version_check_service.dart';
import '../constants.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../rent_plan/client/rent_plan_page.dart' as client_rp;
import 'staff/widgets/staff_dashboard_content.dart';
import 'client/widgets/customer_dashboard_content.dart';
import '../services/heartbeat_service.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int? initialIndex;
  const DashboardPage({super.key, required this.userData, this.initialIndex});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  Map<String, dynamic> _customerDashboardData = {};
  int _currentIndex = 0;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _fetchDashboardData();
    _checkAppUpdate();

    // Start heartbeat
    HeartbeatService().start(widget.userData);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    HeartbeatService().stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      HeartbeatService().pause();
    } else if (state == AppLifecycleState.resumed) {
      HeartbeatService().resume();
    }
  }

  bool _hasPermission(String resource) {
    // Prefer data from dashboard refresh if available
    final userData = _dashboardData['user'] ?? widget.userData;

    // Admin has all permissions
    if (userData['role_resources'] == 'all') return true;

    final String resources = userData['role_resources'] ?? '';
    final List<String> resourceList = resources
        .split(',')
        .map((e) => e.trim())
        .toList();
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
    final String currentVersionWithBuild =
        "${packageInfo.version}+${packageInfo.buildNumber}";
    final String? lastSeenVersion = await storage.read(
      key: 'last_seen_version',
    );

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
    await storage.write(
      key: 'last_seen_version',
      value: currentVersionWithBuild,
    );
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
                      color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration,
                      color: Color(0xFF7E57C2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'dashboard.whats_new'.tr(
                        context,
                        args: {'version': info.version.split('+')[0]},
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        info.releaseNotes ??
                            'announcement.no_description_available'.tr(context),
                        style: const TextStyle(fontSize: 14, height: 1.6),
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
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
      builder: (context) => PopScope(
        canPop: !updateInfo.isForceUpdate,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
        },
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
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update,
                        color: Color(0xFF7E57C2),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'main.update_available'.tr(context),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.25),
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
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    if (!updateInfo.isForceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'main.later'.tr(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
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
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
          '${AppConstants.baseUrl}/get_dashboard_data?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _dashboardData = data['data'];
            // If customer, also fetch customer specific dashboard info
            final user = _dashboardData['user'] ?? widget.userData;
            if (user['user_type'] == 'customer' ||
                user['user_role_id'] == 21 ||
                user['user_role_id'] == '21') {
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
            SnackBar(
              content: Text(
                data['message'] ?? 'dashboard.fetch_error'.tr(context),
              ),
            ),
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
          '${AppConstants.baseUrl}/get_customer_dashboard?user_id=$userId';

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
            SnackBar(
              content: Text(
                data['message'] ?? 'dashboard.fetch_error'.tr(context),
              ),
            ),
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
    final bool isCustomer =
        user['user_type'] == 'customer' ||
        user['user_role_id'] == 21 ||
        user['user_role_id'] == '21';
    final bool hasPayroll = _hasPermission('mobile_payroll_enable');

    final List<Widget> pages = isCustomer
        ? [
            _buildHomeContent(),
            client_rp.RentPlanPage(userData: user, isTab: true),
            ProfilePage(userData: user, isTab: true),
          ]
        : [
            _buildHomeContent(),
            AttendancePage(userData: user),
            if (hasPayroll) PayrollPage(userData: user),
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
        case 0:
          activePage = 'dashboard';
          break;
        case 1:
          activePage = 'rent_plan';
          break;
        case 2:
          activePage = 'invoice';
          break;
        case 3:
          activePage = 'profile';
          break;
      }
    } else {
      if (_currentIndex == 0) {
        activePage = 'dashboard';
      } else if (_currentIndex == 1)
        activePage = 'attendance';
      else if (hasPayroll && _currentIndex == 2)
        activePage = 'payroll';
      else if (_currentIndex == (hasPayroll ? 3 : 2))
        activePage = 'profile';
    }

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(userData: user, showBackButton: false),
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        child: CustomBottomNav(
          currentIndex: _currentIndex,
          userData: user,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }


  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = _dashboardData['user'] ?? widget.userData;
    final bool isCustomer = user['user_type'] == 'customer' ||
        user['user_role_id'] == 21 ||
        user['user_role_id'] == '21';
    final bool hasPayroll = _hasPermission('mobile_payroll_enable');

    if (isCustomer) {
      return _buildCustomerContent();
    }

    return StaffDashboardContent(
      userData: widget.userData,
      dashboardData: _dashboardData,
      onRefresh: _fetchDashboardData,
      onProfileTap: () => setState(() => _currentIndex = (hasPayroll ? 3 : 2)),
      hasPermission: _hasPermission,
    );
  }

  Widget _buildCustomerContent() {
    return CustomerDashboardContent(
      userData: widget.userData,
      customerDashboardData: _customerDashboardData,
      onRefresh: _fetchDashboardData,
      onProfileTap: (index) => setState(() => _currentIndex = index),
      onLaunchWhatsApp: _launchWhatsApp,
    );
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
            content: Text(
              'settings.wa_error'.tr(context, args: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }
}
