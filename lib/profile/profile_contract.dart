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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(context, [
              _buildInfoRow(
                context,
                'profile.contract_date'.tr(context),
                data['date_of_joining'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.department'.tr(context),
                data['department_name'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.designation'.tr(context),
                data['designation_name'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.basic_salary'.tr(context),
                '$currency ${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(double.tryParse(data['basic_salary']?.toString() ?? '0') ?? 0)}',
              ),
              _buildInfoRow(
                context,
                'profile.hourly_rate'.tr(context),
                '$currency ${data['hourly_rate'] ?? '0'}',
              ),
              _buildInfoRow(
                context,
                'profile.office_shift'.tr(context),
                data['shift_name'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.contract_end'.tr(context),
                data['date_of_leaving'] ?? '-',
                last: true,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
