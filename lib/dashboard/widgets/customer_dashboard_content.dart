import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants.dart';

import '../../localization/app_localizations.dart';
import '../../widgets/connectivity_wrapper.dart';
import 'package:intl/intl.dart';

class CustomerDashboardContent extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> customerDashboardData;
  final Future<void> Function() onRefresh;
  final Function(int) onProfileTap;
  final Function(String, String) onLaunchWhatsApp;

  const CustomerDashboardContent({
    super.key,
    required this.userData,
    required this.customerDashboardData,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onLaunchWhatsApp,
  });

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(double.tryParse(price.toString()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final stats = customerDashboardData['stats'] ?? {};
    final products = customerDashboardData['products'] ?? [];
    final contact = customerDashboardData['contact'] ?? {};

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(context),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'dashboard.rental_active'.tr(context),
                    '${stats['active_rentals'] ?? 0}',
                    Icons.laptop_mac_rounded,
                    const Color(0xFF2ECC71),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'dashboard.total_paid'.tr(context),
                    'Rp ${_formatPrice(stats['total_paid'] ?? 0)}',
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF2ECC71),
                    isOutline: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'dashboard.total_unpaid'.tr(context),
                    'Rp ${_formatPrice(stats['total_unpaid'] ?? 0)}',
                    Icons.error_outline_rounded,
                    const Color(0xFFE74C3C),
                    isOutline: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'dashboard.total_invoice'.tr(context),
                    '${stats['total_invoice'] ?? 0}',
                    Icons.receipt_long_rounded,
                    const Color(0xFF7E57C2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHelpSection(context, contact),
            const SizedBox(height: 16),
            _buildProductList(context, products),
            ValueListenableBuilder<double>(
              valueListenable: ConnectivityStatus.bottomPadding,
              builder: (context, padding, _) =>
                  SizedBox(height: padding.clamp(0.0, double.infinity)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = customerDashboardData['user'] ?? userData;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onProfileTap(2), // Index for profile tab in customer view
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFFF1F5F9)
                        : Theme.of(context).scaffoldBackgroundColor,
                    child: (user['profile_photo'] != null &&
                            user['profile_photo'].toString().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl:
                                '${AppConstants.serverRoot}/uploads/users/thumb/${user['profile_photo']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.white,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['nama'] ?? 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${user['username'] ?? 'username'}',
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildRoleBadge(context, user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, Map user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Text(
        (user['role_name'] ?? 'Staff').toString().roleTr(context),
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isOutline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOutline ? Theme.of(context).cardColor : color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : (isOutline
                    ? Theme.of(context).dividerColor
                    : Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isOutline ? Colors.grey : Colors.white,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: isOutline ? color : Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isOutline
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, Map contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3F51B5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUTUH BANTUAN?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contact['company_name'] ?? 'PT. ISKOM SARANA NUSANTARA',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contact['address'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onLaunchWhatsApp(
                '0895384314416',
                'dashboard.dashboard_help_msg'.tr(context),
              ),
              icon: const Icon(Icons.chat, color: Colors.white, size: 18),
              label: Text(
                'dashboard.contact_via_wa'.tr(context),
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List products) {
    final String laptopBaseUrl = '${AppConstants.serverRoot}/uploads/products/';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.laptop_windows_rounded,
                size: 20, color: Color(0xFF7E57C2)),
            const SizedBox(width: 8),
            Text(
              'dashboard.available_products'.tr(context),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...products.map(
          (p) => InkWell(
            onTap: () => _showProductSpecs(context, p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: '$laptopBaseUrl${p['gambar']}',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.laptop,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['nama_laptop'] ?? 'Laptop',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${p['procesor'] ?? 'Core'} - ${p['ram'] ?? '8GB'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showProductSpecs(BuildContext context, Map p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl:
                                '${AppConstants.serverRoot}/uploads/products/${p['gambar']}',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['nama_laptop'] ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF7E57C2).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p['tipe_laptop'] ?? 'Notebook',
                                  style: const TextStyle(
                                    color: Color(0xFF7E57C2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildSpecRow(
                      context,
                      Icons.memory_rounded,
                      'Processor',
                      p['procesor'],
                    ),
                    _buildSpecRow(context, Icons.memory_rounded, 'RAM',
                        p['ram']),
                    _buildSpecRow(
                        context, Icons.storage_rounded, 'Storage', p['hdd']),
                    _buildSpecRow(
                        context, Icons.display_settings_rounded, 'VGA', p['vga']),
                    _buildSpecRow(
                        context, Icons.screenshot_rounded, 'Screen', p['layar']),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(
    BuildContext context,
    IconData icon,
    String label,
    String? value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                value ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
