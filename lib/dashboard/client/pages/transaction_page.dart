import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants.dart';
import '../../../localization/app_localizations.dart';
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TransactionPage({super.key, required this.userData});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filters = [
    'unpaid',
    'waiting',
    'processed',
    'shipping',
    'arrived',
    'success',
    'failed'
  ];

  final Map<String, List<dynamic>> _transactionsByFilter = {};
  final Map<String, bool> _isLoadingByFilter = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Initial fetch
    _fetchTransactions(_filters[0]);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      String currentFilter = _filters[_tabController.index];
      if (!_transactionsByFilter.containsKey(currentFilter)) {
        _fetchTransactions(currentFilter);
      }
    }
  }

  Future<void> _fetchTransactions(String filter) async {
    setState(() => _isLoadingByFilter[filter] = true);

    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = '${AppConstants.baseUrl}/get_order_history?user_id=$userId&filter=$filter';
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        setState(() {
          _transactionsByFilter[filter] = data['data'];
          _isLoadingByFilter[filter] = false;
        });
      } else {
        setState(() => _isLoadingByFilter[filter] = false);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      setState(() => _isLoadingByFilter[filter] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'dashboard.my_transaction'.tr(context),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: _filters.map((f) => Tab(text: _getFilterLabel(f))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _filters.map((f) => _buildTransactionList(f)).toList(),
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all': return 'Semua';
      case 'unpaid': return 'Belum Bayar';
      case 'waiting': return 'Konfirmasi';
      case 'processed': return 'Proses';
      case 'shipping': return 'Dikirim';
      case 'arrived': return 'Tiba';
      case 'success': return 'Selesai';
      case 'failed': return 'Gagal';
      default: return filter;
    }
  }

  Widget _buildTransactionList(String filter) {
    final isLoading = _isLoadingByFilter[filter] ?? false;
    final transactions = _transactionsByFilter[filter] ?? [];

    if (isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Belum ada transaksi',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchTransactions(filter),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final item = transactions[index];
          return InkWell(
            onTap: () => _showTransactionDetails(item),
            borderRadius: BorderRadius.circular(12),
            child: _buildTransactionCard(item),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final items = (item['items'] as List? ?? []);
    final firstItem = items.isNotEmpty ? items[0] : null;
    final otherItemsCount = items.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['invoice_number'] ?? '#-',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                _buildStatusBadge(item),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    image: (firstItem != null && firstItem['image_url'] != null)
                        ? DecorationImage(
                            image: NetworkImage(firstItem['image_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (firstItem == null || firstItem['image_url'] == null)
                      ? const Icon(Icons.shopping_bag_outlined, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem?['nama_laptop'] ?? 'Produk',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (otherItemsCount > 0)
                        Text(
                          '+$otherItemsCount produk lainnya',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Pesanan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                          .format(double.tryParse(item['grand_total'].toString()) ?? 0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (item['status_pembayaran'] == 'belum')
                  ElevatedButton(
                    onPressed: () {
                      // Logic bayar
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Bayar Sekarang'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> item) {
    Color color = Colors.grey;
    String label = item['status_label'] ?? 'Diproses';

    switch (item['status_label']) {
      case 'Belum Bayar': color = Colors.orange; break;
      case 'Dikirim': color = Colors.blue; break;
      case 'Selesai': color = Colors.green; break;
      case 'Gagal': color = Colors.red; break;
      case 'Menunggu Konfirmasi': color = Colors.cyan; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> item) {
    final items = (item['items'] as List? ?? []);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Status & Order Number
                  _buildDetailSection(
                    title: 'Info Pesanan',
                    child: Column(
                      children: [
                        _buildDetailRow('Status', item['status_label'] ?? 'Diproses', isStatus: true, item: item),
                        _buildDetailRow('Nomor Invoice', item['invoice_number'] ?? '-'),
                        _buildDetailRow('Tanggal Transaksi', item['created_at'] != null 
                          ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at']))
                          : '-'),
                      ],
                    ),
                  ),
                  
                  // Product List
                  _buildDetailSection(
                    title: 'Daftar Produk',
                    child: Column(
                      children: items.map<Widget>((prod) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                                image: prod['image_url'] != null 
                                  ? DecorationImage(image: NetworkImage(prod['image_url']), fit: BoxFit.cover)
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod['nama_laptop'] ?? 'Produk',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${prod['quantity']} unit x ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(prod['unit_price'].toString()) ?? 0)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  
                  // Customer Info
                  _buildDetailSection(
                    title: 'Informasi Pelanggan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (widget.userData['email'] != null)
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(widget.userData['email'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        const SizedBox(height: 4),
                        if (widget.userData['contact_number'] != null)
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(widget.userData['contact_number'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // Shipping Address
                  _buildDetailSection(
                    title: 'Alamat Pengiriman',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipient Name
                        Text(
                          item['nama_lengkap'] ?? 
                          item['nama_pribadi'] ?? 
                          '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim() ?? 
                          'Penerima',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        
                        // Phone Number
                        if (item['whatsapp'] != null || item['emergency_contact_number'] != null || widget.userData['contact_number'] != null)
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                item['whatsapp'] ?? 
                                item['emergency_contact_number'] ?? 
                                widget.userData['contact_number'] ?? 
                                '-',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // Address
                        if (item['shipping_address'] != null && item['shipping_address'].toString().isNotEmpty)
                          Text(
                            item['shipping_address'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        
                        // Build complete address from location components
                        Builder(
                          builder: (context) {
                            final locationParts = [
                              item['shipping_village'] ?? '',
                              item['shipping_district'] ?? '',
                              item['shipping_city'] ?? item['regency_current_name'] ?? '',
                              item['shipping_state'] ?? item['province_current_name'] ?? '',
                              item['shipping_zipcode'] ?? item['zipcode'] ?? '',
                            ].where((part) => part != null && part.toString().isNotEmpty).toList();
                            
                            if (locationParts.isNotEmpty) {
                              return Text(
                                locationParts.join(', '),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        
                        // Show courier info if available
                        if (item['tipe_pengiriman'] != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('Kurir', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['tipe_pengiriman'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Payment Info
                  _buildDetailSection(
                    title: 'Rincian Pembayaran',
                    child: Column(
                      children: [
                        _buildDetailRow('Metode Pembayaran', item['payment_method']?.toString().toUpperCase() ?? 'TRANSFER'),
                        _buildDetailRow('Subtotal Produk', NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(item['subtotal_amount']?.toString() ?? '0') ?? 0)),
                        _buildDetailRow('Ongkos Kirim', NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(item['shipping_amount']?.toString() ?? item['biaya_kirim']?.toString() ?? '0') ?? 0)),
                        _buildDetailRow('Biaya Administratif', NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(item['admin_fee']?.toString() ?? '7000') ?? 7000)),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(double.tryParse(item['grand_total']?.toString() ?? '0') ?? 0),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: child,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, Map<String, dynamic>? item}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          isStatus && item != null
              ? _buildStatusBadge(item)
              : Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
