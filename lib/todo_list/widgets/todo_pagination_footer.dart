import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class TodoPaginationFooter extends StatelessWidget {
  final int currentPage;
  final int totalCount;
  final int selectedLimit;
  final Function(int) onPageChanged;
  final Color primaryColor;

  const TodoPaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalCount,
    required this.selectedLimit,
    required this.onPageChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalCount / selectedLimit).ceil();
    if (totalCount <= selectedLimit) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          context,
          icon: Icons.chevron_left_rounded,
          onPressed: currentPage > 1
              ? () => onPageChanged(currentPage - 1)
              : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'todo_list.page_x_of_y'.tr(
              context,
              args: {
                'current': currentPage.toString(),
                'total': totalPages.toString(),
              },
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          context,
          icon: Icons.chevron_right_rounded,
          onPressed: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildPageButton(BuildContext context, {required IconData icon, VoidCallback? onPressed}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: onPressed == null
          ? (isDark ? Colors.white12 : Colors.grey[200])
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? (isDark ? Colors.white24 : Colors.grey[400])
                : primaryColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}
