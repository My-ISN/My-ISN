import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/secondary_app_bar.dart';

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
      _selectedType = d['transaction_type'] == 'income' ? 1 : 2;
      _descController.text = (d['description'] ?? '').toString();
      _selectedDate = DateTime.tryParse(d['transaction_date']?.toString() ?? '') ?? DateTime.now();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu'), backgroundColor: Colors.orange),
      );
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
        await _financeService.storePersonalBudget(budgetData);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {bool isNumber = false, bool required = true, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      validator: required ? (val) => val == null || val.isEmpty ? 'main.required'.tr(context) : null : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF7E57C2).withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2)),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = (_selectedType == 1 || _selectedType == 3) ? _incomeCategories : _expenseCategories;
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
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
          border: Border.all(color: Colors.grey[200]!),
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
                Text(
                  _selectedType == 3
                      ? DateFormat('MMMM yyyy').format(_selectedDate)
                      : DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7E57C2),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFF7E57C2).withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                'main.save'.tr(context),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
      ),
    );
  }
}
