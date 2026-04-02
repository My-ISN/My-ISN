import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../localization/app_localizations.dart';
import '../services/finance_service.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import 'widgets/finance_account_item.dart';
import 'widgets/finance_transaction_item.dart';
import 'add_finance_data_page.dart';

class FinancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FinancePage({super.key, required this.userData});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _availableTabs = [];

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',').map((e) => e.trim()).toList();

    // Mapping legacy web permissions to new mobile granular permissions
    bool hasMobileView = resourceList.contains('mobile_finance_view') || resourceList.contains('mobile_finance_enable');
    bool hasMobileAddEdit = resourceList.contains('mobile_finance_add') || resourceList.contains('mobile_finance_enable');
    bool hasMobileDelete = resourceList.contains('mobile_finance_delete') || resourceList.contains('mobile_finance_enable');

    if (resource == 'finance6' || resource == 'finance5' || resource == 'finance1' || resource == 'hr_finance') {
      if (hasMobileView) return true;
    }
    if (resource == 'finance2' || resource == 'finance3') {
      if (hasMobileAddEdit) return true;
    }
    if (resource == 'finance4') {
      if (hasMobileDelete) return true;
    }
    
    return resourceList.contains(resource);
  }
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  bool _isHeaderExpanded = true;
  double _totalBalance = 0;
  double _monthlyExpense = 0;
  double _monthlyDeposit = 0;
  List<dynamic> _accounts = [];
  List<dynamic> _transactions = [];
  String _errorMessage = '';
  
  // Pagination & Filters (Transactions)
  int _currentPage = 1;
  int _totalCount = 0;
  int _selectedLimit = 10;
  String? _selectedMonth;
  String? _selectedYear;
  bool _isTransactionsLoading = false;

  // Pagination & Filters (Accounts)
  int _accountsPage = 1;
  int _accountsTotalCount = 0;
  int _accountsSelectedLimit = 10;
  bool _isAccountsLoading = false;

  final List<int> _limitOptions = [10, 25, 50, 100];
  final List<String> _years = List.generate(5, (index) => (DateTime.now().year - index).toString());
  final List<Map<String, String>> _months = [
    {'id': '01', 'name': 'january'},
    {'id': '02', 'name': 'february'},
    {'id': '03', 'name': 'march'},
    {'id': '04', 'name': 'april'},
    {'id': '05', 'name': 'may'},
    {'id': '06', 'name': 'june'},
    {'id': '07', 'name': 'july'},
    {'id': '08', 'name': 'august'},
    {'id': '09', 'name': 'september'},
    {'id': '10', 'name': 'october'},
    {'id': '11', 'name': 'november'},
    {'id': '12', 'name': 'december'},
  ];

  @override
  void initState() {
    super.initState();
    
    _availableTabs.clear();
    if (_hasPermission('finance5')) {
      _availableTabs.add({'title': 'finance.accounts', 'index': 0});
    }
    if (_hasPermission('finance1') || _hasPermission('hr_finance')) {
      _availableTabs.add({'title': 'finance.deposit', 'index': 1});
      _availableTabs.add({'title': 'finance.expense', 'index': 2});
      _availableTabs.add({'title': 'finance.transactions', 'index': 3});
    }

    _tabController = TabController(
      length: _availableTabs.isEmpty ? 1 : _availableTabs.length, 
      vsync: this
    );
    _tabController.addListener(_handleTabSelection);
    
    // Set default month/year for filter (current month)
    _selectedMonth = DateTime.now().month.toString().padLeft(2, '0');
    _selectedYear = DateTime.now().year.toString();
    
    _loadData();
  }

  void _handleTabSelection() {
    if (_availableTabs.isEmpty) return;
    final currentTab = _availableTabs[_tabController.index];
    if (currentTab['index'] == 0) {
      _accountsPage = 1;
      _fetchAccounts();
    } else {
      _currentPage = 1;
      _fetchTransactions();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    if (!_hasPermission('finance6')) {
        setState(() {
            _isLoading = false;
        });
        _fetchAccounts();
        _fetchTransactions();
        return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dashboard = await _financeService.getFinanceDashboard();
      
      if (mounted) {
        setState(() {
          _totalBalance = (dashboard['data']['total_balance'] as num).toDouble();
          _monthlyExpense = (dashboard['data']['monthly_expense'] as num).toDouble();
          _monthlyDeposit = (dashboard['data']['monthly_deposit'] as num).toDouble();
          _isLoading = false;
        });
        
        // Refresh all data
        _fetchAccounts();
        _fetchTransactions();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAccounts() async {
    if (!mounted) return;
    setState(() => _isAccountsLoading = true);

    try {
      final offset = (_accountsPage - 1) * _accountsSelectedLimit;
      final result = await _financeService.getFinanceAccounts(
        limit: _accountsSelectedLimit,
        offset: offset,
      );

      if (mounted) {
        setState(() {
          _accounts = result['data'] ?? [];
          _accountsTotalCount = result['pagination']['total'] ?? 0;
          _isAccountsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
      if (mounted) setState(() => _isAccountsLoading = false);
    }
  }

  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() => _isTransactionsLoading = true);

    try {
      String? type;
      if (_availableTabs.isNotEmpty) {
        final currentTabIndex = _availableTabs[_tabController.index]['index'];
        if (currentTabIndex == 1) type = 'income';
        if (currentTabIndex == 2) type = 'expense';
      }
      
      String? monthYear;
      if (_selectedMonth != null && _selectedYear != null) {
        monthYear = '$_selectedYear-$_selectedMonth';
      }

      final offset = (_currentPage - 1) * _selectedLimit;
      final result = await _financeService.getFinanceTransactions(
        type: type,
        monthYear: monthYear,
        limit: _selectedLimit,
        offset: offset,
      );

      if (mounted) {
        setState(() {
          _transactions = result['data'] ?? [];
          _totalCount = result['pagination']['total'] ?? 0;
          _isTransactionsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      if (mounted) setState(() => _isTransactionsLoading = false);
    }
  }

  void _showDeleteAccountConfirmation(Map<String, dynamic> account) {
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
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'finance.delete_account_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'finance.delete_account_confirm_msg'.tr(context, args: {'name': account['account_name'] ?? ''}),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performDeleteAccount(account['account_id'].toString());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _performDeleteAccount(String accountId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _financeService.deleteFinanceAccount(accountId);
      if (response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('finance.account_deleted_success'.tr(context)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
          _fetchAccounts();
          _loadData(); // Refresh dashboard stats
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
                  Expanded(child: Text(response['message'] ?? 'Failed to delete account')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performDeleteTransaction(String transactionId) async {
    setState(() => _isTransactionsLoading = true);
    try {
      final response = await _financeService.deleteFinanceTransaction(transactionId);
      if (response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('finance.transaction_deleted_success'.tr(context)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
          _loadData();
        }
      } else {
        throw Exception(response['message'] ?? 'finance.transaction_deleted_failed'.tr(context));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('main.error_with_msg'.tr(context, args: {'msg': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransactionsLoading = false);
    }
  }

  void _showTransactionDetail(Map<String, dynamic> transaction) {
    bool isIncome = transaction['transaction_type'] == 'income';
    Color primaryColor = isIncome ? Colors.green : Colors.red;
    String firstName = transaction['payer_first_name'] ?? '';
    String lastName = transaction['payer_last_name'] ?? '';
    String fullName = '$firstName $lastName'.trim();
    if (fullName.isEmpty) fullName = '-';
    String category = transaction['category_name'] ?? (isIncome ? 'Income' : 'Expense');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('finance.transaction_details'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFinanceDataPage(
                            accounts: _accounts,
                            initialType: isIncome ? 1 : 2,
                            initialData: transaction,
                            userData: widget.userData,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchTransactions();
                        _fetchAccounts();
                      }
                    } else if (value == 'web') {
                      _launchTransactionWebUrl(transaction);
                    } else if (value == 'delete') {
                      Navigator.pop(context);
                      _showDeleteTransactionConfirmation(transaction);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasPermission('finance2'))
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF7E57C2)),
                            const SizedBox(width: 12),
                            Text('finance.edit_transaction'.tr(context)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'web',
                      child: Row(
                        children: [
                          const Icon(Icons.launch_rounded, size: 20, color: Color(0xFF7E57C2)),
                          const SizedBox(width: 12),
                          Text('finance.open_web_ledger'.tr(context)),
                        ],
                      ),
                    ),
                    if (_hasPermission('finance4'))
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('finance.delete_transaction'.tr(context), style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} Rp ${_formatCurrency(transaction['amount'])}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      isIncome ? 'finance.income_deposit'.tr(context) : 'finance.expense_spending'.tr(context),
                      style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(Icons.person_rounded, 'finance.payer'.tr(context), fullName),
            const Divider(height: 32),
            _buildDetailRow(Icons.category_rounded, 'finance.category'.tr(context), category),
            const Divider(height: 32),
            _buildDetailRow(Icons.account_balance_wallet_rounded, 'finance.account'.tr(context), transaction['account_name'] ?? '-'),
            const Divider(height: 32),
            _buildDetailRow(Icons.calendar_today_rounded, 'finance.date'.tr(context), transaction['transaction_date'] ?? '-'),
            const SizedBox(height: 32),
            Text('finance.description'.tr(context), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Text(
                transaction['description']?.toString().isNotEmpty == true 
                    ? transaction['description'] 
                    : 'finance.no_description'.tr(context),
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            if (transaction['attachment_url'] != null && transaction['attachment_url'].toString().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('finance.attachment'.tr(context), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: transaction['attachment_url'].toString().toLowerCase().endsWith('.pdf')
                  ? InkWell(
                      onTap: () => launchUrl(Uri.parse(transaction['attachment_url']), mode: LaunchMode.externalApplication),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.red.withOpacity(0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('finance.view_pdf'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                    )
                  : Image.network(
                      transaction['attachment_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.grey.withOpacity(0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.broken_image_rounded, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text('finance.failed_load_image'.tr(context), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF7E57C2).withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Future<void> _launchTransactionWebUrl(Map<String, dynamic> transaction) async {
    final String? encodedId = transaction['encoded_transaction_id'];
    final dynamic transactionId = transaction['transaction_id'];

    if (encodedId == null || transactionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('finance.web_link_error'.tr(context))),
      );
      return;
    }

    // Generate MD5 Token (Must match backend secret)
    const String secret = 'foxgeen_mobile_transaction_secret_2024';
    final String token = md5.convert(utf8.encode('$transactionId$secret')).toString();
    
    final Uri url = Uri.parse('https://foxgeen.com/HRIS/erp/transaction-details/$encodedId?token=$token');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('finance.web_launch_error'.tr(context, args: {'item': 'transaction', 'id': transactionId.toString()}))),
        );
      }
    }
  }

  void _showAccountDetail(Map<String, dynamic> account) {
    Color primaryColor = const Color(0xFF7E57C2);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('finance.account_details'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddFinanceDataPage(
                            accounts: _accounts,
                            initialType: 0,
                            initialData: account,
                            userData: widget.userData,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchAccounts();
                      }
                    } else if (value == 'web') {
                      _launchAccountWebUrl(account);
                    } else if (value == 'delete') {
                      Navigator.pop(context);
                      _showDeleteAccountConfirmation(account);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasPermission('finance2'))
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF7E57C2)),
                            const SizedBox(width: 12),
                            Text('finance.edit_account'.tr(context)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'web',
                      child: Row(
                        children: [
                          Icon(Icons.launch_rounded, size: 20, color: primaryColor),
                          const SizedBox(width: 12),
                          Text('finance.open_web_ledger'.tr(context)),
                        ],
                      ),
                    ),
                    if (_hasPermission('finance4'))
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('finance.delete_account'.tr(context), style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Rp ${_formatCurrency(account['account_balance'])}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'finance.current_balance_caps'.tr(context),
                      style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(Icons.account_balance_wallet_rounded, 'finance.account_name'.tr(context), account['account_name'] ?? '-'),
            const Divider(height: 32),
            _buildDetailRow(Icons.account_balance_rounded, 'finance.bank'.tr(context), account['bank'] ?? '-'),
            const Divider(height: 32),
            _buildDetailRow(Icons.numbers_rounded, 'finance.account_number'.tr(context), account['account_number'] ?? '-'),
            const Divider(height: 32),
            _buildDetailRow(Icons.location_on_rounded, 'finance.branch'.tr(context), account['bank_branch'] ?? '-'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _launchAccountWebUrl(Map<String, dynamic> account) async {
    final String? encodedId = account['encoded_account_id'];
    final dynamic accountId = account['account_id'];

    if (encodedId == null || accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('finance.web_link_error'.tr(context))),
      );
      return;
    }

    // Generate MD5 Token (Must match backend secret)
    const String secret = 'foxgeen_mobile_transaction_secret_2024';
    final String token = md5.convert(utf8.encode('$accountId$secret')).toString();
    
    final Uri url = Uri.parse('https://foxgeen.com/HRIS/erp/account-ledger/$encodedId?token=$token');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('finance.web_launch_error'.tr(context, args: {'item': 'account', 'id': accountId.toString()}))),
        );
      }
    }
  }

  void _showDeleteTransactionConfirmation(Map<String, dynamic> transaction) {
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
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'finance.delete_transaction_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'finance.delete_transaction_confirm_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performDeleteTransaction(transaction['transaction_id'].toString());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "0";
    double val = double.tryParse(amount.toString()) ?? 0;
    
    // If it's a whole number, don't show decimals
    if (val == val.toInt()) {
      String formatted = val.toInt().toString();
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return formatted.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    }
    
    // Otherwise show 2 decimals with comma
    String formatted = val.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    integerPart = integerPart.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return "$integerPart,$decimalPart";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        title: 'finance.title'.tr(context),
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'finance'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : Column(
            children: [
              _buildFinanceHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _availableTabs.map((tab) {
                    final int idx = tab['index'];
                    if (idx == 0) return _buildAccountsTab();
                    return _buildTransactionTab(); 
                  }).toList(),
                ),
              ),
            ],
          ),
      floatingActionButton: (!_hasPermission('finance2') || (_availableTabs.isNotEmpty && _availableTabs[_tabController.index]['index'] == 3)) 
        ? null 
        : FloatingActionButton.extended(
            onPressed: () async {
              if (_availableTabs.isEmpty) return;
              // 0 = Accounts, 1 = Deposit, 2 = Expense, 3 = All
              int initialType = _availableTabs[_tabController.index]['index'];
              if (initialType > 2) initialType = 1; // Default to Income if on 'All' tab

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddFinanceDataPage(
                    accounts: _accounts,
                    initialType: initialType,
                    userData: widget.userData,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data saved successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                }
              }
            },
            backgroundColor: const Color(0xFF7E57C2),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Icon(
              _availableTabs.isEmpty ? Icons.add : (
              _availableTabs[_tabController.index]['index'] == 0 
                ? Icons.account_balance_wallet_rounded 
                : (_availableTabs[_tabController.index]['index'] == 1 ? Icons.add_chart_rounded : Icons.shopping_cart_checkout_rounded)),
              color: Colors.white,
            ),
            label: Text(
              _availableTabs.isEmpty ? 'Add' : (
              _availableTabs[_tabController.index]['index'] == 0 
                ? 'finance.add_account'.tr(context) 
                : (_availableTabs[_tabController.index]['index'] == 1 ? 'finance.add_deposit'.tr(context) : 'finance.add_expense'.tr(context))),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
    );
  }

  Widget _buildFinanceHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: GestureDetector(
        onTap: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: Colors.white24)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'finance.total_balance'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Icon(
                      _isHeaderExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'IDR ${_formatCurrency(_totalBalance)}',
                  style: TextStyle(
                    fontSize: _isHeaderExpanded ? 24 : 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7E57C2),
                  ),
                ),
                if (_isHeaderExpanded) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportStat(
                          _monthlyDeposit,
                          'finance.deposit'.tr(context),
                          isIncome: true,
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: _buildReportStat(
                            _monthlyExpense,
                            'finance.expense'.tr(context),
                            isIncome: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportStat(double amount, String label, {bool isIncome = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            _buildThisMonthBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Rp ${_formatCurrency(amount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green[600] : Colors.red[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    if (_availableTabs.isEmpty) return const SizedBox.shrink();
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: _availableTabs.map((tab) => Tab(text: (tab['title'] as String).tr(context))).toList(),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Show Limit
              Row(
                children: [
                  Text(
                    'rent_plan.show'.tr(context),
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  _buildAccountsLimitDropdown(),
                ],
              ),
              // Right: Total Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'rent_plan.total_count'.tr(context, args: {'count': _accountsTotalCount.toString()}),
                  style: const TextStyle(
                    color: Color(0xFF7E57C2),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAccounts,
            child: _isAccountsLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7E57C2)))
              : _accounts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) => FinanceAccountItem(
                      account: _accounts[index],
                      onTap: () => _showAccountDetail(_accounts[index]),
                    ),
                  ),
          ),
        ),
        if (_accounts.isNotEmpty && _accountsTotalCount > _accountsSelectedLimit) 
          Padding(
            padding: const EdgeInsets.only(bottom: 32, top: 8),
            child: _buildAccountsPagination(),
          ),
      ],
    );
  }

  Widget _buildAccountsLimitDropdown() {
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
          value: _accountsSelectedLimit,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF7E57C2)),
          style: const TextStyle(
            color: Color(0xFF7E57C2), 
            fontWeight: FontWeight.bold, 
            fontSize: 13
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _accountsSelectedLimit = newValue;
                _accountsPage = 1;
              });
              _fetchAccounts();
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

  Widget _buildAccountsPagination() {
    int totalPages = (_accountsTotalCount / _accountsSelectedLimit).ceil();
    if (totalPages <= 0) totalPages = 1;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _accountsPage > 1 ? () {
            setState(() => _accountsPage--);
            _fetchAccounts();
          } : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7E57C2).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'rent_plan.page_x_of_y'.tr(context, args: {
              'current': _accountsPage.toString(),
              'total': totalPages.toString(),
            }),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _accountsPage < totalPages ? () {
            setState(() => _accountsPage++);
            _fetchAccounts();
          } : null,
        ),
      ],
    );
  }

  Widget _buildThisMonthBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'finance.this_month'.tr(context).toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTransactionTab() {
    return RefreshIndicator(
      onRefresh: _fetchTransactions,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildTransactionFilters(),
            ),
          ),
          if (_isTransactionsLoading && _transactions.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_transactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => FinanceTransactionItem(
                    transaction: _transactions[index],
                    onTap: () => _showTransactionDetail(_transactions[index]),
                  ),
                  childCount: _transactions.length,
                ),
              ),
            ),
          
          if (_totalCount > _selectedLimit && !_isTransactionsLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _buildPagination(),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildTransactionFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Group: Show [Limit] [DatePicker]
        Row(
          children: [
            Text(
              'rent_plan.show'.tr(context),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            _buildLimitDropdown(),
            const SizedBox(width: 8),
            // DatePicker (Month-Year)
            InkWell(
              onTap: _showMonthYearPicker,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF7E57C2)),
                    const SizedBox(width: 6),
                    Text(
                      '${_months.firstWhere((m) => m['id'] == _selectedMonth)['name']!.tr(context).substring(0, 3)} $_selectedYear',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Right Group: Total Badge (Pill version like Image 2)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'rent_plan.total_count'.tr(context, args: {'count': _totalCount.toString()}),
            style: const TextStyle(
              color: Color(0xFF7E57C2),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitDropdown() {
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF7E57C2)),
          style: const TextStyle(
            color: Color(0xFF7E57C2), 
            fontWeight: FontWeight.bold, 
            fontSize: 13
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchTransactions();
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
            _fetchTransactions();
          } : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7E57C2).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'rent_plan.page_x_of_y'.tr(context, args: {
              'current': _currentPage.toString(),
              'total': totalPages.toString(),
            }),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < totalPages ? () {
            setState(() => _currentPage++);
            _fetchTransactions();
          } : null,
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
                : const Color(0xFF7E57C2), 
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded, 
              size: 48, 
              color: Color(0xFF7E57C2)
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'main.no_data'.tr(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try filtering with a different month',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'finance.choose_period'.tr(context),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _years.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _years[index] == _selectedYear;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(_years[index]),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => _selectedYear = _years[index]);
                            setState(() => _selectedYear = _years[index]);
                          }
                        },
                        selectedColor: const Color(0xFF7E57C2).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF7E57C2) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF7E57C2) : Colors.grey.withOpacity(0.1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final int monthId = int.parse(_months[index]['id']!);
                  final int selectedYearInt = int.parse(_selectedYear!);
                  final DateTime now = DateTime.now();
                  
                  // Disable if month is in the future
                  bool isFuture = (selectedYearInt > now.year) || 
                                 (selectedYearInt == now.year && monthId > now.month);
                  
                  bool isSelected = _months[index]['id'] == _selectedMonth;
                  
                  return InkWell(
                    onTap: isFuture ? null : () {
                      setModalState(() => _selectedMonth = _months[index]['id']!);
                      setState(() {
                        _selectedMonth = _months[index]['id']!;
                        _currentPage = 1;
                      });
                      Navigator.pop(context);
                      _fetchTransactions();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF7E57C2) 
                            : (isFuture ? Colors.transparent : Theme.of(context).cardColor),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF7E57C2) 
                              : (isFuture ? Colors.grey.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
                        ),
                      ),
                      child: Text(
                        _months[index]['name']!.tr(context),
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isFuture ? Colors.grey[300] : Colors.grey[500]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
