import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/cart_provider.dart';
import '../../../constants.dart';
import '../../../localization/app_localizations.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/rent_plan_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../widgets/searchable_dropdown.dart';

class PurchaseCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<CartItem> items;

  const PurchaseCheckoutPage({
    super.key,
    required this.userData,
    required this.items,
  });

  @override
  State<PurchaseCheckoutPage> createState() => _PurchaseCheckoutPageState();
}

class _PurchaseCheckoutPageState extends State<PurchaseCheckoutPage> {
  final RentPlanService _paymentService = RentPlanService();
  bool _isSubmitting = false;
  String? _selectedPaymentMethod = 'transfer'; // flip

  // Address controllers & state
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _zipController;
  
  List<dynamic> _provinces = [];
  List<dynamic> _regencies = [];
  List<dynamic> _districts = [];
  List<dynamic> _villages = [];
  
  String? _selectedProvince, _selectedRegency, _selectedDistrict, _selectedVillage;
  bool _isAddressIncomplete = false;
  bool _isLoadingWilayah = false;
  bool _isEditingAddress = false;

  // Shipping state
  List<dynamic> _shippingCosts = [];
  String? _selectedShippingId;
  int _shippingCostAmount = 0;
  String _tipePengiriman = '';

  @override
  void initState() {
    super.initState();
    _address1Controller = TextEditingController(text: widget.userData['address_1'] ?? '');
    _address2Controller = TextEditingController(text: widget.userData['address_2'] ?? '');
    _zipController = TextEditingController(text: widget.userData['zipcode'] ?? '');
    
    // Check if address is incomplete
    _isAddressIncomplete = (widget.userData['address_1']?.toString().isEmpty ?? true) ||
                           (widget.userData['city']?.toString().isEmpty ?? true) ||
                           (widget.userData['state']?.toString().isEmpty ?? true) ||
                           (widget.userData['zipcode']?.toString().isEmpty ?? true);
    
    _isEditingAddress = _isAddressIncomplete;
    _loadProvinces();
  }

  @override
  void dispose() {
    _address1Controller.dispose();
    _address2Controller.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _isLoadingWilayah = true);
    try {
      final res = await _paymentService.getRentFormData();
      if (res['status'] == true) {
        setState(() {
          _provinces = res['data']['provinces'] ?? [];
          _shippingCosts = res['data']['shipping_costs'] ?? [];
        });
      }
    } finally {
      setState(() => _isLoadingWilayah = false);
    }
  }

  Future<void> _loadRegencies(String provinceId) async {
    setState(() => _isLoadingWilayah = true);
    try {
      final res = await _paymentService.getRegencies(provinceId);
      if (res['status'] == true) {
        setState(() {
          _regencies = res['data'] ?? [];
          _selectedRegency = null;
          _selectedDistrict = null;
          _selectedVillage = null;
          _districts = [];
          _villages = [];
        });
      }
    } finally {
      setState(() => _isLoadingWilayah = false);
    }
  }

  Future<void> _loadDistricts(String regencyId) async {
    setState(() => _isLoadingWilayah = true);
    try {
      final res = await _paymentService.getDistricts(regencyId);
      if (res['status'] == true) {
        setState(() {
          _districts = res['data'] ?? [];
          _selectedDistrict = null;
          _selectedVillage = null;
          _villages = [];
        });
      }
    } finally {
      setState(() => _isLoadingWilayah = false);
    }
  }

  Future<void> _loadVillages(String districtId) async {
    setState(() => _isLoadingWilayah = true);
    try {
      final res = await _paymentService.getVillages(districtId);
      if (res['status'] == true) {
        setState(() {
          _villages = res['data'] ?? [];
          _selectedVillage = null;
        });
      }
    } finally {
      setState(() => _isLoadingWilayah = false);
    }
  }

  String _formatPrice(double price) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(price).trim();
  }

  double get _subtotal => widget.items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  double get _adminFee => 7000;
  double get _total => _subtotal + _adminFee + _shippingCostAmount;
  
  Future<void> _handleCheckout() async {
    final laptopCodes = widget.items.map((e) => e.id).toList();
    final quantities = widget.items.map((e) => e.quantity).toList();
    final unitPrices = widget.items.map((e) => e.price * e.quantity).toList();
    if (_isEditingAddress) {
      if (_address1Controller.text.isEmpty || 
          _selectedProvince == null || 
          _selectedRegency == null || 
          _selectedDistrict == null || 
          _selectedVillage == null || 
          _zipController.text.isEmpty) {
        context.showErrorSnackBar('Mohon lengkapi alamat pengiriman.');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final orderNumber = 'PUR-${DateTime.now().millisecondsSinceEpoch}';
      
      // Get Wilayah Names
      String provinceName = _selectedProvince != null ? _provinces.firstWhere((p) => p['id'].toString() == _selectedProvince, orElse: () => {'name': ''})['name'] : (widget.userData['state'] ?? '');
      String regencyName = _selectedRegency != null ? _regencies.firstWhere((r) => r['id'].toString() == _selectedRegency, orElse: () => {'name': ''})['name'] : (widget.userData['city'] ?? '');
      String districtName = _selectedDistrict != null ? _districts.firstWhere((d) => d['id'].toString() == _selectedDistrict, orElse: () => {'name': ''})['name'] : '';
      String villageName = _selectedVillage != null ? _villages.firstWhere((v) => v['id'].toString() == _selectedVillage, orElse: () => {'name': ''})['name'] : '';

      final Map<String, String> body = {
        'customer_id': (widget.userData['id'] ?? widget.userData['user_id']).toString(),
        'order_number': orderNumber,
        'invoice_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'lama_sewa': '1', 
        'jenis_sewa': 'beli', 
        'whatsapp': widget.userData['contact_number'] ?? '',
        'nama_lengkap': '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim(),
        'laptop_codes': jsonEncode(laptopCodes),
        'quantities': jsonEncode(quantities),
        'unit_prices': jsonEncode(unitPrices),
        'notes': 'Direct Purchase from Mobile app',
        'is_sale': '1',
        // Address parameters
        'address_1': _address1Controller.text,
        'address_2': _address2Controller.text,
        'city': regencyName,
        'state': provinceName,
        'district_current_name': districtName,
        'village_current_name': villageName,
        'zipcode': _zipController.text,
        'tipe_pengiriman': _tipePengiriman,
        'biaya_kirim': _shippingCostAmount.toString(),
        'payment_method': _selectedPaymentMethod ?? 'transfer',
        'admin_fee': _adminFee.toString(),
      };

      // Since we don't have files for purchase, we send empty map
      final res = await _paymentService.storeRentPlan(body, {});

      if (res['status'] == true) {
        final rentalId = res['rental_id'];
        
        // 2. Process Flip Payment
        if (_selectedPaymentMethod == 'transfer') {
          final payRes = await _paymentService.processPayment(
            int.parse(rentalId.toString()),
            'transfer',
            subMethod: 'Flip',
          );

          if (payRes['status'] == true && payRes['data']['payment_url'] != null) {
            final url = Uri.parse(payRes['data']['payment_url']);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
              context.showSuccessSnackBar('Checkout berhasil. Silakan selesaikan pembayaran di Flip.');
              
              // Clear cart after successful checkout
              context.read<CartProvider>().clear();
              Navigator.pop(context); // Back to cart
              Navigator.pop(context); // Back to dashboard
            } else {
              context.showErrorSnackBar('Tidak dapat membuka link pembayaran.');
            }
          } else {
            context.showErrorSnackBar(payRes['message'] ?? 'Gagal membuat link pembayaran.');
          }
        } else {
          // Cash flow
          context.showSuccessSnackBar('Checkout berhasil. Pesanan Anda sedang diproses.');
          context.read<CartProvider>().clear();
          Navigator.pop(context);
        }
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Gagal memproses pesanan.');
      }
    } catch (e) {
      context.showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Pembelian', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Pesanan Anda'),
                ...widget.items.map((item) => _buildItemRow(item, isDark)),
                const SizedBox(height: 24),
                _buildSectionHeader('Metode Pembayaran'),
                _buildPaymentOption(
                  id: 'transfer',
                  title: 'Transfer Bank / QRIS (Flip)',
                  subtitle: 'Otomatis terverifikasi & aman',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.blue,
                ),
                _buildPaymentOption(
                  id: 'cash',
                  title: 'Bayar Langsung (Cash)',
                  subtitle: 'Bayar saat pengambilan barang',
                  icon: Icons.payments_rounded,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Alamat Pengiriman'),
                _buildAddressSection(isDark, primaryColor),
                const SizedBox(height: 24),
                _buildSectionHeader('Layanan Pengiriman'),
                const SizedBox(height: 8),
                _buildShippingDropdown(),
                const SizedBox(height: 24),
                _buildSectionHeader('Informasi Pengiriman'),
                _buildInfoCard(
                  icon: Icons.person_outline,
                  title: widget.userData['nama'] ?? widget.userData['first_name'] ?? 'Customer',
                  subtitle: widget.userData['hp'] ?? widget.userData['contact_number'] ?? '',
                ),
              ],
            ),
          ),
          _buildBottomSummary(primaryColor),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItemRow(CartItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: '${AppConstants.serverRoot}/uploads/products/${item.image}',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${item.quantity} x ${_formatPrice(item.price)}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Text(_formatPrice(item.price * item.quantity), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? color.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal', _formatPrice(_subtotal)),
            _buildSummaryRow('Biaya Kirim', _formatPrice(_shippingCostAmount.toDouble())),
            _buildSummaryRow('Biaya Admin', _formatPrice(_adminFee)),
            const Divider(height: 24),
            _buildSummaryRow('Total Pembayaran', _formatPrice(_total), isBold: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingDropdown() {
    final String selectedName = _selectedShippingId != null
        ? _shippingCosts.firstWhere(
                    (s) => s['constants_id'].toString() == _selectedShippingId,
                    orElse: () => {},
                  )['category_name'] !=
                  null
              ? '${_shippingCosts.firstWhere((s) => s['constants_id'].toString() == _selectedShippingId)['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(_shippingCosts.firstWhere((s) => s['constants_id'].toString() == _selectedShippingId)['field_one']))}'
              : ''
        : '';

    return SearchableDropdown(
      label: 'Pilih Pengiriman',
      value: selectedName,
      options: _shippingCosts
          .map(
            (s) => {
              'id': s['constants_id'].toString(),
              'name':
                  '${s['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(s['field_one']))}',
            },
          )
          .toList(),
      onSelected: (val) {
        final ship = _shippingCosts.firstWhere(
          (s) => s['constants_id'].toString() == val,
        );
        setState(() {
          _selectedShippingId = val;
          _shippingCostAmount = int.parse(ship['field_one']);
          _tipePengiriman = ship['category_name'];
        });
      },
      placeholder: 'Cari layanan pengiriman...',
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: isBold ? null : Colors.grey)),
        Text(value, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  Widget _buildAddressSection(bool isDark, Color primaryColor) {
    if (!_isEditingAddress) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.userData['address_1'] ?? 'Belum ada alamat',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditingAddress = true),
                  child: const Text('Ubah'),
                ),
              ],
            ),
            if (widget.userData['city'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '${widget.userData['city']}, ${widget.userData['state']} ${widget.userData['zipcode']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _address1Controller,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap',
              hintText: 'Jl. Nama Jalan No. XX',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SearchableDropdown(
            label: 'Provinsi',
            value: _selectedProvince != null ? _provinces.firstWhere((p) => p['id'].toString() == _selectedProvince, orElse: () => {'name': ''})['name'] : (widget.userData['state'] ?? ''),
            options: _provinces.map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedProvince = val);
              _loadRegencies(val);
            },
            placeholder: 'Pilih Provinsi',
          ),
          const SizedBox(height: 16),
          SearchableDropdown(
            label: 'Kota / Kabupaten',
            value: _selectedRegency != null ? _regencies.firstWhere((r) => r['id'].toString() == _selectedRegency, orElse: () => {'name': ''})['name'] : (widget.userData['city'] ?? ''),
            options: _regencies.map((r) => {'id': r['id'].toString(), 'name': r['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedRegency = val);
              _loadDistricts(val);
            },
            placeholder: 'Pilih Kota',
          ),
          const SizedBox(height: 16),
          SearchableDropdown(
            label: 'Kecamatan',
            value: _selectedDistrict != null ? _districts.firstWhere((d) => d['id'].toString() == _selectedDistrict, orElse: () => {'name': ''})['name'] : '',
            options: _districts.map((d) => {'id': d['id'].toString(), 'name': d['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedDistrict = val);
              _loadVillages(val);
            },
            placeholder: 'Pilih Kecamatan',
          ),
          const SizedBox(height: 16),
          SearchableDropdown(
            label: 'Desa / Kelurahan',
            value: _selectedVillage != null ? _villages.firstWhere((v) => v['id'].toString() == _selectedVillage, orElse: () => {'name': ''})['name'] : '',
            options: _villages.map((v) => {'id': v['id'].toString(), 'name': v['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedVillage = val);
            },
            placeholder: 'Pilih Desa',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _zipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kode Pos',
                    hintText: '12345',
                  ),
                ),
              ),
            ],
          ),
          if (_isLoadingWilayah)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          if (widget.userData['address_1'] != null && widget.userData['address_1'].toString().isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _isEditingAddress = false),
              child: const Text('Batal Ubah Alamat'),
            ),
        ],
      ),
    );
  }
}
