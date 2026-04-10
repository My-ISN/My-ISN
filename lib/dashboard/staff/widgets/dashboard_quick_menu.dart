import 'package:flutter/material.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/custom_app_bar.dart'; // For NotificationManager
import '../../../widgets/connectivity_wrapper.dart';
import 'package:provider/provider.dart';
import '../../../providers/quick_menu_provider.dart';
import 'menu_registry.dart';
import '../../all_menus_page.dart';

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
    final quickMenuProvider = Provider.of<QuickMenuProvider>(context);
    final pinnedKeys = quickMenuProvider.pinnedKeys;

    final allModules = MenuRegistry.getModules(user);
    final allPermitted = allModules.where((m) {
      if (m.permission == null) return true;
      return hasPermission(m.permission!);
    }).toList();

    final List<AppModule> displayModules;

    if (pinnedKeys != null && pinnedKeys.isNotEmpty) {
      // Show customized pins
      displayModules = pinnedKeys
          .map((key) => allModules.firstWhere(
                (m) => m.titleKey == key,
                orElse: () => allModules.first,
              ))
          .where((m) {
        if (m.permission == null) return true;
        return hasPermission(m.permission!);
      }).toList();
    } else {
      // Show default priority
      displayModules = allPermitted;
    }

    const int maxVisible = 5;
    // Show 'More' if we have more than 6 total permitted, 
    // OR if the user has pinned a subset of their permitted modules.
    final bool showMore = (pinnedKeys != null && pinnedKeys.isNotEmpty)
        ? allPermitted.length > displayModules.length
        : allPermitted.length > maxVisible + 1;

    final List<Widget> menuItems = [];

    // Take up to 5 if showing more, else show all displayModules
    final int displayCount = showMore ? maxVisible : displayModules.length;

    for (int i = 0; i < displayCount; i++) {
      if (i >= displayModules.length) break;
      final m = displayModules[i];
      menuItems.add(_buildMenuWidget(context, m, user));
    }

    if (showMore) {
      menuItems.add(
        _buildQuickMenuCard(
          context,
          'dashboard.quick_menu_more'.tr(context),
          Icons.grid_view_rounded,
          const Color(0xFF7E57C2),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllMenusPage(
                  userData: user,
                  hasPermission: hasPermission,
                ),
              ),
            );
          },
        ),
      );
    }

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
        _buildDynamicQuickMenu(context, menuItems),
        ValueListenableBuilder<double>(
          valueListenable: ConnectivityStatus.bottomPadding,
          builder: (context, padding, _) =>
              SizedBox(height: padding.clamp(0.0, double.infinity)),
        ),
      ],
    );
  }

  Widget _buildMenuWidget(
      BuildContext context, AppModule m, Map<String, dynamic> user) {
    if (m.permission == 'mobile_todo_enable') {
      return ValueListenableBuilder<int>(
        valueListenable: NotificationManager().unreadTodoCount,
        builder: (context, count, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildQuickMenuCard(
                context,
                m.titleKey.tr(context),
                m.icon,
                m.color,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => m.pageBuilder(context, user),
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
      );
    }

    return _buildQuickMenuCard(
      context,
      m.titleKey.tr(context),
      m.icon,
      m.color,
      () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => m.pageBuilder(context, user),
          ),
        );
      },
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
