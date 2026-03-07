import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfileContractPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const ProfileContractPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final currency = data['currency'] ?? 'IDR';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Contract Details',
          style: TextStyle(color: Colors.black),
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
              _buildInfoRow('Contract Date', data['date_of_joining'] ?? '-'),
              _buildInfoRow('Department', data['department_name'] ?? '-'),
              _buildInfoRow('Designation', data['designation_name'] ?? '-'),
              _buildInfoRow(
                'Basic Salary',
                '$currency ${NumberFormat.decimalPattern('id').format(double.tryParse(data['basic_salary']?.toString() ?? '0') ?? 0)}',
              ),
              _buildInfoRow(
                'Hourly Rate',
                '$currency ${data['hourly_rate'] ?? '0'}',
              ),
              _buildInfoRow('Office Shift', data['shift_name'] ?? '-'),
              _buildInfoRow(
                'Contract End',
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
