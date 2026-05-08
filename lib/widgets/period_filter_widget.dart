import 'package:flutter/material.dart';
import 'package:myisn/localization/app_localizations.dart';

class PeriodFilterButton extends StatelessWidget {
  final String selectedMonth;
  final String selectedYear;
  final List<Map<String, String>> months;
  final VoidCallback onTap;

  const PeriodFilterButton({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.months,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF7E57C2);
    
    // Get month name and truncate it
    String monthName = '';
    try {
      final monthMap = months.firstWhere(
        (m) => m['id'] == selectedMonth,
        orElse: () => {'id': '01', 'name': 'month_jan'},
      );
      monthName = (monthMap['name'] ?? '').tr(context);
      if (monthName.length > 3) {
        monthName = monthName.substring(0, 3);
      }
    } catch (e) {
      monthName = 'Jan';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$monthName $selectedYear',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class PeriodPickerSheet extends StatefulWidget {
  final String initialMonth;
  final String initialYear;
  final List<Map<String, String>> months;
  final List<String> years;
  final Function(String month, String year) onApply;

  const PeriodPickerSheet({
    super.key,
    required this.initialMonth,
    required this.initialYear,
    required this.months,
    required this.years,
    required this.onApply,
  });

  static void show({
    required BuildContext context,
    required String initialMonth,
    required String initialYear,
    required List<Map<String, String>> months,
    required List<String> years,
    required Function(String month, String year) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PeriodPickerSheet(
        initialMonth: initialMonth,
        initialYear: initialYear,
        months: months,
        years: years,
        onApply: onApply,
      ),
    );
  }

  @override
  State<PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<PeriodPickerSheet> {
  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF7E57C2);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'finance.choose_period'.tr(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Year Selector
              Expanded(
                child: _buildDropdownContainer(
                  context: context,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(15),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedYear = newValue);
                        }
                      },
                      dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      items: widget.years.map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Month Selector
              Expanded(
                child: _buildDropdownContainer(
                  context: context,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(15),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedMonth = newValue);
                        }
                      },
                      dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      items: widget.months.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text(m['name']!.tr(context)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selectedMonth, _selectedYear);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: Text(
                'main.apply'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }
}
