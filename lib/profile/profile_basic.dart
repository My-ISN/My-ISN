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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF7E57C2),
                  size: 20,
                ),
              ),
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildInfoCard(context, [
              if (data['user_type'] != 'customer')
                _buildInfoRow(
                  context,
                  'profile.employee_id'.tr(context),
                  data['employee_id'] ?? '-',
                  const Icon(
                    Icons.badge_rounded,
                    size: 20,
                    color: Color(0xFF7E57C2),
                  ),
                ),
              _buildInfoRow(
                context,
                'profile.gender'.tr(context),
                data['gender'] == '1'
                    ? 'profile.male'.tr(context)
                    : 'profile.female'.tr(context),
                const Icon(
                  Icons.people_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.dob'.tr(context),
                data['date_of_birth'] ?? '-',
                const Icon(
                  Icons.cake_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.marital_status'.tr(context),
                _getMaritalStatus(data['marital_status'], context),
                const Icon(
                  Icons.favorite_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.religion'.tr(context),
                data['religion_name'] ?? '-',
                const Icon(
                  Icons.mosque_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.blood_group'.tr(context),
                data['blood_group'] ?? '-',
                const Icon(
                  Icons.bloodtype_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.nationality'.tr(context),
                'Indonesia',
                const Icon(
                  Icons.flag_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.address'.tr(context),
                data['address_1'] ?? '-',
                const Icon(
                  Icons.home_rounded,
                  size: 20,
                  color: Color(0xFF7E57C2),
                ),
              ),
              _buildInfoRow(
                context,
                'profile.city_state'.tr(context),
                '${data['city'] ?? ''}, ${data['state'] ?? ''}',
                const Icon(
                  Icons.location_city_rounded,
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
