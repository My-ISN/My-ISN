import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/searchable_dropdown.dart';

class TodoFilterBar extends StatelessWidget {
  final String viewMode;
  final Function(String) onViewModeChanged;
  final List<dynamic> employees;
  final List<dynamic> shortcutEmployees;
  final String? selectedEmployeeId;
  final Function(String) onEmployeeSelected;
  final bool isEmployeesLoading;
  final Color primaryColor;

  const TodoFilterBar({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.employees,
    this.shortcutEmployees = const [],
    this.selectedEmployeeId,
    required this.onEmployeeSelected,
    required this.isEmployeesLoading,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildViewModePills(context, isDark),
        if (shortcutEmployees.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildShortcutChips(context, isDark),
        ],
        if (viewMode == 'team') ...[
          const SizedBox(height: 14),
          _buildEmployeeDropdown(context, isDark),
        ],
      ],
    );
  }

  Widget _buildShortcutChips(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 15, color: Colors.amber[700]),
            const SizedBox(width: 4),
            Text(
              'SHORTCUT RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: shortcutEmployees.map((sc) {
              final isSelected = (viewMode == 'team') && (selectedEmployeeId == sc['user_id'].toString());
              final name = (sc['first_name'] ?? sc['name'] ?? '').toString();
              final incomplete = int.tryParse(sc['incomplete_todo']?.toString() ?? '0') ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (viewMode != 'team') {
                        onViewModeChanged('team');
                      }
                      onEmployeeSelected(sc['user_id'].toString());
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          if (incomplete > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$incomplete',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildViewModePills(BuildContext context, bool isDark) {
    final int selectedIndex = viewMode == 'personal' ? 0 : 1;

    return Container(
      height: 54,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).primaryColor.withValues(alpha: 0.04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
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
                  borderRadius: BorderRadius.circular(12),
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
          color: isActive 
              ? Colors.white 
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
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
