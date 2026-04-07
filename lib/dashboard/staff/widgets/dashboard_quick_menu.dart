import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/custom_app_bar.dart'; // For NotificationManager
import '../../../widgets/connectivity_wrapper.dart';
import '../../../rent_plan/staff/rent_plan_page.dart' as staff_rp;
import '../../../rent_plan/client/rent_plan_page.dart' as client_rp;
import '../../../todo_list/todo_list_page.dart';
import '../../../employees/employees_page.dart';
import '../../../work_log/work_log_page.dart';
import '../../../finance/finance_page.dart';
import '../../../personal_finance/personal_finance_page.dart';
import '../../../helpdesk/helpdesk_list_page.dart';
import '../../../ai_bot/ai_bot_page.dart';
import '../../../creative_idea/creative_idea_page.dart';
import '../../../intercom/intercom_page.dart';

class DashboardQuickMenu extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> dashboardData;
  final bool Function(String) hasPermission;

  const DashboardQuickMenu({
    super.key,
    required this.userData,
    required this.dashboardData,
    required this.hasPermission,
  });

  @override
  Widget build(BuildContext context) {
    final user = dashboardData['user'] ?? userData;
    final bool isCustomer = user['user_type'] == 'customer' ||
        user['user_role_id'] == 21 ||
        user['user_role_id'] == '21';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDynamicQuickMenu(context, [
          if (hasPermission('mobile_rent_plan_enable'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_rent_plan'.tr(context),
              Icons.house_rounded,
              const Color(0xFF7E57C2),
              () {
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
          if (hasPermission('mobile_todo_enable'))
            ValueListenableBuilder<int>(
              valueListenable: NotificationManager().unreadTodoCount,
              builder: (context, count, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildQuickMenuCard(
                      context,
                      'dashboard.quick_menu_todo_list'.tr(context),
                      Icons.assignment_rounded,
                      const Color(0xFF7E57C2),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TodoListPage(userData: user),
                          ),
                        );
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (hasPermission('mobile_employees_enable'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_employees'.tr(context),
              Icons.people_alt_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeesPage(userData: user),
                  ),
                );
              },
            ),
          if (hasPermission('mobile_worklog_enable'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_work_log'.tr(context),
              Icons.assignment_turned_in_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkLogPage(userData: user),
                  ),
                );
              },
            ),
          if (hasPermission('mobile_finance_enable'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_finance'.tr(context),
              Icons.account_balance_wallet_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FinancePage(userData: user),
                  ),
                );
              },
            ),
          if (hasPermission('mobile_personal_finance_enable'))
            _buildQuickMenuCard(
              context,
              'personal_finance.my_wallet'.tr(context),
              Icons.payments_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonalFinancePage(userData: user),
                  ),
                );
              },
            ),
          if (hasPermission('mobile_helpdesk_view'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_helpdesk'.tr(context),
              Icons.support_agent_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HelpdeskListPage(userData: user),
                  ),
                );
              },
            ),
          _buildQuickMenuCard(
            context,
            'dashboard.quick_menu_ai_bot'.tr(context),
            Icons.smart_toy_rounded,
            const Color(0xFF7E57C2),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AiBotPage(userData: user),
                ),
              );
            },
            ),
          if (hasPermission('creative_idea'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_creative_idea'.tr(context),
              Icons.lightbulb_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreativeIdeaPage(userData: user),
                  ),
                );
              },
            ),
          if (hasPermission('mobile_intercom_view'))
            _buildQuickMenuCard(
              context,
              'dashboard.quick_menu_intercom'.tr(context),
              Icons.volume_up_rounded,
              const Color(0xFF7E57C2),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IntercomPage(userData: user),
                  ),
                );
              },
            ),
        ]),
        ValueListenableBuilder<double>(
          valueListenable: ConnectivityStatus.bottomPadding,
          builder: (context, padding, _) =>
              SizedBox(height: padding.clamp(0.0, double.infinity)),
        ),
      ],
    );
  }

  Widget _buildDynamicQuickMenu(BuildContext context, List<Widget> items) {
    if (items.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - (10 * 2)) / 3;
        final double fixedHeight = itemWidth * 1.05;

        final List<List<Widget>> rows = [];
        for (var i = 0; i < items.length; i += 3) {
          rows.add(
            items.sublist(i, i + 3 > items.length ? items.length : i + 3),
          );
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
                        child: SizedBox(height: fixedHeight, child: item),
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
    BuildContext context,
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
            : Border.all(color: Colors.grey.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                    color: color.withValues(alpha: 0.1),
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
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
}
