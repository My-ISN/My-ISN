import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/connectivity_wrapper.dart';
import 'widgets/custom_app_bar.dart';

class AnnouncementPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AnnouncementPage({super.key, required this.userData});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    final userId = widget.userData['user_id'] ?? widget.userData['id'];
    final deptId =
        widget.userData['department_id'] ?? widget.userData['dept_id'] ?? 0;
    final desigId =
        widget.userData['designation_id'] ?? widget.userData['desig_id'] ?? 0;

    final url = Uri.parse(
      'https://foxgeen.com/HRIS/mobileapi/get_announcements?user_id=$userId&department_id=$deptId&designation_id=$desigId',
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
        }
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (ConnectivityStatus.of(context)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal memuat pengumuman. Periksa koneksi internet Anda.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsSeen(int announcementId) async {
    final userId = widget.userData['user_id'] ?? widget.userData['id'];
    const url = 'https://foxgeen.com/HRIS/mobileapi/mark_announcement_seen';

    // Optimistic update for global count
    NotificationManager().decrement();

    try {
      final response = await http.post(
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                announcement['title'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                announcement['created_at'] ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const Divider(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (announcement['summary'] != null) ...[
                        Text(
                          announcement['summary'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        announcement['description'] ?? '',
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
  }

  Future<void> _markAllAsRead() async {
    final userId = widget.userData['user_id'] ?? widget.userData['id'];
    final deptId =
        widget.userData['department_id'] ?? widget.userData['dept_id'] ?? 0;
    final desigId =
        widget.userData['designation_id'] ?? widget.userData['desig_id'] ?? 0;

    const url =
        'https://foxgeen.com/HRIS/mobileapi/mark_all_announcements_seen';

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
    final userId = widget.userData['user_id'] ?? widget.userData['id'];
    const url = 'https://foxgeen.com/HRIS/mobileapi/clear_seen_announcements';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Pengumuman',
          style: TextStyle(
            color: Color(0xFF7E57C2),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF7E57C2)),
            tooltip: 'Lihat semua',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tandai semua?'),
                  content: const Text(
                    'Tandai semua pengumuman sebagai sudah dibaca?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAllAsRead();
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Hapus yang sudah dibaca',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus yang dibaca?'),
                  content: const Text(
                    'Sembunyikan semua pengumuman yang sudah dibaca dari daftar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearSeen();
                      },
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada pengumuman',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                              color: const Color(0xFFE6D4FA).withOpacity(0.5),
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
                                    color: Colors.white,
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
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['created_at'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
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
