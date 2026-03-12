import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';

class TodoListPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TodoListPage({super.key, required this.userData});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  bool _isLoading = true;
  List<dynamic> _todos = [];
  
  // Pagination
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  // Stats
  int _completedCount = 0;
  int _pendingCount = 0;
  
  // Throttling
  final Map<String, DateTime> _lastToggleTimes = {};

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchTodos({int? page}) async {
    final int targetPage = page ?? _currentPage;
    setState(() => _isLoading = true);
    try {
      final offset = (targetPage - 1) * _selectedLimit;
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_todos'),
        body: {
          'user_id': (widget.userData['id'] ?? widget.userData['user_id']).toString(),
          'limit': _selectedLimit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _currentPage = targetPage;
            _todos = result['data'];
            _totalCount = result['total_count'] ?? 0;
            _completedCount = result['completed_count'] ?? 0;
            _pendingCount = result['pending_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching todos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTodo(dynamic todo) async {
    final String todoId = todo['todo_item_id'].toString();
    final now = DateTime.now();

    // Throttling: Prevent clicks faster than 500ms
    if (_lastToggleTimes.containsKey(todoId) && 
        now.difference(_lastToggleTimes[todoId]!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastToggleTimes[todoId] = now;

    // 1. Optimistic UI Update
    final int index = _todos.indexOf(todo);
    if (index == -1) return;

    final bool originalStatus = (todo['is_done'] == '1' || todo['is_done'] == 1);
    final bool newStatus = !originalStatus;

    setState(() {
      _todos[index]['is_done'] = newStatus ? 1 : 0;
      if (newStatus) {
        _completedCount++;
        _pendingCount--;
      } else {
        _completedCount--;
        _pendingCount++;
      }
    });

    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/toggle_todo'),
        body: {'todo_item_id': todo['todo_item_id'].toString()},
      );

      if (response.statusCode != 200) {
        // Revert on failure
        _revertToggle(index, originalStatus);
      } else {
        // Optional: Silent refresh to stay in sync with database (e.g. server-side timestamps)
        // But for performance, we don't necessarily need to call _fetchTodos() immediately 
        // unless we expect other fields to change.
      }
    } catch (e) {
      debugPrint('Error toggling todo: $e');
      _revertToggle(index, originalStatus);
    }
  }

  void _revertToggle(int index, bool originalStatus) {
    if (mounted) {
      setState(() {
        _todos[index]['is_done'] = originalStatus ? 1 : 0;
        if (!originalStatus) {
          _completedCount--;
          _pendingCount++;
        } else {
          _completedCount++;
          _pendingCount--;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('todo_list.status_update_failed'.tr(context)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTodo(dynamic todo) async {
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/delete_todo'),
        body: {'todo_item_id': todo['todo_item_id'].toString()},
      );

      if (response.statusCode == 200) {
        _fetchTodos();
      }
    } catch (e) {
      debugPrint('Error deleting todo: $e');
    }
  }

  Future<void> _addTodo(String description) async {
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/add_todo'),
        body: {
          'user_id': (widget.userData['id'] ?? widget.userData['user_id']).toString(),
          'description': description,
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
      }
    } catch (e) {
      debugPrint('Error adding todo: $e');
    }
  }

  void _showAddTodoDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('todo_list.new_task_title'.tr(context)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'todo_list.task_desc'.tr(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addTodo(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('main.save'.tr(context), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: widget.userData, showBackButton: true),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'todo_list'),
      body: RefreshIndicator(
        onRefresh: () => _fetchTodos(),
        color: _primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildHeaderCard(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPaginationHeader(),
              ),
            ),
            if (_isLoading && _todos.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7E57C2))),
              )
            else if (_todos.isEmpty && !_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'todo_list.no_tasks'.tr(context),
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final todo = _todos[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTodoItem(context, todo),
                      );
                    },
                    childCount: _todos.length,
                  ),
                ),
              ),
            if (_totalCount > _selectedLimit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildPaginationFooter(),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _hasPermission('mobile_todo_add')
      ? FloatingActionButton.extended(
        onPressed: _showAddTodoDialog,
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: Text('todo_list.add_task'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
      : null,
    );
  }

  Widget _buildPaginationHeader() {
    final totalPages = (_totalCount / _selectedLimit).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('main.show'.tr(context), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLimit,
                  items: _limitOptions.map((limit) {
                    return DropdownMenuItem<int>(
                      value: limit,
                      child: Text(limit.toString(), style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLimit = value;
                      });
                      _fetchTodos(page: 1);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('main.entries'.tr(context), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        if (_todos.isNotEmpty)
          Text(
            'todo_list.showing_x_of_y'.tr(context, args: {
              'current': _currentPage.toString(),
              'total': totalPages.toString(),
            }),
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    final totalPages = (_totalCount / _selectedLimit).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1
              ? () => _fetchTodos(page: _currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          color: _primaryColor,
        ),
        Text('todo_list.showing_x_of_y'.tr(context, args: {
          'current': _currentPage.toString(),
          'total': totalPages.toString(),
        }), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: _currentPage < totalPages
              ? () => _fetchTodos(page: _currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: _primaryColor,
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMiniInfo(context, 'main.total'.tr(context), _totalCount.toString(), Colors.blue),
          _buildMiniInfo(context, 'todo_list.completed'.tr(context), _completedCount.toString(), Colors.green),
          _buildMiniInfo(context, 'todo_list.pending'.tr(context), _pendingCount.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoItem(BuildContext context, dynamic todo) {
    final bool isCompleted = (todo['is_done'] == '1' || todo['is_done'] == 1);
    final String description = todo['description'] ?? '-';
    final String date = todo['created_at'] ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _hasPermission('mobile_todo_delete') ? _confirmDelete(todo) : null,
            onTap: () => _toggleTodo(todo),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleTodo(todo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green : Colors.transparent,
                        border: Border.all(
                          color: isCompleted ? Colors.green : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isCompleted ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(todo);
                      if (value == 'toggle') _toggleTodo(todo);
                    },
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(isCompleted ? Icons.undo : Icons.check_circle, size: 18),
                            const SizedBox(width: 8),
                            Text(isCompleted ? 'todo_list.pending'.tr(context) : 'todo_list.completed'.tr(context)),
                          ],
                        ),
                      ),
                      if (_hasPermission('mobile_todo_delete'))
                         PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('main.delete'.tr(context), style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(dynamic todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('todo_list.delete_confirm_title'.tr(context)),
        content: Text('todo_list.delete_confirm_desc'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteTodo(todo);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('main.delete'.tr(context), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
