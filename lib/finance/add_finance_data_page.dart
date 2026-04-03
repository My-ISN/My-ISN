import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/finance_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';

class AddFinanceDataPage extends StatefulWidget {
  final List<dynamic> accounts;
  final int initialType; // 0 = Account, 1 = Income, 2 = Expense
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> userData;

  const AddFinanceDataPage({
    super.key, 
    required this.accounts, 
    this.initialType = 0,
    this.initialData,
    required this.userData,
  });

  @override
  State<AddFinanceDataPage> createState() => _AddFinanceDataPageState();
}

class _AddFinanceDataPageState extends State<AddFinanceDataPage> {
  final FinanceService _financeService = FinanceService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Type selection: 0 = Account, 1 = Income, 2 = Expense
  late int _selectedType;

  // Common Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Account Controllers
  final TextEditingController _accTitleController = TextEditingController();
  final TextEditingController _accNameController = TextEditingController(); // nama_rekening
  final TextEditingController _accNumberController = TextEditingController(); // nomor_rekening
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _branchCodeController = TextEditingController();
  final TextEditingController _bankBranchController = TextEditingController();

  String? _selectedBank;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedPayerId;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();

  String? _pickedFilePath;
  String? _pickedFileName;

  List<dynamic> _incomeCategories = [];
  List<dynamic> _expenseCategories = [];
  List<dynamic> _employees = [];
  final List<String> _paymentMethods = ['Cash', 'Paypal', 'Bank', 'Stripe', 'Paystack', 'Cheque'];
  final List<String> _banks = ['BCA', 'Mandiri', 'BNI'];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    
    // Handle mode Edit
    if (widget.initialData != null) {
      final d = widget.initialData!;
      debugPrint('Edit Mode: InitialData keys: ${d.keys.toList()}');
      
      if (_selectedType == 0) { // Account
        _accTitleController.text = (d['account_name'] ?? '').toString();
        _accNameController.text = (d['nama_rekening'] ?? '').toString();
        _accNumberController.text = (d['nomor_rekening'] ?? '').toString();
        _cardNumberController.text = (d['nomor_kartu'] ?? '').toString();
        _selectedBank = d['bank']?.toString();
        _branchCodeController.text = (d['branch_code'] ?? '').toString();
        _bankBranchController.text = (d['bank_branch'] ?? '').toString();
        
        final double amt = double.tryParse(d['account_opening_balance']?.toString() ?? '0') ?? 0;
        _amountController.text = _formatCurrency(amt.toInt().toString());
      } else { // Transaction
        // Global flexible lookup for common keys
        _descController.text = (d['description'] ?? d['desc'] ?? '').toString();
        _selectedDate = DateTime.tryParse((d['transaction_date'] ?? d['date'] ?? '').toString()) ?? DateTime.now();
        _selectedAccountId = (d['account_id'] ?? d['acc_id'])?.toString();
        _selectedCategoryId = (d['entity_category_id'] ?? d['category_id'] ?? d['constants_id'])?.toString();
        _selectedPayerId = (d['entity_id'] ?? d['payer_id'] ?? d['user_id'])?.toString();
        
        // Flexible payment method lookup
        final dynamic rawMethod = d['payment_method_id'] ?? d['payment_method'] ?? d['method'];
        if (rawMethod != null) {
          final String mStr = rawMethod.toString();
          // Safe case-insensitive lookup
          final int mIdx = _paymentMethods.indexWhere((m) => m.toLowerCase() == mStr.toLowerCase());
          if (mIdx != -1) {
            _selectedPaymentMethod = _paymentMethods[mIdx];
          } else {
            // Fallback: stay null or use first if invalid but dropdown safety will handle it
            _selectedPaymentMethod = null;
          }
        }

        // Flexible attachment/proof lookup
        _pickedFileName = (d['deposit_attachment'] ?? d['attachment'] ?? d['file_name'] ?? d['proof'])?.toString();

        final double amt = double.tryParse((d['amount'] ?? '0').toString()) ?? 0;
        _amountController.text = _formatCurrency(amt.toInt().toString());
      }
    } else {
      // Mode Add Baru — set default untuk payer & payment method
      _selectedPayerId = widget.userData['id']?.toString();
      _selectedPaymentMethod = 'Bank';
    }

    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    if (_selectedAccountId == null && widget.accounts.isNotEmpty) {
      _selectedAccountId = widget.accounts[0]['account_id']?.toString();
    }
    
    _fetchMeta();
    
    // Listener untuk format currency otomatis saat user mengetik amount
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final text = _amountController.text;
    // Hapus semua titik dulu untuk dapat angka murni
    final raw = text.replaceAll('.', '');
    if (raw.isEmpty) return;
    final formatted = _formatCurrency(raw);
    // Hanya update kalau beda supaya tidak infinite loop
    if (formatted != text) {
      _amountController.value = _amountController.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchMeta() async {
    try {
      final meta = await _financeService.getFinanceMeta();
      if (mounted) {
        setState(() {
          _incomeCategories = meta['data']['income_categories'] ?? [];
          _expenseCategories = meta['data']['expense_categories'] ?? [];
          _employees = meta['data']['employees'] ?? [];
        });
        debugPrint('Income Categories: ${_incomeCategories.length}');
        debugPrint('Expense Categories: ${_expenseCategories.length}');
      }
    } catch (e) {
      debugPrint('Error fetching meta: $e');
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _dateController.dispose();
    _descController.dispose();
    _accTitleController.dispose();
    _accNameController.dispose();
    _accNumberController.dispose();
    _cardNumberController.dispose();
    _branchCodeController.dispose();
    _bankBranchController.dispose();
    super.dispose();
  }

  String _formatCurrency(String value) {
    if (value.isEmpty) return "0";
    try {
      double val = double.parse(value.replaceAll('.', ''));
      String formatted = val.toInt().toString();
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return formatted.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    } catch (e) {
      return "0";
    }
  }

  Future<void> _selectDate() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
                ? const ColorScheme.dark(primary: Color(0xFF7E57C2), surface: Color(0xFF1E1E1E), onSurface: Colors.white)
                : const ColorScheme.light(primary: Color(0xFF7E57C2), onPrimary: Colors.white, onSurface: Colors.black87),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final isEdit = widget.initialData != null;
      if (_selectedType == 0) {
        // Save Account
        final accountData = {
          'user_id': widget.userData['id'].toString(),
          'account_name': _accTitleController.text,
          'nama_rekening': _accNameController.text,
          'initial_balance': _amountController.text.replaceAll('.', ''),
          'nomor_rekening': _accNumberController.text,
          'nomor_kartu': _cardNumberController.text,
          'bank': _selectedBank ?? '',
          'branch_code': _branchCodeController.text,
          'bank_branch': _bankBranchController.text,
        };

        if (isEdit) {
          accountData['account_id'] = widget.initialData!['account_id'].toString();
          await _financeService.updateFinanceAccount(accountData);
        } else {
          await _financeService.storeFinanceAccount(accountData);
        }
      } else {
        // Save Income/Expense
        final transactionData = {
          'user_id': widget.userData['id'].toString(),
          'account_id': _selectedAccountId!,
          'type': _selectedType == 1 ? 'income' : 'expense',
          'amount': _amountController.text.replaceAll('.', ''),
          'date': _dateController.text,
          'category_id': _selectedCategoryId ?? '',
          'payer_id': _selectedPayerId ?? '',
          'payment_method': _selectedPaymentMethod ?? '',
          'description': _descController.text,
        };

        if (isEdit) {
          transactionData['transaction_id'] = widget.initialData!['transaction_id'].toString();
          await _financeService.updateFinanceTransaction(transactionData, filePath: _pickedFilePath);
        } else {
          await _financeService.storeFinanceTransaction(transactionData, filePath: _pickedFilePath);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('main.error_with_msg'.tr(context, args: {'msg': e.toString()})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialData != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title: isEdit 
              ? (_selectedType == 0 ? 'finance.edit_account'.tr(context) : (_selectedType == 1 ? 'finance.edit_deposit'.tr(context) : 'finance.edit_expense'.tr(context)))
              : (_selectedType == 0 ? 'finance.add_account'.tr(context) : (_selectedType == 1 ? 'finance.add_deposit'.tr(context) : 'finance.add_expense'.tr(context))),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          children: [
            if (_selectedType == 0) ...[
              _buildSection(
                title: 'finance.account_info'.tr(context),
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF7E57C2),
                children: [
                  _buildTextField('finance.account_title'.tr(context), _accTitleController, Icons.title_rounded, required: true),
                  const SizedBox(height: 16),
                  _buildTextField('finance.account_holder_name'.tr(context), _accNameController, Icons.person_rounded, required: true),
                  const SizedBox(height: 16),
                  _buildTextField('finance.initial_balance'.tr(context), _amountController, Icons.money_rounded, isNumber: true, required: true),
                  const SizedBox(height: 16),
                  _buildTextField('finance.account_number'.tr(context), _accNumberController, Icons.numbers_rounded, required: true),
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: 'finance.bank_details'.tr(context),
                icon: Icons.business_rounded,
                color: Colors.indigo[700]!,
                children: [
                  _buildBankDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField('finance.card_number'.tr(context), _cardNumberController, Icons.credit_card_rounded, required: false),
                  const SizedBox(height: 16),
                  _buildTextField('finance.branch_code'.tr(context), _branchCodeController, Icons.code_rounded, required: false),
                  const SizedBox(height: 16),
                  _buildTextField('finance.bank_branch'.tr(context), _bankBranchController, Icons.location_on_rounded, required: false),
                ],
              ),
            ] else ...[
              _buildSection(
                title: 'finance.transaction_details'.tr(context),
                icon: Icons.receipt_long_rounded,
                color: _selectedType == 1 ? Colors.green[700]! : Colors.red[700]!,
                children: [
                  _buildAccountDropdown(),
                  const SizedBox(height: 16),
                  _buildTextField('finance.amount'.tr(context), _amountController, Icons.payments_rounded, isNumber: true, required: true),
                  const SizedBox(height: 16),
                  _buildDatePicker('finance.date'.tr(context)),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildPayerDropdown(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodDropdown(),
                  const SizedBox(height: 16),
                  _buildFilePickerSection(),
                  const SizedBox(height: 16),
                  _buildTextField('finance.description'.tr(context), _descController, Icons.description_rounded, maxLines: 3, required: false),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : color.withOpacity(0.1), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool required = true, bool readOnly = false, VoidCallback? onTap, int maxLines = 1}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      validator: required ? (val) => val == null || val.isEmpty ? 'main.required'.tr(context) : null : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF7E57C2).withOpacity(0.7)),
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }


  Widget _buildBankDropdown() {
    final String label = 'finance.bank'.tr(context);
    
    return SearchableDropdown(
      label: label,
      value: _selectedBank ?? '',
      options: _banks.map((bank) => {'id': bank, 'name': bank}).toList(),
      onSelected: (id) => setState(() => _selectedBank = id),
    );
  }

  Widget _buildAccountDropdown() {
    final String label = 'finance.account'.tr(context);
    
    // Find current selected name
    String selectedName = '';
    if (_selectedAccountId != null) {
      final acc = widget.accounts.firstWhere(
        (a) => a['account_id'].toString() == _selectedAccountId,
        orElse: () => null,
      );
      selectedName = acc?['account_name'] ?? '';
    }

    return SearchableDropdown(
      label: label,
      value: selectedName,
      options: widget.accounts.map((acc) => {
        'id': acc['account_id'].toString(),
        'name': (acc['account_name'] ?? 'No Name').toString(),
      }).toList(),
      onSelected: (id) => setState(() => _selectedAccountId = id),
      placeholder: 'finance.select_account'.tr(context),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = _selectedType == 1 ? _incomeCategories : _expenseCategories;
    final String label = 'finance.category'.tr(context);
    
    // Find current selected name
    String selectedName = '';
    if (_selectedCategoryId != null) {
      final cat = categories.firstWhere(
        (c) => c['constants_id'].toString() == _selectedCategoryId,
        orElse: () => null,
      );
      selectedName = cat?['category_name'] ?? '';
    }

    return SearchableDropdown(
      label: label,
      value: selectedName,
      options: categories.map((cat) => {
        'id': cat['constants_id'].toString(),
        'name': (cat['category_name'] ?? 'No Category').toString(),
      }).toList(),
      onSelected: (id) => setState(() => _selectedCategoryId = id),
    );
  }

  Widget _buildPayerDropdown() {
    final String label = 'finance.payer'.tr(context);
    
    // Find current selected name
    String selectedName = '';
    if (_selectedPayerId != null) {
      final emp = _employees.firstWhere(
        (e) => e['user_id'].toString() == _selectedPayerId,
        orElse: () => null,
      );
      if (emp != null) {
        selectedName = '${emp['first_name']} ${emp['last_name']}';
      }
    }

    return SearchableDropdown(
      label: label,
      value: selectedName,
      options: _employees.map((emp) => {
        'id': emp['user_id'].toString(),
        'name': '${emp['first_name']} ${emp['last_name']}'.toString(),
      }).toList(),
      onSelected: (id) => setState(() => _selectedPayerId = id),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return SearchableDropdown(
      label: 'finance.payment_method'.tr(context),
      value: _selectedPaymentMethod ?? '',
      options: _paymentMethods.map((method) => {
        'id': method,
        'name': 'finance.pm_${method.toLowerCase()}'.tr(context),
      }).toList(),
      onSelected: (id) => setState(() => _selectedPaymentMethod = id),
    );
  }

  Widget _buildDatePicker(String label) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 16, color: Color(0xFF7E57C2)),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerSection() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finance.attachment_proof'.tr(context),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pickedFilePath != null ? const Color(0xFF7E57C2) : (isDark ? Colors.white12 : Colors.grey[200]!),
                width: _pickedFilePath != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  (_pickedFilePath != null || _pickedFileName != null) ? Icons.file_present_rounded : Icons.cloud_upload_rounded,
                  color: const Color(0xFF7E57C2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pickedFileName ?? 'finance.choose_file_hint'.tr(context),
                    style: TextStyle(
                      color: _pickedFileName != null ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pickedFilePath != null || (widget.initialData != null && _pickedFileName != null))
                  IconButton(
                    onPressed: () => setState(() {
                      _pickedFilePath = null;
                      _pickedFileName = null;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _pickedFilePath = result.files.single.path;
          _pickedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedType == 0 ? 'finance.initial_balance'.tr(context) : 'finance.estimated_total'.tr(context),
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rp ${_formatCurrency(_amountController.text)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF7E57C2)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _selectedType == 0 ? 'finance.save_account'.tr(context) : 'finance.save_transaction'.tr(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
