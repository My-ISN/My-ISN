import 'package:flutter/material.dart';
import 'profile_edit.dart';
import '../localization/app_localizations.dart';

class ProfileBankPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic> userData;
  final Map<String, dynamic> fullProfileData;

  const ProfileBankPage({
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
          'profile.bank_account'.tr(context),
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
                    section: 'bank',
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
              _buildInfoRow(
                context,
                'profile.account_title'.tr(context),
                data['account_title'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.account_number'.tr(context),
                data['account_number'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.bank_name'.tr(context),
                data['bank_name'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.iban'.tr(context),
                data['iban'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.swift_code'.tr(context),
                data['swift_code'] ?? '-',
              ),
              _buildInfoRow(
                context,
                'profile.bank_branch'.tr(context),
                data['bank_branch'] ?? '-',
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
