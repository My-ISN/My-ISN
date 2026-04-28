import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../localization/app_localizations.dart';
import '../services/project_task_service.dart';
import '../widgets/pagination_header.dart';
import '../todo_list/widgets/todo_pagination_footer.dart';
import 'models/task_model.dart';
import 'task_detail_page.dart';
import 'add_task_page.dart';

class TaskListPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int? projectId;
  const TaskListPage({super.key, required this.userData, this.projectId});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final ProjectTaskService _service = ProjectTaskService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Task> _tasks = [];
  List<Task> _filteredTasks = []; // Added for filtering
  bool _isLoading = true;
  bool _isInitialLoad = true; // Flag for first-time loading
  String? _error;

  // Pagination state
  int _limit = 10;
  int _page = 1;
  int _totalCount = 0;

  // Summary counts
  int _completed = 0;
  int _inProgress = 0;
  int _notStarted = 0;
  int _onHold = 0;

  // Filter state
  int? _selectedDepartmentId;
  List<dynamic> _departments = [];
  final Color _primaryColor = const Color(0xFF7E57C2);

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }


  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _fetchTasks();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchDepartments() async {
    final result = await _service.getDepartments();
    if (result['status'] == true) {
      setState(() {
        _departments = result['data'] ?? [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _page = 1;
      });
      _fetchTasks();
    });
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getTasks(
      projectId: widget.projectId,
      limit: _limit,
      page: _page,
      search: _searchController.text,
      departmentId: _selectedDepartmentId,
    );
    if (mounted) {
      if (result['status'] == true) {
        final List data = result['data'] ?? [];
        List<Task> allTasks = data.map((json) => Task.fromJson(json)).toList();

        // Sorting Logic (within current page)
        List<Task> incomplete = allTasks.where((t) => t.progress < 100).toList();
        List<Task> complete = allTasks.where((t) => t.progress >= 100).toList();
        incomplete.sort((a, b) => b.id.compareTo(a.id));
        complete.sort((a, b) => b.id.compareTo(a.id));

        final statusCounts = result['status_counts'] ?? {};

        setState(() {
          _tasks = [...incomplete, ...complete];
          _filteredTasks = _tasks; // Initialize filtered tasks
          _totalCount = result['total_count'] ?? 0;
          _completed = statusCounts['completed'] ?? 0;
          _inProgress = statusCounts['in_progress'] ?? 0;
          _notStarted = statusCounts['not_started'] ?? 0;
          _onHold = statusCounts['on_hold'] ?? 0;
          _isLoading = false;
          _isInitialLoad = false;
        });
      } else {
        setState(() {
          _error = result['message'];
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '0': return Colors.orange; // Not Started
      case '1': return Colors.blue;   // In Progress
      case '2': return Colors.green;  // Completed
      case '3': return Colors.red;    // Cancelled
      case '4': return Colors.grey;   // Hold
      default: return Colors.blueGrey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case '0': return 'tasks.not_started'.tr(context);
      case '1': return 'tasks.in_progress'.tr(context);
      case '2': return 'tasks.completed'.tr(context);
      case '3': return 'tasks.cancelled'.tr(context);
      case '4': return 'tasks.on_hold'.tr(context);
      default: return 'Unknown';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'My ISN',
        userData: widget.userData,
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'tasks',
      ),
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _filteredTasks.length + 5,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildSummaryCards();
                      if (index == 1) return _buildSearchField();
                      if (index == 2) return _buildDepartmentFilter();
                      if (index == 3) return _buildPaginationHeader();
                      
                      if (index == _filteredTasks.length + 4) {
                        return _buildPaginationFooter();
                      }
                      
                      if (_filteredTasks.isEmpty && index == 4) return _buildEmptyState();
                      if (_filteredTasks.isEmpty) return const SizedBox.shrink();

                      final task = _filteredTasks[index - 4];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTaskCard(task),
                      );
                    },
                  ),
                ),
      floatingActionButton: _hasPermission('mobile_tasks_add') 
      ? FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskPage(userData: widget.userData),
            ),
          );
          if (result == true) _fetchTasks();
        },
        backgroundColor: const Color(0xFF7E57C2),
        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        label: Text('tasks.add_task'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildPaginationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PaginationHeader(
        limit: _limit,
        totalCount: _totalCount,
        onLimitChanged: (val) {
          if (val != null) {
            setState(() {
              _limit = val;
              _page = 1;
            });
            _fetchTasks();
          }
        },
        totalLabel: 'todo_list.total'.tr(
          context,
          args: {'count': _totalCount.toString()},
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Theme.of(context).brightness == Brightness.dark
              ? Border.all(color: Colors.white.withOpacity(0.1))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'tasks.search_hint'.tr(context),
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            border: InputBorder.none,
            icon: Icon(Icons.search_rounded, color: Colors.grey[300], size: 20),
            suffixIcon: _isLoading && !_isInitialLoad 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentFilter() {
    if (!_hasPermission('mobile_tasks_view_all')) return const SizedBox.shrink();
    if (_departments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _departments.length + 1,
          itemBuilder: (context, index) {
            final bool isAll = index == 0;
            final dept = isAll ? null : _departments[index - 1];
            final bool isSelected = (isAll && _selectedDepartmentId == null) || 
                                  (!isAll && _selectedDepartmentId == int.parse(dept['department_id'].toString()));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDepartmentId = isAll ? null : int.parse(dept['department_id'].toString());
                    _page = 1;
                  });
                  _fetchTasks();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? _primaryColor.withValues(alpha: 0.2)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
                            : Theme.of(context).cardColor),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? _primaryColor 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white.withOpacity(0.1) 
                              : Theme.of(context).dividerColor.withOpacity(0.1)),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isAll ? 'tasks.all'.tr(context) : dept['department_name'],
                      style: TextStyle(
                        color: isSelected ? _primaryColor : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: TodoPaginationFooter(
        currentPage: _page,
        totalCount: _totalCount,
        selectedLimit: _limit,
        onPageChanged: (page) {
          setState(() => _page = page);
          _fetchTasks();
        },
        primaryColor: const Color(0xFF7E57C2),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildStatCard('tasks.completed'.tr(context), _completed, Colors.green, Icons.check_circle_outline, '2'),
          _buildStatCard('tasks.in_progress'.tr(context), _inProgress, Colors.indigo, Icons.sync, '1'),
          _buildStatCard('tasks.not_started'.tr(context), _notStarted, Colors.teal, Icons.hourglass_empty, '0'),
          _buildStatCard('tasks.on_hold'.tr(context), _onHold, Colors.red, Icons.pause_circle_outline, '4'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon, String statusKey) {
    return Container(
      width: 160,
      height: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: double.parse(count.toString())),
                curve: Curves.easeOutExpo,
                builder: (context, value, child) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 24,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), 
              fontSize: 13, 
              fontWeight: FontWeight.w500
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final statusColor = _getStatusColor(task.status);
    final bool isCompleted = task.progress >= 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF7E57C2).withValues(alpha: 0.04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(
            isCompleted ? Icons.check_circle : Icons.pending_actions,
            color: isCompleted ? Colors.green : statusColor,
            size: 30,
          ),
          title: Text(
            task.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isCompleted ? Colors.grey : Theme.of(context).textTheme.titleMedium?.color,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.projectName,
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress / 100,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : statusColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${task.progress}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.calendar_today, 'tasks.period'.tr(context), '${task.startDate} - ${task.endDate}'),
                  _buildInfoRow(Icons.people_outline, 'tasks.team_assign'.tr(context), task.assignedTo.isEmpty ? 'tasks.all_staff'.tr(context) : task.assignedTo),
                  if (task.description.isNotEmpty)
                    _buildInfoRow(Icons.notes, 'tasks.description'.tr(context), task.description),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailPage(
                                  userData: widget.userData,
                                  task: task,
                                ),
                              ),
                            );
                            if (result == true) _fetchTasks();
                          },
                          icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                          label: Text('tasks.open_detail_update'.tr(context), style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('tasks.no_tasks'.tr(context), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
