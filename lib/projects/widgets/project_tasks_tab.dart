import 'package:flutter/material.dart';
import '../../services/project_task_service.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/task_detail_page.dart';
import '../../localization/app_localizations.dart';

class ProjectTasksTab extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic> userData;
  final VoidCallback? onRefresh;
  final DateTime? lastRefresh;

  const ProjectTasksTab({super.key, required this.projectId, required this.userData, this.onRefresh, this.lastRefresh});

  @override
  State<ProjectTasksTab> createState() => _ProjectTasksTabState();
}

class _ProjectTasksTabState extends State<ProjectTasksTab> {
  final ProjectTaskService _service = ProjectTaskService();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(ProjectTasksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId || oldWidget.lastRefresh != widget.lastRefresh) {
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final result = await _service.getTasks(projectId: widget.projectId);
    if (mounted) {
      setState(() {
        if (result['status'] == true) {
          _tasks = (result['data'] as List).map((t) => Task.fromJson(t)).toList();
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'projects.no_tasks_in_project'.tr(context),
              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = task.progress.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailPage(
                userData: widget.userData,
                task: task,
              ),
            ),
          ).then((_) {
            _loadTasks();
            if (widget.onRefresh != null) widget.onRefresh!();
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              task.endDate.isEmpty ? '-' : task.endDate,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task.taskAssignees.isEmpty ? 'tasks.all_staff'.tr(context) : task.taskAssignees,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(task.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(task.status)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${progress.toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(task.status),
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

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case '0': return 'projects.not_started'.tr(context);
      case '1': return 'projects.in_progress'.tr(context);
      case '2': return 'projects.completed'.tr(context);
      case '3': return 'projects.cancelled'.tr(context);
      case '4': return 'projects.on_hold'.tr(context);
      default: return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '0': return Colors.orange;
      case '1': return Colors.blue;
      case '2': return Colors.green;
      case '3': return Colors.red;
      case '4': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }
}
