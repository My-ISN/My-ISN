import '../services/finance_service.dart';
import '../finance/widgets/finance_transaction_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import '../widgets/side_drawer.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/period_filter_widget.dart';
import '../widgets/custom_snackbar.dart';

import 'add_personal_finance_page.dart';

// ... (rest of imports)

class PersonalFinancePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PersonalFinancePage({super.key, required this.userData});

  @override
  State<PersonalFinancePage> createState() => _PersonalFinancePageState();
}

class _PersonalFinancePageState extends State<PersonalFinancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color _primaryColor = const Color(0xFF7E57C2);
  bool isLoading = true;
  bool isSummaryExpanded = false;
  Map<String, dynamic>? dashboardData;
  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final storage = const FlutterSecureStorage();
  final FinanceService _financeService = FinanceService();

  // Transaction State
  List<Map<String, dynamic>> _incomeTransactions = [];
  List<Map<String, dynamic>> _expenseTransactions = [];
  bool _isTransactionsLoading = false;
  bool _hasLoadedIncome = false;
  bool _hasLoadedExpense = false;
  int _incomeCurrentPage = 1;
  int _expenseCurrentPage = 1;
  int _incomeTotalCount = 0;
  int _expenseTotalCount = 0;
  int _selectedLimit = 10;
  String? _selectedMonth;
  String? _selectedYear;
  String? _selectedReportYear;
  Map<String, dynamic>? reportData;
  bool _isReportLoading = false;
  bool _hasLoadedReport = false;

  final List<int> _limitOptions = [10, 20, 50, 100];
  final List<Map<String, String>> _months = [
    {'id': '01', 'name': 'month_jan'},
    {'id': '02', 'name': 'month_feb'},
    {'id': '03', 'name': 'month_march'},
    {'id': '04', 'name': 'month_april'},
    {'id': '05', 'name': 'month_may'},
    {'id': '06', 'name': 'month_june'},
    {'id': '07', 'name': 'month_july'},
    {'id': '08', 'name': 'month_aug'},
    {'id': '09', 'name': 'month_sep'},
    {'id': '10', 'name': 'month_oct'},
    {'id': '11', 'name': 'month_nov'},
    {'id': '12', 'name': 'month_dec'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateFormat('MM').format(DateTime.now());
    _selectedYear = DateFormat('yyyy').format(DateTime.now());
    _selectedReportYear = _selectedYear;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchDashboardData();
  }

  void _handleTabSelection() {
    setState(() {}); // Trigger rebuild to update FAB label
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1 && !_hasLoadedIncome) {
        _fetchTransactions(type: 'income');
      } else if (_tabController.index == 2 && !_hasLoadedExpense) {
        _fetchTransactions(type: 'expense');
      } else if (_tabController.index == 3 && !_hasLoadedReport) {
        _fetchReportData();
      } else if (_tabController.index == 0) {
        _fetchDashboardData(silent: true);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool silent = false}) async {
    if (!_hasPermission('mobile_personal_finance_view')) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    if (!silent || dashboardData == null) {
      setState(() => isLoading = true);
    }
    try {
      final monthYear = (_selectedYear != null && _selectedMonth != null)
          ? '$_selectedYear-$_selectedMonth'
          : DateFormat('yyyy-MM').format(DateTime.now());

      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/get_personal_finance_dashboard',
        ),
        body: {'month_year': monthYear},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        if (status == 'success' || status == true) {
          setState(() {
            dashboardData = data['data'];
            isLoading = false;
          });
        } else {
          debugPrint('API Error (Status: $status): ${data['message']}');
          setState(() => isLoading = false);
        }
      } else {
        debugPrint('Server Error: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching finance dashboard: $e');
      setState(() => isLoading = false);
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchReportData() async {
    if (!_hasPermission('mobile_personal_finance_view')) return;
    setState(() => _isReportLoading = true);
    try {
      final response = await _financeService.getPersonalFinanceReport(
        year: _selectedReportYear,
      );

      if (response['status']) {
        setState(() {
          reportData = response['data'];
          _isReportLoading = false;
          _hasLoadedReport = true;
        });
      } else {
        setState(() => _isReportLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      setState(() => _isReportLoading = false);
    }
  }

  Future<void> _deleteTransaction(String id, String type) async {
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
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'finance.delete_transaction'.tr(context),
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'finance.delete_transaction_confirm_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _performActualDelete(id, type);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Future<void> _performActualDelete(String id, String type) async {
    try {
      final response = await _financeService.deletePersonalFinanceTransaction(
        id,
        type,
      );

      if (response['status']) {
        if (mounted) {
          context.showSuccessSnackBar('finance.transaction_deleted_success'.tr(context));
          _fetchTransactions(type: type);
          _fetchDashboardData();
        }
      } else {
        throw Exception(response['message'] ?? 'Gagal menghapus transaksi');
      }
    } catch (e) {
      if (mounted) {
          context.showErrorSnackBar('Gagal menghapus: $e');
      }
    }
  }

  Future<void> _openEditPage(
    Map<String, dynamic> transaction,
    String type,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPersonalFinancePage(
          initialData: transaction,
          userData: widget.userData,
        ),
      ),
    );
    if (result == true) {
      _fetchTransactions(type: type);
      _fetchDashboardData();
    }
  }

  Future<void> _openEditBudgetPage(Map<String, dynamic> budget) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPersonalFinancePage(
          initialData: {
            ...budget,
            'type': 3, // Budget type
            'amount': budget['budget_amount'],
            'category': budget['category_name'],
          },
          userData: widget.userData,
        ),
      ),
    );
    if (result == true) {
      _fetchDashboardData();
    }
  }

  void _showTransactionDetail(Map<String, dynamic> transaction, String type) {
    final bool isIncome = type == 'income';
    final Color primaryColor = isIncome ? Colors.green : Colors.red;
    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: '',
      decimalDigits: 0,
    );
    final amount =
        double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'finance.transaction_details'.tr(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.grey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    Navigator.pop(context); // Close BottomSheet
                    if (value == 'edit') {
                      _openEditPage(transaction, type);
                    } else if (value == 'delete') {
                      _deleteTransaction(transaction['id'].toString(), type);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasPermission('mobile_personal_finance_edit'))
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF7E57C2),
                            ),
                            const SizedBox(width: 12),
                            Text('finance.edit_transaction'.tr(context)),
                          ],
                        ),
                      ),
                    if (_hasPermission('mobile_personal_finance_delete'))
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'finance.delete_transaction'.tr(context),
                              style: const TextStyle(color: Colors.red),
                            ),
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
                    '${isIncome ? '+' : '-'} Rp ${currencyFormat.format(amount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isIncome
                          ? 'finance.income_deposit'.tr(context)
                          : 'finance.expense_spending'.tr(context),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              Icons.category_rounded,
              'finance.category'.tr(context),
              transaction['category_name'] ?? '-',
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.calendar_today_rounded,
              'finance.date'.tr(context),
              transaction['transaction_date'] ?? '-',
            ),
            const SizedBox(height: 32),
            Text(
              'finance.description'.tr(context),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Text(
                transaction['description']?.toString().isNotEmpty == true
                    ? transaction['description']
                    : 'finance.no_description'.tr(context),
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF7E57C2).withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'my_wallet'),
      appBar: CustomAppBar(
        userData: widget.userData,
        title: "My ISN",
        showBackButton: false,
      ),
      body: !_hasPermission('mobile_personal_finance_view')
          ? _buildUnauthorizedView()
          : isLoading
          ? _buildShimmerLoading()
          : Column(
              children: [
                _buildSummaryCard(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildTransactionTab('income'),
                      _buildTransactionTab('expense'),
                      _buildReportTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton:
          (!_hasPermission('mobile_personal_finance_add') ||
              _tabController.index == 3)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (_tabController.index == 0) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPersonalFinancePage(
                        initialType: 3,
                        userData: widget.userData,
                      ),
                    ),
                  );
                  if (result == true) _fetchDashboardData();
                  return;
                }

                if (_tabController.index == 3) return;

                final int type = _tabController.index == 2 ? 2 : 1;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPersonalFinancePage(
                      initialType: type,
                      userData: widget.userData,
                    ),
                  ),
                );
                if (result == true) {
                  _fetchDashboardData();
                  if (_tabController.index == 1) {
                    _fetchTransactions(type: 'income');
                  } else if (_tabController.index == 2) {
                    _fetchTransactions(type: 'expense');
                  }
                }
              },
              backgroundColor: _primaryColor,
              icon: Icon(_getFabIcon(), color: Colors.white, size: 24),
              label: Text(
                _getFabLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
    );
  }

  String _getFabLabel() {
    switch (_tabController.index) {
      case 0:
        return 'personal_finance.add_budget'.tr(context);
      case 1:
        return 'personal_finance.add_income'.tr(context);
      case 2:
        return 'personal_finance.add_expense'.tr(context);
      case 3:
        return '';
      default:
        return 'personal_finance.add_income'.tr(context);
    }
  }

  IconData _getFabIcon() {
    switch (_tabController.index) {
      case 0:
        return Icons.track_changes_rounded; // Budget/Goal
      case 1:
        return Icons.trending_up_rounded; // Income
      case 2:
        return Icons.trending_down_rounded; // Expense
      case 3:
        return Icons.assessment_rounded; // Report
      default:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildOverviewTab() {
    if (dashboardData == null) return const SizedBox.shrink();
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                PeriodFilterButton(
                  selectedMonth: _selectedMonth ?? '01',
                  selectedYear: _selectedYear ?? DateTime.now().year.toString(),
                  months: _months,
                  onTap: _showMonthYearPicker,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTrendChartSection(),
            const SizedBox(height: 24),
            _buildCategoryChartSection(),
            const SizedBox(height: 24),
            _buildBudgetSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTab(String type) {
    final bool isIncome = type == 'income';
    final List<Map<String, dynamic>> transactions = isIncome
        ? _incomeTransactions
        : _expenseTransactions;
    final int totalCount = isIncome ? _incomeTotalCount : _expenseTotalCount;

    return RefreshIndicator(
      onRefresh: () => _fetchTransactions(type: type),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isTransactionsLoading &&
                (transactions.isEmpty ||
                    (isIncome ? _incomeCurrentPage : _expenseCurrentPage) == 1))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTransactionShimmer(),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildTransactionFilters(type),
                ),
              ),
              if (transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final transaction = transactions[index];
                      return FinanceTransactionItem(
                        transaction: transaction,
                        onTap: () => _showTransactionDetail(transaction, type),
                      );
                    }, childCount: transactions.length),
                  ),
                ),
            ],
            if (totalCount > _selectedLimit && !_isTransactionsLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _buildPagination(type),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchTransactions({String? type}) async {
    final String transactionType =
        type ?? (_tabController.index == 1 ? 'income' : 'expense');
    final isIncome = transactionType == 'income';
    final int currentPage = isIncome ? _incomeCurrentPage : _expenseCurrentPage;

    setState(() => _isTransactionsLoading = true);
    try {
      final response = await _financeService.getPersonalFinanceTransactions(
        type: transactionType,
        limit: _selectedLimit,
        offset: (currentPage - 1) * _selectedLimit,
        monthYear: _selectedMonth != null && _selectedYear != null
            ? '$_selectedYear-$_selectedMonth'
            : null,
      );

      if (response['status']) {
        final List<Map<String, dynamic>> results = (response['data'] as List)
            .map((t) {
              final Map<String, dynamic> transactionMap =
                  Map<String, dynamic>.from(t);
              return {
                ...transactionMap,
                'id': isIncome
                    ? transactionMap['income_id']
                    : transactionMap['expense_id'],
                'transaction_type': transactionType,
                'transaction_date': isIncome
                    ? transactionMap['income_date']
                    : transactionMap['expense_date'],
                'category_name': transactionMap['category'],
              };
            })
            .toList();

        setState(() {
          if (isIncome) {
            _incomeTransactions = results;
            _incomeTotalCount = response['total'] ?? 0;
            _hasLoadedIncome = true;
          } else {
            _expenseTransactions = results;
            _expenseTotalCount = response['total'] ?? 0;
            _hasLoadedExpense = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isTransactionsLoading = false);
    }
  }

  Widget _buildTransactionFilters(String type) {
    final bool isIncome = type == 'income';
    final int totalCount = isIncome ? _incomeTotalCount : _expenseTotalCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'rent_plan.show'.tr(context),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            _buildLimitDropdown(type),
            const SizedBox(width: 8),
            PeriodFilterButton(
              selectedMonth: _selectedMonth ?? '01',
              selectedYear: _selectedYear ?? DateTime.now().year.toString(),
              months: _months,
              onTap: _showMonthYearPicker,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'rent_plan.total_count'.tr(
              context,
              args: {'count': totalCount.toString()},
            ),
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

  Widget _buildLimitDropdown(String type) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: _primaryColor,
          ),
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                if (type == 'income') {
                  _incomeCurrentPage = 1;
                } else {
                  _expenseCurrentPage = 1;
                }
              });
              _fetchTransactions(type: type);
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

  Widget _buildPagination(String type) {
    final bool isIncome = type == 'income';
    final int totalCount = isIncome ? _incomeTotalCount : _expenseTotalCount;
    final int currentPage = isIncome ? _incomeCurrentPage : _expenseCurrentPage;

    int totalPages = (totalCount / _selectedLimit).ceil();
    if (totalPages <= 0) totalPages = 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: currentPage > 1
              ? () {
                  setState(() {
                    if (isIncome) {
                      _incomeCurrentPage--;
                    } else {
                      _expenseCurrentPage--;
                    }
                  });
                  _fetchTransactions(type: type);
                }
              : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'rent_plan.page_x_of_y'.tr(
              context,
              args: {
                'current': currentPage.toString(),
                'total': totalPages.toString(),
              },
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: currentPage < totalPages
              ? () {
                  setState(() {
                    if (isIncome) {
                      _incomeCurrentPage++;
                    } else {
                      _expenseCurrentPage++;
                    }
                  });
                  _fetchTransactions(type: type);
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? Colors.grey[400]
                : _primaryColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              size: 64,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Akses Terbatas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Anda tidak memiliki izin untuk melihat modul Personal Finance. Silakan hubungi admin untuk mendapatkan akses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
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
              color: _primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'personal_finance.on_progress_desc'.tr(context),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() {
    final List<String> years = List.generate(
      5,
      (index) => (DateTime.now().year - index).toString(),
    );

    PeriodPickerSheet.show(
      context: context,
      initialMonth: _selectedMonth ?? '01',
      initialYear: _selectedYear ?? DateTime.now().year.toString(),
      months: _months,
      years: years,
      onApply: (month, year) {
        setState(() {
          _selectedMonth = month;
          _selectedYear = year;
          _incomeCurrentPage = 1;
          _expenseCurrentPage = 1;
          _incomeTransactions = [];
          _expenseTransactions = [];
          _hasLoadedIncome = false;
          _hasLoadedExpense = false;
        });
        // Reload based on current tab
        if (_tabController.index == 1) {
          _fetchTransactions(type: 'income');
        } else if (_tabController.index == 2) {
          _fetchTransactions(type: 'expense');
        }
        _fetchDashboardData();
      },
    );
  }

  Widget _buildSummaryCard() {
    final bool isReportTab = _tabController.index == 3;
    final data = isReportTab ? reportData : dashboardData;

    final summary = data?['summary'];
    final double income = summary != null
        ? (double.tryParse(summary['total_income'].toString()) ?? 0)
        : 0;
    final double expense = summary != null
        ? (double.tryParse(summary['total_expense'].toString()) ?? 0)
        : 0;
    final double balance = summary != null
        ? (double.tryParse(summary['net_balance'].toString()) ?? 0)
        : 0;
    final String ratio = summary?['expense_ratio'] ?? '0%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: GestureDetector(
        onTap: () => setState(() => isSummaryExpanded = !isSummaryExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
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
                      isReportTab
                          ? 'personal_finance.annual_balance'.tr(context)
                          : 'personal_finance.net_balance'.tr(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSummaryExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                data == null && !isReportTab
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : data == null && isReportTab
                    ? const SizedBox(height: 24) // Placeholder without shimmer
                    : Text(
                        'IDR ${currencyFormat.format(balance).replaceAll('Rp', '').trim()}',
                        style: TextStyle(
                          fontSize: isSummaryExpanded ? 24 : 20,
                          fontWeight: FontWeight.w900,
                          color: _primaryColor,
                        ),
                      ),
                if (isSummaryExpanded) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          income,
                          'personal_finance.income'.tr(context),
                          isIncome: true,
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: _buildSummaryItem(
                            expense,
                            'personal_finance.expense'.tr(context),
                            isIncome: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isReportTab) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 18,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'personal_finance.expense_ratio'.tr(context),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            ratio,
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    double amount,
    String label, {
    bool isIncome = true,
  }) {
    final bool isReportTab = _tabController.index == 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (isReportTab
                        ? 'finance.this_year'.tr(context)
                        : 'finance.this_month'.tr(context))
                    .toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF7E57C2),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Rp ${currencyFormat.format(amount).replaceAll('Rp', '').trim()}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: _primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'personal_finance.overview'.tr(context)),
          Tab(text: 'personal_finance.income'.tr(context)),
          Tab(text: 'personal_finance.expense'.tr(context)),
          Tab(text: 'personal_finance.report'.tr(context)),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection() {
    final List trendData = dashboardData?['trends'] ?? [];
    if (trendData.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'personal_finance.six_month_trend'.tr(context),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[index]['month_short'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                minX: 0,
                maxX: (trendData.length - 1).toDouble(),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (double.tryParse(e.value['income'].toString()) ?? 0) /
                            1000,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.greenAccent.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (double.tryParse(e.value['expense'].toString()) ?? 0) /
                            1000,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.orangeAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orangeAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('Income', Colors.greenAccent),
              const SizedBox(width: 16),
              _buildChartLegend('Expense', Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartSection() {
    final List categories = dashboardData?['categories'] ?? [];
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'personal_finance.expense_by_category'.tr(context),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Legend di Kiri
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: categories.asMap().entries.map((e) {
                        final data = e.value;
                        final categoryName = data['category'] ?? 'General';
                        final amount =
                            double.tryParse(data['amount'].toString()) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildCategoryStatRow(
                            categoryName,
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(amount),
                            _getCategoryColor(categoryName),
                            isCompact: true,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chart di Kanan
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 38,
                              sections: categories.asMap().entries.map((e) {
                                final data = e.value;
                                final categoryName =
                                    data['category'] ?? 'General';
                                final val =
                                    double.tryParse(
                                      data['percentage'].toString(),
                                    ) ??
                                    0;
                                return PieChartSectionData(
                                  value: val > 0 ? val : 1, // Fallback visual
                                  showTitle: false,
                                  radius: 12,
                                  color: _getCategoryColor(categoryName),
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).hintColor.withValues(alpha: 0.5),
                                ),
                              ),
                              FittedBox(
                                child: Text(
                                  NumberFormat.compactCurrency(
                                    locale: 'id',
                                    symbol: 'Rp',
                                    decimalDigits: 0,
                                  ).format(
                                    double.tryParse(
                                          dashboardData!['summary']['total_expense']
                                              .toString(),
                                        ) ??
                                        0,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetSection() {
    if (dashboardData == null || dashboardData!['budgets'] == null) {
      return const SizedBox.shrink();
    }
    final List budgets = dashboardData!['budgets'];
    if (budgets.isEmpty) return const SizedBox.shrink();

    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'IDR ',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    size: 20,
                    color: Color(0xFF7E57C2).withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'finance.budget'.tr(context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: budgets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final double limit =
                  double.tryParse(budget['budget_amount'].toString()) ?? 0;
              final double actual =
                  double.tryParse(budget['actual_amount'].toString()) ?? 0;
              final double progress = (limit > 0) ? (actual / limit) : 0;
              final int percent = (progress * 100).toInt();

              Color progressColor = Colors.green;
              if (progress >= 1.0) {
                progressColor = Colors.red;
              } else if (progress >= 0.8) {
                progressColor = Colors.orange;
              }

              return InkWell(
                onTap: () => _showBudgetDetail(budget),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              budget['category_name'] ?? 'General',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${currencyFormat.format(actual)} / ${currencyFormat.format(limit)} ($percent%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBudgetDetail(Map<String, dynamic> budget) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id',
      symbol: 'IDR ',
      decimalDigits: 0,
    );

    final double limit =
        double.tryParse(budget['budget_amount'].toString()) ?? 0;
    final double actual =
        double.tryParse(budget['actual_amount'].toString()) ?? 0;
    final double remaining = limit - actual;
    final double progress = (limit > 0) ? (actual / limit) : 0;
    final int percent = (progress * 100).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
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
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'finance.budget_details'.tr(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.grey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      _openEditBudgetPage(budget);
                    } else if (value == 'delete') {
                      Navigator.pop(context);
                      _deleteBudget(budget['category_name']);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasPermission('mobile_personal_finance_edit'))
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF7E57C2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'finance.edit_budget'.tr(context),
                              style: const TextStyle(color: Color(0xFF7E57C2)),
                            ),
                          ],
                        ),
                      ),
                    if (_hasPermission('mobile_personal_finance_delete'))
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'finance.delete_budget'.tr(context),
                              style: const TextStyle(color: Colors.red),
                            ),
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
                    currencyFormat.format(remaining),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: remaining < 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (remaining < 0 ? Colors.red : Colors.green)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'finance.remaining_budget'.tr(context).toUpperCase(),
                      style: TextStyle(
                        color: remaining < 0 ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              Icons.category_rounded,
              'finance.category'.tr(context),
              budget['category_name'] ?? '-',
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.calendar_today_rounded,
              'finance.budget_period'.tr(context),
              '$_selectedYear-$_selectedMonth'.split('-').reversed.join(' '),
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.assistant_photo_rounded,
              'finance.budget_limit'.tr(context),
              currencyFormat.format(limit),
            ),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.shopping_cart_rounded,
              'finance.actual_spending'.tr(context),
              currencyFormat.format(actual),
              valueColor: progress >= 1.0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 32),
            const Text(
              'Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.red : Colors.green,
                    ),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percent% ${'finance.used'.tr(context)}',
                  style: TextStyle(
                    color: progress >= 1.0 ? Colors.red : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${currencyFormat.format(actual)} / ${currencyFormat.format(limit)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBudget(String category) {
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
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'finance.delete_budget'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'finance.delete_budget_confirm_msg'.tr(
                context,
                args: {'category': category},
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.cancel'.tr(context),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _performActualDeleteBudget(category);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Future<void> _performActualDeleteBudget(String category) async {
    try {
      final response = await _financeService.deletePersonalBudget(
        category: category,
        budgetMonth: '$_selectedYear-$_selectedMonth',
      );
      if (response['status'] == 'success') {
        if (mounted) {
          context.showSuccessSnackBar('finance.budget_deleted_success'.tr(context));
          _fetchDashboardData();
        }
      } else {
        throw Exception(response['message'] ?? 'Gagal menghapus anggaran');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Gagal menghapus: $e');
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildChartLegend(
    String label,
    Color color, {
    bool isCompact = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: isCompact ? 11 : 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String label) {
    if (label.isEmpty) return Colors.grey;
    final List<Color> colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.indigoAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.deepOrangeAccent,
      Colors.lightGreenAccent,
    ];

    // Gunakan hash sederhana dari string untuk pemilihan warna yang stabil
    int hash = 0;
    for (int i = 0; i < label.length; i++) {
      hash = label.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  Widget _buildCategoryStatRow(
    String label,
    String value,
    Color color, {
    bool isCompact = false,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isCompact ? 13 : 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    if (_isReportLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reportData == null) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat data laporan',
                style: TextStyle(color: Colors.grey[600]),
              ),
              TextButton(
                onPressed: _fetchReportData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReportData,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [_buildYearPicker()]),
            const SizedBox(height: 16),
            _buildAnnualTrendChart(),
            const SizedBox(height: 24),
            // Combined Breakdowns (1 box)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildYearlyCategorySegment(
                    'personal_finance.income_by_category'.tr(context),
                    reportData?['income_by_cat'] ?? [],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  _buildYearlyCategorySegment(
                    'personal_finance.expense_by_category'.tr(context),
                    reportData?['expense_by_cat'] ?? [],
                  ),
                ],
              ),
            ),
            _buildAnnualSummaryTable(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildYearPicker() {
    final int currentYear = DateTime.now().year;
    final List<String> years = List.generate(
      5,
      (index) => (currentYear - index).toString(),
    );

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: _primaryColor),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedReportYear,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _primaryColor,
              ),
              items: years.map((String year) {
                return DropdownMenuItem<String>(
                  value: year,
                  child: Text(
                    year,
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedReportYear = newValue;
                    _hasLoadedReport = false;
                  });
                  _fetchReportData();
                  if (_selectedReportYear == _selectedYear) {
                    _fetchDashboardData(silent: true);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualTrendChart() {
    final List trendData = reportData?['monthly'] ?? [];
    if (trendData.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '${'personal_finance.monthly_trend'.tr(context)} (Ribu)',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[index]['month_short'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                minX: 0,
                maxX: (trendData.length - 1).toDouble(),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (double.tryParse(e.value['income'].toString()) ?? 0) /
                            1000,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.greenAccent.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (double.tryParse(e.value['expense'].toString()) ?? 0) /
                            1000,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.orangeAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orangeAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('Income', Colors.greenAccent),
              const SizedBox(width: 16),
              _buildChartLegend('Expense', Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyCategorySegment(String title, List categories) {
    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          const SizedBox(height: 12),
          Text(
            'personal_finance.on_progress_desc'.tr(context),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: categories.take(5).map((cat) {
                  final String categoryName = cat['category'] ?? 'General';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildCategoryStatRow(
                      categoryName,
                      currencyFormat.format(
                        double.tryParse(cat['total']?.toString() ?? '0') ?? 0,
                      ),
                      _getCategoryColor(categoryName),
                      isCompact: true,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        sections: categories.map((cat) {
                          final String categoryName =
                              cat['category'] ?? 'General';
                          return PieChartSectionData(
                            color: _getCategoryColor(categoryName),
                            value:
                                double.tryParse(
                                  cat['total']?.toString() ?? '0',
                                ) ??
                                0,
                            showTitle: false,
                            radius: 12,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            NumberFormat.compactCurrency(
                              locale: 'id',
                              symbol: 'Rp',
                              decimalDigits: 0,
                            ).format(
                              categories.fold<double>(
                                0,
                                (sum, cat) =>
                                    sum +
                                    (double.tryParse(
                                          cat['total']?.toString() ?? '0',
                                        ) ??
                                        0),
                              ),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnnualSummaryTable() {
    final List trendData = reportData?['monthly'] ?? [];
    if (trendData.isEmpty) return const SizedBox.shrink();

    double totalIncome = 0;
    double totalExpense = 0;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildSectionHeader(
              'personal_finance.monthly_summary'.tr(context),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 20,
              headingRowColor: WidgetStateProperty.all(
                Colors.grey.withOpacity(0.05),
              ),
              headingRowHeight: 48,
              columns: [
                DataColumn(
                  label: Text(
                    'personal_finance.month'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'personal_finance.income'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'personal_finance.expense'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'personal_finance.net'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'personal_finance.status'.tr(context).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              rows: [
                ...trendData.map((item) {
                  final double income =
                      double.tryParse(item['income']?.toString() ?? '0') ?? 0;
                  final double expense =
                      double.tryParse(item['expense']?.toString() ?? '0') ?? 0;
                  final double net = income - expense;

                  totalIncome += income;
                  totalExpense += expense;

                  return DataRow(
                    cells: [
                      DataCell(Text(item['month_short'] ?? '-')),
                      DataCell(
                        Text(
                          'IDR ${currencyFormat.format(income).replaceAll('Rp', '').trim()}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          'IDR ${currencyFormat.format(expense).replaceAll('Rp', '').trim()}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          'IDR ${currencyFormat.format(net).replaceAll('Rp', '').trim()}',
                          style: TextStyle(
                            color: net >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (net >= 0
                                        ? Colors.greenAccent
                                        : Colors.redAccent)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (net >= 0
                                    ? 'personal_finance.surplus'
                                    : 'personal_finance.deficit')
                                .tr(context),
                            style: TextStyle(
                              color: net >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // Total Row
                DataRow(
                  color: WidgetStateProperty.all(Colors.grey.withOpacity(0.02)),
                  cells: [
                    const DataCell(
                      Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                        'IDR ${currencyFormat.format(totalIncome).replaceAll('Rp', '').trim()}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'IDR ${currencyFormat.format(totalExpense).replaceAll('Rp', '').trim()}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'IDR ${currencyFormat.format(totalIncome - totalExpense).replaceAll('Rp', '').trim()}',
                        style: TextStyle(
                          color: (totalIncome - totalExpense) >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const DataCell(Text('-')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildTransactionShimmer() {
    return const Center(child: CircularProgressIndicator());
  }
}
