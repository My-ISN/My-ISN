import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/connectivity_wrapper.dart';

class PayrollPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PayrollPage({super.key, required this.userData});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasPermission(String resource) => _hasPermissionIn(widget.userData, resource);
  bool get _canMakePayment => _hasPermission('mobile_payroll_add');

  bool _hasPermissionIn(Map<String, dynamic> data, String resource) {
    if (data['role_resources'] == 'all') return true;
    final String resources = data['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }
  Map<String, dynamic>? _payrollStats;
  bool _isLoading = true;
  List<dynamic> _history = [];
  List<dynamic> _staffList = [];
  String? _selectedStaffId;
  DateTime _selectedMonth = DateTime.now();
  List<dynamic> _accounts = [];
  String? _selectedAccountId;
  Map<String, dynamic>? _previewData;
  bool _isActionLoading = false;
  bool _isStaffLoading = true;
  String? _staffErrorMessage;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final int tabCount = _canMakePayment ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchPayrollHistory();
    _fetchDashboardStats();
    _fetchStaffList();
    _fetchAccounts();
  }

  @override
  void didUpdateWidget(PayrollPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool oldCan = _hasPermissionIn(oldWidget.userData, 'mobile_payroll_add');
    final bool newCan = _canMakePayment;
    if (oldCan != newCan) {
      final int newLength = newCan ? 2 : 1;
      _tabController.dispose();
      _tabController = TabController(length: newLength, vsync: this);
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "0,00";
    double val = double.tryParse(amount.toString()) ?? 0;
    String formatted = val.toStringAsFixed(2).replaceAll('.', ',');
    List<String> parts = formatted.split(',');
    String integerPart = parts[0];
    String decimalPart = parts[1];
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    integerPart = integerPart.replaceAllMapped(reg, (Match match) => '${match[1]}.');
    return "$integerPart,$decimalPart";
  }

  Future<void> _fetchStaffList() async {
    setState(() {
      _isStaffLoading = true;
      _staffErrorMessage = null;
    });
    try {
      final userId = widget.userData['user_id'] ?? widget.userData['id'];
      debugPrint('Fetching staff for user: $userId');
      if (userId == null) {
        setState(() {
          _isStaffLoading = false;
          _staffErrorMessage = "Kesalahan: ID Pengguna tidak ditemukan (Silakan Logout & Login kembali)";
        });
        return;
      }
      String? responseBody;
      try {
        final url = 'https://foxgeen.com/HRIS/mobileapi/get_payroll_staff_list?user_id=$userId';
        final response = await http.get(Uri.parse(url));
        responseBody = response.body;
        debugPrint('Staff list response body: "$responseBody"');
        
        if (responseBody.trim().isEmpty) {
           throw Exception("Server memberikan respon kosong");
        }

        final data = json.decode(responseBody);
        if (data['status'] == true && mounted) {
          setState(() {
            _staffList = data['data'];
            _isStaffLoading = false;
          });
        } else {
          setState(() {
            _isStaffLoading = false;
            _staffErrorMessage = data['message'] ?? "Gagal mengambil data staff";
          });
        }
      } catch (e) {
        debugPrint('Error fetching staff: $e');
        if (mounted) {
          String errorMsg = "Kesalahan koneksi: $e";
          if (e is FormatException && responseBody != null) {
             final snippet = responseBody.length > 100 ? responseBody.substring(0, 100) : responseBody;
             errorMsg += "\nRespon Server: $snippet";
          }
          setState(() {
            _isStaffLoading = false;
            _staffErrorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      debugPrint('Global error fetching staff: $e');
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_payroll_accounts?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true && mounted) {
        setState(() {
          _accounts = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
    }
  }

  Future<void> _fetchPreview() async {
    if (_selectedStaffId == null) return;
    setState(() => _isActionLoading = true);
    try {
      final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_payroll_preview?staff_id=$_selectedStaffId&salary_month=$monthStr';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == true && mounted) {
        setState(() {
          _previewData = data;
        });
      } else {
        debugPrint('Preview failed: ${data['message']}');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(data['message'] ?? 'Gagal memuat preview gaji'), backgroundColor: Colors.red),
           );
        }
      }
    } catch (e) {
      debugPrint('Error fetching preview: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Kesalahan koneksi saat memuat preview'), backgroundColor: Colors.orange),
         );
      }
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _executePayment() async {
    if (_selectedStaffId == null || _selectedAccountId == null) return;

    final selectedStaffName = _staffList.firstWhere((s) => s['user_id'].toString() == _selectedStaffId.toString())['full_name'] ?? '';
    final selectedAccountName = _accounts.firstWhere((a) => a['account_id'].toString() == _selectedAccountId.toString())['account_name'] ?? '';
    final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
    final netSalary = _previewData?['breakdown']['net_salary'] ?? 0;

    final confirm = await showModalBottomSheet<bool>(
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
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF7E57C2), size: 48),
            const SizedBox(height: 16),
            Text(
              'payroll.confirm_payment'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'IDR ${_formatCurrency(netSalary)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'payroll.net_salary'.tr(context),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.person_outline, 'Staff', selectedStaffName),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today_outlined, 'Bulan', monthStr),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.account_balance_outlined, 'Sumber', selectedAccountName),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
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
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('main.save'.tr(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      
      final url = 'https://foxgeen.com/HRIS/mobileapi/execute_payroll_payment';
      final response = await http.post(Uri.parse(url), body: {
        'user_id': userId.toString(),
        'staff_id': _selectedStaffId,
        'salary_month': monthStr,
        'account_id': _selectedAccountId,
        'comments': _commentController.text,
      });
      
      final data = json.decode(response.body);
      if (data['status'] == true && mounted) {
        // Show success dialog for better feedback
        await showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
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
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                const SizedBox(height: 20),
                Text(
                  'payroll.payment_success'.tr(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'payroll.payment_success_desc'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('OK'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );

        setState(() {
          _selectedStaffId = null;
          _previewData = null;
          _commentController.clear();
          _tabController.animateTo(1); // Switch to History tab
        });
        _fetchPayrollHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Error'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error executing payment: $e');
    } finally {
      setState(() => _isActionLoading = false);
    }
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
      debugPrint('Payroll history response: "${response.body}"');
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
    await Future.wait([
      _fetchPayrollHistory(),
      _fetchDashboardStats(),
      _fetchStaffList(),
      _fetchAccounts(),
    ]);
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
            if (_canMakePayment) _buildTabSwitcher(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (_tabController.length == 2) _buildMakePaymentTab(),
                  _buildHistoryTab()
                ],
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _tabController.animateTo(0);
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'payroll.make_payment'.tr(context),
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _tabController.animateTo(1);
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'payroll.history'.tr(context),
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
            if (_payrollStats == null)
              ShimmerLoading(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerSkeleton(height: 18, width: 120),
                        const SizedBox(height: 6),
                        const ShimmerSkeleton(height: 12, width: 80),
                      ],
                    ),
                    const SizedBox(width: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerSkeleton(height: 18, width: 120),
                        const SizedBox(height: 6),
                        const ShimmerSkeleton(height: 12, width: 80),
                      ],
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  _buildReportStat(
                    'IDR ${_formatCurrency(_payrollStats?['total'])}',
                    'dashboard.total'.tr(context),
                  ),
                  const SizedBox(width: 32),
                  _buildReportStat(
                    'IDR ${_formatCurrency(_payrollStats?['this_month'])}',
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
    if (_isLoading) return const ShimmerList(padding: EdgeInsets.all(20));
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
        itemCount: _history.length + 1,
        itemBuilder: (context, index) {
          if (index == _history.length) {
            return ValueListenableBuilder<double>(
              valueListenable: ConnectivityStatus.bottomPadding,
              builder: (context, padding, _) => SizedBox(
                height: padding - 20,
              ),
            );
          }
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
                              'IDR ${_formatCurrency(item['net_salary'])}',
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

  Widget _buildMakePaymentTab() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF7E57C2),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionCard(),
            const SizedBox(height: 20),
            if (_previewData != null) ...[
              _buildSalaryPreviewCard(),
              const SizedBox(height: 20),
              _buildAccountSelectionCard(),
              const SizedBox(height: 20),
              _buildActionCard(),
            ] else if (_selectedStaffId != null && !_isActionLoading)
              Center(child: Text('payroll.preview_not_loaded'.tr(context)))
            else if (_isActionLoading)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'payroll.no_preview'.tr(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ValueListenableBuilder<double>(
              valueListenable: ConnectivityStatus.bottomPadding,
              builder: (context, padding, _) => SizedBox(
                height: padding - 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('payroll.select_staff'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isStaffLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_staffErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(_staffErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            )
          else if (_staffList.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('payroll.no_staff_found'.tr(context), style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          SearchableDropdown(
            label: 'payroll.select_staff'.tr(context),
            value: _selectedStaffId != null ? (_staffList.firstWhere((s) => s['user_id'].toString() == _selectedStaffId, orElse: () => {'full_name': ''})['full_name'] ?? '') : '',
            options: _staffList.map((s) => {
              'id': s['user_id'].toString(),
              'name': s['full_name'].toString(),
            }).toList(),
            onSelected: (val) {
              setState(() {
                _selectedStaffId = val;
                _previewData = null;
              });
              _fetchPreview();
            },
          ),
          const SizedBox(height: 20),
          Text('payroll.select_month'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked != null) {
                setState(() {
                  _selectedMonth = picked;
                  _previewData = null;
                });
                _fetchPreview();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}"),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryPreviewCard() {
    final breakdown = _previewData!['breakdown'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('payroll.preview_salary'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 32),
          _buildAmountRow('payroll.basic_salary'.tr(context), breakdown['basic_salary']),
          ..._buildDynamicPreviewRows(breakdown['allowances'], false),
          ..._buildDynamicPreviewRows(breakdown['commissions'], false),
          ..._buildDynamicPreviewRows(breakdown['other_payments'], false),
          const Divider(height: 32),
          ..._buildDynamicPreviewRows(breakdown['statutory_deductions'], true),
          ..._buildDynamicPreviewRows(breakdown['optional_deductions'], true),
          if ((breakdown['advance_salary_deduct'] ?? 0) > 0)
            _buildAmountRow('payroll.advance_salary'.tr(context), breakdown['advance_salary_deduct'], isNegative: true),
          if ((breakdown['loan_deduct'] ?? 0) > 0)
            _buildAmountRow('payroll.loan'.tr(context), breakdown['loan_deduct'], isNegative: true),
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF7E57C2).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('payroll.net_salary'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('IDR ${_formatCurrency(breakdown['net_salary'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E57C2))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicPreviewRows(List<dynamic> items, bool isNegative) {
    return items.map((i) => _buildAmountRow(i['title'], i['amount'], isNegative: isNegative)).toList();
  }

  Widget _buildAccountSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('payroll.source_account'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SearchableDropdown(
            label: 'payroll.source_account'.tr(context),
            value: _selectedAccountId != null ? (_accounts.firstWhere((a) => a['account_id'].toString() == _selectedAccountId, orElse: () => {'account_name': ''})['account_name'] ?? '') : '',
            options: _accounts.map((a) => {
              'id': a['account_id'].toString(),
              'name': "${a['account_name']} (IDR ${_formatCurrency(a['account_balance'])})",
            }).toList(),
            onSelected: (val) => setState(() => _selectedAccountId = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              labelText: 'payroll.comments'.tr(context),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _executePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isActionLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('payroll.pay_now'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'payroll.net_salary'.tr(context),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'IDR ${_formatCurrency(payslip['net_salary'])}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
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
            '${isNegative ? '-' : '+'} IDR ${_formatCurrency(value)}',
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
