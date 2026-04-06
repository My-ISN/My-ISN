import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/searchable_dropdown.dart';

class TodoFilterBar extends StatelessWidget {
  final String viewMode;
  final Function(String) onViewModeChanged;
  final List<dynamic> employees;
  final String? selectedEmployeeId;
  final Function(String) onEmployeeSelected;
  final bool isEmployeesLoading;
  final Color primaryColor;

  const TodoFilterBar({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.employees,
    this.selectedEmployeeId,
    required this.onEmployeeSelected,
    required this.isEmployeesLoading,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildViewModePills(context, isDark),
        if (viewMode == 'team') ...[
          const SizedBox(height: 16),
          _buildEmployeeDropdown(context, isDark),
        ],
      ],
    );
  }

  Widget _buildViewModePills(BuildContext context, bool isDark) {
    final int selectedIndex = viewMode == 'personal' ? 0 : 1;

    return Container(
      height: 54,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutBack,
            alignment: Alignment(selectedIndex == 0 ? -1 : 1, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildPillLabel(
                  context,
                  'personal',
                  'todo_list.personal'.tr(context),
                  viewMode == 'personal',
                ),
              ),
              Expanded(
                child: _buildPillLabel(
                  context,
                  'team',
                  'todo_list.team'.tr(context),
                  viewMode == 'team',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillLabel(BuildContext context, String mode, String label, bool isActive) {
    return GestureDetector(
      onTap: () => onViewModeChanged(mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[600],
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
        child: Center(child: Text(label)),
      ),
    );
  }

  Widget _buildEmployeeDropdown(BuildContext context, bool isDark) {
    String selectedName = '';
    if (selectedEmployeeId != null) {
      final emp = employees.firstWhere(
        (e) => e['user_id'].toString() == selectedEmployeeId,
        orElse: () => null,
      );
      if (emp != null) {
        selectedName = '${emp['first_name']} ${emp['last_name'] ?? ''}'.trim();
      }
    }

    final List<Map<String, String>> employeeOptions = employees.map((emp) {
      return {
        'id': emp['user_id'].toString(),
        'name': '${emp['first_name']} ${emp['last_name'] ?? ''}'.trim(),
      };
    }).toList();

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SearchableDropdown(
        label: 'todo_list.select_employee'.tr(context),
        value: selectedName,
        options: employeeOptions,
        icon: Icons.person_search_rounded,
        placeholder: isEmployeesLoading
            ? 'profile.loading'.tr(context)
            : 'employees.search_hint'.tr(context),
        required: false,
        onSelected: onEmployeeSelected,
      ),
    );
  }
}
