import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../services/project_task_service.dart';
import '../widgets/pagination_header.dart';
import '../todo_list/widgets/todo_pagination_footer.dart';
import '../localization/app_localizations.dart';
import 'models/project_model.dart';
import '../tasks/task_list_page.dart';
import 'project_detail_page.dart';
import 'add_project_page.dart';

class ProjectListPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProjectListPage({super.key, required this.userData});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  final ProjectTaskService _service = ProjectTaskService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  
  List<Project> _projects = [];
  List<Project> _filteredProjects = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isInitialLoad = true; // Flag for first-time loading
  String? _error = null;
  List<dynamic> _departments = [];
  int? _selectedDepartmentId;

  // Pagination state
  int _limit = 10;
  int _page = 1;
  int _totalCount = 0;

  Color get _primaryColor => const Color(0xFF7E57C2);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchDepartments();
    _searchController.addListener(_filterProjects);
  }

  Future<void> _fetchDepartments() async {
    final result = await _service.getDepartments();
    if (mounted && result['status'] == true) {
      setState(() {
        _departments = result['data'] ?? [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProjects() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _page = 1; // Reset to page 1 on search
      });
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final results = await Future.wait([
      _service.getProjects(
        limit: _limit, 
        page: _page, 
        search: _searchController.text,
        departmentId: _selectedDepartmentId,
      ),
      _service.getProjectStats(
        search: _searchController.text,
        departmentId: _selectedDepartmentId,
      ),
    ]);

    if (mounted) {
      final projectResult = results[0];
      final statsResult = results[1];

      if (projectResult['status'] == true) {
        final List data = projectResult['data'] ?? [];
        final List<Project> allProjects = data.map((json) => Project.fromJson(json)).toList();
        
        setState(() {
          _projects = allProjects;
          _filteredProjects = _projects;
          _stats = statsResult['data'] ?? {};
          _totalCount = projectResult['total_count'] ?? 0;
          _isLoading = false;
          _isInitialLoad = false;
        });
      } else {
        setState(() {
          _error = projectResult['message'];
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _fetchProjects() async => _fetchData();

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    return resources.split(',').contains(resource);
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
        activePage: 'projects',
      ),
      floatingActionButton: _hasPermission('mobile_projects_add') ? FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProjectPage(userData: widget.userData),
            ),
          );
          if (result == true) {
            _fetchData();
          }
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
        label: Text('projects.add_project'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _filteredProjects.length + 5, // Summary, Search, DeptFilter, PagHead, Projects, PagFoot
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildSummaryCards();
                      if (index == 1) return _buildHeader(); // Search Bar
                      if (index == 2) return _buildDepartmentFilter(); // New Filter
                      if (index == 3) return _buildPaginationHeader();
                      
                      if (index == _filteredProjects.length + 4) {
                        return _buildPaginationFooter();
                      }

                      if (_filteredProjects.isEmpty && index == 4) return _buildEmptyState();
                      if (_filteredProjects.isEmpty) return const SizedBox.shrink();

                      final project = _filteredProjects[index - 4];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildProjectCard(project),
                      );
                    },
                  ),
                ),
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
            _fetchData();
          }
        },
        totalLabel: 'todo_list.total'.tr(
          context,
          args: {'count': _totalCount.toString()},
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
          _fetchData();
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
          _buildStatCard('projects.completed'.tr(context), _stats['completed'] ?? 0, Colors.green, Icons.check_circle_outline, '2'),
          _buildStatCard('projects.in_progress'.tr(context), _stats['in_progress'] ?? 0, Colors.indigo, Icons.sync, '1'),
          _buildStatCard('projects.not_started'.tr(context), _stats['not_started'] ?? 0, Colors.teal, Icons.hourglass_empty, '0'),
          _buildStatCard('projects.on_hold'.tr(context), _stats['hold'] ?? 0, Colors.red, Icons.pause_circle_outline, '4'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic count, Color color, IconData icon, String statusKey) {
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

  Widget _buildDepartmentFilter() {
    if (!_hasPermission('mobile_projects_view_all')) return const SizedBox.shrink();
    if (_departments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
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
                      _fetchData();
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
                          isAll ? 'projects.all'.tr(context) : dept['department_name'],
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            hintText: 'projects.search_hint'.tr(context),
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

  Widget _buildProjectCard(Project project) {
    final statusColor = _getStatusColor(project.status);
    final isCompleted = project.progress >= 100;

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
            isCompleted ? Icons.check_circle : Icons.folder_rounded,
            color: isCompleted ? Colors.green : statusColor,
            size: 30,
          ),
          title: Text(
            project.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isCompleted ? Colors.grey : Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.departmentName,
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.progress / 100,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : statusColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${project.progress}%',
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
                  _buildInfoRow(Icons.priority_high_rounded, 'projects.priority'.tr(context), _getPriorityText(project.priority)),
                  _buildInfoRow(Icons.calendar_today, 'projects.period'.tr(context), '${project.startDate} - ${project.endDate}'),
                  _buildInfoRow(Icons.people_outline, 'projects.team'.tr(context), project.team),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProjectDetailPage(
                                  projectId: project.id,
                                  userData: widget.userData,
                                ),
                              ),
                            ).then((_) => _fetchData());
                          },
                          icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                          label: Text('projects.open_detail_update'.tr(context), style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
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

  String _getPriorityText(String priority) {
    switch (priority) {
      case '1': return 'projects.priority_highest'.tr(context);
      case '2': return 'projects.priority_high'.tr(context);
      case '3': return 'projects.priority_normal'.tr(context);
      default: return 'projects.priority_low'.tr(context);
    }
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('projects.no_projects'.tr(context), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          TextButton(onPressed: _fetchData, child: Text('main.try_again'.tr(context))),
        ],
      ),
    );
  }
}
