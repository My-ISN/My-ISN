import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import 'create_ticket_page.dart';
import 'ticket_detail_page.dart';

class HelpdeskListPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HelpdeskListPage({super.key, required this.userData});

  @override
  State<HelpdeskListPage> createState() => _HelpdeskListPageState();
}

class _HelpdeskListPageState extends State<HelpdeskListPage> {
  bool _isLoading = true;
  bool _isStatsLoading = true;
  bool _isStatsExpanded = true;
  List<dynamic> _allTickets = [];
  List<dynamic> _filteredTickets = [];
  Map<String, dynamic> _stats = {'priority': [], 'status': []};

  // Pagination
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchTickets(), _fetchStats()]);
  }

  Future<void> _fetchTickets({int? page}) async {
    if (!mounted) return;
    final int targetPage = page ?? _currentPage;
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final offset = (targetPage - 1) * _selectedLimit;

      final url = '${AppConstants.baseUrl}/get_tickets';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'user_id': userId.toString(),
          'limit': _selectedLimit.toString(),
          'offset': offset.toString(),
        },
      );
      final data = json.decode(response.body);

      if (data['status'] == true && mounted) {
        setState(() {
          _currentPage = targetPage;
          _allTickets = data['data'];
          _totalCount = data['total_count'] ?? 0;
          _filteredTickets = List.from(_allTickets);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Helpdesk: Error fetching tickets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isStatsLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          '${AppConstants.baseUrl}/get_helpdesk_stats?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true && mounted) {
        setState(() {
          _stats = data['data'];
          _isStatsLoading = false;
        });
      } else {
        if (mounted) setState(() => _isStatsLoading = false);
      }
    } catch (e) {
      debugPrint('Helpdesk: Error fetching stats: $e');
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  void _runFilter(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTickets = List.from(_allTickets);
      });
      return;
    }

    final filtered = _allTickets.where((ticket) {
      final subject = (ticket['subject'] ?? '').toString().toLowerCase();
      final code = (ticket['ticket_code'] ?? '').toString().toLowerCase();
      final searchLower = query.toLowerCase();
      return subject.contains(searchLower) || code.contains(searchLower);
    }).toList();

    setState(() {
      _filteredTickets = filtered;
    });
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1') return true;
    final String? resources = widget.userData['role_resources'];
    if (resources == null || resources.isEmpty) return false;
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Color _getStatusColor(String status) {
    if (status == '1') return Colors.green;
    if (status == '2') return Colors.red;
    return Colors.grey;
  }

  String _getStatusText(BuildContext context, String status) {
    if (status == '1') return 'helpdesk.open'.tr(context);
    if (status == '2') return 'helpdesk.closed'.tr(context);
    return status;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.deepOrange;
      case '4':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(BuildContext context, String priority) {
    switch (priority) {
      case '1':
        return 'helpdesk.priority_low'.tr(context);
      case '2':
        return 'helpdesk.priority_medium'.tr(context);
      case '3':
        return 'helpdesk.priority_high'.tr(context);
      case '4':
        return 'helpdesk.priority_critical'.tr(context);
      default:
        return priority;
    }
  }

  Future<void> _deleteTicket(String ticketId) async {
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/delete_ticket'),
        body: {'ticket_id': ticketId, 'user_id': userId.toString()},
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('helpdesk.success_delete'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'helpdesk.failed_delete'.tr(context)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error deleting ticket: $e');
    }
  }

  void _confirmDelete(Map<String, dynamic> ticket) {
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
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'helpdesk.confirm_delete_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'helpdesk.confirm_delete_msg'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
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
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTicket(ticket['ticket_id'].toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'main.app_name'.tr(context),
        showBackButton: false,
        userData: widget.userData,
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'helpdesk'),
      floatingActionButton: _hasPermission('mobile_helpdesk_add')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateTicketPage(userData: widget.userData),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              backgroundColor: const Color(0xFF7E57C2),
              icon: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
              ),
              label: Text(
                'helpdesk.create_ticket'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: ConnectivityWrapper(
        child: RefreshIndicator(
          onRefresh: _loadData,
          displacement: 20,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Stats Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildStatsCard(),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildSearchBar(),
                ),
              ),

              // Pagination Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildPaginationHeader(),
                ),
              ),

              if (_isLoading && _allTickets.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_allTickets.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'helpdesk.no_tickets'.tr(context),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredTickets.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets found for "${_searchController.text}"',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final ticket = _filteredTickets[index];
                      return _buildTicketCard(ticket);
                    }, childCount: _filteredTickets.length),
                  ),
                ),

              if (_totalCount > _selectedLimit)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPaginationFooter(),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    int total = 0;
    int closed = 0;
    for (var item in _stats['status']) {
      int count = int.parse(item['count'].toString());
      total += count;
      if (item['ticket_status'].toString() == '2') closed = count;
    }
    double progress = total > 0 ? (closed / total) : 0;

    int low = 0, med = 0, high = 0, crit = 0;
    for (var item in _stats['priority']) {
      int count = int.parse(item['count'].toString());
      String p = item['ticket_priority'].toString();
      if (p == '1') {
        low = count;
      } else if (p == '2')
        med = count;
      else if (p == '3')
        high = count;
      else if (p == '4')
        crit = count;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                        'helpdesk.ticket_list'.tr(context),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.5,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'todo_list.general_accumulation'.tr(context),
                        style: const TextStyle(
                          color: Color(0xFF7E57C2),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isStatsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF7E57C2),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _isStatsLoading
                        ? const SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatMiniRow(
                                      'helpdesk.priority_critical'.tr(context),
                                      crit.toString(),
                                      Colors.purple,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatMiniRow(
                                      'helpdesk.priority_high'.tr(context),
                                      high.toString(),
                                      Colors.deepOrange,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatMiniRow(
                                      'helpdesk.priority_medium'.tr(context),
                                      med.toString(),
                                      Colors.orange,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildStatMiniRow(
                                      'helpdesk.priority_low'.tr(context),
                                      low.toString(),
                                      Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 10,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).dividerColor.withOpacity(0.1),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Colors.green,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.color,
                                        ),
                                      ),
                                      Text(
                                        'helpdesk.closed'.tr(context).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
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

  Widget _buildStatMiniRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: _runFilter,
      decoration: InputDecoration(
        hintText: 'todo_list.search_hint'.tr(context),
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            _buildPremiumDropdown(),
          ],
        ),
        if (_allTickets.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'todo_list.total'.tr(
                context,
                args: {'count': _totalCount.toString()},
              ),
              style: const TextStyle(
                color: Color(0xFF7E57C2),
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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF7E57C2),
          ),
          style: const TextStyle(
            color: Color(0xFF7E57C2),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchTickets();
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

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status = ticket['ticket_status'].toString();
    final priority = ticket['ticket_priority'].toString();
    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailPage(
                userData: widget.userData,
                ticketId: ticket['ticket_id'].toString(),
              ),
            ),
          );
          if (result == true) _loadData();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket['ticket_code'] ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildChip(_getStatusText(context, status), statusColor),
                      const SizedBox(width: 8),
                      _buildChip(_getPriorityText(context, priority), priorityColor),
                      if (_hasPermission('mobile_helpdesk_delete')) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(ticket),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket['subject'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ticket['created_at'] ?? '',
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.person_outline, size: 14, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${ticket['first_name'] ?? ''} ${ticket['last_name'] ?? ''}'.trim(),
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1
              ? () {
                  _fetchTickets(page: _currentPage - 1);
                }
              : null,
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
            'todo_list.page_x_of_y'.tr(
              context,
              args: {
                'current': _currentPage.toString(),
                'total': ((_totalCount / _selectedLimit).ceil()).toString(),
              },
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < (_totalCount / _selectedLimit).ceil()
              ? () {
                  _fetchTickets(page: _currentPage + 1);
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null ? const Color(0xFF7E57C2) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
