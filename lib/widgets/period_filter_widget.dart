import 'package:flutter/material.dart';
import 'package:foxgeen_mobile/localization/app_localizations.dart';

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
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              '$monthName $selectedYear',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Colors.grey,
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
                color: Colors.grey.withOpacity(0.3),
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}
