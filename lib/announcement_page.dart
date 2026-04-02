import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/connectivity_wrapper.dart';
import 'widgets/custom_app_bar.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'localization/app_localizations.dart';

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
      'http://17.5.45.192/KODINGAN/PKL/mobileapi/get_announcements?user_id=$userId&department_id=$deptId&designation_id=$desigId',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('announcement.fetch_error'.tr(context))),
          );
        }
      }
    }
  }

  Future<void> _markAsSeen(int announcementId) async {
    if (_currentUserData == null) return;
    final userId = _currentUserData!['user_id'] ?? _currentUserData!['id'];
    const url = 'http://17.5.45.192/KODINGAN/PKL/mobileapi/mark_announcement_seen';

    // Optimistic update for global count
    NotificationManager().decrement();

    try {
      await http.post(
        Uri.parse(url),
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
      'http://17.5.45.192/KODINGAN/PKL/mobileapi/get_announcement_details?announcement_id=${announcement['announcement_id']}',
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('announcement.fetch_error'.tr(context))),
        );
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
        'http://17.5.45.192/KODINGAN/PKL/mobileapi/mark_all_announcements_seen';

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
    const url = 'http://17.5.45.192/KODINGAN/PKL/mobileapi/clear_seen_announcements';

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
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'announcement.title'.tr(context),
          style: const TextStyle(
            color: Color(0xFF7E57C2),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF7E57C2)),
            tooltip: 'announcement.mark_all_tooltip'.tr(context),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('announcement.mark_all'.tr(context)),
                  content: Text('announcement.mark_all_desc'.tr(context)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('announcement.cancel'.tr(context)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAllAsRead();
                      },
                      child: Text('announcement.yes'.tr(context)),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'announcement.clear_seen_tooltip'.tr(context),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('announcement.delete_seen'.tr(context)),
                  content: Text('announcement.delete_seen_desc'.tr(context)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('announcement.cancel'.tr(context)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearSeen();
                      },
                      child: Text('announcement.delete'.tr(context)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
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
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 16),
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E57C2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.campaign,
                              color: Color(0xFF7E57C2),
                            ),
                          ),
                          if (isUnread)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        item['title'] ?? '',
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            item['summary'] ?? (item['description'] ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['created_at'] ?? '',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showDetail(item),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
