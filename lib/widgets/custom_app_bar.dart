import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../announcement_page.dart';
import '../todo_list/todo_list_page.dart';
import 'top_notification.dart';
import '../localization/app_localizations.dart';
import '../widgets/custom_snackbar.dart';
import '../constants.dart';
import '../dashboard/staff/widgets/menu_registry.dart';
import '../dashboard/dashboard_page.dart';


// Global Manager for Notification State
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<int> unreadTodoCount = ValueNotifier<int>(0);
  int _lastKnownId = -1;
  int _lastKnownTodoId = -1;

  void updateCount(
    int count, {
    int? latestId,
    String? latestTitle,
    String? latestSummary,
    BuildContext? context,
    Map<String, dynamic>? userData,
    int? todoCount,
    int? latestTodoId,
    String? latestTodoDesc,
  }) {
    // Announcements logic
    if (_lastKnownId == -1) {
      _lastKnownId = latestId ?? 0;
      unreadCount.value = count;
    } else if (latestId != null &&
        latestId > _lastKnownId &&
        context != null &&
        context.mounted &&
        latestTitle != null &&
        latestTitle.isNotEmpty) {
      _lastKnownId = latestId;
      _showBanner(
        context,
        latestTitle,
        latestSummary ?? 'announcement.tap_to_view'.tr(context),
        () {
          if (userData != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnnouncementPage(
                  userData: userData,
                  initialAnnouncementId: latestId,
                ),
              ),
            );
          }
        },
      );
    }

    if (unreadCount.value != count) {
      unreadCount.value = count;
    }

    // Todos logic
    if (_lastKnownTodoId == -1) {
      _lastKnownTodoId = latestTodoId ?? 0;
      unreadTodoCount.value = todoCount ?? 0;
    } else if (latestTodoId != null &&
        latestTodoId > _lastKnownTodoId &&
        context != null &&
        context.mounted &&
        latestTodoDesc != null &&
        latestTodoDesc.isNotEmpty) {
      _lastKnownTodoId = latestTodoId;
      _showBanner(context, 'Tugas To-Do Baru', latestTodoDesc, () {
        if (userData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TodoListPage(userData: userData),
            ),
          );
        }
      });
    }

    if (todoCount != null && unreadTodoCount.value != todoCount) {
      unreadTodoCount.value = todoCount;
    }
  }

  void _showBanner(
    BuildContext context,
    String title,
    String message,
    VoidCallback onTap,
  ) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        TopNotification.show(
          context,
          title: title,
          message: message,
          onTap: onTap,
        );
      }
    });
  }

  void decrement() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }

  void clearTodoBadge() {
    unreadTodoCount.value = 0;
  }
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Map<String, dynamic> userData;
  final bool showBackButton;
  final String? title;
  final Widget? subtitle;
  final PreferredSizeWidget? bottom;
  final bool showActions;
  final List<Widget>? extraActions;
  final Function(String)? onTabSelected;

  const CustomAppBar({
    super.key,
    required this.userData,
    this.showBackButton = false,
    this.title,
    this.subtitle,
    this.bottom,
    this.showActions = true,
    this.extraActions,
    this.onTabSelected,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

class _CustomAppBarState extends State<CustomAppBar> {
  Timer? _timer;
  final NotificationManager _notifManager = NotificationManager();
  
  OverlayEntry? _searchOverlayEntry;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<AppModule> _filteredModules = [];
  bool _isSearchOpen = false;
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<String> _historyKeys = [];

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _loadHistory();
    // Poll every 15 seconds for a snappy feel
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchUnreadCount();
    });
  }

  @override
  void didUpdateWidget(CustomAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData['user_id'] != widget.userData['user_id'] ||
        oldWidget.userData['id'] != widget.userData['id']) {
      _fetchUnreadCount();
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList =
        resources.split(',').map((e) => e.trim()).toList();
    return resourceList.contains(resource);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideSearchOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final String? historyJson = await _storage.read(key: 'module_search_history');
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        setState(() {
          _historyKeys = decoded.cast<String>();
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _saveHistory() async {
    try {
      await _storage.write(
        key: 'module_search_history',
        value: json.encode(_historyKeys),
      );
    } catch (e) {
      // Silent error
    }
  }

  void _addToHistory(String titleKey) {
    setState(() {
      _historyKeys.remove(titleKey);
      _historyKeys.insert(0, titleKey);
      if (_historyKeys.length > 3) {
        _historyKeys = _historyKeys.sublist(0, 3);
      }
    });
    _saveHistory();
  }

  void _showSearchOverlay() {
    if (_isSearchOpen) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _updateFilteredModules(''); // Initialize with history/empty
    _searchController.clear();

    _searchOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dimmed Background
          GestureDetector(
            onTap: _hideSearchOverlay,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          // Search Bar & Results
          Positioned(
            top: offset.dy + size.height,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Cari menu...',
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF7E57C2)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _hideSearchOverlay,
                              ),
                            ),
                            onChanged: (value) {
                              _updateFilteredModules(value);
                            },
                          ),
                        ),
                        StatefulBuilder(
                          builder: (context, setStateOverlay) {
                            return _filteredModules.isEmpty
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_searchController.text.isEmpty && _historyKeys.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                                          child: Text(
                                            'Pencarian Terakhir',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: _filteredModules.length,
                                          itemBuilder: (context, index) {
                                            final module = _filteredModules[index];
                                            return ListTile(
                                              leading: Icon(module.icon, color: module.color),
                                              title: Text(module.titleKey.tr(context)),
                                              onTap: () {
                                                _addToHistory(module.titleKey);
                                                _hideSearchOverlay();
                                                if (module.tabTag != null) {
                                                  if (widget.onTabSelected != null) {
                                                    widget.onTabSelected!(module.tabTag!);
                                                  } else {
                                                    DashboardPage.switchTab(module.tabTag!);
                                                    Navigator.popUntil(context, (route) => route.isFirst);
                                                  }
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => module.pageBuilder(context, widget.userData),
                                                    ),
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_searchOverlayEntry!);
    setState(() => _isSearchOpen = true);
  }

  void _hideSearchOverlay() {
    if (!_isSearchOpen) return;
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
    setState(() => _isSearchOpen = false);
  }

  void _updateFilteredModules(String query) {
    setState(() {
      final allModules = MenuRegistry.getModules(widget.userData);
      if (query.isEmpty) {
        if (_historyKeys.isEmpty) {
          _filteredModules = [];
        } else {
          // Show history items (max 3)
          _filteredModules = [];
          for (var key in _historyKeys) {
            try {
              final module = allModules.firstWhere((m) => m.titleKey == key);
              if (module.permission == null || _hasPermission(module.permission!)) {
                _filteredModules.add(module);
              }
            } catch (e) {
              // Module no longer exists or protected
            }
          }
        }
      } else {
        _filteredModules = allModules.where((module) {
          final title = module.titleKey.tr(context).toLowerCase();
          final hasPermission = module.permission == null || _hasPermission(module.permission!);
          return hasPermission && title.contains(query.toLowerCase());
        }).toList();
      }
      _searchOverlayEntry?.markNeedsBuild();
    });
  }

  Future<void> _fetchUnreadCount() async {
    final userId = widget.userData['user_id'] ?? widget.userData['id'];
    final deptId =
        widget.userData['department_id'] ?? widget.userData['dept_id'] ?? 0;
    final desigId =
        widget.userData['designation_id'] ?? widget.userData['desig_id'] ?? 0;

    if (userId == null) return;

    // 1. Fetch Announcement Count
    final annUrl = Uri.parse(
      '${AppConstants.baseUrl}/get_unread_announcements_count?user_id=$userId&department_id=$deptId&designation_id=$desigId',
    );

    // 2. Fetch Todo Count
    final todoUrl = Uri.parse(
      '${AppConstants.baseUrl}/get_unread_todos_count?user_id=$userId',
    );

    try {
      final responses = await Future.wait([
        http.get(annUrl),
        http.get(todoUrl),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final annData = json.decode(responses[0].body);
        final todoData = json.decode(responses[1].body);

        _notifManager.updateCount(
          annData['unread_count'] ?? 0,
          latestId: annData['latest_announcement_id'],
          latestTitle: annData['latest_title'],
          latestSummary: annData['latest_summary'],
          context: context,
          userData: widget.userData,
          todoCount: todoData['unread_count'] ?? 0,
          latestTodoId: todoData['latest_todo_id'],
          latestTodoDesc: todoData['latest_description'],
        );
      }
    } catch (e) {
      // Silent error
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: widget.showBackButton,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title ?? 'My ISN',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: widget.subtitle != null ? 18 : 20,
            ),
          ),
          if (widget.subtitle != null) widget.subtitle!,
        ],
      ),
      bottom: widget.bottom,
      actions: widget.showActions
          ? [
              if (widget.extraActions != null) ...widget.extraActions!,
                Transform.translate(
                  offset: const Offset(8, 0), // Shift 8 pixels to the right
                  child: IconButton(
                    padding: const EdgeInsets.all(8.0),
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                    ),
                    onPressed: _showSearchOverlay,
                  ),
                ),
                ValueListenableBuilder<int>(
                valueListenable: _notifManager.unreadCount,
                builder: (context, count, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        padding: const EdgeInsets.all(8.0),
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.notifications_none,
                          color: Colors.grey,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AnnouncementPage(userData: widget.userData),
                            ),
                          );
                          // Removed _fetchUnreadCount() here because NotificationManager
                          // already handles immediate updates locally.
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              InkWell(
                onTap: () {
                  Scaffold.of(context).openEndDrawer();
                },
                child: ClipOval(
                  child: Container(
                    width: 36,
                    height: 36,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    child:
                        (widget.userData['profile_photo'] != null &&
                            widget.userData['profile_photo']
                                .toString()
                                .isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl:
                                '${AppConstants.serverRoot}/uploads/users/thumb/${widget.userData['profile_photo']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ]
          : [],
    );
  }
}
