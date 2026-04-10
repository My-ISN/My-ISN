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
  static int _activeInstances = 0;

  @override
  void initState() {
    super.initState();
    _activeInstances++;
    // Set padding for floating bar (bar height + margin + shadow/buffer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityStatus.bottomPadding.value = 92.0;
    });
  }

  @override
  void dispose() {
    _activeInstances--;
    // Only reset if no more active nav bars exist
    if (_activeInstances <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ConnectivityStatus.bottomPadding.value = 0.0;
      });
    }
    super.dispose();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources
        .split(',')
        .map((e) => e.trim())
        .toList();
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasPayroll = _hasPermission('mobile_payroll_enable');
    final bool isCustomer =
        widget.userData['user_type'] == 'customer' ||
        widget.userData['user_role_id'] == 21 ||
        widget.userData['user_role_id'] == '21';

    final Color primaryColor = Theme.of(context).colorScheme.primary;

    final List<Map<String, dynamic>> items = isCustomer
        ? [
            {
              'icon': Icons.home_rounded,
              'label': 'main.xin_dashboard'.tr(context),
            },
            {
              'icon': Icons.house_rounded,
              'label': 'main.xin_rent_plan'.tr(context),
            },
            {
              'icon': Icons.person_rounded,
              'label': 'main.xin_profile'.tr(context),
            },
          ]
        : [
            {
              'icon': Icons.home_rounded,
              'label': 'main.xin_dashboard'.tr(context),
            },
            {
              'icon': Icons.calendar_month_rounded,
              'label': 'main.xin_attendance'.tr(context),
            },
            if (hasPayroll)
              {
                'icon': Icons.receipt_long_rounded,
                'label': 'main.xin_payroll'.tr(context),
              },
            {
              'icon': Icons.person_rounded,
              'label': 'main.xin_profile'.tr(context),
            },
          ];

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomPadding > 0 ? bottomPadding : 12,
      ), // Dynamic bottom margin for floating look
      child: Container(
        height: 80, // Increased height
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 77 : 25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: isDark ? Border.all(color: Colors.white10) : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final int itemCount = items.length;
            final double totalMargin =
                itemCount * 4; // Margin horizontal (2*2) per item
            final double availableWidth = constraints.maxWidth - totalMargin;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(itemCount, (index) {
                final bool isActive = widget.currentIndex == index;
                final item = items[index];

                // Dynamic width calculation: Active item takes ~45%, others share the rest
                final double activeWidth = availableWidth * 0.45;
                final double inactiveWidth =
                    (availableWidth - activeWidth) / (itemCount - 1);
                final double itemWidth = isActive ? activeWidth : inactiveWidth;

                return GestureDetector(
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCirc,
                    width: itemWidth,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: isActive ? 16 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          color: isActive
                              ? Colors.white
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 24,
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item['label'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
