import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import 'limit_dropdown_widget.dart';

class PaginationHeader extends StatelessWidget {
  final int limit;
  final List<int> limitOptions;
  final int totalCount;
  final ValueChanged<int?> onLimitChanged;
  final Color? primaryColor;
  final String? totalLabel;
  final List<Widget>? extraLeftActions;
  final List<Widget>? extraRightActions;

  const PaginationHeader({
    super.key,
    required this.limit,
    this.limitOptions = const [10, 25, 50, 100],
    required this.totalCount,
    required this.onLimitChanged,
    this.primaryColor,
    this.totalLabel,
    this.extraLeftActions,
    this.extraRightActions,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = primaryColor ?? const Color(0xFF7E57C2);
    
    // Default total label matches the most common pattern in the app
    final String label = totalLabel ?? 'rent_plan.total_count'.tr(
      context,
      args: {'count': totalCount.toString()},
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Group: Show [Dropdown] [Extras]
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LimitDropdown(
                value: limit,
                options: limitOptions,
                onChanged: onLimitChanged,
                activeColor: color,
                label: 'rent_plan.show'.tr(context),
              ),
              if (extraLeftActions != null) ...[
                const SizedBox(width: 8),
                ...extraLeftActions!,
              ],
            ],
          ),
        ),
        // Right Group: [Extras] [Total Badge]
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (extraRightActions != null) ...[
              ...extraRightActions!,
              const SizedBox(width: 12),
            ],
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
