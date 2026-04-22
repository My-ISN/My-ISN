import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/rent_plan_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/secondary_app_bar.dart';
import '../../widgets/custom_snackbar.dart';
import '../../providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CartCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<CartItem> items;

  const CartCheckoutPage({
    super.key,
    required this.userData,
    required this.items,
  });

  @override
  State<CartCheckoutPage> createState() => _CartCheckoutPageState();
}

class _CartCheckoutPageState extends State<CartCheckoutPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  // Form Data from API
  String _orderNumber = '';
  List<dynamic> _jaminanPribadi = [];
  List<dynamic> _jaminanPerusahaan = [];
  List<dynamic> _shippingCosts = [];
  List<dynamic> _provinces = [];
  List<dynamic> _agreements = [];

  // User input
  int _lamaSewa = 1;
  String _jenisSewa = 'pribadi';
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _namaPerusahaanController = TextEditingController();
  final TextEditingController _npwpController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _currentAddressController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Region Data
  String? _selectedProvinceKtp, _selectedRegencyKtp, _selectedDistrictKtp, _selectedVillageKtp;
  String? _selectedProvinceCur, _selectedRegencyCur, _selectedDistrictCur, _selectedVillageCur;
  List<dynamic> _regenciesKtp = [], _districtsKtp = [], _villagesKtp = [];
  List<dynamic> _regenciesCur = [], _districtsCur = [], _villagesCur = [];
  bool _isLoadingRegKtp = false, _isLoadingDistKtp = false, _isLoadingVillKtp = false;
  bool _isLoadingRegCur = false, _isLoadingDistCur = false, _isLoadingVillCur = false;
  
  // Cache for better performance
  Map<String, List<dynamic>> _regencyCache = {};
  Map<String, List<dynamic>> _districtCache = {};
  Map<String, List<dynamic>> _villageCache = {};
  
  // Debounce timer
  Timer? _debounceTimer;

  // Files
  File? _fileKtp, _fileNpwp, _filePo, _fileKtpPimpinan, _fileDomisiliPerusahaan;
  final Map<int, File?> _fileJaminan = {1: null, 2: null, 3: null};
  final Map<int, String?> _selectedJaminanIds = {1: null, 2: null, 3: null};

  // Payment & Shipping
  String? _selectedShippingId;
  int _shippingCostAmount = 0;
  String _paymentMethod = 'transfer'; // 'transfer' (Flip) or 'cash' (COD)
  String _tipePengiriman = '';

  bool get _hasRental {
    final hasRental = widget.items.any((i) => i.isRental);
    print('DEBUG: Has rental items: $hasRental');
    print('DEBUG: Total items: ${widget.items.length}');
    print('DEBUG: Rental items: ${widget.items.where((i) => i.isRental).length}');
    print('DEBUG: Purchase items: ${widget.items.where((i) => !i.isRental).length}');
    return hasRental;
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final response = await _rentPlanService.getRentFormData();
    if (response['status'] == true) {
      final data = response['data'];
      setState(() {
        // Generate unified order number for mixed items
        final hasRentalItems = widget.items.any((item) => item.isRental);
        final hasPurchaseItems = widget.items.any((item) => !item.isRental);
        
        if (hasRentalItems && hasPurchaseItems) {
          _orderNumber = 'MIX-${DateTime.now().millisecondsSinceEpoch}';
        } else if (hasRentalItems) {
          _orderNumber = data['order_number'] ?? '';
        } else {
          _orderNumber = 'PUR-${DateTime.now().millisecondsSinceEpoch}';
        }
        
        _jaminanPribadi = List<dynamic>.from(data['jaminan_pribadi'] ?? [])
            .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
        _jaminanPerusahaan = List<dynamic>.from(data['jaminan_perusahaan'] ?? [])
            .where((j) => j['category_name'].toString().toUpperCase() != 'KTP').toList();
        _shippingCosts = List<dynamic>.from(data['shipping_costs'] ?? []);
        _provinces = List<dynamic>.from(data['provinces'] ?? []);
        _agreements = List<dynamic>.from(data['agreements'] ?? []);

        // Pre-fill user data
        _whatsappController.text = widget.userData['contact_number']?.toString() ?? '';
        _namaLengkapController.text = '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
        _currentAddressController.text = widget.userData['address_1']?.toString() ?? '';
        _zipCodeController.text = widget.userData['zipcode']?.toString() ?? '';
        _emergencyContactController.text = widget.userData['emergency_contact_number']?.toString() ?? '';
        _durationController.text = _lamaSewa.toString();

        // Auto-select "DEPOSIT" for jaminan 1 if available
        try {
          final depositJaminan = _jaminanPribadi.firstWhere(
            (j) => j['category_name'].toString().toUpperCase().contains('DEPOSIT'),
            orElse: () => null,
          );
          if (depositJaminan != null) {
            _selectedJaminanIds[1] = depositJaminan['constants_id'].toString();
          }
        } catch (_) {}

        _isLoadingData = false;
      });
    } else {
      if (mounted) {
        context.showErrorSnackBar(response['message'] ?? 'Error fetching form data');
        Navigator.pop(context);
      }
    }
  }

  double get _totalPrice {
    double total = 0;
    for (var item in widget.items) {
      if (item.isRental) {
        total += (item.price * item.quantity * _lamaSewa);
      } else {
        total += (item.price * item.quantity);
      }
    }
    return total + _shippingCostAmount + 7000; // 7000 Admin Fee
  }

  void _nextStep() {
    int maxSteps = 2; // 0, 1, 2
    if (_currentStep < maxSteps) {
      // Validate current step
      if (_currentStep == 0 && _hasRental) {
        if (!_formKey.currentState!.validate()) return;
        if (_jenisSewa == 'pribadi' && _fileKtp == null) {
          context.showErrorSnackBar('rent_plan.validation.upload_ktp'.tr(context));
          return;
        }
        
        // Check jaminan validation - ALLOW "DEPOSIT" to have no file
        int minJaminan = _jenisSewa == 'pribadi' ? 3 : 2;
        List<dynamic> baseOptions = _jenisSewa == 'pribadi' ? _jaminanPribadi : _jaminanPerusahaan;
        
        int validJaminanCount = 0;
        for (int i = 1; i <= minJaminan; i++) {
          final id = _selectedJaminanIds[i];
          if (id == null) continue;

          final file = _fileJaminan[i];
          final jType = baseOptions.firstWhere(
            (j) => j['constants_id'].toString() == id,
            orElse: () => null,
          );
          bool isDeposit = jType != null &&
              jType['category_name'].toString().toUpperCase().contains('DEPOSIT');

          if (isDeposit || file != null) {
            validJaminanCount++;
          }
        }

        if (validJaminanCount < minJaminan) {
          context.showErrorSnackBar('rent_plan.validation.min_guarantee'.tr(context, args: {'min': minJaminan.toString()}));
          return;
        }
      }
      
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _showAgreementPopup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _showBackConfirmationDialog();
    }
  }

  // Handle system back button for PopScope
  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      _prevStep();
      return false; // Prevent default pop
    } else {
      // Show confirmation dialog
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text('Apakah Anda yakin ingin kembali? Semua perubahan yang belum disimpan akan hilang.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Don't pop
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Allow pop
              child: const Text('Ya, Kembali'),
            ),
          ],
        ),
      );
      return shouldPop ?? false; // Default to false if dialog dismissed
    }
  }

  void _showBackConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin kembali? Semua perubahan yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to cart
            },
            child: const Text('Ya, Kembali'),
          ),
        ],
      ),
    );
  }

  void _showAgreementPopup() {
    print('DEBUG: _showAgreementPopup called');
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed or form key is null');
      return;
    }
    print('DEBUG: Form validation passed');

    // Check required files based on jenisSewa
    if (_jenisSewa == 'pribadi' && _fileKtp == null) {
      context.showWarningSnackBar('rent_plan.validation.ktp_required'.tr(context));
      return;
    }

    // Jaminan validation
    int requiredGua = _jenisSewa == 'pribadi' ? 3 : 2;
    int providedGua = _selectedJaminanIds.values.where((v) => v != null).length;
    print('DEBUG: Required jaminan: $requiredGua, Provided: $providedGua');
    
    if (providedGua < requiredGua) {
      print('DEBUG: Jaminan validation failed');
      context.showWarningSnackBar('rent_plan.validation.guarantee_min'.tr(context, args: {'min': requiredGua.toString()}));
      return;
    }

    print('DEBUG: Agreements count: ${_agreements.length}');
    if (_agreements.isEmpty) {
      print('DEBUG: No agreements, calling _submitForm directly');
      _submitForm();
      return;
    }

    print('DEBUG: Showing agreement modal');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scrollController = ScrollController();
        bool hasScrolledToBottom = false;
        bool hasAgreed = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            scrollController.addListener(() {
              if (scrollController.position.atEdge &&
                  scrollController.position.pixels != 0 &&
                  !hasScrolledToBottom) {
                setSheetState(() => hasScrolledToBottom = true);
              }
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'rent_plan.agreement.title'.tr(context),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Agreement content (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var agreement in _agreements) ...[
                            Text(
                              agreement['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              agreement['content'] ?? agreement['description'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.8,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (agreement != _agreements.last)
                              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Scroll hint
                  if (!hasScrolledToBottom)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'rent_plan.agreement.scroll_to_bottom'.tr(context),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Checkbox + Button (bottom fixed)
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(0, -10),
                          blurRadius: 20,
                        ),
                      ],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: hasScrolledToBottom
                              ? () => setSheetState(() => hasAgreed = !hasAgreed)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: hasAgreed,
                                    onChanged: hasScrolledToBottom
                                        ? (v) => setSheetState(() => hasAgreed = v ?? false)
                                        : null,
                                    activeColor: Theme.of(context).colorScheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'rent_plan.agreement.agree_checkbox'.tr(context),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: hasScrolledToBottom
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: hasScrolledToBottom && hasAgreed
                                ? () {
                                    print('DEBUG: Agreement button clicked - calling _submitForm');
                                    Navigator.pop(context);
                                    _submitForm();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Setuju & Lanjutkan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        );
      },
    );
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      print('DEBUG: Starting submission...');
      print('DEBUG: Widget items: ${widget.items}');
      print('DEBUG: Items length: ${widget.items.length}');
      
      final hasRentalItems = widget.items.any((item) => item.isRental);
      final hasPurchaseItems = widget.items.any((item) => !item.isRental);
      
      print('DEBUG: Has rental: $hasRentalItems');
      print('DEBUG: Has purchase: $hasPurchaseItems');
      
      Map<String, String> body = {
        'customer_id': (widget.userData['user_id'] ?? widget.userData['id']).toString(),
        'order_number': _orderNumber,
        'invoice_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'lama_sewa': hasRentalItems ? _lamaSewa.toString() : '1',
        'jenis_sewa': hasRentalItems ? _jenisSewa : 'beli',
        'whatsapp': _whatsappController.text,
        'nama_lengkap': _namaLengkapController.text,
        'nik': _nikController.text,
        'nama_perusahaan': _namaPerusahaanController.text,
        'npwp': _npwpController.text,
        'notes': hasRentalItems && hasPurchaseItems 
          ? 'Mixed Order: Rental + Purchase Items' 
          : (hasRentalItems ? _notesController.text : 'Direct Purchase from Mobile app'),
        // KTP Address
        'province_ktp_name': _getNameFromList(_provinces, _selectedProvinceKtp),
        'regency_ktp_name': _getNameFromList(_regenciesKtp, _selectedRegencyKtp),
        'district_ktp_name': _getNameFromList(_districtsKtp, _selectedDistrictKtp),
        'village_ktp_name': _getNameFromList(_villagesKtp, _selectedVillageKtp),
        // Domisili Address
        'address_1': _currentAddressController.text ?? '',
        'zipcode': _zipCodeController.text ?? '',
        'province_current_name': _getNameFromList(_provinces, _selectedProvinceCur),
        'regency_current_name': _getNameFromList(_regenciesCur, _selectedRegencyCur),
        'district_current_name': _getNameFromList(_districtsCur, _selectedDistrictCur),
        'village_current_name': _getNameFromList(_villagesCur, _selectedVillageCur),
        'laptop_codes': json.encode(widget.items.map((i) => i.id).toList()),
        'quantities': json.encode(widget.items.map((i) => i.quantity).toList()),
        'unit_prices': json.encode(widget.items.map((i) => i.price * i.quantity).toList()),
        'is_rentals': json.encode(widget.items.map((i) => i.isRental ? 1 : 0).toList()),
        'jaminan_ids': json.encode(_selectedJaminanIds.values.where((v) => v != null).toList()),
        'biaya_kirim': _shippingCostAmount.toString(),
        'tipe_pengiriman': _tipePengiriman,
        'admin_fee': '7000',
        'payment_method': _paymentMethod,
        'emergency_contact_number': _emergencyContactController.text ?? '',
        // Add flags for mixed orders
        'is_mixed_order': (hasRentalItems && hasPurchaseItems).toString(),
        'is_sale': hasPurchaseItems ? '1' : '0',
      };

      Map<String, String> files = {
        if (_fileKtp != null) 'file_ktp': _fileKtp!.path,
        if (_fileNpwp != null) 'file_npwp': _fileNpwp!.path,
        if (_filePo != null) 'file_po': _filePo!.path,
        if (_fileKtpPimpinan != null) 'file_ktp_pimpinan': _fileKtpPimpinan!.path,
        if (_fileDomisiliPerusahaan != null) 'file_domisili_perusahaan': _fileDomisiliPerusahaan!.path,
        for (int i = 1; i <= 3; i++) if (_fileJaminan[i] != null) 'file_jaminan_$i': _fileJaminan[i]!.path,
      };

      final res = await _rentPlanService.storeRentPlan(body, files);
      if (res['status'] == true) {
        // Clear Cart
        Provider.of<CartProvider>(context, listen: false).clear();
        
        if (res['payment_url'] != null) {
          final url = Uri.parse(res['payment_url']);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
        
        if (mounted) {
          context.showSuccessSnackBar('rent_plan.success_save'.tr(context));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar(res['message'] ?? 'Error saving order');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getNameFromList(List<dynamic> list, String? id) {
    if (id == null || list.isEmpty) return '';
    try {
      final item = list.firstWhere((e) => e['id']?.toString() == id, orElse: () => null);
      return item?['name']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: 'Checkout',
          onBackPressed: _prevStep,
        ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (_hasRental) _buildRentalDocsStep() else _buildShippingStep(),
                  if (_hasRental) _buildShippingStep() else _buildSummaryStep(),
                  if (_hasRental) _buildSummaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
        bottomNavigationBar: _buildBottomAction(),
      ),
    );
  }

  Widget _buildProgressBar() {
    int totalSteps = _hasRental ? 3 : 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          bool isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, {TextEditingController? controller, int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildFileUploadTile(String label, File? file, VoidCallback onTap) {
    return ListTile(
      leading: Icon(file == null ? Icons.upload_file : Icons.check_circle, color: file == null ? null : Colors.green),
      title: Text(label),
      subtitle: Text(file?.path.split('/').last ?? 'Tap to upload'),
      onTap: onTap,
      tileColor: Colors.grey.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildPaymentOption(String label, String value, IconData icon) {
    bool isSelected = _paymentMethod == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () => setState(() => _paymentMethod = value),
    );
  }

  Widget _buildSummaryItem(CartItem item) {
    double rowTotal = item.isRental ? (item.price * item.quantity * _lamaSewa) : (item.price * item.quantity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${item.isRental ? "Rental" : "Purchase"} x ${item.quantity}${item.isRental ? " (${_lamaSewa} days)" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          Text('Rp ${NumberFormat('#,###').format(rowTotal)}'),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : null)),
        Text('Rp ${NumberFormat('#,###').format(amount)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : null)),
      ],
    );
  }

  Widget _buildBottomAction() {
    String label = _currentStep < (_hasRental ? 2 : 1) ? 'Next' : 'Process Payment';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isSubmitting ? null : _nextStep,
        child: _isSubmitting 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildTipePenyewaToggle() {
    return ToggleButtons(
      isSelected: [_jenisSewa == 'pribadi', _jenisSewa == 'perusahaan'],
      onPressed: (index) => setState(() => _jenisSewa = index == 0 ? 'pribadi' : 'perusahaan'),
      borderRadius: BorderRadius.circular(16),
      children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Personal')), const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('Company'))],
    );
  }

  Widget _buildJaminanSelector(int index) {
    List<dynamic> options = _jenisSewa == 'pribadi' ? _jaminanPribadi : _jaminanPerusahaan;
    final selectedId = _selectedJaminanIds[index];
    final selectedJaminan = selectedId != null 
        ? options.firstWhere((j) => j['constants_id'].toString() == selectedId, orElse: () => null)
        : null;
    final isDeposit = selectedJaminan != null &&
        selectedJaminan['category_name'].toString().toUpperCase().contains('DEPOSIT');
    
    return Column(
      children: [
        SearchableDropdown(
          label: 'Guarantee $index',
          options: options.map((j) => {'id': j['constants_id'].toString(), 'name': j['category_name'].toString()}).toList(),
          onSelected: (val) => setState(() => _selectedJaminanIds[index] = val),
          placeholder: 'Select Guarantee',
          value: (options.firstWhere((j) => j['constants_id'].toString() == _selectedJaminanIds[index], orElse: () => {})['category_name'] ?? '').toString(),
        ),
        if (_selectedJaminanIds[index] != null && !isDeposit) 
          _buildFileUploadTile('Upload Guarantee $index', _fileJaminan[index], () => _pickFile('jaminan_$index')),
        if (_selectedJaminanIds[index] != null && isDeposit) 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'DEPOSIT - Tidak perlu upload file',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            return ship['category_name'] != null && ship['field_one'] != null
                ? '${ship['category_name']} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.tryParse(ship['field_one'].toString()) ?? 0)}'
                : '';
          })()
        : '';

    return SearchableDropdown(
      label: 'Pilih Pengiriman',
      value: selectedName,
      options: _shippingCosts
          .map(
            (s) => {
              'id': s['constants_id'].toString(),
              'name': '${s['category_name'] ?? ''} - Rp ${NumberFormat.compact(locale: 'id_ID').format(int.tryParse(s['field_one'].toString()) ?? 0)}',
            },
          )
          .toList(),
      onSelected: (val) {
        if (val == null) return;
        
        final ship = _shippingCosts.firstWhere(
          (s) => s['constants_id'].toString() == val,
          orElse: () => {},
        );
        
        if (ship['field_one'] != null && ship['category_name'] != null) {
          setState(() {
            _selectedShippingId = val;
            _shippingCostAmount = int.tryParse(ship['field_one'].toString()) ?? 0;
            _tipePengiriman = ship['category_name'].toString();
          });
        }
      },
      placeholder: 'Cari layanan pengiriman...',
    );
  }

  Widget _buildRegionDropdowns(bool isKtp) {
    return Column(
      children: [
        _buildAddressDropdown(
          label: 'Province',
          options: _provinces.map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
          value: _getNameFromList(_provinces, isKtp ? _selectedProvinceKtp : _selectedProvinceCur),
          onSelected: (val) {
            setState(() { 
              if (isKtp) _selectedProvinceKtp = val; else _selectedProvinceCur = val; 
            });
            _loadRegenciesDebounced(val, isKtp);
          },
          placeholder: 'Select Province',
          isLoading: false,
        ),
        const SizedBox(height: 12),
        _buildAddressDropdown(
          label: 'Regency/Kabupaten',
          options: (isKtp ? _regenciesKtp : _regenciesCur).map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
          value: _getNameFromList(isKtp ? _regenciesKtp : _regenciesCur, isKtp ? _selectedRegencyKtp : _selectedRegencyCur),
          onSelected: (val) {
            if (isKtp ? _isLoadingRegKtp : _isLoadingRegCur) return; // Prevent selection during loading
            setState(() { 
              if (isKtp) _selectedRegencyKtp = val; else _selectedRegencyCur = val; 
            });
            _loadDistricts(val, isKtp);
          },
          placeholder: (isKtp ? _isLoadingRegKtp : _isLoadingRegCur) ? 'Loading...' : 'Select Regency',
          isLoading: isKtp ? _isLoadingRegKtp : _isLoadingRegCur,
        ),
        const SizedBox(height: 12),
        _buildAddressDropdown(
          label: 'District',
          options: (isKtp ? _districtsKtp : _districtsCur).map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
          value: _getNameFromList(isKtp ? _districtsKtp : _districtsCur, isKtp ? _selectedDistrictKtp : _selectedDistrictCur),
          onSelected: (val) {
            if (isKtp ? _isLoadingDistKtp : _isLoadingDistCur) return; // Prevent selection during loading
            setState(() { 
              if (isKtp) _selectedDistrictKtp = val; else _selectedDistrictCur = val; 
            });
            _loadVillages(val, isKtp);
          },
          placeholder: (isKtp ? _isLoadingDistKtp : _isLoadingDistCur) ? 'Loading...' : 'Select District',
          isLoading: isKtp ? _isLoadingDistKtp : _isLoadingDistCur,
        ),
        const SizedBox(height: 12),
        _buildAddressDropdown(
          label: 'Village',
          options: (isKtp ? _villagesKtp : _villagesCur).map((p) => {'id': p['id'].toString(), 'name': p['name'].toString()}).toList(),
          value: _getNameFromList(isKtp ? _villagesKtp : _villagesCur, isKtp ? _selectedVillageKtp : _selectedVillageCur),
          onSelected: (val) {
            if (isKtp ? _isLoadingVillKtp : _isLoadingVillCur) return; // Prevent selection during loading
            setState(() { 
              if (isKtp) _selectedVillageKtp = val; else _selectedVillageCur = val; 
            });
          },
          placeholder: (isKtp ? _isLoadingVillKtp : _isLoadingVillCur) ? 'Loading...' : 'Select Village',
          isLoading: isKtp ? _isLoadingVillKtp : _isLoadingVillCur,
        ),
      ],
    );
  }

  Widget _buildAddressDropdown({
    required String label,
    required List<Map<String, String>> options,
    required String? value,
    required Function(String) onSelected,
    required String placeholder,
    required bool isLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isLoading 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade300,
          width: isLoading ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isLoading 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : null,
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading $label...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SearchableDropdown(
              label: label,
              options: options,
              onSelected: onSelected,
              placeholder: placeholder,
              value: value ?? '',
            ),
    );
  }

  Widget _buildRentalDocsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSection(
            title: 'rent_plan.docs_guarantees'.tr(context),
            icon: Icons.verified_user_rounded,
            children: [
              _buildTipePenyewaToggle(),
              const SizedBox(height: 20),
              if (_jenisSewa == 'pribadi') ...[
                _buildFileUploadTile('rent_plan.upload_ktp'.tr(context), _fileKtp, () => _pickFile('ktp')),
                const SizedBox(height: 12),
                _buildTextField('rent_plan.full_name'.tr(context), controller: _namaLengkapController),
                const SizedBox(height: 12),
                _buildTextField('rent_plan.nik'.tr(context), controller: _nikController, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField('WhatsApp Number', controller: _whatsappController, keyboardType: TextInputType.phone),
              ] else ...[
                _buildFileUploadTile('rent_plan.upload_npwp'.tr(context), _fileNpwp, () => _pickFile('npwp')),
                const SizedBox(height: 12),
                _buildFileUploadTile('rent_plan.upload_po'.tr(context), _filePo, () => _pickFile('po')),
                const SizedBox(height: 12),
                _buildFileUploadTile('Upload KTP Pimpinan', _fileKtpPimpinan, () => _pickFile('ktp_pimpinan')),
                const SizedBox(height: 12),
                _buildFileUploadTile('Upload Surat Domisili Perusahaan', _fileDomisiliPerusahaan, () => _pickFile('domisili')),
              ],
              const Divider(height: 40),
              for (int i = 1; i <= (_jenisSewa == 'pribadi' ? 3 : 2); i++) ...[
                _buildJaminanSelector(i),
                const SizedBox(height: 12),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Alamat Sesuai KTP',
            icon: Icons.credit_card_rounded,
            children: [
              _buildRegionDropdowns(true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_hasRental) _buildSection(
            title: 'Rental Information',
            icon: Icons.date_range_rounded,
            children: [
              _buildTextField('Durasi Sewa (hari)', controller: _durationController, keyboardType: TextInputType.number, onChanged: (val) {
                final newDuration = int.tryParse(val) ?? 1;
                if (newDuration > 0) setState(() => _lamaSewa = newDuration);
              }),
            ],
          ),
          if (_hasRental) const SizedBox(height: 24),
          if (_hasRental) _buildSection(
            title: 'Rent Items',
            icon: Icons.shopping_cart_rounded,
            children: [
              ...widget.items.where((item) => item.isRental).map((item) => _buildSummaryItem(item)),
            ],
          ),
          if (_hasRental) const SizedBox(height: 24),
          _buildSection(
            title: 'Alamat Domisili',
            icon: Icons.home_rounded,
            children: [
              _buildTextField('Alamat Lengkap (Domisili)', controller: _currentAddressController, maxLines: 2),
              const SizedBox(height: 16),
              _buildRegionDropdowns(false),
              const SizedBox(height: 16),
              _buildTextField('Kode Pos (Domisili)', controller: _zipCodeController, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField('Kontak Darurat', controller: _emergencyContactController, keyboardType: TextInputType.phone),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Layanan Pengiriman',
            icon: Icons.local_shipping_rounded,
            children: [
              _buildShippingDropdown(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Metode Pembayaran',
            icon: Icons.payment_rounded,
            children: [
              _buildPaymentOption('Transfer (Flip)', 'transfer', Icons.account_balance_rounded),
              _buildPaymentOption('Tunai (COD)', 'cash', Icons.payments_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...widget.items.map((item) => _buildSummaryItem(item)),
          const Divider(height: 32),
          _buildPriceRow('Subtotal', _totalPrice - _shippingCostAmount - 7000),
          _buildPriceRow('Shipping', _shippingCostAmount.toDouble()),
          _buildPriceRow('Admin Fee', 7000),
          const Divider(),
          _buildPriceRow('Total', _totalPrice, isBold: true),
        ],
      ),
    );
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        File file = File(result.files.single.path!);
        if (type == 'ktp') _fileKtp = file;
        else if (type == 'npwp') _fileNpwp = file;
        else if (type == 'po') _filePo = file;
        else if (type == 'ktp_pimpinan') _fileKtpPimpinan = file;
        else if (type == 'domisili') _fileDomisiliPerusahaan = file;
        else if (type.startsWith('jaminan_')) _fileJaminan[int.parse(type.split('_')[1])] = file;
      });
    }
  }

  Future<void> _loadRegencies(String provinceId, bool isKtp) async {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Check cache first
    if (_regencyCache.containsKey(provinceId)) {
      setState(() { 
        if (isKtp) {
          _regenciesKtp = _regencyCache[provinceId]!;
          _selectedRegencyKtp = null;
          _districtsKtp = [];
          _selectedDistrictKtp = null;
          _villagesKtp = [];
          _selectedVillageKtp = null;
        } else {
          _regenciesCur = _regencyCache[provinceId]!;
          _selectedRegencyCur = null;
          _districtsCur = [];
          _selectedDistrictCur = null;
          _villagesCur = [];
          _selectedVillageCur = null;
        }
      });
      return;
    }

    // Set loading state and reset child selections
    setState(() {
      if (isKtp) {
        _isLoadingRegKtp = true;
        _selectedRegencyKtp = null;
        _regenciesKtp = [];
        _selectedDistrictKtp = null;
        _districtsKtp = [];
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingRegCur = true;
        _selectedRegencyCur = null;
        _regenciesCur = [];
        _selectedDistrictCur = null;
        _districtsCur = [];
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    try {
      final res = await _rentPlanService.getRegencies(provinceId)
          .timeout(const Duration(seconds: 10));
      
      if (res['status'] == true && res['data'] != null) {
        // Save to cache
        _regencyCache[provinceId] = res['data'];
        
        setState(() { 
          if (isKtp) {
            _regenciesKtp = res['data'];
            _isLoadingRegKtp = false;
          } else {
            _regenciesCur = res['data'];
            _isLoadingRegCur = false;
          }
        });
      } else {
        throw Exception(res['message'] ?? 'Failed to load regencies');
      }
    } catch (e) {
      setState(() {
        if (isKtp) _isLoadingRegKtp = false;
        else _isLoadingRegCur = false;
      });
      
      if (mounted) {
        context.showErrorSnackBar('Gagal memuat data kabupaten/kota');
      }
    }
  }

  Future<void> _loadDistricts(String regencyId, bool isKtp) async {
    // Check cache first
    if (_districtCache.containsKey(regencyId)) {
      setState(() { 
        if (isKtp) {
          _districtsKtp = _districtCache[regencyId]!;
          _selectedDistrictKtp = null;
          _villagesKtp = [];
          _selectedVillageKtp = null;
        } else {
          _districtsCur = _districtCache[regencyId]!;
          _selectedDistrictCur = null;
          _villagesCur = [];
          _selectedVillageCur = null;
        }
      });
      return;
    }

    // Set loading state and reset child selections
    setState(() {
      if (isKtp) {
        _isLoadingDistKtp = true;
        _selectedDistrictKtp = null;
        _districtsKtp = [];
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingDistCur = true;
        _selectedDistrictCur = null;
        _districtsCur = [];
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    try {
      final res = await _rentPlanService.getDistricts(regencyId)
          .timeout(const Duration(seconds: 10));
      
      if (res['status'] == true && res['data'] != null) {
        // Save to cache
        _districtCache[regencyId] = res['data'];
        
        setState(() { 
          if (isKtp) {
            _districtsKtp = res['data'];
            _isLoadingDistKtp = false;
          } else {
            _districtsCur = res['data'];
            _isLoadingDistCur = false;
          }
        });
      } else {
        throw Exception(res['message'] ?? 'Failed to load districts');
      }
    } catch (e) {
      setState(() {
        if (isKtp) _isLoadingDistKtp = false;
        else _isLoadingDistCur = false;
      });
      
      if (mounted) {
        context.showErrorSnackBar('Gagal memuat data kecamatan');
      }
    }
  }

  Future<void> _loadVillages(String districtId, bool isKtp) async {
    // Check cache first
    if (_villageCache.containsKey(districtId)) {
      setState(() { 
        if (isKtp) {
          _villagesKtp = _villageCache[districtId]!;
          _selectedVillageKtp = null;
        } else {
          _villagesCur = _villageCache[districtId]!;
          _selectedVillageCur = null;
        }
      });
      return;
    }

    // Set loading state
    setState(() {
      if (isKtp) {
        _isLoadingVillKtp = true;
        _selectedVillageKtp = null;
        _villagesKtp = [];
      } else {
        _isLoadingVillCur = true;
        _selectedVillageCur = null;
        _villagesCur = [];
      }
    });

    try {
      final res = await _rentPlanService.getVillages(districtId)
          .timeout(const Duration(seconds: 10));
      
      if (res['status'] == true && res['data'] != null) {
        // Save to cache
        _villageCache[districtId] = res['data'];
        
        setState(() { 
          if (isKtp) {
            _villagesKtp = res['data'];
            _isLoadingVillKtp = false;
          } else {
            _villagesCur = res['data'];
            _isLoadingVillCur = false;
          }
        });
      } else {
        throw Exception(res['message'] ?? 'Failed to load villages');
      }
    } catch (e) {
      setState(() {
        if (isKtp) _isLoadingVillKtp = false;
        else _isLoadingVillCur = false;
      });
      
      if (mounted) {
        context.showErrorSnackBar('Gagal memuat data desa/kelurahan');
      }
    }
  }

  // Debounced version for rapid selections
  Future<void> _loadRegenciesDebounced(String provinceId, bool isKtp) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadRegencies(provinceId, isKtp);
    });
  }
}
