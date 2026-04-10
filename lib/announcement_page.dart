import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart';
import 'widgets/connectivity_wrapper.dart';
import 'widgets/secondary_app_bar.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'localization/app_localizations.dart';
import 'widgets/custom_app_bar.dart'; // For NotificationManager
import 'widgets/custom_snackbar.dart';

class AnnouncementPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final int? initialAnnouncementId;

  const AnnouncementPage({
    super.key,
    this.userData,
    this.initialAnnouncementId,
  });

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (widget.userData != null) {
      _currentUserData = widget.userData;
      _fetchAnnouncements();
    } else {
      const storage = FlutterSecureStorage();
      final userDataStr = await storage.read(key: 'user_data');
      if (userDataStr != null) {
        if (mounted) {
          setState(() {
            _currentUserData = json.decode(userDataStr);
          });
          _fetchAnnouncements();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAnnouncements() async {
    if (_currentUserData == null) return;

    final userId = _currentUserData!['user_id'] ?? _currentUserData!['id'];
    final deptId =
        _currentUserData!['department_id'] ?? _currentUserData!['dept_id'] ?? 0;
    final desigId =
        _currentUserData!['designation_id'] ??
        _currentUserData!['desig_id'] ??
        0;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/get_announcements?user_id=$userId&department_id=$deptId&designation_id=$desigId',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _announcements = data['data'];
            _isLoading = false;
          });

          // Sync unread count globally if list is empty
          if (_announcements.isEmpty) {
            NotificationManager().unreadCount.value = 0;
          }

          // Handle initialAnnouncementId for deep linking
          if (widget.initialAnnouncementId != null) {
            try {
              final initialAnnouncement = _announcements.firstWhere(
                (element) =>
                    element['announcement_id'].toString() ==
                    widget.initialAnnouncementId.toString(),
              );
              _showDetail(initialAnnouncement);
            } catch (e) {
              debugPrint(
                'Initial announcement not found: ${widget.initialAnnouncementId}',
              );
            }
          }
        }
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (ConnectivityStatus.of(context)) {
          context.showErrorSnackBar('announcement.fetch_error'.tr(context));
        }
      }
    }
  }

  Future<void> _markAsSeen(int announcementId) async {
    if (_currentUserData == null) return;
    final userId = _currentUserData!['user_id'] ?? _currentUserData!['id'];
    final url = Uri.parse('${AppConstants.baseUrl}/mark_announcement_read');

    // Optimistic update for global count
    NotificationManager().decrement();

    try {
      await http.post(
        url,
        body: {
          'user_id': userId.toString(),
          'announcement_id': announcementId.toString(),
        },
      );
      // No need to do anything here if successful, we already decremented
    } catch (e) {
      debugPrint('Error marking as seen: $e');
      // On error, we could increment back, but simple is better for now
    }
  }

  void _showDetail(Map<String, dynamic> announcement) async {
    // Robust unread check
    final isUnread = announcement['is_seen'].toString() == '0';

    if (isUnread) {
      // Mark as seen immediately in local state to remove red dot
      setState(() {
        announcement['is_seen'] = 1;
      });
      // Call server and update global count
      _markAsSeen(int.parse(announcement['announcement_id'].toString()));
    }

    // Show loading indicator
    if (!mounted) return;
    final loaderContext = context;
    showDialog(
      context: loaderContext,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Lazy load full description
    final detailUrl = Uri.parse(
      '${AppConstants.baseUrl}/get_announcement_details?announcement_id=${announcement['announcement_id']}',
    );

    try {
      final response = await http.get(detailUrl);

      // Close loader immediately after request returns
      if (mounted) Navigator.of(loaderContext).pop();

      final data = json.decode(response.body);

      if (data['status'] == true) {
        final fullData = data['data'];
        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    fullData['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullData['created_at'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (fullData['summary'] != null &&
                              fullData['summary'].toString().isNotEmpty) ...[
                            Text(
                              fullData['summary'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            fullData['description'] ??
                                'announcement.no_description'.tr(context),
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        context.showErrorSnackBar('announcement.fetch_error'.tr(context));
      }
    } catch (e) {
      if (mounted) Navigator.of(loaderContext).pop();
      debugPrint('Error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUserData == null) return;
    final userId = _currentUserData!['user_id'] ?? _currentUserData!['id'];
    final deptId =
        _currentUserData!['department_id'] ?? _currentUserData!['dept_id'] ?? 0;
    final desigId =
        _currentUserData!['designation_id'] ??
        _currentUserData!['desig_id'] ??
        0;

    const url =
        '${AppConstants.baseUrl}/mark_all_announcements_seen';

    // Count unread locally for optimistic update
    int unreadCount = 0;
    for (var item in _announcements) {
      if (item['is_seen'].toString() == '0') unreadCount++;
    }

    setState(() {
      for (var item in _announcements) {
        item['is_seen'] = 1;
      }
    });

    // Update global badge count optimistically
    for (int i = 0; i < unreadCount; i++) {
      NotificationManager().decrement();
    }

    try {
      await http.post(
        Uri.parse(url),
        body: {
          'user_id': userId.toString(),
          'department_id': deptId.toString(),
          'designation_id': desigId.toString(),
        },
      );
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _clearSeen() async {
    if (_currentUserData == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final userId = _currentUserData!['user_id'] ?? _currentUserData!['id'];
    const url = '${AppConstants.baseUrl}/clear_seen_announcements';

    setState(() {
      _announcements.removeWhere((item) => item['is_seen'].toString() != '0');
    });

    try {
      await http.post(Uri.parse(url), body: {'user_id': userId.toString()});
    } catch (e) {
      debugPrint('Error clearing seen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        onBackPressed: () => Navigator.pop(context, true),
        title: 'announcement.title'.tr(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF7E57C2)),
            tooltip: 'announcement.mark_all_tooltip'.tr(context),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Icon(
                        Icons.done_all_rounded,
                        color: Color(0xFF7E57C2),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'announcement.mark_all'.tr(context),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'announcement.mark_all_desc'.tr(context),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'announcement.cancel'.tr(context),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _markAllAsRead();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E57C2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text('announcement.yes'.tr(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'announcement.clear_seen_tooltip'.tr(context),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Icon(
                        Icons.delete_sweep_rounded,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'announcement.delete_seen'.tr(context),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'announcement.delete_seen_desc'.tr(context),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'announcement.cancel'.tr(context),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _clearSeen();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text('announcement.delete'.tr(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.announcement_outlined,
                    size: 80,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'announcement.no_announcements'.tr(context),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAnnouncements,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _announcements.length,
                itemBuilder: (context, index) {
                  final item = _announcements[index];
                  final isUnread = item['is_seen'].toString() == '0';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _showDetail(item),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? const Color(0xFF7E57C2).withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isUnread
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                color: isUnread
                                    ? const Color(0xFF7E57C2)
                                    : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['created_at'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7E57C2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
