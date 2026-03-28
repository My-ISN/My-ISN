import 'package:flutter/material.dart';
import '../../services/rent_plan_service.dart';
import 'rent_plan_detail_page.dart';
import 'add_rent_plan_page.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/side_drawer.dart';
import '../../localization/app_localizations.dart';

class RentPlanPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isTab;
  const RentPlanPage({super.key, required this.userData, this.isTab = false});

  @override
  State<RentPlanPage> createState() => _RentPlanPageState();
}

class _RentPlanPageState extends State<RentPlanPage> with SingleTickerProviderStateMixin {
  final RentPlanService _rentPlanService = RentPlanService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  List<dynamic> _rentals = [];
  Map<String, dynamic> _stats = {};
  String _currentStatus = 'all';
  int _currentPage = 1;
  int _selectedLimit = 10;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': 'Semua'},
    {'key': 'new', 'label': 'Baru'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'masalah', 'label': 'Masalah'},
    {'key': 'completed', 'label': 'Selesai'},
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
          SnackBar(content: Text(response['message'] ?? 'Gagal mengambil data')),
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
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : RefreshIndicator(
                  onRefresh: _fetchRentPlans,
                  color: _primaryColor,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
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
                        if (_totalCount > 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 80),
                            child: _buildPagination(),
                          );
                        } else {
                          return const SizedBox(height: 80);
                        }
                      }

                      final rental = _rentals[index - 1];
                      return _buildRentalCard(rental);
                    },
                  ),
                ),
          ),
        ],
      );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'rent_plan'),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRentPlanPage(userData: widget.userData),
            ),
          );
          if (result == true) {
            _fetchRentPlans();
          }
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: Text('rent_plan.add_rental'.tr(context), 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard('Total Masuk', _stats['total_masuk']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Aktiv (New)', _stats['new']?.toString() ?? '0', Colors.green),
          _buildStatCard('Masalah', _stats['masalah']?.toString() ?? '0', Colors.red),
          _buildStatCard('Selesai', _stats['completed']?.toString() ?? '0', Colors.grey),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
          onSubmitted: (value) {
            setState(() => _currentPage = 1);
            _fetchRentPlans();
          },
          onChanged: (value) {
            setState(() {}); // For suffix icon
          },
          decoration: InputDecoration(
            hintText: 'Cari Invoice atau Nama...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 20, color: Colors.grey),
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
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
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
        tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
      ),
    );
  }

  Widget _buildRentalCard(Map<String, dynamic> rental) {
    String clientName = '-';
    if (rental['first_name'] != null) {
      clientName = '${rental['first_name']} ${rental['last_name'] ?? ''}';
    } else if (rental['nama_pribadi'] != null && rental['nama_pribadi'] != '') {
      clientName = rental['nama_pribadi'];
    } else if (rental['nama_perusahaan'] != null && rental['nama_perusahaan'] != '') {
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
        daysLeft = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;
      } catch (_) {}
    }

    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final double totalHarga = double.tryParse(rental['grand_total']?.toString() ?? '0') ?? 0;

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
              MaterialPageRoute(builder: (context) => RentPlanDetailPage(rentalId: int.parse(rental['rental_id']), invoiceNumber: rental['invoice_number'])),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryColor),
                      ),
                    ),
                    _buildStatusPill(status, statusColor),
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
                      child: Icon(Icons.person_rounded, color: _primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sewa: ${rental['jenis_sewa'] ?? 'Pribadi'} • ${rental['total_laptop'] ?? 0} Unit',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Biaya', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(currencyFormat.format(totalHarga), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Sisa Waktu', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          daysLeft < 0 ? '${daysLeft.abs()} Hari Terlambat' : (daysLeft == 0 ? 'Hari Ini' : '$daysLeft Hari'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            color: daysLeft < 0 ? Colors.red : (daysLeft <= 3 ? Colors.orange : Colors.green)
                          ),
                        ),
                      ],
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
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new': return Colors.green;
      case 'pending': return Colors.orange;
      case 'masalah': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Tampilkan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
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
            '$_totalCount total',
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _primaryColor),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
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
          onPressed: _currentPage > 1 ? () {
            setState(() => _currentPage--);
            _fetchRentPlans();
          } : null,
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
            'Page $_currentPage of $totalPages',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < totalPages ? () {
            setState(() => _currentPage++);
            _fetchRentPlans();
          } : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? Colors.grey[200] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Icon(icon, color: onPressed == null ? Colors.grey[400] : _primaryColor, size: 24),
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
            'Tidak ada data rental',
            style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
