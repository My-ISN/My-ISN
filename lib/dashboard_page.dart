import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'widgets/custom_bottom_nav.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/side_drawer.dart';
import 'profile/profile_page.dart';
import 'attendance_page.dart';
import 'payroll/payroll_page.dart';
import 'localization/app_localizations.dart';
import 'services/version_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    // Small delay to ensure context is ready if needed,
    // though for dialogs it's better to wait a bit after build.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final updateInfo = await VersionCheckService.checkForUpdate();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  void _showUpdateDialog(AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Color(0xFF7E57C2)),
              const SizedBox(width: 10),
              Text('main.update_available'.tr(context)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'main.new_version'.tr(context)}: ${updateInfo.version}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (updateInfo.releaseNotes != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'What\'s new:',
                  style: TextStyle(fontWeight: FontWeight.w500),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('dashboard.fetch_error'.tr(context))),
        );
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

  Future<void> _clockIn() async {
    final shiftIn = _dashboardData['stats']?['shift_in'];
    final shiftOut = _dashboardData['stats']?['shift_out'];

    if (shiftIn == null || shiftOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dashboard.shift_not_found'.tr(context))),
      );
      return;
    }

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final shiftOutDt = DateTime.parse("$todayStr $shiftOut");

    // Option B: Block if after shift out time
    if (now.isAfter(shiftOutDt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('dashboard.shift_ended_msg'.tr(context)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/clock_in'),
        body: {
          'user_id': widget.userData['id']?.toString() ?? '',
          'company_id':
              (widget.userData['company_id'] ??
                      _dashboardData['user']?['company_id'])
                  ?.toString() ??
              '',
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        _fetchDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw data['message'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'dashboard.clock_in_failed'.tr(
              context,
              args: {'error': e.toString()},
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clockOut() async {
    final activeAtt = _dashboardData['attendance'];
    if (activeAtt == null) return;

    final shiftOut = _dashboardData['stats']?['shift_out'];
    if (shiftOut != null) {
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final shiftOutDt = DateTime.parse("$todayStr $shiftOut");

      // Show warning for early clock out
      if (now.isBefore(shiftOutDt)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('dashboard.early_out_title'.tr(context)),
            content: Text('dashboard.early_out_content'.tr(context)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('dashboard.cancel'.tr(context)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  'dashboard.continue'.tr(context),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/clock_out'),
        body: {
          'user_id': widget.userData['id']?.toString() ?? '',
          'attendance_id': activeAtt?['id']?.toString() ?? '',
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        _fetchDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw data['message'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'dashboard.clock_out_failed'.tr(
              context,
              args: {'error': e.toString()},
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw data['message'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHomeContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final attendance = _dashboardData['attendance'];
    final bool hasClockIn = attendance != null;
    final bool hasClockOut =
        attendance != null &&
        attendance['clock_out'] != null &&
        attendance['clock_out'].toString().isNotEmpty &&
        attendance['clock_out'].toString() != '-';

    final bool hasBreakIn =
        attendance != null &&
        attendance['break_in'] != null &&
        attendance['break_in'].toString() != '-';
    final bool hasBreakOut =
        attendance != null &&
        attendance['break_out'] != null &&
        attendance['break_out'].toString() != '-';

    String breakLabel = 'dashboard.break_time_clock'.tr(context);
    if (hasBreakIn) {
      breakLabel = 'dashboard.already_break'.tr(context);
    } else if (hasBreakOut) {
      breakLabel = 'dashboard.end_break'.tr(context);
    } else if (hasClockIn) {
      breakLabel = 'dashboard.start_break'.tr(context);
    }

    final String buttonMasukLabel = hasClockIn
        ? 'dashboard.already_clock_in'.tr(context)
        : 'dashboard.clock_in'.tr(context).toUpperCase();
    final String buttonPulangLabel = hasClockOut
        ? 'dashboard.already_clock_out'.tr(context)
        : 'dashboard.clock_out'.tr(context).toUpperCase();

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
                  if (hasClockIn) ...[
                    const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (hasClockIn) ? null : _clockIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            disabledBackgroundColor: Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              buttonMasukLabel,
                              style: TextStyle(
                                color: hasClockIn ? Colors.grey : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (!hasClockIn || hasClockOut)
                              ? null
                              : _clockOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE74C3C),
                            disabledBackgroundColor: Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              buttonPulangLabel,
                              style: TextStyle(
                                color: (!hasClockIn || hasClockOut)
                                    ? Colors.grey
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!hasClockIn || hasClockOut || hasBreakIn)
                          ? null
                          : _clockBreak,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E57C2),
                        disabledBackgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          breakLabel,
                          style: TextStyle(
                            color: (!hasClockIn || hasClockOut || hasBreakIn)
                                ? Colors.grey
                                : Colors.white,
                          ),
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
            const SizedBox(height: 24),

            // Payroll Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'dashboard.payroll_report'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildPayrollStat(
                        'IDR ${_dashboardData['payroll']?['total'] ?? 0}',
                        'dashboard.total'.tr(context),
                      ),
                      const SizedBox(width: 32),
                      _buildPayrollStat(
                        'IDR ${_dashboardData['payroll']?['this_month'] ?? 0}',
                        'dashboard.this_month'.tr(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
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

  Widget _buildPayrollStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
