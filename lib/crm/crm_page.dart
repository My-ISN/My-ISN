import 'dart:async';
import 'package:flutter/material.dart';
import '../services/crm_service.dart';
import '../services/tracking_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';

class CrmPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int initialTabIndex;

  const CrmPage({
    super.key,
    required this.userData,
    this.initialTabIndex = 0,
  });

  @override
  State<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends State<CrmPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CrmService _crmService = CrmService();
  final Color _primaryColor = const Color(0xFF7E57C2);

  // --- LEADS STATE ---
  List<dynamic> _leads = [];
  Map<String, dynamic> _leadStats = {};
  List<dynamic> _categories = [];
  bool _isLoadingLeads = true;
  final TextEditingController _leadSearchController = TextEditingController();
  String _selectedLeadStatus = 'all';
  String _selectedLeadCategory = 'all';
  int _leadPage = 1;
  int _leadTotalPages = 1;

  // --- CUSTOMERS STATE ---
  List<dynamic> _customers = [];
  bool _isLoadingCustomers = true;
  final TextEditingController _customerSearchController = TextEditingController();
  String _selectedCustomerStatus = 'all';
  String _selectedCustomerType = 'all';
  int _customerPage = 1;
  int _customerTotalPages = 1;

  // --- COMPETITORS STATE ---
  List<dynamic> _competitors = [];
  bool _isLoadingCompetitors = true;
  final TextEditingController _competitorSearchController = TextEditingController();
  String _selectedCompetitorType = 'all';
  int _competitorPage = 1;
  int _competitorTotalPages = 1;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    try {
      TrackingService().logCurrentFeature('CRM');
    } catch (_) {}

    _fetchLeads();
    _fetchCustomers();
    _fetchCompetitors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leadSearchController.dispose();
    _customerSearchController.dispose();
    _competitorSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FETCH METHODS
  // ---------------------------------------------------------------------------
  Future<void> _fetchLeads({int page = 1}) async {
    setState(() => _isLoadingLeads = true);
    final result = await _crmService.getLeads(
      page: page,
      search: _leadSearchController.text.trim(),
      categoryId: _selectedLeadCategory,
      status: _selectedLeadStatus,
    );

    if (mounted) {
      setState(() {
        _isLoadingLeads = false;
        if (result['status'] == true) {
          _leads = result['data'] ?? [];
          _leadStats = result['stats'] ?? {};
          _categories = result['categories'] ?? [];
          _leadPage = result['pagination']?['page'] ?? 1;
          _leadTotalPages = result['pagination']?['total_pages'] ?? 1;
        }
      });
    }
  }

  Future<void> _fetchCustomers({int page = 1}) async {
    setState(() => _isLoadingCustomers = true);
    final result = await _crmService.getCustomers(
      page: page,
      search: _customerSearchController.text.trim(),
      customerType: _selectedCustomerType,
      status: _selectedCustomerStatus,
    );

    if (mounted) {
      setState(() {
        _isLoadingCustomers = false;
        if (result['status'] == true) {
          _customers = result['data'] ?? [];
          _customerPage = result['pagination']?['page'] ?? 1;
          _customerTotalPages = result['pagination']?['total_pages'] ?? 1;
        }
      });
    }
  }

  Future<void> _fetchCompetitors({int page = 1}) async {
    setState(() => _isLoadingCompetitors = true);
    final result = await _crmService.getCompetitors(
      page: page,
      search: _competitorSearchController.text.trim(),
      typeCategory: _selectedCompetitorType,
    );

    if (mounted) {
      setState(() {
        _isLoadingCompetitors = false;
        if (result['status'] == true) {
          _competitors = result['data'] ?? [];
          _competitorPage = result['pagination']?['page'] ?? 1;
          _competitorTotalPages = result['pagination']?['total_pages'] ?? 1;
        }
      });
    }
  }

  void _onSearchChanged(VoidCallback fetchFn) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), fetchFn);
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'crm',
      ),
      body: Column(
        children: [
          // Styled Tab Bar Container
          Container(
            color: isDark
                ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
                : theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              indicatorColor: _primaryColor,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _primaryColor,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.leaderboard_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('CRM Leads'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Pelanggan'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Kompetitor'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeadsTab(),
                _buildCustomersTab(),
                _buildCompetitorsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: CRM LEADS
  // ---------------------------------------------------------------------------
  Widget _buildLeadsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_lead',
        onPressed: () => _showLeadFormModal(),
        backgroundColor: _primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchLeads(page: 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              _buildLeadSummaryCards(),
              const SizedBox(height: 12),
              // Search Input
              _buildSearchBar(
                controller: _leadSearchController,
                hintText: 'Cari lead, nama, perusahaan, hp...',
                onChanged: () => _onSearchChanged(() => _fetchLeads(page: 1)),
              ),
              const SizedBox(height: 10),
              // Status Filters (Horizontal Pills)
              _buildLeadStatusPills(),
              const SizedBox(height: 12),
              // Leads List
              if (_isLoadingLeads)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_leads.isEmpty)
                _buildEmptyState('Belum ada data Lead.')
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _leads.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildLeadCard(_leads[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaginationControls(
                  currentPage: _leadPage,
                  totalPages: _leadTotalPages,
                  onPageChanged: (p) => _fetchLeads(page: p),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadSummaryCards() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildStatCard('Total Lead', _leadStats['total_leads'] ?? 0, const Color(0xFF6A11CB), Icons.trending_up_rounded),
          _buildStatCard('Lead Baru', _leadStats['new_leads'] ?? 0, Colors.orange, Icons.fiber_new_rounded),
          _buildStatCard('Followup Hari Ini', _leadStats['today_followups'] ?? 0, Colors.blue, Icons.today_rounded),
          _buildStatCard('Deal', _leadStats['deal_leads'] ?? 0, Colors.green, Icons.check_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic count, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0, end: double.parse(count.toString())),
                curve: Curves.easeOutExpo,
                builder: (context, value, child) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadStatusPills() {
    final statuses = [
      {'key': 'all', 'label': 'Semua Status'},
      {'key': 'Lead Baru', 'label': 'Lead Baru'},
      {'key': 'Prospek', 'label': 'Prospek'},
      {'key': 'Penawaran', 'label': 'Penawaran'},
      {'key': 'Negosiasi', 'label': 'Negosiasi'},
      {'key': 'Deal', 'label': 'Deal'},
      {'key': 'Loss', 'label': 'Loss'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final item = statuses[index];
          final isSelected = _selectedLeadStatus == item['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text(item['label']!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
              selectedColor: _primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              elevation: isSelected ? 2 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                setState(() => _selectedLeadStatus = item['key']!);
                _fetchLeads(page: 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = item['status'] ?? 'Lead Baru';
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7E57C2).withValues(alpha: 0.04) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLeadDetailModal(int.parse(item['lead_id'].toString())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: _primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['client_name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if ((item['company_name'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item['company_name'],
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if ((item['contact_number'] ?? '').isNotEmpty) ...[
                      Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(item['contact_number'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                    ],
                    if ((item['city'] ?? '').isNotEmpty) ...[
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(item['city'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                    const Spacer(),
                    if ((item['category_name'] ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['category_name'],
                          style: TextStyle(fontSize: 10, color: _primaryColor, fontWeight: FontWeight.w600),
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

  // ---------------------------------------------------------------------------
  // TAB 2: CRM CUSTOMERS
  // ---------------------------------------------------------------------------
  Widget _buildCustomersTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_customer',
        onPressed: () => _showCustomerFormModal(),
        backgroundColor: _primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Pelanggan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchCustomers(page: 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(
                controller: _customerSearchController,
                hintText: 'Cari pelanggan, perusahaan, hp, kota...',
                onChanged: () => _onSearchChanged(() => _fetchCustomers(page: 1)),
              ),
              const SizedBox(height: 10),
              _buildCustomerTypePills(),
              const SizedBox(height: 12),
              if (_isLoadingCustomers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_customers.isEmpty)
                _buildEmptyState('Belum ada data Pelanggan.')
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _customers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildCustomerCard(_customers[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaginationControls(
                  currentPage: _customerPage,
                  totalPages: _customerTotalPages,
                  onPageChanged: (p) => _fetchCustomers(page: p),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerTypePills() {
    final types = [
      {'key': 'all', 'label': 'Semua Tipe'},
      {'key': 'Customer Baru', 'label': 'Customer Baru'},
      {'key': 'Customer Reguler', 'label': 'Customer Reguler'},
      {'key': 'Customer VIP', 'label': 'Customer VIP'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final item = types[index];
          final isSelected = _selectedCustomerType == item['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text(item['label']!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
              selectedColor: _primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              elevation: isSelected ? 2 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                setState(() => _selectedCustomerType = item['key']!);
                _fetchCustomers(page: 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = item['status'] ?? 'Active';
    final type = item['customer_type'] ?? 'Customer Baru';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7E57C2).withValues(alpha: 0.04) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCustomerDetailModal(int.parse(item['customer_id'].toString())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_outlined, color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['client_name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if ((item['company_name'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item['company_name'],
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (status == 'Active' ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'Active' ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    if ((item['contact_number'] ?? '').isNotEmpty) ...[
                      Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(item['contact_number'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: CRM COMPETITORS / PARTNERS
  // ---------------------------------------------------------------------------
  Widget _buildCompetitorsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_competitor',
        onPressed: () => _showCompetitorFormModal(),
        backgroundColor: _primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Kompetitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchCompetitors(page: 1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(
                controller: _competitorSearchController,
                hintText: 'Cari nama, bidang usaha, kota...',
                onChanged: () => _onSearchChanged(() => _fetchCompetitors(page: 1)),
              ),
              const SizedBox(height: 10),
              _buildCompetitorTypePills(),
              const SizedBox(height: 12),
              if (_isLoadingCompetitors)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_competitors.isEmpty)
                _buildEmptyState('Belum ada data Kompetitor / Mitra.')
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _competitors.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildCompetitorCard(_competitors[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaginationControls(
                  currentPage: _competitorPage,
                  totalPages: _competitorTotalPages,
                  onPageChanged: (p) => _fetchCompetitors(page: p),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompetitorTypePills() {
    final types = [
      {'key': 'all', 'label': 'Semua Tipe'},
      {'key': 'kompetitor', 'label': 'Kompetitor'},
      {'key': 'partner', 'label': 'Partner / Mitra'},
      {'key': 'prospek', 'label': 'Prospek'},
      {'key': 'customer', 'label': 'Customer Base'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final item = types[index];
          final isSelected = _selectedCompetitorType == item['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text(item['label']!, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
              selectedColor: _primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              elevation: isSelected ? 2 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                setState(() => _selectedCompetitorType = item['key']!);
                _fetchCompetitors(page: 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompetitorCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = item['type_category'] ?? 'kompetitor';
    final rating = item['google_rating']?.toString() ?? '0.0';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7E57C2).withValues(alpha: 0.04) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCompetitorDetailModal(int.parse(item['competitor_id'].toString())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getCompetitorTypeColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.storefront_outlined, color: _getCompetitorTypeColor(type), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if ((item['business_category'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item['business_category'],
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCompetitorTypeColor(type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: _getCompetitorTypeColor(type),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if ((item['city'] ?? '').isNotEmpty) ...[
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(item['city'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                    ],
                    if (double.tryParse(rating) != null && double.parse(rating) > 0) ...[
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMON SEARCH BAR WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7E57C2).withValues(alpha: 0.04) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: InputBorder.none,
          ),
          onChanged: (val) => onChanged(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODALS & FORMS
  // ---------------------------------------------------------------------------
  void _showLeadFormModal([Map<String, dynamic>? lead]) {
    final isEdit = lead != null;
    final clientNameCtrl = TextEditingController(text: lead?['client_name'] ?? '');
    final companyNameCtrl = TextEditingController(text: lead?['company_name'] ?? '');
    final contactCtrl = TextEditingController(text: lead?['contact_number'] ?? '');
    final emailCtrl = TextEditingController(text: lead?['email'] ?? '');
    final cityCtrl = TextEditingController(text: lead?['city'] ?? '');
    final addressCtrl = TextEditingController(text: lead?['address'] ?? '');
    final notesCtrl = TextEditingController(text: lead?['notes'] ?? '');
    String selectedStatus = lead?['status'] ?? 'Lead Baru';
    String? selectedCategory = lead?['category_id']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(modalContext).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit ? 'Edit Lead' : 'Tambah Lead Baru',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: clientNameCtrl, decoration: const InputDecoration(labelText: 'Nama Klien *')),
                  const SizedBox(height: 12),
                  TextField(controller: companyNameCtrl, decoration: const InputDecoration(labelText: 'Nama Perusahaan')),
                  const SizedBox(height: 12),
                  TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'No. HP / WhatsApp')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Kota')),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status Lead'),
                    items: const [
                      DropdownMenuItem(value: 'Lead Baru', child: Text('Lead Baru')),
                      DropdownMenuItem(value: 'Prospek', child: Text('Prospek')),
                      DropdownMenuItem(value: 'Penawaran', child: Text('Penawaran')),
                      DropdownMenuItem(value: 'Negosiasi', child: Text('Negosiasi')),
                      DropdownMenuItem(value: 'Deal', child: Text('Deal')),
                      DropdownMenuItem(value: 'Loss', child: Text('Loss')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c['category_id'].toString(),
                      child: Text(c['name'] ?? ''),
                    )).toList(),
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (clientNameCtrl.text.trim().isEmpty) {
                          if (mounted) context.showWarningSnackBar('Nama Klien wajib diisi.');
                          return;
                        }
                        final res = await _crmService.saveLead({
                          if (isEdit) 'lead_id': lead['lead_id'].toString(),
                          'client_name': clientNameCtrl.text.trim(),
                          'company_name': companyNameCtrl.text.trim(),
                          'contact_number': contactCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'status': selectedStatus,
                          'category_id': selectedCategory ?? '0',
                          'notes': notesCtrl.text.trim(),
                        });
                        if (mounted) {
                          Navigator.pop(modalContext);
                          if (res['status'] == true) {
                            context.showSuccessSnackBar(res['message'] ?? 'Berhasil!');
                            _fetchLeads();
                          } else {
                            context.showErrorSnackBar(res['message'] ?? 'Gagal!');
                          }
                        }
                      },
                      child: Text(isEdit ? 'Update Lead' : 'Simpan Lead', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLeadDetailModal(int leadId) async {
    final detail = await _crmService.getLeadDetail(leadId);
    if (!mounted || detail['status'] != true) return;
    final lead = detail['lead'];
    final followups = List<Map<String, dynamic>>.from(detail['followups'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(modalContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(lead['client_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _showLeadFormModal(lead);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () async {
                    final confirm = await _showConfirmDialog('Hapus Lead', 'Yakin menghapus lead ini?');
                    if (confirm == true) {
                      final res = await _crmService.deleteLead(leadId);
                      if (mounted) {
                        Navigator.pop(modalContext);
                        if (res['status'] == true) {
                          context.showSuccessSnackBar('Lead dihapus.');
                          _fetchLeads();
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailRow('Perusahaan', lead['company_name']),
                  _buildDetailRow('Telepon / WA', lead['contact_number']),
                  _buildDetailRow('Email', lead['email']),
                  _buildDetailRow('Kota', lead['city']),
                  _buildDetailRow('Status', lead['status']),
                  _buildDetailRow('Kategori', lead['category_name']),
                  _buildDetailRow('Catatan', lead['notes']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Riwayat Follow Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Follow Up'),
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _showAddLeadFollowupModal(leadId);
                        },
                      ),
                    ],
                  ),
                  if (followups.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada riwayat follow up.', style: TextStyle(color: Colors.grey)))
                  else
                    ...followups.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f['followup_notes'] ?? '', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '${f['first_name'] ?? 'Staff'} • ${f['followup_date'] ?? ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLeadFollowupModal(int leadId) {
    final notesCtrl = TextEditingController();
    String? newStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: Theme.of(modalContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Follow Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan Follow Up *')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Update Status (Opsional)'),
              items: const [
                DropdownMenuItem(value: 'Lead Baru', child: Text('Lead Baru')),
                DropdownMenuItem(value: 'Prospek', child: Text('Prospek')),
                DropdownMenuItem(value: 'Penawaran', child: Text('Penawaran')),
                DropdownMenuItem(value: 'Negosiasi', child: Text('Negosiasi')),
                DropdownMenuItem(value: 'Deal', child: Text('Deal')),
                DropdownMenuItem(value: 'Loss', child: Text('Loss')),
              ],
              onChanged: (val) => newStatus = val,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  if (notesCtrl.text.trim().isEmpty) return;
                  final res = await _crmService.addLeadFollowup(
                    leadId: leadId,
                    followupNotes: notesCtrl.text.trim(),
                    newStatus: newStatus,
                  );
                  if (mounted) {
                    Navigator.pop(modalContext);
                    if (res['status'] == true) {
                      context.showSuccessSnackBar('Followup disimpan!');
                      _fetchLeads();
                    }
                  }
                },
                child: const Text('Simpan Follow Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CUSTOMER FORM & DETAILS ---
  void _showCustomerFormModal([Map<String, dynamic>? cust]) {
    final isEdit = cust != null;
    final clientNameCtrl = TextEditingController(text: cust?['client_name'] ?? '');
    final companyNameCtrl = TextEditingController(text: cust?['company_name'] ?? '');
    final contactCtrl = TextEditingController(text: cust?['contact_number'] ?? '');
    final emailCtrl = TextEditingController(text: cust?['email'] ?? '');
    final cityCtrl = TextEditingController(text: cust?['city'] ?? '');
    final addressCtrl = TextEditingController(text: cust?['address'] ?? '');
    final notesCtrl = TextEditingController(text: cust?['notes'] ?? '');
    String selectedType = cust?['customer_type'] ?? 'Customer Baru';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          height: MediaQuery.of(modalContext).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(modalContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: clientNameCtrl, decoration: const InputDecoration(labelText: 'Nama Klien *')),
                const SizedBox(height: 12),
                TextField(controller: companyNameCtrl, decoration: const InputDecoration(labelText: 'Perusahaan')),
                const SizedBox(height: 12),
                TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'No. HP / WhatsApp')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Kota')),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe Pelanggan'),
                  items: const [
                    DropdownMenuItem(value: 'Customer Baru', child: Text('Customer Baru')),
                    DropdownMenuItem(value: 'Customer Reguler', child: Text('Customer Reguler')),
                    DropdownMenuItem(value: 'Customer VIP', child: Text('Customer VIP')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan')),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (clientNameCtrl.text.trim().isEmpty) return;
                      final res = await _crmService.saveCustomer({
                        if (isEdit) 'customer_id': cust['customer_id'].toString(),
                        'client_name': clientNameCtrl.text.trim(),
                        'company_name': companyNameCtrl.text.trim(),
                        'contact_number': contactCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'customer_type': selectedType,
                        'notes': notesCtrl.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(modalContext);
                        if (res['status'] == true) {
                          context.showSuccessSnackBar(res['message'] ?? 'Berhasil!');
                          _fetchCustomers();
                        }
                      }
                    },
                    child: Text(isEdit ? 'Update Pelanggan' : 'Simpan Pelanggan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomerDetailModal(int customerId) async {
    final detail = await _crmService.getCustomerDetail(customerId);
    if (!mounted || detail['status'] != true) return;
    final cust = detail['customer'];
    final followups = List<Map<String, dynamic>>.from(detail['followups'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(modalContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(cust['client_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _showCustomerFormModal(cust);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () async {
                    final confirm = await _showConfirmDialog('Hapus Pelanggan', 'Yakin menghapus pelanggan ini?');
                    if (confirm == true) {
                      final res = await _crmService.deleteCustomer(customerId);
                      if (mounted) {
                        Navigator.pop(modalContext);
                        if (res['status'] == true) {
                          context.showSuccessSnackBar('Pelanggan dihapus.');
                          _fetchCustomers();
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailRow('Perusahaan', cust['company_name']),
                  _buildDetailRow('Telepon', cust['contact_number']),
                  _buildDetailRow('Email', cust['email']),
                  _buildDetailRow('Tipe', cust['customer_type']),
                  _buildDetailRow('Kota', cust['city']),
                  _buildDetailRow('Alamat', cust['address']),
                  _buildDetailRow('Catatan', cust['notes']),
                  const SizedBox(height: 16),
                  const Text('Riwayat Follow Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (followups.isEmpty)
                    const Text('Belum ada riwayat follow up.', style: TextStyle(color: Colors.grey))
                  else
                    ...followups.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f['followup_notes'] ?? '', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${f['first_name'] ?? 'Staff'} • ${f['followup_date'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPETITOR FORM & DETAILS ---
  void _showCompetitorFormModal([Map<String, dynamic>? comp]) {
    final isEdit = comp != null;
    final nameCtrl = TextEditingController(text: comp?['name'] ?? '');
    final categoryCtrl = TextEditingController(text: comp?['business_category'] ?? '');
    final cityCtrl = TextEditingController(text: comp?['city'] ?? '');
    final addressCtrl = TextEditingController(text: comp?['address'] ?? '');
    final descCtrl = TextEditingController(text: comp?['description'] ?? '');
    final waCtrl = TextEditingController(text: comp?['whatsapp'] ?? '');
    final websiteCtrl = TextEditingController(text: comp?['website'] ?? '');
    String selectedType = comp?['type_category'] ?? 'kompetitor';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          height: MediaQuery.of(modalContext).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(modalContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Data Kompetitor' : 'Tambah Kompetitor / Partner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Kompetitor / Partner *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe Data'),
                  items: const [
                    DropdownMenuItem(value: 'kompetitor', child: Text('Kompetitor')),
                    DropdownMenuItem(value: 'partner', child: Text('Partner / Mitra')),
                    DropdownMenuItem(value: 'prospek', child: Text('Prospek')),
                    DropdownMenuItem(value: 'customer', child: Text('Customer Base')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Bidang Usaha')),
                const SizedBox(height: 12),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Kota')),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat')),
                const SizedBox(height: 12),
                TextField(controller: waCtrl, decoration: const InputDecoration(labelText: 'WhatsApp')),
                const SizedBox(height: 12),
                TextField(controller: websiteCtrl, decoration: const InputDecoration(labelText: 'Website')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi / Observasi')),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final res = await _crmService.saveCompetitor({
                        if (isEdit) 'competitor_id': comp['competitor_id'].toString(),
                        'name': nameCtrl.text.trim(),
                        'type_category': selectedType,
                        'business_category': categoryCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'whatsapp': waCtrl.text.trim(),
                        'website': websiteCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(modalContext);
                        if (res['status'] == true) {
                          context.showSuccessSnackBar(res['message'] ?? 'Berhasil!');
                          _fetchCompetitors();
                        }
                      }
                    },
                    child: Text(isEdit ? 'Update Data' : 'Simpan Data', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCompetitorDetailModal(int competitorId) async {
    final detail = await _crmService.getCompetitorDetail(competitorId);
    if (!mounted || detail['status'] != true) return;
    final comp = detail['competitor'];
    final logs = List<Map<String, dynamic>>.from(detail['logs'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(modalContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(comp['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _showCompetitorFormModal(comp);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () async {
                    final confirm = await _showConfirmDialog('Hapus Competitor', 'Yakin menghapus data ini?');
                    if (confirm == true) {
                      final res = await _crmService.deleteCompetitor(competitorId);
                      if (mounted) {
                        Navigator.pop(modalContext);
                        if (res['status'] == true) {
                          context.showSuccessSnackBar('Data dihapus.');
                          _fetchCompetitors();
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailRow('Tipe Data', (comp['type_category'] ?? '').toString().toUpperCase()),
                  _buildDetailRow('Bidang Usaha', comp['business_category']),
                  _buildDetailRow('Kota', comp['city']),
                  _buildDetailRow('Alamat', comp['address']),
                  _buildDetailRow('WhatsApp', comp['whatsapp']),
                  _buildDetailRow('Website', comp['website']),
                  _buildDetailRow('Deskripsi', comp['description']),
                  const SizedBox(height: 16),
                  const Text('Log Aktivitas / Observasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    const Text('Belum ada log observasi.', style: TextStyle(color: Colors.grey))
                  else
                    ...logs.map((l) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l['action_type']} - ${l['notes'] ?? ''}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${l['first_name'] ?? 'User'} • ${l['created_at'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls({required int currentPage, required int totalPages, required Function(int) onPageChanged}) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        ),
        Text('Halaman $currentPage dari $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Lead Baru':
        return Colors.orange;
      case 'Prospek':
        return Colors.blue;
      case 'Penawaran':
        return Colors.purple;
      case 'Negosiasi':
        return Colors.indigo;
      case 'Deal':
        return Colors.green;
      case 'Loss':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCompetitorTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'kompetitor':
        return Colors.red;
      case 'partner':
        return Colors.green;
      case 'prospek':
        return Colors.orange;
      case 'customer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
