import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../announcement_page.dart';
import '../todo_list/todo_list_page.dart';
import 'connectivity_wrapper.dart';
import 'top_notification.dart';
import '../localization/app_localizations.dart';

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
      _showBanner(context, latestTitle, latestSummary ?? 'announcement.tap_to_view'.tr(context), () {
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
      });
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

  void _showBanner(BuildContext context, String title, String message, VoidCallback onTap) {
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
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.userData,
    this.showBackButton = false,
    this.title,
    this.bottom,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

class _CustomAppBarState extends State<CustomAppBar> {
  Timer? _timer;
  final NotificationManager _notifManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
      'https://foxgeen.com/HRIS/mobileapi/get_unread_announcements_count?user_id=$userId&department_id=$deptId&designation_id=$desigId',
    );

    // 2. Fetch Todo Count
    final todoUrl = Uri.parse(
      'https://foxgeen.com/HRIS/mobileapi/get_unread_todos_count?user_id=$userId',
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
      title: Text(
        widget.title ?? 'My ISN',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottom: widget.bottom,
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: _notifManager.unreadCount,
          builder: (context, count, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
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
                        style: const TextStyle(
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
              color: Theme.of(context).colorScheme.primaryContainer,
              child:
                  (widget.userData['profile_photo'] != null &&
                      widget.userData['profile_photo'].toString().isNotEmpty)
                  ? Image.network(
                      'https://foxgeen.com/HRIS/public/uploads/users/thumb/${widget.userData['profile_photo']}',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}
