import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/limit_dropdown_widget.dart';
import '../widgets/pagination_header.dart';

import '../widgets/searchable_dropdown.dart';
import 'widgets/todo_stats_card.dart';
import 'widgets/todo_item_tile.dart';
import 'widgets/todo_filter_bar.dart';
import 'widgets/todo_pagination_footer.dart';


class TodoListPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final int? initialTodoId;

  const TodoListPage({super.key, this.userData, this.initialTodoId});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  bool _isLoading = true;
  List<dynamic> _allTodos = []; // Master list for client-side pagination
  List<dynamic> _todos = []; // Current page slice

  // Pagination
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  // Stats
  int _completedCount = 0;
  int _pendingCount = 0;
  int _completedTodayCount = 0;
  bool _isStatsExpanded = true;

  // Throttling
  final Map<String, DateTime> _lastToggleTimes = {};
  Map<String, dynamic>? _currentUserData;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  StateSetter? _currentModalSetState;

  // Team Mode State
  String _viewMode = 'personal'; // 'personal' or 'team'
  String? _selectedEmployeeId;
  List<dynamic> _employees = [];
  bool _isEmployeesLoading = false;

  // Offline Sync State
  List<Map<String, dynamic>> _pendingTodos = [];
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initSpeech();
    _loadPendingTodos();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncPendingTodos();
      }
    });
  }

  void _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
            if (_currentModalSetState != null) {
              try {
                _currentModalSetState!(() {});
              } catch (e) {}
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Speech init error: \$e");
    }
  }

  Future<void> _initializeData() async {
    if (widget.userData != null) {
      _currentUserData = widget.userData;
      _fetchTodos();
      _fetchEmployees(); // Pre-fetch in background
      _markAsSeen();
    } else {
      const storage = FlutterSecureStorage();
      final userDataStr = await storage.read(key: 'user_data');
      if (userDataStr != null) {
        if (mounted) {
          setState(() {
            _currentUserData = json.decode(userDataStr);
          });
          _fetchTodos();
          _fetchEmployees();
          _markAsSeen();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPendingTodos() async {
    const storage = FlutterSecureStorage();
    final jsonStr = await storage.read(key: 'pending_todos');
    if (jsonStr != null) {
      try {
        setState(() {
          _pendingTodos = List<Map<String, dynamic>>.from(json.decode(jsonStr));
        });
      } catch (e) {
        debugPrint('Error loading pending todos: $e');
      }
    }
  }

  Future<void> _savePendingTodos() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'pending_todos', value: json.encode(_pendingTodos));
  }

  Future<void> _markAsSeen() async {
    if (_currentUserData == null) return;
    final userId = _currentUserData!['id'] ?? _currentUserData!['user_id'];
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/mark_todo_seen'),
        body: {'user_id': userId.toString()},
      );
      NotificationManager().clearTodoBadge();
    } catch (e) {
      // Silent error
    }
  }

  bool _hasPermission(String resource) {
    if (_currentUserData == null) return false;
    if (_currentUserData!['role_access'] == '1' ||
        _currentUserData!['role_resources'] == 'all') {
      return true;
    }
    final String resources = _currentUserData!['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchTodos({int? page, String? targetUserId}) async {
    if (_currentUserData == null) return;
    final int targetPage = page ?? _currentPage;
    setState(() => _isLoading = true);
    try {
      // Use selected employee ID if in team mode, otherwise use current user ID
      final String userId =
          targetUserId ??
          ((_viewMode == 'team' && _selectedEmployeeId != null)
              ? _selectedEmployeeId!
              : (_currentUserData!['id'] ?? _currentUserData!['user_id'])
                    .toString());

      final url =
          '${AppConstants.baseUrl}/get_todos?user_id=$userId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _currentPage = targetPage;
            _allTodos = result['data'] ?? [];
            _totalCount = result['total_count'] ?? _allTodos.length;
            _completedCount = result['completed_count'] ?? 0;
            _pendingCount = result['pending_count'] ?? 0;
            _completedTodayCount = result['completed_today_count'] ?? 0;

            // Initial sort
            _sortTodos(_allTodos);
            // Apply pagination slice
            _paginateLocal();
          });

          // Handle deep linking for highlighting specific Todo
          if (widget.initialTodoId != null) {
            _highlightInitialTodo();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching todos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchEmployees() async {
    if (_employees.isNotEmpty) return; // Only fetch once
    setState(() => _isEmployeesLoading = true);
    try {
      final companyId = _currentUserData?['company_id'] ?? 2;
      final url =
          '${AppConstants.baseUrl}/get_employees?company_id=$companyId&limit=500';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        setState(() {
          _employees = data['data'];
          // Filter to remove current user from team list? No, keep it or auto-select.
          if (_selectedEmployeeId == null && _employees.isNotEmpty) {
            // Don't auto-select yet to avoid confusion
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    } finally {
      setState(() => _isEmployeesLoading = false);
    }
  }

  void _paginateLocal() {
    final start = (_currentPage - 1) * _selectedLimit;
    int end = start + _selectedLimit;
    if (end > _allTodos.length) end = _allTodos.length;

    if (start >= _allTodos.length) {
      _todos = [];
    } else {
      _todos = _allTodos.sublist(start, end);
    }
  }

  void _sortTodos(List<dynamic> list) {
    list.sort((a, b) {
      bool aDone =
          (a['is_done'] == '1' || a['is_done'] == 1 || a['is_done'] == true);
      bool bDone =
          (b['is_done'] == '1' || b['is_done'] == 1 || b['is_done'] == true);

      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;

      // Secondary sort: newest first
      try {
        DateTime aDate = DateTime.parse(a['created_at']);
        DateTime bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate);
      } catch (e) {
        return 0;
      }
    });
  }

  void _highlightInitialTodo() {
    // Current pagination only shows first N todos.
    // If we want to find the specific todo, we might need a separate API or different approach.
    // For now, if it exists in the current page, we can show a snackbar or scroll to it.
    final todo = _todos.firstWhere(
      (t) => t['todo_item_id'].toString() == widget.initialTodoId.toString(),
      orElse: () => null,
    );

    if (todo != null) {
      context.showSuccessSnackBar('todo_list.search_result_msg'.tr(context, args: {'%s': todo['description'] ?? ''}));
    }
  }

  Future<void> _toggleTodo(dynamic todo) async {
    final String todoId = todo['todo_item_id'].toString();
    final now = DateTime.now();

    // Throttling: Prevent clicks faster than 500ms
    if (_lastToggleTimes.containsKey(todoId) &&
        now.difference(_lastToggleTimes[todoId]!) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastToggleTimes[todoId] = now;

    // 1. Optimistic UI Update
    final int index = _todos.indexOf(todo);
    if (index == -1) return;

    final bool originalStatus =
        (todo['is_done'] == '1' || todo['is_done'] == 1);
    final bool newStatus = !originalStatus;

    setState(() {
      _allTodos[index]['is_done'] = newStatus ? 1 : 0;
      if (newStatus) {
        _completedCount++;
        _pendingCount--;
        _completedTodayCount++;
      } else {
        _completedCount--;
        _pendingCount++;
        if (_completedTodayCount > 0) _completedTodayCount--;
      }
      _sortTodos(_allTodos);
      _paginateLocal();
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/toggle_todo'),
        body: {'todo_item_id': todo['todo_item_id'].toString()},
      );

      if (response.statusCode != 200) {
        // Revert on failure
        _revertToggle(index, originalStatus);
      } else {
        // Refresh to stay in sync with global server-side sorting
        _fetchTodos();
      }
    } catch (e) {
      debugPrint('Error toggling todo: $e');
      _revertToggle(index, originalStatus);
    }
  }

  void _revertToggle(int index, bool originalStatus) {
    if (mounted) {
      setState(() {
        _allTodos[index]['is_done'] = originalStatus ? 1 : 0;
        if (!originalStatus) {
          _completedCount--;
          _pendingCount++;
        } else {
          _completedCount++;
          _pendingCount--;
        }
        _sortTodos(_allTodos);
        _paginateLocal();
      });
      context.showErrorSnackBar('todo_list.status_update_failed'.tr(context));
    }
  }

  Future<void> _deleteTodo(dynamic todo) async {
    if (_currentUserData == null) return;
    final userId = (_currentUserData!['id'] ?? _currentUserData!['user_id'])
        .toString();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/delete_todo'),
        body: {
          'todo_item_id': todo['todo_item_id'].toString(),
          'user_id': userId,
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
        if (mounted) {
          context.showSuccessSnackBar('todo_list.delete_success'.tr(context));
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar('${'todo_list.delete_failed'.tr(context)} (${response.statusCode})');
        }
      }
    } catch (e) {
      debugPrint('Error deleting todo: \$e');
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    }
  }

  Future<void> _addTodo(String description) async {
    final String targetUserId =
        (_viewMode == 'team' && _selectedEmployeeId != null)
            ? _selectedEmployeeId!
            : (_currentUserData!['id'] ?? _currentUserData!['user_id'])
                .toString();

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _saveTodoOffline(description, targetUserId);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/add_todo'),
        body: {'user_id': targetUserId, 'description': description},
      );

      if (response.statusCode == 200) {
        _fetchTodos();
        if (mounted) {
          context.showSuccessSnackBar('todo_list.save_success'.tr(context));
        }
      }
    } catch (e) {
      debugPrint('Error adding todo: $e');
      // If error (timeout/network), save offline too
      _saveTodoOffline(description, targetUserId);
    }
  }

  void _saveTodoOffline(String description, String userId) async {
    final newItem = {
      'todo_item_id': 'offline_${DateTime.now().millisecondsSinceEpoch}',
      'description': description,
      'user_id': userId,
      'is_done': '0',
      'priority': '2',
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _pendingTodos.add(newItem);
    });
    await _savePendingTodos();

    if (mounted) {
      context.showWarningSnackBar('todo_list.offline_saved'.tr(context));
    }
  }

  Future<void> _syncPendingTodos() async {
    if (_isSyncing || _pendingTodos.isEmpty) return;

    _isSyncing = true;
    List<Map<String, dynamic>> successfullySynced = [];

    try {
      for (var todo in _pendingTodos) {
        try {
          final response = await http.post(
            Uri.parse('${AppConstants.baseUrl}/add_todo'),
            body: {
              'user_id': todo['user_id'].toString(),
              'description': todo['description'],
            },
          );
          if (response.statusCode == 200) {
            successfullySynced.add(todo);
          }
        } catch (e) {
          debugPrint('Sync error for item: $e');
        }
      }

      if (successfullySynced.isNotEmpty) {
        setState(() {
          _pendingTodos.removeWhere((item) => successfullySynced.contains(item));
        });
        await _savePendingTodos();
        _fetchTodos();

        if (mounted) {
          context.showSuccessSnackBar('todo_list.sync_success'.tr(context));
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _updateTodo(dynamic todoId, String description) async {
    if (_currentUserData == null) return;
    final userId = (_currentUserData!['id'] ?? _currentUserData!['user_id'])
        .toString();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/edit_todo'),
        body: {
          'todo_item_id': todoId.toString(),
          'user_id': userId,
          'description': description,
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
      }
    } catch (e) {
      debugPrint('Error updating todo: $e');
    }
  }

  Future<void> _updateTodoPriority(dynamic todoId, int newPriority) async {
    if (_currentUserData == null) return;
    final userId = (_currentUserData!['id'] ?? _currentUserData!['user_id'])
        .toString();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/edit_todo'),
        body: {
          'todo_item_id': todoId.toString(),
          'user_id': userId,
          'priority': newPriority.toString(),
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
        if (mounted) {
          context.showSuccessSnackBar('todo_list.update_success'.tr(context));
        }
      }
    } catch (e) {
      debugPrint('Error updating todo priority: $e');
    }
  }

  void _showPriorityDialog(dynamic todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('todo_list.priority'.tr(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityOption(context, todo, 1, Colors.red, 'todo_list.high'.tr(context)),
            _buildPriorityOption(context, todo, 2, Colors.orange, 'todo_list.normal'.tr(context)),
            _buildPriorityOption(context, todo, 3, Colors.grey, 'todo_list.low'.tr(context)),
          ],
        ),
      ),
    );
  }

  void _copyTodoText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      context.showSuccessSnackBar('todo_list.copy_success'.tr(context));
    }
  }

  Widget _buildPriorityOption(BuildContext context, dynamic todo, int priority, Color color, String label) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        _updateTodoPriority(todo['todo_item_id'], priority);
      },
    );
  }

  Future<void> _moveTodo(dynamic todo, String targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/edit_todo'),
        body: {
          'todo_item_id': todo['todo_item_id'].toString(),
          'user_id': targetUserId,
          'description': todo['description'] ?? '',
        },
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['status'] == true) {
        _fetchTodos();
        if (mounted) {
          context.showSuccessSnackBar('todo_list.move_success'.tr(context));
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar('${'todo_list.move_failed'.tr(context)}: ${result['message'] ?? response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error moving todo: $e');
      if (mounted) {
        context.showErrorSnackBar('${'todo_list.move_failed'.tr(context)}: $e');
      }
    }
  }

  void _showMoveTodoDialog(dynamic todo) {
    String? localSelectedId;
    String selectedName = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<Map<String, String>> employeeOptions = _employees.map((
            emp,
          ) {
            return {
              'id': emp['user_id'].toString(),
              'name': '${emp['first_name']} ${emp['last_name'] ?? ''}'.trim(),
            };
          }).toList();

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'todo_list.move_task'.tr(context),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'todo_list.move_to'.tr(context),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                SearchableDropdown(
                  label: 'todo_list.select_employee'.tr(context),
                  value: selectedName,
                  options: employeeOptions,
                  icon: Icons.person_add_alt_1_rounded,
                  required: true,
                  onSelected: (val) {
                    final emp = _employees.firstWhere(
                      (e) => e['user_id'].toString() == val,
                    );
                    setModalState(() {
                      localSelectedId = val;
                      selectedName =
                          '${emp['first_name']} ${emp['last_name'] ?? ''}'
                              .trim();
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: localSelectedId == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            _confirmMove(todo, localSelectedId!, selectedName);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'todo_list.move_task'.tr(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmMove(dynamic todo, String targetUserId, String targetName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
            Icon(Icons.unarchive_rounded, color: _primaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              'todo_list.move_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'todo_list.move_confirm_desc'
                    .tr(context)
                    .replaceAll('%s', targetName),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
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
                      _moveTodo(todo, targetUserId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.xin_confirm'.tr(context)),
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

  void _showEditTodoDialog(dynamic todo) {
    final TextEditingController controller = TextEditingController(
      text: todo['description'],
    );
    _isListening = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          _currentModalSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'todo_list.edit_task'.tr(context),
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'todo_list.task_desc'.tr(context),
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _isSpeechInitialized
                          ? IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? Colors.red
                                    : _primaryColor,
                              ),
                              onPressed: () async {
                                if (!_isListening) {
                                  bool available = await _speech.initialize();
                                  if (available) {
                                    setModalState(() => _isListening = true);
                                    _speech.listen(
                                      localeId: 'id_ID',
                                      listenFor: const Duration(hours: 1),
                                      pauseFor: const Duration(seconds: 60),
                                      listenMode: stt.ListenMode.dictation,
                                      onResult: (val) {
                                        setModalState(() {
                                          controller.text = val.recognizedWords;
                                          controller.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset:
                                                      controller.text.length,
                                                ),
                                              );
                                        });
                                      },
                                    );
                                  }
                                } else {
                                  setModalState(() => _isListening = false);
                                  _speech.stop();
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _speech.stop();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'main.cancel'.tr(context),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            _speech.stop();
                            _updateTodo(
                              todo['todo_item_id'],
                              controller.text.trim(),
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'main.save'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _speech.stop());
  }

  void _showAddTodoDialog() {
    final TextEditingController controller = TextEditingController();
    _isListening = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          _currentModalSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'todo_list.new_task_title'.tr(context),
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'todo_list.task_desc'.tr(context),
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _isSpeechInitialized
                          ? IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? Colors.red
                                    : _primaryColor,
                              ),
                              onPressed: () async {
                                if (!_isListening) {
                                  bool available = await _speech.initialize();
                                  if (available) {
                                    setModalState(() => _isListening = true);
                                    _speech.listen(
                                      localeId: 'id_ID',
                                      listenFor: const Duration(hours: 1),
                                      pauseFor: const Duration(seconds: 60),
                                      listenMode: stt.ListenMode.dictation,
                                      onResult: (val) {
                                        setModalState(() {
                                          controller.text = val.recognizedWords;
                                          controller.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset:
                                                      controller.text.length,
                                                ),
                                              );
                                        });
                                      },
                                    );
                                  }
                                } else {
                                  setModalState(() => _isListening = false);
                                  _speech.stop();
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _speech.stop();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'main.cancel'.tr(context),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            _speech.stop();
                            _addTodo(controller.text.trim());
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'main.save'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _speech.stop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: _currentUserData ?? {},
        showBackButton: false,
      ),
      endDrawer: SideDrawer(
        userData: _currentUserData ?? {},
        activePage: 'todo_list',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _currentPage = 1;
          await _fetchTodos();
          if (_viewMode == 'team') {
            await _fetchEmployees();
          }
        },
        color: _primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    TodoStatsCard(
                      totalCount: _totalCount,
                      completedCount: _completedCount,
                      pendingCount: _pendingCount,
                      completedTodayCount: _completedTodayCount,
                      isExpanded: _isStatsExpanded,
                      onToggleExpand: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
                      primaryColor: _primaryColor,
                    ),
                    const SizedBox(height: 16),
                    if (_hasPermission('mobile_todo_team')) ...[
                      TodoFilterBar(
                        viewMode: _viewMode,
                        onViewModeChanged: (mode) {
                          if (_viewMode == mode) return;
                          setState(() {
                            _viewMode = mode;
                            _currentPage = 1;
                            _todos = [];
                            _allTodos = [];
                          });

                          if (mode == 'team') {
                            if (_selectedEmployeeId != null) {
                              _fetchTodos();
                            } else {
                              setState(() => _isLoading = false);
                            }
                          } else {
                            _fetchTodos();
                          }
                        },
                        employees: _employees,
                        selectedEmployeeId: _selectedEmployeeId,
                        onEmployeeSelected: (val) {
                          if (val.isNotEmpty) {
                            setState(() {
                              _selectedEmployeeId = val;
                              _currentPage = 1;
                            });
                            _fetchTodos();
                          }
                        },
                        isEmployeesLoading: _isEmployeesLoading,
                        primaryColor: _primaryColor,
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
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
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_todos.isEmpty && _pendingTodos.isEmpty && !_isLoading)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final bool isPendingItem = index < _pendingTodos.length;
                    final todo = isPendingItem
                        ? _pendingTodos[index]
                        : _todos[index - _pendingTodos.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TodoItemTile(
                        todo: todo,
                        isOffline: isPendingItem,
                        isCompleted: (todo['is_done'] == '1' || todo['is_done'] == 1 || todo['is_done'] == true),
                        onToggle: () => isPendingItem ? null : _toggleTodo(todo),
                        onEdit: () => isPendingItem ? null : _showEditTodoDialog(todo),
                        onDelete: () => isPendingItem ? null : _confirmDelete(todo),
                        onMove: () => isPendingItem ? null : _showMoveTodoDialog(todo),
                        hasPermissionDelete: _hasPermission('mobile_todo_delete'),
                        hasPermissionTeam: _hasPermission('mobile_todo_team'),
                        primaryColor: _primaryColor,
                        onPriorityChange: () => isPendingItem ? null : _showPriorityDialog(todo),
                        onCopy: () => _copyTodoText(todo['description']),
                      ),
                    );
                  }, childCount: _todos.length + _pendingTodos.length),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TodoPaginationFooter(
                  currentPage: _currentPage,
                  totalCount: _totalCount,
                  selectedLimit: _selectedLimit,
                  onPageChanged: (page) => _fetchTodos(page: page),
                  primaryColor: _primaryColor,
                ),
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
              label: Text(
                'todo_list.add_task'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPaginationHeader() {
    return PaginationHeader(
      limit: _selectedLimit,
      limitOptions: _limitOptions,
      totalCount: _totalCount,
      onLimitChanged: (int? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedLimit = newValue;
            _currentPage = 1;
          });
          _fetchTodos();
        }
      },
      primaryColor: _primaryColor,
      totalLabel: 'todo_list.total'.tr(
        context,
        args: {'count': _totalCount.toString()},
      ),
    );
  }



  void _confirmDelete(dynamic todo) {
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
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
              'todo_list.delete_confirm_title'.tr(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'todo_list.delete_confirm_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      _deleteTodo(todo);
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
}
