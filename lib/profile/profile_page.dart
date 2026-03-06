import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile_contract.dart';
import 'profile_basic.dart';
import 'profile_personal.dart';
import 'profile_bank.dart';
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

  Future<void> _fetchProfileDetails() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_profile_details?user_id=$userId';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        debugPrint('PROFILE DEBUG DATA: ${data['data']['debug_raw']}');
        if (mounted) {
          setState(() {
            _profileData = data['data'];
            _isLoading = false;
          });
        }
      } else {
        debugPrint('PROFILE API ERROR: ${data['message']}');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchProfileDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          icon: Icons.assignment_outlined,
                          title: 'Contract',
                          subtitle: 'Informasi kontrak & gaji',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileContractPage(
                                data: _profileData['contract'] ?? {},
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuTile(
                          icon: Icons.person_outline,
                          title: 'Basic Information',
                          subtitle: 'Detail data diri dasar',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileBasicPage(
                                data: _profileData['basic_info'] ?? {},
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuTile(
                          icon: Icons.info_outline,
                          title: 'Personal Information',
                          subtitle: 'Sosial media & pengalaman',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePersonalPage(
                                data: _profileData['personal_info'] ?? {},
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuTile(
                          icon: Icons.account_balance_outlined,
                          title: 'Bank Account',
                          subtitle: 'Informasi rekening bank',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileBankPage(
                                data: _profileData['bank_info'] ?? {},
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
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
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          // Tambahkan logika navigasi tab lain jika perlu
        },
      ),
    );
  }

  Widget _buildHeader() {
    final basic = _profileData['basic_info'] ?? {};
    final contract = _profileData['contract'] ?? {};

    String fullName = '${basic['first_name'] ?? ''} ${basic['last_name'] ?? ''}'
        .trim();
    if (fullName.isEmpty) {
      fullName =
          widget.userData['nama'] ?? widget.userData['first_name'] ?? 'User';
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: const Color(0xFFE6D4FA),
            backgroundImage:
                (basic['profile_photo'] != null &&
                    basic['profile_photo'].toString().isNotEmpty)
                ? NetworkImage(
                    'https://foxgeen.com/HRIS/public/uploads/users/thumb/${basic['profile_photo']}',
                  )
                : (widget.userData['profile_photo'] != null &&
                      widget.userData['profile_photo'].toString().isNotEmpty)
                ? NetworkImage(
                    'https://foxgeen.com/HRIS/public/uploads/users/thumb/${widget.userData['profile_photo']}',
                  )
                : null,
            child:
                (basic['profile_photo'] == null ||
                        basic['profile_photo'].toString().isEmpty) &&
                    (widget.userData['profile_photo'] == null ||
                        widget.userData['profile_photo'].toString().isEmpty)
                ? const Icon(Icons.person, size: 45, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '@${basic['username'] ?? widget.userData['username'] ?? 'username'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              basic['role_name'] ?? widget.userData['role_name'] ?? 'Staff',
              style: const TextStyle(
                color: Color(0xFF7E57C2),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.business_outlined,
            contract['department_name'] ?? '-',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.email_outlined,
            basic['email'] ?? widget.userData['email'] ?? '-',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.supervisor_account_outlined,
            'Manager: ${contract['manager_name'] ?? '-'}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
            overflow: TextOverflow.ellipsis,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF7E57C2), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }
}
