import 'package:flutter/material.dart';
import 'connectivity_wrapper.dart';
import '../localization/app_localizations.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Map<String, dynamic> userData;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.userData,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  @override
  void initState() {
    super.initState();
    // Set padding when bottom nav is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityStatus.bottomPadding.value = 56.0;
    });
  }

  @override
  void dispose() {
    // Reset padding when bottom nav is removed
    ConnectivityStatus.bottomPadding.value = 0.0;
    super.dispose();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPayroll = _hasPermission('mobile_payroll_enable');
    final bool isCustomer = widget.userData['user_type'] == 'customer' || 
                           widget.userData['user_role_id'] == 21 || 
                           widget.userData['user_role_id'] == '21';

    final List<BottomNavigationBarItem> items = isCustomer ? [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home),
        label: 'main.xin_dashboard'.tr(context),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.house_rounded),
        label: 'main.xin_rent_plan'.tr(context),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt_long_rounded),
        label: 'main.xin_invoice'.tr(context),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        label: 'main.xin_profile'.tr(context),
      ),
    ] : [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home),
        label: 'main.xin_dashboard'.tr(context),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_month),
        label: 'main.xin_attendance'.tr(context),
      ),
      if (hasPayroll)
        BottomNavigationBarItem(
          icon: const Icon(Icons.payments_outlined),
          label: 'main.xin_payroll'.tr(context),
        ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        label: 'main.xin_profile'.tr(context),
      ),
    ];

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: items,
    );
  }
}
