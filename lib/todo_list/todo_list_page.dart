import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  List<dynamic> _todos = [];    // Current page slice

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

  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  StateSetter? _currentModalSetState;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
            if (_currentModalSetState != null) {
              try { _currentModalSetState!(() {}); } catch (e) {}
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
          _markAsSeen();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsSeen() async {
    if (_currentUserData == null) return;
    final userId = _currentUserData!['id'] ?? _currentUserData!['user_id'];
    try {
      await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/mark_todo_seen'),
        body: {'user_id': userId.toString()},
      );
      NotificationManager().clearTodoBadge();
    } catch (e) {
      // Silent error
    }
  }

  bool _hasPermission(String resource) {
    if (_currentUserData == null) return false;
    if (_currentUserData!['role_access'] == '1' || _currentUserData!['role_resources'] == 'all') return true;
    final String resources = _currentUserData!['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchTodos({int? page}) async {
    if (_currentUserData == null) return;
    final int targetPage = page ?? _currentPage;
    setState(() => _isLoading = true);
    try {
      final userId = (_currentUserData!['id'] ?? _currentUserData!['user_id']).toString();
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_todos?user_id=$userId';
      
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
      bool aDone = (a['is_done'] == '1' || a['is_done'] == 1 || a['is_done'] == true);
      bool bDone = (b['is_done'] == '1' || b['is_done'] == 1 || b['is_done'] == true);
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tugas yang Anda cari: "${todo['description']}"'),
          backgroundColor: _primaryColor,
        ),
      );
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
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/toggle_todo'),
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
          'user_id': (_currentUserData!['id'] ?? _currentUserData!['user_id']).toString(),
          'description': description,
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('todo_list.save_success'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding todo: $e');
    }
  }

  Future<void> _updateTodo(dynamic todoId, String description) async {
    try {
      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/edit_todo'),
        body: {
          'todo_item_id': todoId.toString(),
          'description': description,
        },
      );

      if (response.statusCode == 200) {
        _fetchTodos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('todo_list.update_success'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating todo: $e');
    }
  }

  void _showEditTodoDialog(dynamic todo) {
    final TextEditingController controller = TextEditingController(text: todo['description']);
    _isListening = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          _currentModalSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'todo_list.task_desc'.tr(context),
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _isSpeechInitialized ? IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : _primaryColor,
                        ),
                        onPressed: () async {
                          if (!_isListening) {
                            bool available = await _speech.initialize();
                            if (available) {
                              setModalState(() => _isListening = true);
                              _speech.listen(
                                localeId: 'id_ID',
                                onResult: (val) {
                                  setModalState(() {
                                    controller.text = val.recognizedWords;
                                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                                  });
                                },
                              );
                            }
                          } else {
                            setModalState(() => _isListening = false);
                            _speech.stop();
                          }
                        },
                      ) : null,
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
                            _updateTodo(todo['todo_item_id'], controller.text.trim());
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        }
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'todo_list.task_desc'.tr(context),
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _isSpeechInitialized ? IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : _primaryColor,
                        ),
                        onPressed: () async {
                          if (!_isListening) {
                            bool available = await _speech.initialize();
                            if (available) {
                              setModalState(() => _isListening = true);
                              _speech.listen(
                                localeId: 'id_ID',
                                onResult: (val) {
                                  setModalState(() {
                                    controller.text = val.recognizedWords;
                                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                                  });
                                },
                              );
                            }
                          } else {
                            setModalState(() => _isListening = false);
                            _speech.stop();
                          }
                        },
                      ) : null,
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        }
      ),
    ).whenComplete(() => _speech.stop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: _currentUserData ?? {}, showBackButton: false),
      endDrawer: SideDrawer(userData: _currentUserData ?? {}, activePage: 'todo_list'),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      const ShimmerCard(height: 120),
                      const SizedBox(height: 20),
                      const ShimmerList(itemCount: 5),
                    ],
                  ),
                ),
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
        if (_todos.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'todo_list.total'.tr(context, args: {
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
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _primaryColor),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchTodos();
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
    final totalPages = (_totalCount / _selectedLimit).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1 ? () {
            _fetchTodos(page: _currentPage - 1);
          } : null,
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
            'todo_list.page_x_of_y'.tr(context, args: {
              'current': _currentPage.toString(),
              'total': totalPages.toString(),
            }),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < totalPages ? () {
            _fetchTodos(page: _currentPage + 1);
          } : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: onPressed == null 
          ? (isDark ? Colors.white12 : Colors.grey[200]) 
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Icon(
            icon, 
            color: onPressed == null 
                ? (isDark ? Colors.white24 : Colors.grey[400]) 
                : _primaryColor, 
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    double progress = _totalCount > 0 ? (_completedCount / _totalCount) : 0;
    if (progress > 1.0) progress = 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                        'todo_list.stats_title'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'todo_list.general_accumulation'.tr(context),
                        style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
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
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isStatsExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatMiniRow('main.total'.tr(context), _totalCount.toString(), Colors.blue),
                              const SizedBox(height: 12),
                              _buildStatMiniRow('todo_list.completed_today'.tr(context), _completedTodayCount.toString(), Colors.purple),
                              const SizedBox(height: 12),
                              _buildStatMiniRow('todo_list.complete'.tr(context), _completedCount.toString(), Colors.green),
                              const SizedBox(height: 12),
                              _buildStatMiniRow('todo_list.pending'.tr(context), _pendingCount.toString(), Colors.orange),
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
                                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  'todo_list.completed'.tr(context).toUpperCase(),
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
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
          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAgeBadge(String createdAt, bool isCompleted) {
    try {
      final createdDate = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(createdDate);
      
      final int minutes = difference.inMinutes;
      final int hours = difference.inHours;
      final int days = difference.inDays;

      Color badgeColor;
      String label;

      if (isCompleted) {
        badgeColor = Colors.grey;
      } else {
        if (days < 1) {
          badgeColor = Colors.green;
        } else if (days < 3) {
          badgeColor = Colors.orange;
        } else {
          badgeColor = Colors.red;
        }
      }

      if (difference.inSeconds < 60) {
        label = 'time.just_now'.tr(context);
      } else if (minutes < 60) {
        String unitKey = minutes == 1 ? 'time.minute' : 'time.minutes';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.minute'.tr(context);
        label = '$minutes $unit ${'time.ago'.tr(context)}';
      } else if (hours < 24) {
        String unitKey = hours == 1 ? 'time.hour' : 'time.hours';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.hour'.tr(context);
        label = '$hours $unit ${'time.ago'.tr(context)}';
      } else if (days < 30) {
        String unitKey = days == 1 ? 'time.day' : 'time.days';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.day'.tr(context);
        label = '$days $unit ${'time.ago'.tr(context)}';
      } else {
        final months = (days / 30).floor();
        String unitKey = months == 1 ? 'time.month' : 'time.months';
        String unit = unitKey.tr(context);
        if (unit == unitKey) unit = 'time.month'.tr(context);
        label = '$months $unit ${'time.ago'.tr(context)}';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: badgeColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
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
            onLongPress: () {
              if (_hasPermission('mobile_todo_delete')) {
                _confirmDelete(todo);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Anda tidak memiliki izin untuk menghapus tugas')),
                );
              }
            },
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
                            Flexible(
                              child: Text(
                                date,
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAgeBadge(date, isCompleted),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _showEditTodoDialog(todo);
                      if (value == 'delete') _confirmDelete(todo);
                      if (value == 'toggle') _toggleTodo(todo);
                    },
                    icon: Icon(Icons.more_horiz_rounded, size: 20, color: Colors.grey[400]),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: _primaryColor),
                            const SizedBox(width: 12),
                            Text('todo_list.edit_task'.tr(context)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(isCompleted ? Icons.undo_rounded : Icons.check_circle_rounded, size: 20, color: _primaryColor),
                            const SizedBox(width: 12),
                            Text(isCompleted ? 'todo_list.pending'.tr(context) : 'todo_list.completed'.tr(context)),
                          ],
                        ),
                      ),
                      if (_hasPermission('mobile_todo_delete'))
                         PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                              const SizedBox(width: 12),
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
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'todo_list.delete_confirm_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'todo_list.delete_confirm_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTodo(todo);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
