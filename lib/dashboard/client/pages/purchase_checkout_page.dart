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
  final Map<String, dynamic>? prefilledAddress;

  const PurchaseCheckoutPage({
    super.key,
    required this.userData,
    required this.items,
    this.prefilledAddress,
  });

  @override
  State<PurchaseCheckoutPage> createState() => _PurchaseCheckoutPageState();
}

class _PurchaseCheckoutPageState extends State<PurchaseCheckoutPage> {
  final RentPlanService _paymentService = RentPlanService();
  bool _isSubmitting = false;
  String? _selectedPaymentMethod = 'transfer';

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

  List<dynamic> _shippingCosts = [];
  String? _selectedShippingId;
  int _shippingCostAmount = 0;
  String _tipePengiriman = '';

  @override
  void initState() {
    super.initState();
    final hasPrefilled = widget.prefilledAddress != null;

    _address1Controller = TextEditingController(
        text: hasPrefilled ? widget.prefilledAddress!['address_1'] : widget.userData['address_1'] ?? '');
    _address2Controller = TextEditingController(text: widget.userData['address_2'] ?? '');
    _zipController = TextEditingController(
        text: hasPrefilled ? widget.prefilledAddress!['zipcode'] : widget.userData['zipcode'] ?? '');

    _isAddressIncomplete = (widget.userData['address_1']?.toString().isEmpty ?? true) ||
        (widget.userData['city']?.toString().isEmpty ?? true) ||
        (widget.userData['state']?.toString().isEmpty ?? true) ||
        (widget.userData['zipcode']?.toString().isEmpty ?? true);

    _isEditingAddress = _isAddressIncomplete || hasPrefilled;

    if (hasPrefilled) {
      _selectedProvince = widget.prefilledAddress!['province_name'];
      _selectedRegency = widget.prefilledAddress!['regency_name'];
      _selectedDistrict = widget.prefilledAddress!['district_name'];
      _selectedVillage = widget.prefilledAddress!['village_name'];
    }

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
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(price).trim();
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

      String provinceName = _selectedProvince != null
          ? _provinces.firstWhere((p) => p['id'].toString() == _selectedProvince, orElse: () => {'name': ''})['name']
          : (widget.userData['state'] ?? '');
      String regencyName = _selectedRegency != null
          ? _regencies.firstWhere((r) => r['id'].toString() == _selectedRegency, orElse: () => {'name': ''})['name']
          : (widget.userData['city'] ?? '');
      String districtName = _selectedDistrict != null
          ? _districts.firstWhere((d) => d['id'].toString() == _selectedDistrict, orElse: () => {'name': ''})['name']
          : '';
      String villageName = _selectedVillage != null
          ? _villages.firstWhere((v) => v['id'].toString() == _selectedVillage, orElse: () => {'name': ''})['name']
          : '';

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

      final res = await _paymentService.storeRentPlan(body, {});

      if (res['status'] == true) {
        final rentalId = res['rental_id'];

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
              context.read<CartProvider>().clearByType(isRental: false);
              Navigator.pop(context);
              Navigator.pop(context);
            } else {
              context.showErrorSnackBar('Tidak dapat membuka link pembayaran.');
            }
          } else {
            context.showErrorSnackBar(payRes['message'] ?? 'Gagal membuat link pembayaran.');
          }
        } else {
          context.showSuccessSnackBar('Checkout berhasil. Pesanan Anda sedang diproses.');
          context.read<CartProvider>().clearByType(isRental: false);
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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        title: const Text('Checkout Pembelian', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildStepIndicator(context, primaryColor),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionCard(
                  context: context,
                  icon: Icons.receipt_long_rounded,
                  iconColor: primaryColor,
                  title: 'Pesanan Anda',
                  child: Column(children: widget.items.map((item) => _buildItemRow(item, isDark)).toList()),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  context: context,
                  icon: Icons.payment_rounded,
                  iconColor: Colors.blue,
                  title: 'Metode Pembayaran',
                  child: Column(
                    children: [
                      _buildPaymentOption(
                        id: 'transfer',
                        title: 'Transfer Bank / QRIS',
                        subtitle: 'via Flip — otomatis terverifikasi',
                        icon: Icons.account_balance_rounded,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      _buildPaymentOption(
                        id: 'cash',
                        title: 'Bayar Langsung (Cash)',
                        subtitle: 'Bayar saat pengambilan barang',
                        icon: Icons.payments_rounded,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  context: context,
                  icon: Icons.location_on_rounded,
                  iconColor: Colors.orange,
                  title: 'Alamat Pengiriman',
                  child: _buildAddressSection(isDark, primaryColor),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  context: context,
                  icon: Icons.local_shipping_rounded,
                  iconColor: Colors.teal,
                  title: 'Layanan Pengiriman',
                  child: _buildShippingDropdown(),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  context: context,
                  icon: Icons.person_outline_rounded,
                  iconColor: Colors.purple,
                  title: 'Informasi Penerima',
                  child: _buildReceiverInfo(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildBottomSummary(primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = ['Keranjang', 'Checkout', 'Selesai'];
    final currentStep = 1;

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < currentStep ? primaryColor : Colors.grey[300],
              ),
            );
          }
          final idx = i ~/ 2;
          final isDone = idx < currentStep;
          final isActive = idx == currentStep;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone || isActive ? primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isDone || isActive ? primaryColor : Colors.grey[300]!,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : Colors.grey[400],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[idx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? primaryColor : Colors.grey[400],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: '${AppConstants.serverRoot}/uploads/products/${item.image}',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 52,
                height: 52,
                color: Colors.grey[100],
                child: const Icon(Icons.laptop_mac_rounded, color: Colors.grey, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2),
                const SizedBox(height: 2),
                Text('${item.quantity}x ${_formatPrice(item.price)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Text(_formatPrice(item.price * item.quantity),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.2), width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? color.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(Icons.check_circle_rounded, color: color, key: const ValueKey('checked'))
                  : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey[300], key: const ValueKey('unchecked')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverInfo() {
    final name =
        '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim().isNotEmpty
            ? '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim()
            : widget.userData['nama'] ?? 'Customer';
    final phone = widget.userData['contact_number'] ?? widget.userData['hp'] ?? '-';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_rounded, color: Colors.purple, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(phone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSummary(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -6))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal (${widget.items.length} item)', _formatPrice(_subtotal)),
            const SizedBox(height: 6),
            _buildSummaryRow(
                'Biaya Kirim', _shippingCostAmount > 0 ? _formatPrice(_shippingCostAmount.toDouble()) : '-'),
            const SizedBox(height: 6),
            _buildSummaryRow('Biaya Admin', _formatPrice(_adminFee)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  _formatPrice(_total),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildShippingDropdown() {
    final String selectedName = _selectedShippingId != null
        ? (() {
            final ship = _shippingCosts.firstWhere(
              (s) => s['constants_id'].toString() == _selectedShippingId,
              orElse: () => {},
            );
            return ship['category_name'] != null
                ? '${ship['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(ship['field_one']))}'
                : '';
          })()
        : '';

    return SearchableDropdown(
      label: 'Pilih Pengiriman',
      value: selectedName,
      options: _shippingCosts
          .map((s) => {
                'id': s['constants_id'].toString(),
                'name':
                    '${s['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.parse(s['field_one']))}',
              })
          .toList(),
      onSelected: (val) {
        final ship = _shippingCosts.firstWhere((s) => s['constants_id'].toString() == val);
        setState(() {
          _selectedShippingId = val;
          _shippingCostAmount = int.parse(ship['field_one']);
          _tipePengiriman = ship['category_name'];
        });
      },
      placeholder: 'Cari layanan pengiriman...',
    );
  }

  Widget _buildAddressSection(bool isDark, Color primaryColor) {
    if (!_isEditingAddress) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.orange.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userData['address_1'] ?? 'Belum ada alamat',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (widget.userData['city'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${widget.userData['city']}, ${widget.userData['state']} ${widget.userData['zipcode']}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isEditingAddress = true),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Ubah', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _address1Controller,
            decoration: InputDecoration(
              labelText: 'Alamat Lengkap',
              hintText: 'Jl. Nama Jalan No. XX',
              prefixIcon: const Icon(Icons.home_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SearchableDropdown(
            label: 'Provinsi',
            value: _selectedProvince != null
                ? _provinces.firstWhere((p) => p['id'].toString() == _selectedProvince, orElse: () => {'name': ''})['name']
                : (widget.userData['state'] ?? ''),
            options: _provinces.map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedProvince = val);
              _loadRegencies(val);
            },
            placeholder: 'Pilih Provinsi',
          ),
          const SizedBox(height: 12),
          SearchableDropdown(
            label: 'Kota / Kabupaten',
            value: _selectedRegency != null
                ? _regencies.firstWhere((r) => r['id'].toString() == _selectedRegency, orElse: () => {'name': ''})['name']
                : (widget.userData['city'] ?? ''),
            options: _regencies.map((r) => {'id': r['id'].toString(), 'name': r['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedRegency = val);
              _loadDistricts(val);
            },
            placeholder: 'Pilih Kota',
          ),
          const SizedBox(height: 12),
          SearchableDropdown(
            label: 'Kecamatan',
            value: _selectedDistrict != null
                ? _districts.firstWhere((d) => d['id'].toString() == _selectedDistrict, orElse: () => {'name': ''})['name']
                : '',
            options: _districts.map((d) => {'id': d['id'].toString(), 'name': d['name'].toString()}).toList(),
            onSelected: (val) {
              setState(() => _selectedDistrict = val);
              _loadVillages(val);
            },
            placeholder: 'Pilih Kecamatan',
          ),
          const SizedBox(height: 12),
          SearchableDropdown(
            label: 'Desa / Kelurahan',
            value: _selectedVillage != null
                ? _villages.firstWhere((v) => v['id'].toString() == _selectedVillage, orElse: () => {'name': ''})['name']
                : '',
            options: _villages.map((v) => {'id': v['id'].toString(), 'name': v['name'].toString()}).toList(),
            onSelected: (val) => setState(() => _selectedVillage = val),
            placeholder: 'Pilih Desa',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _zipController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kode Pos',
              hintText: '12345',
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          if (_isLoadingWilayah)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          if (widget.userData['address_1'] != null && widget.userData['address_1'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isEditingAddress = false),
              child: Text('Batal Ubah Alamat', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ],
      ),
    );
  }
}
