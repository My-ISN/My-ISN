import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';

class RentPlanPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Color _primaryColor = const Color(0xFF7E57C2);

  const RentPlanPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: userData, showBackButton: true),
      endDrawer: SideDrawer(userData: userData, activePage: 'rent_plan'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHeaderCard(context),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'attendance.summary'.tr(context),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusCard(
                    context,
                    title: 'Rencana Aktif',
                    value: '12',
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    context,
                    title: 'Menunggu Persetujuan',
                    value: '3',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    context,
                    title: 'Rencana Selesai',
                    value: '45',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.house_outlined,
                          size: 64,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Data Detail',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daftar penyewaan Anda akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.house_outlined, color: _primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.rent_plan'.tr(context),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Kelola rencana penyewaan Anda',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
        ],
      ),
    );
  }
}


