import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../announcement_page.dart';
import 'connectivity_wrapper.dart';
import 'top_notification.dart';

// Global Manager for Notification State
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  int _lastKnownId = -1;

  void updateCount(
    int count, {
    int? latestId,
    String? latestTitle,
    String? latestSummary,
    BuildContext? context,
    Map<String, dynamic>? userData,
  }) {
    // Avoid showing notification on first load (initial state)
    if (_lastKnownId == -1) {
      _lastKnownId = latestId ?? 0;
      unreadCount.value = count;
      return;
    }

    // Trigger notification banner if a NEW ID is detected
    if (latestId != null &&
        latestId > _lastKnownId &&
        context != null &&
        context.mounted &&
        latestTitle != null &&
        latestTitle.isNotEmpty) {
      _lastKnownId = latestId;

      // Small delay to ensure Overlay/Context is stable
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          TopNotification.show(
            context,
            title: latestTitle,
            message: (latestSummary != null && latestSummary.isNotEmpty)
                ? latestSummary
                : 'Ketuk untuk melihat detail pengumuman baru.',
            onTap: () {
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
      });
    }

    if (unreadCount.value != count) {
      unreadCount.value = count;
    }
  }

  void decrement() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Map<String, dynamic> userData;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.userData,
    this.showBackButton = false,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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

    final url = Uri.parse(
      'https://foxgeen.com/HRIS/mobileapi/get_unread_announcements_count?user_id=$userId&department_id=$deptId&designation_id=$desigId',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          _notifManager.updateCount(
            data['unread_count'] ?? 0,
            latestId: data['latest_announcement_id'],
            latestTitle: data['latest_title'],
            latestSummary: data['latest_summary'],
            context: context,
            userData: widget.userData,
          );
        }
      }
    } catch (e) {
      // Silent error
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: widget.showBackButton,
      iconTheme: const IconThemeData(color: Colors.black),
      title: const Text(
        'ServerHub',
        style: TextStyle(color: Color(0xFF7E57C2), fontWeight: FontWeight.bold),
      ),
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
              color: const Color(0xFFE6D4FA),
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
