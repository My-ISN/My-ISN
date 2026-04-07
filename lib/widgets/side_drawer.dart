import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../login_page.dart';
import '../settings_page.dart';
import '../dashboard/dashboard_page.dart';
import '../rent_plan/staff/rent_plan_page.dart' as staff_rp;
import '../rent_plan/client/rent_plan_page.dart' as client_rp;
import '../todo_list/todo_list_page.dart';
import '../employees/employees_page.dart';
import '../work_log/work_log_page.dart';
import '../finance/finance_page.dart';
import '../helpdesk/helpdesk_list_page.dart';
import '../ai_bot/ai_bot_page.dart';
import '../creative_idea/creative_idea_page.dart';
import '../personal_finance/personal_finance_page.dart';
import '../intercom/intercom_page.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import 'custom_app_bar.dart'; // For NotificationManager

class SideDrawer extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String activePage;
  final Function(int)? onTabSelected;

  const SideDrawer({
    super.key,
    required this.userData,
    required this.activePage,
    this.onTabSelected,
  });

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  final Map<String, bool> _expandedSections = {
    'work': false,
    'financial': false,
    'support': false,
  };

  @override
  void initState() {
    super.initState();
    // Auto-expand section if it contains the active page
    if (['rent_plan', 'todo_list', 'employees', 'work_log'].contains(
      widget.activePage,
    )) {
      _expandedSections['work'] = true;
    } else if (['finance', 'my_wallet'].contains(widget.activePage)) {
      _expandedSections['financial'] = true;
    } else if (['helpdesk', 'ai_bot', 'creative_idea'].contains(
      widget.activePage,
    )) {
      _expandedSections['support'] = true;
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  bool _hasCategoryPermission(List<String> resources) {
    if (widget.userData['role_resources'] == 'all') return true;
    for (var res in resources) {
      if (_hasPermission(res)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCustomer =
        widget.userData['user_type'] == 'customer' ||
        widget.userData['user_role_id'] == 21 ||
        widget.userData['user_role_id'] == '21';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'main.xin_dashboard'.tr(context),
                  isActive: widget.activePage == 'dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(0);
                    } else if (widget.activePage != 'dashboard') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardPage(
                            userData: widget.userData,
                            initialIndex: 0,
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: isCustomer
                      ? Icons.house_outlined
                      : Icons.calendar_today_outlined,
                  title: isCustomer
                      ? 'dashboard.rent_plan'.tr(context)
                      : 'main.xin_attendance'.tr(context),
                  isActive: isCustomer
                      ? widget.activePage == 'rent_plan'
                      : widget.activePage == 'attendance',
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(1);
                    } else if (isCustomer) {
                      if (widget.activePage != 'rent_plan') {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardPage(
                              userData: widget.userData,
                              initialIndex: 1,
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    } else {
                      if (widget.activePage != 'attendance') {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardPage(
                              userData: widget.userData,
                              initialIndex: 1,
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
                if (_hasPermission('mobile_payroll_enable'))
                  _buildMenuItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'main.xin_payroll'.tr(context),
                    isActive: widget.activePage == 'payroll',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onTabSelected != null) {
                        widget.onTabSelected!(2);
                      } else if (widget.activePage != 'payroll') {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardPage(
                              userData: widget.userData,
                              initialIndex: 2,
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'main.xin_profile'.tr(context),
                  isActive: widget.activePage == 'profile',
                  onTap: () {
                    Navigator.pop(context);
                    final bool hasPayroll = _hasPermission(
                      'mobile_payroll_enable',
                    );
                    int profileIndex = isCustomer ? 2 : (hasPayroll ? 3 : 2);

                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(profileIndex);
                    } else if (widget.activePage != 'profile') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardPage(
                            userData: widget.userData,
                            initialIndex: profileIndex,
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
                const Divider(indent: 16, endIndent: 16),

                // Group: Work / Operational
                if (_hasCategoryPermission([
                  'mobile_rent_plan_enable',
                  'mobile_todo_enable',
                  'mobile_employees_enable',
                  'mobile_worklog_enable',
                ]))
                  _buildExpandableSection(
                    context,
                    title: 'side_drawer.work'.tr(context),
                    icon: Icons.work_outline_rounded,
                    isExpanded: _expandedSections['work'] ?? false,
                    onExpansionChanged: (expanded) {
                      setState(() => _expandedSections['work'] = expanded);
                    },
                    children: [
                      if (!isCustomer &&
                          _hasPermission('mobile_rent_plan_enable'))
                        _buildMenuItem(
                          context,
                          icon: Icons.house_outlined,
                          title: 'dashboard.rent_plan'.tr(context),
                          isActive: widget.activePage == 'rent_plan',
                          padding: const EdgeInsets.only(left: 32, right: 12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => isCustomer
                                    ? client_rp.RentPlanPage(
                                      userData: widget.userData,
                                    )
                                    : staff_rp.RentPlanPage(
                                      userData: widget.userData,
                                    ),
                              ),
                            );
                          },
                        ),
                      if (_hasPermission('mobile_todo_enable'))
                        ValueListenableBuilder<int>(
                          valueListenable: NotificationManager().unreadTodoCount,
                          builder: (context, count, child) {
                            return _buildMenuItem(
                              context,
                              icon: Icons.assignment_outlined,
                              title: 'dashboard.todo_list'.tr(context),
                              isActive: widget.activePage == 'todo_list',
                              badgeCount: count,
                              padding: const EdgeInsets.only(
                                left: 32,
                                right: 12,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TodoListPage(
                                      userData: widget.userData,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      if (_hasPermission('mobile_employees_enable'))
                        _buildMenuItem(
                          context,
                          icon: Icons.people_outline,
                          title: 'dashboard.employees'.tr(context),
                          isActive: widget.activePage == 'employees',
                          padding: const EdgeInsets.only(left: 32, right: 12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmployeesPage(
                                  userData: widget.userData,
                                ),
                              ),
                            );
                          },
                        ),
                      if (_hasPermission('mobile_worklog_enable'))
                        _buildMenuItem(
                          context,
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'work_log.title'.tr(context),
                          isActive: widget.activePage == 'work_log',
                          padding: const EdgeInsets.only(left: 32, right: 12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkLogPage(
                                  userData: widget.userData,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                // Group: Financial
                if (_hasCategoryPermission([
                  'mobile_finance_enable',
                  'mobile_personal_finance_enable',
                ]))
                  _buildExpandableSection(
                    context,
                    title: 'side_drawer.financial'.tr(context),
                    icon: Icons.account_balance_wallet_outlined,
                    isExpanded: _expandedSections['financial'] ?? false,
                    onExpansionChanged: (expanded) {
                      setState(() => _expandedSections['financial'] = expanded);
                    },
                    children: [
                      if (_hasPermission('mobile_finance_enable'))
                        _buildMenuItem(
                          context,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'dashboard.finance'.tr(context),
                          isActive: widget.activePage == 'finance',
                          padding: const EdgeInsets.only(left: 32, right: 12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FinancePage(userData: widget.userData),
                              ),
                            );
                          },
                        ),
                      if (_hasPermission('mobile_personal_finance_enable'))
                        _buildMenuItem(
                          context,
                          icon: Icons.savings_outlined,
                          title: 'personal_finance.my_wallet'.tr(context),
                          isActive: widget.activePage == 'my_wallet',
                          padding: const EdgeInsets.only(left: 32, right: 12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PersonalFinancePage(
                                  userData: widget.userData,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                // Group: Support & AI
                if (_hasCategoryPermission([
                  'mobile_helpdesk_view',
                  'creative_idea',
                  'mobile_intercom_view',
                ]))
                  _buildExpandableSection(
                    context,
                    title: 'side_drawer.support'.tr(context),
                    icon: Icons.auto_awesome_outlined,
                    isExpanded: _expandedSections['support'] ?? false,
                    onExpansionChanged: (expanded) {
                      setState(() => _expandedSections['support'] = expanded);
                    },
                  children: [
                    if (_hasPermission('mobile_helpdesk_view'))
                      _buildMenuItem(
                        context,
                        icon: Icons.support_agent_outlined,
                        title: 'dashboard.helpdesk'.tr(context),
                        isActive: widget.activePage == 'helpdesk',
                        padding: const EdgeInsets.only(left: 32, right: 12),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HelpdeskListPage(
                                userData: widget.userData,
                              ),
                            ),
                          );
                        },
                      ),
                    _buildMenuItem(
                      context,
                      icon: Icons.smart_toy_outlined,
                      title: 'dashboard.quick_menu_ai_bot'.tr(context),
                      isActive: widget.activePage == 'ai_bot',
                      padding: const EdgeInsets.only(left: 32, right: 12),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AiBotPage(
                              userData: widget.userData,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_hasPermission('creative_idea'))
                      _buildMenuItem(
                        context,
                        icon: Icons.lightbulb_outline,
                        title: 'dashboard.quick_menu_creative_idea'.tr(context),
                        isActive: widget.activePage == 'creative_idea',
                        padding: const EdgeInsets.only(left: 32, right: 12),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreativeIdeaPage(
                                userData: widget.userData,
                              ),
                            ),
                          );
                        },
                      ),
                    if (_hasPermission('mobile_intercom_view'))
                      _buildMenuItem(
                        context,
                        icon: Icons.volume_up_outlined,
                        title: 'dashboard.quick_menu_intercom'.tr(context),
                        isActive: widget.activePage == 'intercom',
                        padding: const EdgeInsets.only(left: 32, right: 12),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IntercomPage(
                            userData: widget.userData,
                          ),
                            ),
                          );
                        },
                      ),
                  ],
                ),

              ],
            ),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.settings_outlined,
            title: 'main.xin_settings'.tr(context),
            isActive: widget.activePage == 'settings',
            onTap: () {
              Navigator.pop(context);
              if (widget.activePage != 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(userData: widget.userData),
                  ),
                );
              }
            },
          ),
          _buildLogout(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: Theme.of(
                        context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        final bool isCustomer =
            widget.userData['user_type'] == 'customer' ||
            widget.userData['user_role_id'] == 21 ||
            widget.userData['user_role_id'] == '21';
        final bool hasPayroll = _hasPermission('mobile_payroll_enable');
        int profileIndex = isCustomer ? 2 : (hasPayroll ? 3 : 2);

        if (widget.onTabSelected != null) {
          widget.onTabSelected!(profileIndex);
        } else if (widget.activePage != 'profile') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DashboardPage(userData: widget.userData, initialIndex: profileIndex),
            ),
            (route) => false,
          );
        }
      },

      child: Container(
        padding: const EdgeInsets.only(
          top: 60,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(25),
              backgroundImage:
                  (widget.userData['profile_photo'] != null &&
                      widget.userData['profile_photo'].toString().isNotEmpty)
                  ? CachedNetworkImageProvider(
                      '${AppConstants.serverRoot}/uploads/users/${widget.userData['profile_photo']}',
                    )
                  : null,
              child:
                  (widget.userData['profile_photo'] == null ||
                      widget.userData['profile_photo'].toString().isEmpty)
                  ? Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            const SizedBox(height: 15),
            Text(
              widget.userData['nama'] ?? 'User',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '@${widget.userData['username'] ?? 'username'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isActive,
    int? badgeCount,
    EdgeInsetsGeometry? padding,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context, {EdgeInsetsGeometry? padding}) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: InkWell(
        onTap: () => _showLogoutConfirmation(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent, size: 24),
              const SizedBox(width: 16),
              Text(
                'main.xin_logout'.tr(context),
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.logout_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'main.logout_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'main.logout_confirm_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withAlpha(77)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Perform Logout
                      const storage = FlutterSecureStorage();
                      await storage.delete(key: 'user_data');
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.xin_logout'.tr(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
