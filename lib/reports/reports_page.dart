import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../localization/app_localizations.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../constants.dart';
import '../widgets/custom_snackbar.dart';

class ReportsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ReportsPage({super.key, required this.userData});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "0";
    double val = double.tryParse(amount.toString()) ?? 0;
    String formatted = val.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return formatted.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = '${AppConstants.baseUrl}/get_reports_data?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        setState(() {
          _reportData = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) context.showErrorSnackBar(data['message'] ?? 'Error fetching data');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showErrorSnackBar('Connection error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: CustomAppBar(userData: widget.userData, showBackButton: false, title: 'My ISN'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'reports',
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReportData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasPermission('mobile_reports_income') ||
                  _hasPermission('mobile_reports_expense') ||
                  _hasPermission('mobile_reports_deposit') ||
                  _hasPermission('mobile_reports_payroll')) ...[
                _buildSectionHeader('reports.financial_summary'.tr(context)),
                const SizedBox(height: 16),
                _buildFinancialGrid(),
                const SizedBox(height: 32),
              ],
              if (_hasPermission('mobile_reports_online_sales') ||
                  _hasPermission('mobile_reports_personal_rent') ||
                  _hasPermission('mobile_reports_company_rent')) ...[
                _buildSectionHeader('reports.income_by_category'.tr(context)),
                const SizedBox(height: 16),
                _buildCategoryGrid(),
                const SizedBox(height: 32),
              ],
              if (_hasPermission('mobile_reports_payroll')) ...[
                _buildPayrollChart(),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialGrid() {
    final cards = _reportData['cards'] ?? {};
    final items = <Widget>[];

    if (_hasPermission('mobile_reports_income')) {
      items.add(_buildStatCard(
        'reports.monthly_net_income'.tr(context),
        _currencyFormat.format(cards['monthly_net_income'] ?? 0),
        Icons.account_balance_wallet,
        const Color(0xFF6366F1),
      ));
      items.add(_buildStatCard(
        'reports.yearly_net_income'.tr(context),
        _currencyFormat.format(cards['yearly_net_income'] ?? 0),
        Icons.trending_up,
        const Color(0xFF10B981),
      ));
    }

    if (_hasPermission('mobile_reports_expense')) {
      items.add(_buildStatCard(
        'reports.monthly_expense'.tr(context),
        _currencyFormat.format(cards['monthly_expense'] ?? 0),
        Icons.shopping_cart,
        const Color(0xFFEF4444),
      ));
    }

    if (_hasPermission('mobile_reports_deposit')) {
      items.add(_buildStatCard(
        'reports.monthly_deposit'.tr(context),
        _currencyFormat.format(cards['monthly_deposit'] ?? 0),
        Icons.file_download,
        const Color(0xFFF59E0B),
      ));
    }

    if (_hasPermission('mobile_reports_payroll')) {
      items.add(_buildStatCard(
        'reports.payroll_this_month'.tr(context),
        _currencyFormat.format(cards['payroll_this_month'] ?? 0),
        Icons.payments_outlined,
        const Color(0xFF14B8A6),
      ));
    }

    return _buildResponsiveGrid(items);
  }

  Widget _buildCategoryGrid() {
    final cards = _reportData['cards'] ?? {};
    final items = <Widget>[];

    if (_hasPermission('mobile_reports_online_sales')) {
      items.add(_buildStatCard(
        'reports.cat_online'.tr(context),
        _currencyFormat.format(cards['cat_online'] ?? 0),
        Icons.language,
        const Color(0xFF7E57C2),
      ));
    }

    if (_hasPermission('mobile_reports_personal_rent')) {
      items.add(_buildStatCard(
        'reports.cat_personal'.tr(context),
        _currencyFormat.format(cards['cat_personal'] ?? 0),
        Icons.person_outline,
        const Color(0xFF7E57C2),
      ));
    }

    if (_hasPermission('mobile_reports_company_rent')) {
      items.add(_buildStatCard(
        'reports.cat_company'.tr(context),
        _currencyFormat.format(cards['cat_company'] ?? 0),
        Icons.business,
        const Color(0xFF7E57C2),
      ));
    }

    return _buildResponsiveGrid(items);
  }

  Widget _buildResponsiveGrid(List<Widget> items) {
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      if (i + 1 < items.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 16),
              Expanded(child: items[i + 1]),
            ],
          ),
        );
      } else {
        // Last single item fills the whole width
        rows.add(
          SizedBox(
            width: double.infinity,
            child: items[i],
          ),
        );
      }
      if (i + 2 < items.length || (i + 1 < items.length && i + 2 >= items.length)) {
        rows.add(const SizedBox(height: 16));
      }
    }
    return Column(children: rows);
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color baseColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withValues(alpha: 0.2)
              : Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: baseColor, size: 24),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollChart() {
    final history = _reportData['payroll_history'] as List? ?? [];
    if (history.isEmpty) return const SizedBox.shrink();

    final maxVal = history.map((e) => (e['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    final displayMaxY = maxVal == 0 ? 100.0 : maxVal * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'reports.payroll_report'.tr(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'reports.chart_label'.tr(context),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: displayMaxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF334155) 
                            : Colors.white,
                        tooltipRoundedRadius: 12,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            'Rp ${_formatCurrency(rod.toY)}',
                            TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < history.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              history[index]['month'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: history.asMap().entries.map((e) {
                      final val = (e.value['amount'] as num).toDouble();
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1),
                                const Color(0xFF6366F1).withValues(alpha: 0.7),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: displayMaxY,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
