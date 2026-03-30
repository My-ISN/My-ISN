import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/finance_service.dart';
import '../widgets/custom_app_bar.dart';
import 'widgets/finance_account_item.dart';

class FinancePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FinancePage({super.key, required this.userData});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  bool _isHeaderExpanded = true;
  double _totalBalance = 0;
  double _monthlyExpense = 0;
  double _monthlyDeposit = 0;
  List<dynamic> _accounts = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dashboard = await _financeService.getFinanceDashboard();
      final accounts = await _financeService.getFinanceAccounts();

      if (mounted) {
        setState(() {
          _totalBalance = (dashboard['data']['total_balance'] as num).toDouble();
          _monthlyExpense = (dashboard['data']['monthly_expense'] as num).toDouble();
          _monthlyDeposit = (dashboard['data']['monthly_deposit'] as num).toDouble();
          _accounts = accounts;
          _isLoading = false;
        });
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
        title: 'My ISN',
      ),
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
                  children: [
                    _buildAccountsTab(),
                    _buildOthersTab(), // Deposit
                    _buildOthersTab(), // Expense
                    _buildOthersTab(), // Transactions
                  ],
                ),
              ),
            ],
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
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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
        tabs: [
          Tab(text: 'finance.accounts'.tr(context)),
          Tab(text: 'finance.deposit'.tr(context)),
          Tab(text: 'finance.expense'.tr(context)),
          Tab(text: 'finance.transactions'.tr(context)),
        ],
      ),
    );
  }

  Widget _buildAccountsTab() {
    if (_accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No accounts found', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _accounts.length,
        itemBuilder: (context, index) => FinanceAccountItem(account: _accounts[index]),
      ),
    );
  }

  Widget _buildOthersTab() {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.construction_rounded, size: 48, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'finance.on_progress_msg'.tr(context),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deposit, Expense, & Transactions',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
