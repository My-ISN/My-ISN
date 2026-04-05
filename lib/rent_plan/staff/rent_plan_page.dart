import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/rent_plan_service.dart';
import 'rent_plan_detail_page.dart';
import 'add_rent_plan_page.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_app_bar.dart';

import '../../widgets/side_drawer.dart';
import '../../localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class RentPlanPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isTab;
  const RentPlanPage({super.key, required this.userData, this.isTab = false});

  @override
  State<RentPlanPage> createState() => _RentPlanPageState();
}

class _RentPlanPageState extends State<RentPlanPage>
    with SingleTickerProviderStateMixin {
  final RentPlanService _rentPlanService = RentPlanService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  List<dynamic> _rentals = [];
  Map<String, dynamic> _stats = {};
  String _currentStatus = 'new';
  int _currentPage = 1;
  int _selectedLimit = 10;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  final List<Map<String, String>> _tabs = [
    {'key': 'new', 'label': 'rent_plan.filter.new'},
    {'key': 'pending', 'label': 'rent_plan.filter.pending'},
    {'key': 'masalah', 'label': 'rent_plan.filter.problem'},
    {'key': 'completed', 'label': 'rent_plan.filter.completed'},
  ];

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentStatus = _tabs[_tabController.index]['key']!;
          _currentPage = 1; // Reset to first page on tab change
          _fetchRentPlans();
        });
      }
    });
    _fetchRentPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool _hasPermission(String key) {
    if (widget.userData['user_type'] == 'company') return true;
    final List<String> permissions = (widget.userData['role_resources'] ?? '')
        .toString()
        .split(',');
    return permissions.contains(key);
  }

  void _showDeleteConfirmation(int rentalId) {
    if (!_hasPermission('mobile_rent_plan_delete')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('main.unauthorized_module'.tr(context)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'rent_plan.delete_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'rent_plan.delete_confirm_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performDelete(rentalId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.delete'.tr(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPaymentModal(Map<String, dynamic> rental) {
    String selectedMethod = 'transfer'; // 'transfer' or 'cash'
    String? selectedBank;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          const Color primaryPurple = Color(0xFF7E57C2);

          Future<void> handlePayment() async {
            debugPrint(
              'Payment button clicked. Method: $selectedMethod, Bank: $selectedBank',
            );
            if (isProcessing) return;

            if (selectedMethod == 'transfer' && selectedBank == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Silakan pilih bank terlebih dahulu'),
                ),
              );
              return;
            }

            setSheetState(() => isProcessing = true);

            try {
              final result = await _rentPlanService.processPayment(
                int.parse(rental['rental_id'].toString()),
                selectedMethod,
                subMethod: selectedBank,
              );

              if (result['status'] == true) {
                if (selectedMethod == 'transfer') {
                  final url = Uri.parse(result['data']['payment_url']);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                    if (mounted) Navigator.pop(context);
                  } else {
                    throw 'Tidak dapat membuka link pembayaran';
                  }
                } else {
                  // Cash success
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ??
                              'Pembayaran berhasil dikonfirmasi',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchRentPlans(); // Refresh the list
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ?? 'Gagal memproses pembayaran',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (mounted) setSheetState(() => isProcessing = false);
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header (Purple Gradient)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryPurple, Color(0xFF9575CD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payment_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Buat Link Pembayaran Flip',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Method Selection
                        Row(
                          children: [
                            // Transfer / QRIS
                            Expanded(
                              child: _buildPaymentMethodCard(
                                title: 'Transfer / QRIS',
                                subtitle: 'Virtual Account (BCA, Mandiri, dll)',
                                isActive: selectedMethod == 'transfer',
                                onTap: () => setSheetState(
                                  () => selectedMethod = 'transfer',
                                ),
                                icon: Icons.account_balance_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Tunai (Cash)
                            Expanded(
                              child: _buildPaymentMethodCard(
                                title: 'Tunai (Cash)',
                                subtitle: 'Titip ke Kurir saat laptop sampai',
                                isActive: selectedMethod == 'cash',
                                onTap: () => setSheetState(
                                  () => selectedMethod = 'cash',
                                ),
                                icon: Icons.money_rounded,
                              ),
                            ),
                          ],
                        ),

                        if (selectedMethod == 'transfer') ...[
                          const SizedBox(height: 24),
                          const Text(
                            'PILIH BANK / E-WALLET',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bank Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              _buildBankItem(
                                'Bank BCA',
                                Icons.account_balance,
                                selectedBank == 'bca',
                                () => setSheetState(() => selectedBank = 'bca'),
                              ),
                              _buildBankItem(
                                'Bank Mandiri',
                                Icons.account_balance,
                                selectedBank == 'mandiri',
                                () => setSheetState(
                                  () => selectedBank = 'mandiri',
                                ),
                              ),
                              _buildBankItem(
                                'Bank BNI',
                                Icons.account_balance,
                                selectedBank == 'bni',
                                () => setSheetState(() => selectedBank = 'bni'),
                              ),
                              _buildBankItem(
                                'Bank BRI',
                                Icons.account_balance,
                                selectedBank == 'bri',
                                () => setSheetState(() => selectedBank = 'bri'),
                              ),
                              _buildBankItem(
                                'QRIS (Semua)',
                                Icons.qr_code_scanner_rounded,
                                selectedBank == 'qris',
                                () =>
                                    setSheetState(() => selectedBank = 'qris'),
                              ),
                              _buildBankItem(
                                'GoPay / Dana',
                                Icons.account_balance_wallet_rounded,
                                selectedBank == 'ewallet',
                                () => setSheetState(
                                  () => selectedBank = 'ewallet',
                                ),
                              ),
                              _buildBankItem(
                                'ShopeePay',
                                Icons.account_balance_wallet_rounded,
                                selectedBank == 'shopeepay',
                                () => setSheetState(
                                  () => selectedBank = 'shopeepay',
                                ),
                              ),
                              _buildBankItem(
                                'Kartu Kredit',
                                Icons.credit_card_rounded,
                                selectedBank == 'cc',
                                () => setSheetState(() => selectedBank = 'cc'),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 32),

                        // WhatsApp Info
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_iphone_rounded,
                              color: primaryPurple,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rental['whatsapp'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green[600],
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'WhatsApp Aktif',
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: primaryPurple.withOpacity(0.5),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Link dibuat via Flip for Business — aman & realtime',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => handlePayment(),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  selectedMethod == 'transfer'
                                      ? Icons.link_rounded
                                      : Icons.check_circle_rounded,
                                ),
                          label: Text(
                            isProcessing
                                ? (selectedMethod == 'transfer'
                                      ? 'Menyiapkan Link...'
                                      : 'Memproses...')
                                : (selectedMethod == 'transfer'
                                      ? 'Buat & Kirim Link Bayar'
                                      : 'Konfirmasi Bayar Tunai'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: isProcessing ? 0 : 8,
                            shadowColor: primaryPurple.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    const Color primaryPurple = Color(0xFF7E57C2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? primaryPurple.withOpacity(0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? primaryPurple : Colors.grey.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primaryPurple.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isActive ? primaryPurple : Colors.grey,
                  size: 22,
                ),
                Icon(
                  icon,
                  color: isActive ? primaryPurple : Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isActive ? primaryPurple : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankItem(
    String name,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    const Color primaryPurple = Color(0xFF7E57C2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? primaryPurple.withOpacity(0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? primaryPurple : Colors.grey.withOpacity(0.15),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? primaryPurple : Colors.indigo[300],
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? primaryPurple : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performDelete(int rentalId) async {
    setState(() => _isLoading = true);
    final response = await _rentPlanService.deleteRentPlan(rentalId);
    if (response['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('rent_plan.delete_success'.tr(context)),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchRentPlans();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    response['message'] ??
                        'rent_plan.delete_failed'.tr(context),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchRentPlans() async {
    setState(() => _isLoading = true);
    final response = await _rentPlanService.getRentPlans(
      status: _currentStatus,
      search: _searchController.text,
      limit: _selectedLimit,
      offset: (_currentPage - 1) * _selectedLimit,
    );
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _rentals = response['data'];
          _stats = response['stats'];
          _totalCount = response['total_count'] ?? 0;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'rent_plan.failed_fetch'.tr(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        _buildHeaderStats(),
        _buildPremiumSearchBar(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(
              _tabs.length,
              (index) => _buildRentalList(),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.isTab
          ? null
          : CustomAppBar(userData: widget.userData, showBackButton: false),
      endDrawer: widget.isTab
          ? null
          : SideDrawer(userData: widget.userData, activePage: 'rent_plan'),
      body: content,
      floatingActionButton: _hasPermission('mobile_rent_plan_add')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddRentPlanPage(userData: widget.userData),
                  ),
                );
                if (result == true) {
                  _fetchRentPlans();
                }
              },
              backgroundColor: _primaryColor,
              icon: const Icon(
                Icons.add_shopping_cart_rounded,
                color: Colors.white,
              ),
              label: Text(
                'rent_plan.add_rental'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRentalList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchRentPlans,
            color: _primaryColor,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _rentals.isEmpty ? 2 : _rentals.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildListHeader(),
                  );
                }

                if (_rentals.isEmpty) {
                  return _buildEmptyState();
                }

                if (index == _rentals.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    child: _totalCount > 0
                        ? _buildPagination()
                        : const SizedBox.shrink(),
                  );
                }

                final rental = _rentals[index - 1];
                return _buildRentalCard(rental);
              },
            ),
          );
  }

  Widget _buildHeaderStats() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard(
            'rent_plan.stats.new'.tr(context),
            _stats['new']?.toString() ?? '0',
            Colors.green,
          ),
          _buildStatCard(
            'rent_plan.stats.pending'.tr(context),
            _stats['pending']?.toString() ?? '0',
            Colors.orange,
          ),
          _buildStatCard(
            'rent_plan.stats.problem'.tr(context),
            _stats['masalah']?.toString() ?? '0',
            Colors.red,
          ),
          _buildStatCard(
            'rent_plan.stats.completed'.tr(context),
            _stats['completed']?.toString() ?? '0',
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() => _currentPage = 1);
                _fetchRentPlans();
              }
            });
            setState(() {}); // For suffix icon
          },
          decoration: InputDecoration(
            hintText: 'rent_plan.search_hint'.tr(context),
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _currentPage = 1;
                      });
                      _fetchRentPlans();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: _tabs.map((tab) => Tab(text: tab['label']!.tr(context))).toList(),
      ),
    );
  }

  Widget _buildRentalCard(Map<String, dynamic> rental) {
    String clientName = '-';
    if (rental['first_name'] != null) {
      clientName = '${rental['first_name']} ${rental['last_name'] ?? ''}';
    } else if (rental['nama_pribadi'] != null && rental['nama_pribadi'] != '') {
      clientName = rental['nama_pribadi'];
    } else if (rental['nama_perusahaan'] != null &&
        rental['nama_perusahaan'] != '') {
      clientName = rental['nama_perusahaan'];
    }

    final String status = rental['status'] ?? 'new';
    final Color statusColor = _getStatusColor(status);
    final String dueDateStr = rental['invoice_due_date'] ?? '';

    int daysLeft = 0;
    if (dueDateStr.isNotEmpty) {
      try {
        final dueDate = DateTime.parse(dueDateStr);
        final today = DateTime.now();
        daysLeft = dueDate
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
      } catch (_) {}
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final double totalHarga =
        double.tryParse(rental['grand_total']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RentPlanDetailPage(
                  rentalId: int.parse(rental['rental_id']),
                  invoiceNumber: rental['invoice_number'],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rental['invoice_number'] ?? '#NO-INV',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                    _buildStatusPill(status, statusColor),
                    if (status.toLowerCase() != 'completed') ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showPaymentModal(rental),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E57C2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.payment_rounded,
                              color: Color(0xFF7E57C2),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_hasPermission('mobile_rent_plan_delete')) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showDeleteConfirmation(
                            int.parse(rental['rental_id']),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: _primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'rent_plan.rental_type_laptop_count'.tr(
                              context,
                              args: {
                                'type':
                                    (rental['jenis_sewa'] ?? 'pribadi')
                                            .toString()
                                            .toLowerCase() ==
                                        'perusahaan'
                                    ? 'rent_plan.company'.tr(context)
                                    : 'rent_plan.personal'.tr(context),
                                'count': (rental['total_laptop'] ?? 0)
                                    .toString(),
                              },
                            ),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'rent_plan.total_cost'.tr(context),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(totalHarga),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'rent_plan.time_remaining'.tr(context),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            daysLeft < 0
                                ? 'rent_plan.days_late'.tr(
                                    context,
                                    args: {'days': daysLeft.abs().toString()},
                                  )
                                : (daysLeft == 0
                                      ? 'rent_plan.today'.tr(context)
                                      : 'rent_plan.days_left'.tr(
                                          context,
                                          args: {'days': daysLeft.toString()},
                                        )),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: daysLeft < 0
                                  ? Colors.red
                                  : (daysLeft <= 3
                                        ? Colors.orange
                                        : Colors.green),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _getRentalStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getRentalStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'rent_plan.status_new'.tr(context);
      case 'pending':
        return 'rent_plan.status_pending'.tr(context);
      case 'confirmed':
        return 'rent_plan.status_active'.tr(context);
      case 'masalah':
        return 'rent_plan.status_problem'.tr(context);
      case 'completed':
        return 'rent_plan.status_completed'.tr(context);
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'masalah':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'rent_plan.show'.tr(context),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            _buildPremiumDropdown(),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'rent_plan.total_count'.tr(
              context,
              args: {'count': _totalCount.toString()},
            ),
            style: TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: _primaryColor,
          ),
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchRentPlans();
            }
          },
          items: _limitOptions.map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    int totalPages = (_totalCount / _selectedLimit).ceil();
    if (totalPages <= 0) totalPages = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1
              ? () {
                  setState(() => _currentPage--);
                  _fetchRentPlans();
                }
              : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'rent_plan.page_x_of_y'.tr(
              context,
              args: {
                'current': _currentPage.toString(),
                'total': totalPages.toString(),
              },
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() => _currentPage++);
                  _fetchRentPlans();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: onPressed == null
          ? (isDark ? Colors.white12 : Colors.grey[200])
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? (isDark ? Colors.white24 : Colors.grey[400])
                : _primaryColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'rent_plan.empty_data'.tr(context),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
