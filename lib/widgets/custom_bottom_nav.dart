import 'package:flutter/material.dart';
import 'connectivity_wrapper.dart';
import '../localization/app_localizations.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
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

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: 'main.xin_dashboard'.tr(context),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_month),
          label: 'main.xin_attendance'.tr(context),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.payments_outlined),
          label: 'main.xin_payroll'.tr(context),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          label: 'main.xin_profile'.tr(context),
        ),
      ],
    );
  }
}
