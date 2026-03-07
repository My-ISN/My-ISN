import 'package:flutter/material.dart';
import 'profile_edit.dart';

class ProfileBasicPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> userData;
  final Map<String, dynamic> fullProfileData;

  const ProfileBasicPage({
    super.key,
    required this.data,
    required this.userData,
    required this.fullProfileData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Basic Information',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF7E57C2)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditPage(
                    userData: userData,
                    profileData: fullProfileData,
                    section: 'basic',
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  Navigator.pop(context, true);
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard([
              if (data['user_type'] != 'customer')
                _buildInfoRow('Employee ID', data['employee_id'] ?? '-'),
              _buildInfoRow(
                'Gender',
                data['gender'] == '1' ? 'Male' : 'Female',
              ),
              _buildInfoRow('Date of Birth', data['date_of_birth'] ?? '-'),
              _buildInfoRow(
                'Marital Status',
                _getMaritalStatus(data['marital_status']),
              ),
              _buildInfoRow('Religion', data['religion_name'] ?? '-'),
              _buildInfoRow('Blood Group', data['blood_group'] ?? '-'),
              _buildInfoRow('Nationality', 'Indonesia'),
              _buildInfoRow('Address', data['address_1'] ?? '-'),
              _buildInfoRow(
                'City/State',
                '${data['city'] ?? ''}, ${data['state'] ?? ''}',
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

  String _getMaritalStatus(dynamic status) {
    switch (status?.toString()) {
      case '0':
        return 'Single';
      case '1':
        return 'Married';
      case '2':
        return 'Widowed';
      case '3':
        return 'Separated';
      default:
        return 'Single';
    }
  }
}
