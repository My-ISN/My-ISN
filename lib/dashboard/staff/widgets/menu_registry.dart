import 'package:flutter/material.dart';
import 'package:myisn/rent_plan/staff/rent_plan_page.dart' as staff_rp;
import 'package:myisn/rent_plan/client/rent_plan_page.dart' as client_rp;
import 'package:myisn/todo_list/todo_list_page.dart';
import 'package:myisn/employees/employees_page.dart';
import 'package:myisn/work_log/work_log_page.dart';
import 'package:myisn/finance/finance_page.dart';
import 'package:myisn/personal_finance/personal_finance_page.dart';
import 'package:myisn/helpdesk/helpdesk_list_page.dart';
import 'package:myisn/ai_bot/ai_bot_page.dart';
import 'package:myisn/creative_idea/creative_idea_page.dart';
import 'package:myisn/intercom/intercom_page.dart';
import 'package:myisn/profile/profile_page.dart';
import 'package:myisn/dashboard/dashboard_page.dart';
import 'package:myisn/quicksend/quick_send_page.dart';
import 'package:myisn/job_desk/job_desk_page.dart';
import 'package:myisn/reports/reports_page.dart';
import 'package:myisn/projects/project_list_page.dart';
import 'package:myisn/tasks/task_list_page.dart';

class AppModule {
  final String titleKey;
  final IconData icon;
  final Color color;
  final String? permission;
  final String categoryKey;
  final Widget Function(BuildContext, Map<String, dynamic>) pageBuilder;
  final String? tabTag;

  AppModule({
    required this.titleKey,
    required this.icon,
    required this.color,
    this.permission,
    required this.categoryKey,
    required this.pageBuilder,
    this.tabTag,
  });
}

class MenuRegistry {
  static List<AppModule> getModules(Map<String, dynamic> userData) {
    final bool isCustomer = userData['user_type'] == 'customer' ||
        userData['user_role_id'] == 21 ||
        userData['user_role_id'] == '21';

    return [
      AppModule(
        titleKey: 'dashboard.quick_menu_rent_plan',
        icon: Icons.house_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_rent_plan_enable',
        categoryKey: 'side_drawer.work',
        tabTag: isCustomer ? 'rent_plan' : null,
        pageBuilder: (context, user) => isCustomer
            ? client_rp.RentPlanPage(userData: user)
            : staff_rp.RentPlanPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_todo_list',
        icon: Icons.assignment_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_todo_enable',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => TodoListPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_work_log',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_worklog_enable',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => WorkLogPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_quicksend',
        icon: Icons.send_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_quicksend_view',
        categoryKey: 'side_drawer.support',
        pageBuilder: (context, user) => QuickSendPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_finance',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_finance_enable',
        categoryKey: 'side_drawer.financial',
        pageBuilder: (context, user) => FinancePage(userData: user),
      ),
      AppModule(
        titleKey: 'personal_finance.my_wallet',
        icon: Icons.payments_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_personal_finance_enable',
        categoryKey: 'side_drawer.financial',
        pageBuilder: (context, user) => PersonalFinancePage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_job_desk',
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_jobdesk_view',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => JobDeskPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_employees',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_employees_enable',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => EmployeesPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_creative_idea',
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'creative_idea',
        categoryKey: 'side_drawer.support',
        pageBuilder: (context, user) => CreativeIdeaPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_ai_bot',
        icon: Icons.smart_toy_rounded,
        color: const Color(0xFF7E57C2),
        categoryKey: 'side_drawer.support',
        pageBuilder: (context, user) => AiBotPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_helpdesk',
        icon: Icons.support_agent_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_helpdesk_view',
        categoryKey: 'side_drawer.support',
        pageBuilder: (context, user) => HelpdeskListPage(userData: user),
      ),
      AppModule(
        titleKey: 'dashboard.quick_menu_intercom',
        icon: Icons.volume_up_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_intercom_view',
        categoryKey: 'side_drawer.support',
        pageBuilder: (context, user) => IntercomPage(userData: user),
      ),
      if (!isCustomer)
        AppModule(
          titleKey: 'main.xin_attendance',
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF7E57C2),
          categoryKey: 'main.xin_dashboard',
          tabTag: 'attendance',
          pageBuilder: (context, user) =>
              DashboardPage(userData: user, initialIndex: 1),
        ),
      AppModule(
        titleKey: 'main.xin_profile',
        icon: Icons.person_rounded,
        color: const Color(0xFF7E57C2),
        categoryKey: 'main.xin_dashboard',
        tabTag: 'profile',
        pageBuilder: (context, user) => ProfilePage(userData: user),
      ),
      if (!isCustomer)
        AppModule(
          titleKey: 'main.xin_payroll',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF7E57C2),
          permission: 'mobile_payroll_enable',
          categoryKey: 'main.xin_dashboard',
          tabTag: 'payroll',
          pageBuilder: (context, user) =>
              DashboardPage(userData: user, initialIndex: 2),
        ),
      AppModule(
        titleKey: 'dashboard.quick_menu_reports',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_reports_enable',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => ReportsPage(userData: user),
      ),
      AppModule(
        titleKey: 'Proyek',
        icon: Icons.folder_copy_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_projects_view',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => ProjectListPage(userData: user),
      ),
      AppModule(
        titleKey: 'Tugas',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF7E57C2),
        permission: 'mobile_tasks_view',
        categoryKey: 'side_drawer.work',
        pageBuilder: (context, user) => TaskListPage(userData: user),
      ),
    ];
  }
}

