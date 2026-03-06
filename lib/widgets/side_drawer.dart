import 'package:flutter/material.dart';
import '../login_page.dart';
import '../settings_page.dart';
import '../profile/profile_page.dart';

class SideDrawer extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String activePage;
  final Function(int)? onTabSelected;

  const SideDrawer({
    super.key,
    required this.userData,
    required this.activePage,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  isActive: activePage == 'dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(0);
                    } else if (activePage != 'dashboard') {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Profil Saya',
                  isActive: activePage == 'profile',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(3);
                    } else if (activePage != 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(userData: userData),
                        ),
                      );
                    }
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Pengaturan',
                  isActive: activePage == 'settings',
                  onTap: () {
                    Navigator.pop(context);
                    if (activePage != 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SettingsPage(userData: userData),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLogout(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (onTabSelected != null) {
          onTabSelected!(3);
        } else if (activePage != 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(userData: userData),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.only(
          top: 60,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        color: const Color(0xFF7E57C2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage:
                  (userData['profile_photo'] != null &&
                      userData['profile_photo'].toString().isNotEmpty)
                  ? NetworkImage(
                      'https://foxgeen.com/HRIS/public/uploads/users/thumb/${userData['profile_photo']}',
                    )
                  : null,
              child:
                  (userData['profile_photo'] == null ||
                      userData['profile_photo'].toString().isEmpty)
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 15),
            Text(
              userData['nama'] ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '@${userData['username'] ?? 'username'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF7E57C2).withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF7E57C2) : Colors.grey[700],
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? const Color(0xFF7E57C2) : Colors.grey[800],
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: InkWell(
        onTap: () {
          // Fix for black screen: use pushAndRemoveUntil to clear stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent, size: 24),
              const SizedBox(width: 16),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
