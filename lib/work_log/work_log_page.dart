import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';

import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/custom_snackbar.dart';

import '../widgets/period_filter_widget.dart';
import 'create_work_log_page.dart';
import '../widgets/pagination_header.dart';

class WorkLogPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const WorkLogPage({super.key, required this.userData});

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  bool _isLoading = true;
  bool _isStatsLoading = true;
  List<dynamic> _logs = [];

  // Stats
  int _completedItems = 0;
  int _targetItems = 0;

  // Pagination (Standardized with Todo List/Employees)
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];
  bool _isStatsExpanded = true;

  // Filters
  String? _selectedMonth;
  String? _selectedYear;
  final List<String> _years = List.generate(
    5,
    (index) => (DateTime.now().year - index).toString(),
  );
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
    _selectedMonth = DateTime.now().month.toString().padLeft(2, '0');
    _selectedYear = DateTime.now().year.toString();

    _fetchStats();
    if (_hasPermission('mobile_worklog_view')) {
      _fetchLogs();
    } else {
      _isLoading = false;
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources
        .split(',')
        .map((e) => e.trim())
        .toList();
    return resourceList.contains(resource);
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isStatsLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/get_worklog_stats?user_id=${widget.userData['id'] ?? widget.userData['user_id']}&month=$_selectedMonth&year=$_selectedYear',
        ),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _completedItems = result['data']['completed'];
            _targetItems = result['data']['target'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    } finally {
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _fetchLogs({int? page}) async {
    final int targetPage = page ?? _currentPage;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final offset = (targetPage - 1) * _selectedLimit;
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/get_worklog_list?user_id=${widget.userData['id'] ?? widget.userData['user_id']}&page=$targetPage&limit=$_selectedLimit&offset=$offset&month=$_selectedMonth&year=$_selectedYear',
        ),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _logs = result['data'];
            _currentPage = targetPage;
            _totalCount = result['pagination']['total'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalPages => (_totalCount / _selectedLimit).ceil();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: widget.userData, showBackButton: false),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'work_log'),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchStats();
          await _fetchLogs(page: 1);
        },
        color: _primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: _buildStatsCard(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: PaginationHeader(
                  limit: _selectedLimit,
                  totalCount: _totalCount,
                  totalLabel: 'work_log.total'.tr(context, args: {'count': _totalCount.toString()}),
                  limitOptions: _limitOptions,
                  onLimitChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLimit = value;
                        _currentPage = 1;
                      });
                      _fetchLogs(page: 1);
                    }
                  },
                  extraLeftActions: [
                    PeriodFilterButton(
                      selectedMonth: _selectedMonth!,
                      selectedYear: _selectedYear!,
                      months: _months,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => PeriodPickerSheet(
                            initialMonth: _selectedMonth!,
                            initialYear: _selectedYear!,
                            months: _months,
                            years: _years,
                            onApply: (month, year) {
                              setState(() {
                                _selectedMonth = month;
                                _selectedYear = year;
                                _currentPage = 1;
                              });
                              _fetchStats();
                              _fetchLogs(page: 1);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (!_hasPermission('mobile_worklog_view'))
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'main.xin_role_enable'.tr(context),
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoading && _logs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_logs.isEmpty && !_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_edu,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'work_log.no_logs'.tr(context),
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final log = _logs[index];
                    return _buildLogItem(context, log);
                  }, childCount: _logs.length),
                ),
              ),

            if (_totalPages > 1 && !_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _buildPaginationFooter(),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _hasPermission('mobile_worklog_add')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateWorkLogPage(userData: widget.userData),
                  ),
                );
                if (result == true) {
                  _fetchStats();
                  _fetchLogs(page: 1);
                }
              },
              backgroundColor: _primaryColor,
              elevation: 4,
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: Text(
                'work_log.add_log'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }



  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            icon: Icons.chevron_left_rounded,
            onPressed: _currentPage > 1
                ? () => _fetchLogs(page: _currentPage - 1)
                : null,
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _primaryColor.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              'work_log.page_x_of_y'.tr(
                context,
                args: {
                  'current': _currentPage.toString(),
                  'total': _totalPages.toString(),
                },
              ),
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 20),
          _buildPageButton(
            icon: Icons.chevron_right_rounded,
            onPressed: _currentPage < _totalPages
                ? () => _fetchLogs(page: _currentPage + 1)
                : null,
          ),
        ],
      ),
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

  Widget _buildStatsCard(BuildContext context) {
    double progress = _targetItems > 0 ? (_completedItems / _targetItems) : 0;
    if (progress > 1.0) progress = 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'work_log.my_summary'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_months.firstWhere((m) => m['id'] == _selectedMonth)['name']!.tr(context)} $_selectedYear',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isStatsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isStatsExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isStatsLoading
                                  ? const SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _buildStatRow(
                                      'work_log.monthly_target'.tr(context),
                                      _targetItems.toString(),
                                      Colors.blue,
                                    ),
                              const SizedBox(height: 12),
                              _isStatsLoading
                                  ? const SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _buildStatRow(
                                      'work_log.completed_items'.tr(context),
                                      _completedItems.toString(),
                                      Colors.green,
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 85,
                                  height: 85,
                                  child: _isStatsLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : CircularProgressIndicator(
                                          value: value,
                                          strokeWidth: 10,
                                          backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _primaryColor,
                                          ),
                                          strokeCap: StrokeCap.round,
                                        ),
                                ),
                                if (!_isStatsLoading)
                                  Text(
                                    '${(value * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, dynamic log) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _showDetails(log),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['estimate_date'] ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log['estimate_number'] ?? '-',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${log['item_count']} ${'main.items'.tr(context)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(dynamic log) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _WorkLogDetailsSheet(
          logId: log['estimate_id'].toString(),
          userData: widget.userData,
          initialData: log,
        );
      },
    );

    if (result == true && mounted) {
      _fetchStats();
      _fetchLogs();
    }
  }

}

class _WorkLogDetailsSheet extends StatefulWidget {
  final String logId;
  final Map<String, dynamic> userData;
  final dynamic initialData;

  const _WorkLogDetailsSheet({
    required this.logId, 
    required this.userData,
    this.initialData,
  });

  @override
  State<_WorkLogDetailsSheet> createState() => _WorkLogDetailsSheetState();
}

class _WorkLogDetailsSheetState extends State<_WorkLogDetailsSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/get_worklog_details?estimate_id=${widget.logId}',
        ),
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            setState(() {
              _details = result['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog() async {
    final bool confirm =
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                  'work_log.delete_confirm_title'.tr(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'work_log.delete_confirm_desc'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
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
        ) ??
        false;

    if (!confirm) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/delete_worklog'),
        body: {'estimate_id': widget.logId},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            Navigator.pop(context, true);
            context.showSuccessSnackBar('work_log.delete_success'.tr(context));
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting log: $e');
    }
  }

  Future<void> _editLog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWorkLogPage(
          userData: widget.userData,
          estimateId: widget.logId,
          initialData: _details,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources
        .split(',')
        .map((e) => e.trim())
        .toList();
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _details?['estimate'] ?? widget.initialData;
    final items = (_details?['items'] as List?) ?? [];
    final double sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'work_log.log_details'.tr(context),
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
                      _editLog();
                    } else if (value == 'delete') {
                      _deleteLog();
                    }
                  },
                  itemBuilder: (context) => [
                    if (_hasPermission('mobile_worklog_edit') ||
                        _hasPermission('mobile_worklog_add'))
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
                            Text('main.edit'.tr(context)),
                          ],
                        ),
                      ),
                    if (_hasPermission('mobile_worklog_delete'))
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
                              'main.delete'.tr(context),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    'work_log.date'.tr(context),
                    estimate['estimate_date'] ?? '-',
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(
                    Icons.confirmation_number_outlined,
                    'work_log.number'.tr(context),
                    estimate['estimate_number'] ?? '-',
                  ),
                  const SizedBox(height: 32),

                  // Items Header
                  Text(
                    'work_log.items'.tr(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items List
                  if (_isLoading && items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'work_log.no_items'.tr(context),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['item_name'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF7E57C2).withValues(alpha: 0.7),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
