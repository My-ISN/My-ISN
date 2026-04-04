import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';

class ProfileContractPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const ProfileContractPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = data['currency'] ?? 'IDR';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'profile.contract_details'.tr(context),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildInfoCard(context, [
              _buildInfoRow(
                context,
                'profile.contract_date'.tr(context),
                data['date_of_joining'] ?? '-',
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.department'.tr(context),
                data['department_name'] ?? '-',
                const Icon(
                  Icons.business_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.designation'.tr(context),
                data['designation_name'] ?? '-',
                const Icon(
                  Icons.work_outline_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.basic_salary'.tr(context),
                '$currency ${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(double.tryParse(data['basic_salary']?.toString() ?? '0') ?? 0)}',
                const Icon(
                  Icons.payments_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.hourly_rate'.tr(context),
                '$currency ${data['hourly_rate'] ?? '0'}',
                const Icon(
                  Icons.timer_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.office_shift'.tr(context),
                data['shift_name'] ?? '-',
                const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.contract_end'.tr(context),
                data['date_of_leaving'] ?? '-',
                const Icon(
                  Icons.event_busy_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
                last: true,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    Widget icon, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.08),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: icon,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
