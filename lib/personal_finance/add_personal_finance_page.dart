import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';
import '../widgets/custom_snackbar.dart';

class AddPersonalFinancePage extends StatefulWidget {
  final int initialType; // 1 = Income, 2 = Expense, 3 = Budget
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> userData;

  const AddPersonalFinancePage({
    super.key,
    this.initialType = 1,
    this.initialData,
    required this.userData,
  });

  @override
  State<AddPersonalFinancePage> createState() => _AddPersonalFinancePageState();
}

class _AddPersonalFinancePageState extends State<AddPersonalFinancePage> {
  final FinanceService _financeService = FinanceService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late int _selectedType;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();

  final List<String> _incomeCategories = [
    'Gaji',
    'Bonus',
    'THR',
    'Freelance',
    'Bisnis Sampingan',
    'Investasi',
    'Dividen',
    'Cashback',
    'Hadiah',
    'Lainnya',
  ];

  final List<String> _expenseCategories = [
    'Kebutuhan Pokok',
    'Transportasi',
    'Kesehatan',
    'Hiburan',
    'Pendidikan',
    'Cicilan/Utang',
    'Belanja',
    'Makan & Minum',
    'Lainnya',
  ];

  final List<String> _paymentMethods = [
    'Tunai',
    'Transfer Bank',
    'Kartu Kredit',
    'QRIS',
    'E-Wallet',
    'Cicilan',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    if (widget.initialData != null) {
      final d = widget.initialData!;
      final bool isBudget = d['type'] == 3;
      
      _selectedType = isBudget 
          ? 3 
          : (d['transaction_type'] == 'income' ? 1 : 2);
          
      _descController.text = (d['description'] ?? '').toString();
      
      // Handle Date/Month
      if (isBudget && d['budget_month'] != null) {
        _selectedDate = DateTime.tryParse("${d['budget_month']}-01") ?? DateTime.now();
      } else {
        _selectedDate = DateTime.tryParse(d['transaction_date']?.toString() ?? '') ?? DateTime.now();
      }
      
      _selectedCategory = d['category']?.toString();
      _selectedPaymentMethod = d['payment_method']?.toString();
      
      final double amt = double.tryParse(d['amount']?.toString() ?? '0') ?? 0;
      _amountController.text = _formatCurrency(amt.toInt().toString());
    } else {
      _selectedPaymentMethod = 'Tunai';
    }

    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final text = _amountController.text;
    final raw = text.replaceAll('.', '');
    if (raw.isEmpty) return;
    final formatted = _formatCurrency(raw);
    if (formatted != text) {
      _amountController.value = _amountController.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _dateController.dispose();
    _descController.dispose();
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
                ? const ColorScheme.dark(
                    primary: Color(0xFF7E57C2),
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF7E57C2),
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
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
    if (_selectedCategory == null) {
      context.showWarningSnackBar('Pilih kategori terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isEdit = widget.initialData != null;
      final amountRaw = _amountController.text.replaceAll('.', '');
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (_selectedType == 3) {
        // Handle Budget
        final budgetData = {
          'category': _selectedCategory!,
          'amount': amountRaw,
          'budget_month': DateFormat('yyyy-MM').format(_selectedDate),
        };
        
        if (isEdit) {
          await _financeService.updatePersonalBudget(budgetData);
        } else {
          await _financeService.storePersonalBudget(budgetData);
        }
      } else {
        // Handle Transaction
        final data = {
          'transaction_type': _selectedType == 1 ? 'income' : 'expense',
          'amount': amountRaw,
          'transaction_date': dateFormatted,
          'category': _selectedCategory!,
          'payment_method': _selectedPaymentMethod ?? '',
          'description': _descController.text,
        };

        if (isEdit) {
          data['id'] = widget.initialData!['id'].toString();
          await _financeService.updatePersonalFinanceTransaction(data);
        } else {
          await _financeService.storePersonalFinanceTransaction(data);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
          context.showErrorSnackBar('Gagal menyimpan: $e');
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
            ? (_selectedType == 1 ? 'finance.edit_deposit'.tr(context) : 'finance.edit_expense'.tr(context))
            : (_selectedType == 1
                ? 'finance.add_deposit'.tr(context)
                : (_selectedType == 2 ? 'finance.add_expense'.tr(context) : 'personal_finance.set_budget'.tr(context))),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            _buildSection(
              title: _selectedType == 3 ? 'Anggaran & Kategori' : 'finance.transaction_details'.tr(context),
              icon: _selectedType == 3 ? Icons.assignment_rounded : Icons.receipt_long_rounded,
              color: _selectedType == 1
                  ? Colors.green[700]!
                  : (_selectedType == 2 ? Colors.red[700]! : Colors.purple[700]!),
              children: [
                const SizedBox(height: 10),
                _buildTextField(
                  _selectedType == 3 ? 'Limit Anggaran' : 'finance.amount'.tr(context),
                  _amountController,
                  Icons.payments_rounded,
                  isNumber: true,
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildDatePicker(_selectedType == 3 ? 'finance.date'.tr(context) : 'finance.date'.tr(context)),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                if (_selectedType != 3) ...[
                  const SizedBox(height: 16),
                  _buildPaymentMethodDropdown(),
                ],
                if (_selectedType != 3) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    'finance.description'.tr(context),
                    _descController,
                    Icons.description_rounded,
                    maxLines: 3,
                    required: false,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }


  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.03) 
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.1) : color.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title, 
                  style: const TextStyle(
                    fontSize: 17, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5
                  )
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), 
            child: Column(children: children)
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, bool required = true, int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF7E57C2);
    
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      validator: required ? (val) => val == null || val.isEmpty ? 'main.required'.tr(context) : null : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 18, color: primaryColor.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08))
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08))
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: const BorderSide(color: primaryColor, width: 1.5)
        ),
        filled: true,
        fillColor: isDark 
            ? Colors.white.withValues(alpha: 0.03) 
            : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = (_selectedType == 1) ? _incomeCategories : _expenseCategories;
    return SearchableDropdown(
      label: 'finance.category'.tr(context),
      value: _selectedCategory ?? '',
      options: categories.map((cat) => {'id': cat, 'name': cat}).toList(),
      onSelected: (id) => setState(() => _selectedCategory = id),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return SearchableDropdown(
      label: 'finance.payment_method'.tr(context),
      value: _selectedPaymentMethod ?? '',
      options: _paymentMethods.map((m) => {'id': m, 'name': m}).toList(),
      onSelected: (id) => setState(() => _selectedPaymentMethod = id),
    );
  }

  Widget _buildDatePicker(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF7E57C2);

    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.03) 
              : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: primaryColor.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedType == 3 ? 'Bulan Anggaran *' : '$label *',
                    style: TextStyle(
                      fontSize: 11, 
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedType == 3
                        ? DateFormat('MMMM yyyy').format(_selectedDate)
                        : DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.05))),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7E57C2),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 58),
          elevation: 8,
          shadowColor: const Color(0xFF7E57C2).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(
                'main.save'.tr(context),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
      ),
    );
  }
}
