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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          'profile.contract_details'.tr(context),
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard([
              _buildInfoRow(
                'profile.contract_date'.tr(context),
                data['date_of_joining'] ?? '-',
              ),
              _buildInfoRow(
                'profile.department'.tr(context),
                data['department_name'] ?? '-',
              ),
              _buildInfoRow(
                'profile.designation'.tr(context),
                data['designation_name'] ?? '-',
              ),
              _buildInfoRow(
                'profile.basic_salary'.tr(context),
                '$currency ${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(double.tryParse(data['basic_salary']?.toString() ?? '0') ?? 0)}',
              ),
              _buildInfoRow(
                'profile.hourly_rate'.tr(context),
                '$currency ${data['hourly_rate'] ?? '0'}',
              ),
              _buildInfoRow(
                'profile.office_shift'.tr(context),
                data['shift_name'] ?? '-',
              ),
              _buildInfoRow(
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

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
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

  Widget _buildInfoRow(String label, String value, {bool last = false}) {
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
              style: const TextStyle(
                color: Color(0xFF1A1F36),
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
