import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import 'create_work_log_page.dart';

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
  String _monthName = '';
  
  // Pagination (Standardized with Todo List/Employees)
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];
  bool _isStatsExpanded = true;

  @override
  void initState() {
    super.initState();
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
    final List<String> resourceList = resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isStatsLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_worklog_stats?user_id=${widget.userData['id'] ?? widget.userData['user_id']}'),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _completedItems = result['data']['completed'];
            _targetItems = result['data']['target'];
            _monthName = result['data']['month_name'];
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
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_worklog_list?user_id=${widget.userData['id'] ?? widget.userData['user_id']}&page=$targetPage&limit=$_selectedLimit&offset=$offset'),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildPaginationHeader(),
              ),
            ),
            if (!_hasPermission('mobile_worklog_view'))
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 80, color: Colors.grey[300]),
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty && !_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 80, color: Colors.grey[300]),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = _logs[index];
                      return _buildLogItem(context, log);
                    },
                    childCount: _logs.length,
                  ),
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
                builder: (context) => CreateWorkLogPage(userData: widget.userData),
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
          label: Text('work_log.add_log'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      : null,
    );
  }

  Widget _buildPaginationHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'main.show'.tr(context),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            _buildPremiumDropdown(),
          ],
        ),
        if (_logs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'work_log.total'.tr(context, args: {
                'count': _totalCount.toString(),
              }),
              style: TextStyle(
                color: _primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _primaryColor),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchLogs(page: 1);
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

  Widget _buildPaginationFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1 ? () => _fetchLogs(page: _currentPage - 1) : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'work_log.page_x_of_y'.tr(context, args: {
              'current': _currentPage.toString(),
              'total': _totalPages.toString(),
            }),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < _totalPages ? () => _fetchLogs(page: _currentPage + 1) : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? Colors.grey[200] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Icon(icon, color: onPressed == null ? Colors.grey[400] : _primaryColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    double progress = _targetItems > 0 ? (_completedItems / _targetItems) : 0;
    if (progress > 1.0) progress = 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'work_log.my_summary'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      if (_monthName.isNotEmpty)
                        Text(
                          '$_monthName ${DateTime.now().year}',
                          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isStatsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
                    ],
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
                              _buildStatRow('work_log.monthly_target'.tr(context), _targetItems.toString(), Colors.blue),
                              const SizedBox(height: 16),
                              _buildStatRow('work_log.completed_items'.tr(context), _completedItems.toString(), Colors.green),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 85,
                              height: 85,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[100],
                                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, dynamic log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.assignment_rounded, color: _primaryColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['estimate_date'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log['estimate_number'] ?? '-',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${log['item_count']} ${'main.items'.tr(context)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
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

  const _WorkLogDetailsSheet({required this.logId, required this.userData});

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
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_worklog_details?estimate_id=${widget.logId}'),
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _details = result['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('work_log.delete_confirm_title'.tr(context)),
        content: Text('work_log.delete_confirm_desc'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('main.cancel'.tr(context)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('main.delete'.tr(context)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/delete_worklog'),
        body: {'estimate_id': widget.logId},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            Navigator.pop(context, true); 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('work_log.delete_success'.tr(context))),
            );
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
    final List<String> resourceList = resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
    }

    if (_details == null) {
      return SizedBox(
        height: 300,
        child: Center(child: Text('work_log.fetch_details_failed'.tr(context))),
      );
    }

    final estimate = _details!['estimate'];
    final items = _details!['items'] as List;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'work_log.log_details'.tr(context),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (_hasPermission('mobile_worklog_edit') || _hasPermission('mobile_worklog_add'))
                    IconButton(
                      onPressed: _editLog,
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    ),
                   if (_hasPermission('mobile_worklog_delete'))
                    IconButton(
                      onPressed: _deleteLog,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          _buildInfoRow('work_log.date'.tr(context), estimate['estimate_date']),
          _buildInfoRow('work_log.number'.tr(context), estimate['estimate_number']),
          const SizedBox(height: 20),
          Text(
            'work_log.items'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text(item['item_name'] ?? '-')),
              ],
            ),
          )).toList(),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
