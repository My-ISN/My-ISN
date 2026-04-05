import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import 'profile_contract.dart';
import 'profile_basic.dart';
import 'profile_personal.dart';
import 'profile_bank.dart';
import 'profile_edit.dart';
import '../widgets/connectivity_wrapper.dart';
import '../services/log_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/side_drawer.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isTab;
  const ProfilePage({super.key, required this.userData, this.isTab = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _fetchProfileDetails();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources
        .split(',')
        .map((e) => e.trim())
        .toList();
    return resourceList.contains(resource);
  }

  Future<void> _fetchProfileDetails() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_profile_details?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        Log.d('PROFILE DEBUG DATA: ${data['data']['debug_raw']}');
        if (mounted) {
          setState(() {
            _profileData = data['data'];
            _isLoading = false;
          });
        }
      } else {
        Log.w('PROFILE API ERROR: ${data['message']}');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'main.error_with_msg'.tr(
                  context,
                  args: {'message': data['message'].toString()},
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error fetching profile details: $e');
      if (mounted && ConnectivityStatus.of(context)) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile.conn_error'.tr(context))),
        );
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final basic = _profileData['basic_info'] ?? {};

    Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchProfileDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).padding.top + 20,
                        ),
                        _buildMainInfoCard(),
                        const SizedBox(height: 24),
                        _buildDetailInfoContainer(),
                        const SizedBox(height: 24),
                        _buildMenuSection(),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: ConnectivityStatus.bottomPadding,
                    builder: (context, padding, _) => SizedBox(
                      height: (padding + 20).clamp(0.0, double.infinity),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: _profileData['basic_info'] ?? widget.userData,
        showBackButton: true,
      ),
      body: content,
      endDrawer: SideDrawer(
        userData: _profileData['basic_info'] ?? widget.userData,
        activePage: 'profile',
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _hasPermission('mobile_payroll_enable') ? 3 : 2,
        userData: widget.userData,
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          // Tambahkan logika navigasi tab lain jika perlu
        },
      ),
    );
  }

  Widget _buildMainInfoCard() {
    final basic = _profileData['basic_info'] ?? {};
    String fullName = '${basic['first_name'] ?? ''} ${basic['last_name'] ?? ''}'
        .trim();
    if (fullName.isEmpty) {
      fullName =
          widget.userData['nama'] ?? widget.userData['first_name'] ?? 'User';
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: Colors.white10)
                : null,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF512DA8), Color(0xFF7E57C2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundImage:
                      (basic['profile_photo'] != null &&
                          basic['profile_photo'].toString().isNotEmpty)
                      ? CachedNetworkImageProvider(
                          'https://foxgeen.com/HRIS/public/uploads/users/thumb/${basic['profile_photo']}',
                        )
                      : (widget.userData['profile_photo'] != null &&
                            widget.userData['profile_photo']
                                .toString()
                                .isNotEmpty)
                      ? CachedNetworkImageProvider(
                          'https://foxgeen.com/HRIS/public/uploads/users/thumb/${widget.userData['profile_photo']}',
                        )
                      : null,
                  child:
                      (basic['profile_photo'] == null ||
                              basic['profile_photo'].toString().isEmpty) &&
                          (widget.userData['profile_photo'] == null ||
                              widget.userData['profile_photo']
                                  .toString()
                                  .isEmpty)
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '@${basic['username'] ?? widget.userData['username'] ?? 'username'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  (basic['role_name'] ??
                          widget.userData['role_name'] ??
                          'Staff')
                      .toString()
                      .roleTr(context),
                  style: const TextStyle(
                    color: Color(0xFF2ECC71),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditPage(
                    userData: widget.userData,
                    profileData: _profileData,
                    section: 'header',
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  _fetchProfileDetails();
                }
              });
            },
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).hintColor.withOpacity(0.5),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailInfoContainer() {
    final basic = _profileData['basic_info'] ?? {};
    final contract = _profileData['contract'] ?? {};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white10)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.basic_info'.tr(context),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          if (basic['user_type'] != 'customer') ...[
            _buildEnhancedInfoRow(
              Icons.business_rounded,
              contract['department_name'] ?? '-',
              "profile.department".tr(context),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 0.5),
            ),
          ],
          _buildEnhancedInfoRow(
            Icons.email_rounded,
            basic['email'] ?? widget.userData['email'] ?? '-',
            "profile.email".tr(context),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5),
          ),
          _buildEnhancedInfoRow(
            Icons.phone_android_rounded,
            basic['contact_number'] ?? widget.userData['contact_number'] ?? '-',
            "profile.phone".tr(context),
          ),
          if (basic['user_type'] != 'customer') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 0.5),
            ),
            _buildEnhancedInfoRow(
              Icons.person_pin_rounded,
              contract['manager_name'] ?? '-',
              "profile.manager".tr(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    final basic = _profileData['basic_info'] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'profile.others'.tr(context),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (basic['user_type'] != 'customer') ...[
          _buildMenuTile(
            icon: Icons.assignment_rounded,
            title: 'profile.contract'.tr(context),
            subtitle: 'profile.contract_desc'.tr(context),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfileContractPage(data: _profileData['contract'] ?? {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildMenuTile(
          icon: Icons.account_circle_rounded,
          title: 'profile.basic_info'.tr(context),
          subtitle: 'profile.basic_info_desc'.tr(context),
          onTap: () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileBasicPage(
                    data: _profileData['basic_info'] ?? {},
                    userData: widget.userData,
                    fullProfileData: _profileData,
                  ),
                ),
              ).then((value) {
                if (value == true) _fetchProfileDetails();
              }),
        ),
        const SizedBox(height: 12),
        _buildMenuTile(
          icon: Icons.contact_page_rounded,
          title: 'profile.personal_info'.tr(context),
          subtitle: 'profile.personal_info_desc'.tr(context),
          onTap: () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePersonalPage(
                    data: _profileData['personal_info'] ?? {},
                    userData: widget.userData,
                    fullProfileData: _profileData,
                  ),
                ),
              ).then((value) {
                if (value == true) _fetchProfileDetails();
              }),
        ),
        const SizedBox(height: 12),
        _buildMenuTile(
          icon: Icons.account_balance_rounded,
          title: 'profile.bank_account'.tr(context),
          subtitle: 'profile.bank_account_desc'.tr(context),
          onTap: () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileBankPage(
                    data: _profileData['bank_info'] ?? {},
                    userData: widget.userData,
                    fullProfileData: _profileData,
                  ),
                ),
              ).then((value) {
                if (value == true) _fetchProfileDetails();
              }),
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoRow(IconData icon, String text, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.05,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white10)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey,
            size: 20,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
