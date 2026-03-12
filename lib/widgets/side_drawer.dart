import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../login_page.dart';
import '../settings_page.dart';
import '../profile/profile_page.dart';
import '../attendance_page.dart';
import '../rent_plan/rent_plan_page.dart';
import '../todo_list/todo_list_page.dart';
import '../employees/employees_page.dart';
import '../localization/app_localizations.dart';


class SideDrawer extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String activePage;
  final Function(int)? onTabSelected;

  const SideDrawer({
    super.key,
    required this.userData,
    required this.activePage,
    this.onTabSelected,
  });

  bool _hasPermission(String resource) {
    if (userData['role_resources'] == 'all') return true;
    final String resources = userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
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
                  isActive: activePage == 'dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(0);
                    } else if (activePage != 'dashboard') {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.calendar_today_outlined,
                  title: 'main.xin_attendance'.tr(context),
                  isActive: activePage == 'attendance',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(1);
                    } else if (activePage != 'attendance') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AttendancePage(userData: userData),
                        ),
                      );
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.payments_outlined,
                  title: 'main.xin_payroll'.tr(context),
                  isActive: activePage == 'payroll',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(2);
                    } else if (activePage != 'payroll') {
                      // Handled within dashboard tabs
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'main.xin_profile'.tr(context),
                  isActive: activePage == 'profile',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(3);
                    } else if (activePage != 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(userData: userData),
                        ),
                      );
                    }
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                if (_hasPermission('mobile_rent_plan_enable'))
                  _buildMenuItem(
                    context,
                    icon: Icons.house_outlined,
                    title: 'dashboard.rent_plan'.tr(context),
                    isActive: activePage == 'rent_plan',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RentPlanPage(userData: userData),
                        ),
                      );
                    },
                  ),
                if (_hasPermission('mobile_todo_enable'))
                  _buildMenuItem(
                    context,
                    icon: Icons.list_alt_outlined,
                    title: 'dashboard.todo_list'.tr(context),
                    isActive: activePage == 'todo_list',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TodoListPage(userData: userData),
                        ),
                      );
                    },
                  ),
                if (_hasPermission('mobile_employees_enable'))
                  _buildMenuItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'dashboard.employees'.tr(context),
                    isActive: activePage == 'employees',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeesPage(userData: userData),
                        ),
                      );
                    },
                  ),

                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'main.xin_settings'.tr(context),
                  isActive: activePage == 'settings',
                  onTap: () {
                    Navigator.pop(context);
                    if (activePage != 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SettingsPage(userData: userData),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLogout(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (onTabSelected != null) {
          onTabSelected!(3);
        } else if (activePage != 'profile') {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(userData: userData),
            ),
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
              color: Theme.of(context).dividerColor.withOpacity(0.1),
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
              ).colorScheme.primary.withOpacity(0.1),
              backgroundImage:
                  (userData['profile_photo'] != null &&
                      userData['profile_photo'].toString().isNotEmpty)
                  ? NetworkImage(
                      'https://foxgeen.com/HRIS/public/uploads/users/thumb/${userData['profile_photo']}',
                    )
                  : null,
              child:
                  (userData['profile_photo'] == null ||
                      userData['profile_photo'].toString().isEmpty)
                  ? Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            const SizedBox(height: 15),
            Text(
              userData['nama'] ?? 'User',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '@${userData['username'] ?? 'username'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: InkWell(
        onTap: () async {
          // Clear user session
          const storage = FlutterSecureStorage();
          await storage.delete(key: 'user_data');

          if (!context.mounted) return;

          // Fix for black screen: use pushAndRemoveUntil to clear stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        },
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
}
