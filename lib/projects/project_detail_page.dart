import 'package:flutter/material.dart';
import '../widgets/secondary_app_bar.dart';
import '../localization/app_localizations.dart';
import '../services/project_task_service.dart';
import '../widgets/custom_snackbar.dart';
import 'widgets/project_overview_tab.dart';
import 'widgets/project_edit_tab.dart';
import 'widgets/project_tasks_tab.dart';

class ProjectDetailPage extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic> userData;

  const ProjectDetailPage({super.key, required this.projectId, required this.userData});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final ProjectTaskService _service = ProjectTaskService();
  Map<String, dynamic>? _project;
  bool _isLoading = true;
  bool _isUpdating = false;
  String _activeTab = 'OVERVIEW';
  bool _isExpanded = false;
  DateTime? _lastRefresh;
  
  final GlobalKey<ProjectEditTabState> _editTabKey = GlobalKey<ProjectEditTabState>();

  final List<String> _menuTabs = [
    'OVERVIEW',
    'EDIT',
    'TASKS',
  ];

  Color get _primaryColor => const Color(0xFF7E57C2);

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    return resources.split(',').contains(resource);
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
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
                color: Theme.of(context).dividerColor.withOpacity(0.2),
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
              'projects.delete_title'.tr(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'projects.delete_confirm_permanent'.tr(context),
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
                      _deleteProject();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'main.delete'.tr(context),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _deleteProject() async {
    setState(() => _isUpdating = true);
    final result = await _service.deleteProject(widget.projectId);
    setState(() => _isUpdating = false);

    if (result['status'] == true) {
      CustomSnackBar.showSuccess(context, 'projects.delete_success'.tr(context));
      Navigator.pop(context, true);
    } else {
      CustomSnackBar.showError(context, '${'projects.delete_failed'.tr(context)}: ${result['message']}');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    setState(() => _isLoading = true);
    final result = await _service.getProjectDetails(widget.projectId);
    if (mounted) {
      setState(() {
        if (result['status'] == true) {
          _project = result['data'];
          _lastRefresh = DateTime.now();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    final result = await _service.updateProjectDetails({
      'project_id': widget.projectId,
      'status': status,
    });
    if (mounted) {
      setState(() => _isUpdating = false);
      if (result['status'] == true) {
        CustomSnackBar.showSuccess(context, 'projects.status_updated'.tr(context));
        _loadProject();
      } else {
        CustomSnackBar.showError(context, 'projects.update_status_failed'.tr(context));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title: 'My ISN',
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_hasPermission('mobile_projects_delete'))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _project == null
               ? Center(child: Text('projects.load_failed'.tr(context)))
              : RefreshIndicator(
                  onRefresh: _loadProject,
                  color: _primaryColor,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderCard(),
                              const SizedBox(height: 20),
                              _buildHorizontalMenu(),
                              const SizedBox(height: 24),
                              _buildActiveTabContent(),
                            ],
                          ),
                        ),
                      ),
                      if (_activeTab == 'EDIT') _buildBottomAction(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final progress = double.tryParse(_project?['project_progress']?.toString() ?? '0') ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_isExpanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _project?['title'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatusChip(_project?['status']?.toString() ?? '0'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  Text(
                                    '${value.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value / 100,
                              minHeight: 12,
                              backgroundColor: _primaryColor.withValues(alpha: 0.1),
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(Icons.info_outline, 'projects.status_settings'.tr(context)),
                      const SizedBox(height: 12),
                      _buildStatusDropdown(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDateInfo(
                            'projects.start_date'.tr(context),
                            _project?['start_date'] ?? '-',
                            Icons.calendar_today_rounded,
                          ),
                          _buildDateInfo(
                            'projects.end_date'.tr(context),
                            _project?['end_date'] ?? '-',
                            Icons.event_available_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6), fontWeight: FontWeight.bold),
            ),
            Text(
              date,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHorizontalMenu() {
    final List<String> filteredTabs = List.from(_menuTabs);
    if (!_hasPermission('mobile_projects_edit')) {
      filteredTabs.remove('EDIT');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filteredTabs.map((tab) {
          final isActive = _activeTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? _primaryColor : Theme.of(context).dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                  'projects.${tab.toLowerCase()}'.tr(context),
                style: TextStyle(
                  color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'OVERVIEW':
        return ProjectOverviewTab(project: _project!);
      case 'EDIT':
        return ProjectEditTab(key: _editTabKey, project: _project!, onUpdate: _loadProject);
      case 'TASKS':
        return ProjectTasksTab(
          projectId: widget.projectId,
          userData: widget.userData,
          onRefresh: _loadProject,
          lastRefresh: _lastRefresh,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _editTabKey.currentState?.saveProject(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('projects.save_changes'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case '0': color = Colors.grey; text = 'projects.not_started'.tr(context); break;
      case '1': color = Colors.blue; text = 'projects.in_progress'.tr(context); break;
      case '2': color = Colors.green; text = 'projects.completed'.tr(context); break;
      case '3': color = Colors.red; text = 'projects.cancelled'.tr(context); break;
      case '4': color = Colors.orange; text = 'projects.on_hold'.tr(context); break;
      default: color = Colors.grey; text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _project?['status']?.toString() ?? '0',
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          items: [
            _buildDropdownItem('0', 'projects.not_started'.tr(context), Colors.grey),
            _buildDropdownItem('1', 'projects.in_progress'.tr(context), Colors.blue),
            _buildDropdownItem('2', 'projects.completed'.tr(context), Colors.green),
            _buildDropdownItem('3', 'projects.cancelled'.tr(context), Colors.red),
            _buildDropdownItem('4', 'projects.on_hold'.tr(context), Colors.orange),
          ],
          onChanged: _hasPermission('mobile_projects_edit') ? (val) {
            if (val != null) _updateStatus(val);
          } : null,
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String text, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
