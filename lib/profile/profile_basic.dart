import 'package:flutter/material.dart';
import 'profile_edit.dart';
import '../localization/app_localizations.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'profile.basic_info'.tr(context),
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
            _buildInfoCard(context, [
              if (data['user_type'] != 'customer')
                _buildInfoRow(
                  context,
                  'profile.employee_id'.tr(context),
                  data['employee_id'] ?? '-',
                ),
              _buildInfoRow(
                context,
                'profile.gender'.tr(context),
                data['gender'] == '1'
                    ? 'profile.male'.tr(context)
                    : 'profile.female'.tr(context),
              ),
              _buildInfoRow(
                context,
                'profile.dob'.tr(context),
                data['date_of_birth'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.marital_status'.tr(context),
                _getMaritalStatus(data['marital_status'], context),
              ),
              _buildInfoRow(
                context,
                'profile.religion'.tr(context),
                data['religion_name'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.blood_group'.tr(context),
                data['blood_group'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.nationality'.tr(context),
                'Indonesia',
              ),
              _buildInfoRow(
                context,
                'profile.address'.tr(context),
                data['address_1'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.city_state'.tr(context),
                '${data['city'] ?? ''}, ${data['state'] ?? ''}',
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

  String _getMaritalStatus(dynamic status, BuildContext context) {
    switch (status?.toString()) {
      case '0':
        return 'profile.single'.tr(context);
      case '1':
        return 'profile.married'.tr(context);
      case '2':
        return 'profile.widowed'.tr(context);
      case '3':
        return 'profile.separated'.tr(context);
      default:
        return 'profile.single'.tr(context);
    }
  }
}
