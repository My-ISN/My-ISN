import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';

class PayrollPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PayrollPage({super.key, required this.userData});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _history = [];
  Map<String, dynamic>? _payrollStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchPayrollHistory();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_dashboard_data?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true && mounted) {
        setState(() {
          _payrollStats = data['data']['payroll'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching payroll stats: $e');
    }
  }

  Future<void> _fetchPayrollHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_payroll_history?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        setState(() {
          _history = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching payroll: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([_fetchPayrollHistory(), _fetchDashboardStats()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        toolbarHeight:
            0, // Hide the app bar content but keep the status bar color
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthlyReportBox(),
            _buildTabSwitcher(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics:
                    const NeverScrollableScrollPhysics(), // Prevent swiping if desired for cleaner toggle feel
                children: [_buildHistoryTab(), _buildLatestPayslipTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
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
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: _tabController.index == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController.animateTo(0);
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'payroll.history'.tr(context),
                        style: TextStyle(
                          color: _tabController.index == 0
                              ? Colors.white
                              : Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabController.animateTo(1);
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'payroll.payslip'.tr(context),
                        style: TextStyle(
                          color: _tabController.index == 1
                              ? Colors.white
                              : Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReportBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dashboard.payroll_report'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildReportStat(
                  'IDR ${_payrollStats?['total'] ?? 0}',
                  'dashboard.total'.tr(context),
                ),
                const SizedBox(width: 32),
                _buildReportStat(
                  'IDR ${_payrollStats?['this_month'] ?? 0}',
                  'dashboard.this_month'.tr(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7E57C2),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        message: 'payroll.no_history'.tr(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF7E57C2),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showPayslipDetails(item['payslip_id']),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Color(0xFF7E57C2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['salary_month'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'IDR ${item['net_salary']}',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestPayslipTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        message: 'payroll.no_history'.tr(context),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF7E57C2),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: _buildPayslipView(_history.first['payslip_id']),
      ),
    );
  }

  Widget _buildPayslipView(String payslipId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPayslipDetails(payslipId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!['status'] == false) {
          return Center(child: Text('payroll.fetch_error'.tr(context)));
        }

        final data = snapshot.data!['data'];
        final payslip = data['payslip'];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Theme.of(context).brightness == Brightness.dark
                  ? Border.all(color: Colors.white24)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wallet,
                          color: Color(0xFF7E57C2),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        payslip['salary_month'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'payroll.payslip'.tr(context).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('payroll.details'.tr(context)),
                _buildInfoRow(
                  'payroll.payment_method'.tr(context),
                  payslip['payment_method'] ?? '-',
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('payroll.earnings'.tr(context)),
                _buildAmountRow(
                  'payroll.basic_salary'.tr(context),
                  payslip['basic_salary'],
                ),
                ..._buildDynamicRows(
                  data['allowances'],
                  'allowance_label',
                  'allowance_amount',
                ),
                ..._buildDynamicRows(
                  data['commissions'],
                  'commission_label',
                  'commission_amount',
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('payroll.deductions'.tr(context)),
                ..._buildDynamicRows(
                  data['statutory_deductions'],
                  'statutory_deduction_label',
                  'statutory_deduction_amount',
                  isNegative: true,
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E57C2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E57C2).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'payroll.net_salary'.tr(context),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'IDR ${payslip['net_salary']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchPayslipDetails(String payslipId) async {
    final url =
        'https://foxgeen.com/HRIS/mobileapi/get_payslip_details?payslip_id=$payslipId';
    final response = await http.get(Uri.parse(url));
    return json.decode(response.body);
  }

  void _showPayslipDetails(String payslipId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: _buildPayslipView(payslipId),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7E57C2),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    dynamic value, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            '${isNegative ? '-' : '+'} IDR $value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isNegative
                  ? Colors.red[400]
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicRows(
    List<dynamic> items,
    String labelKey,
    String amountKey, {
    bool isNegative = false,
  }) {
    return items
        .map(
          (item) => _buildAmountRow(
            item[labelKey],
            item[amountKey],
            isNegative: isNegative,
          ),
        )
        .toList();
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Theme.of(context).brightness == Brightness.dark
                  ? Border.all(color: Colors.white24)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(icon, size: 64, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
