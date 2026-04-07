import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/secondary_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';


class TicketDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String ticketId;

  const TicketDetailPage({
    super.key,
    required this.userData,
    required this.ticketId,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic> _ticketData = {};
  List<dynamic> _replies = [];
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTicketDetails();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1') return true;
    final String? resources = widget.userData['role_resources'];
    if (resources == null || resources.isEmpty) return false;
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchTicketDetails() async {
    try {
      final userId = (widget.userData['id'] ?? widget.userData['user_id']).toString();
      final url =
          '${AppConstants.baseUrl}/get_ticket_details?ticket_id=${widget.ticketId}&user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _ticketData = data['data']['ticket'];
            _replies = data['data']['replies'];
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error fetching ticket details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    if (!_hasPermission('mobile_helpdesk_answer')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('helpdesk.no_permission'.tr(context)),
          ),
        );
      }
      return;
    }

    final userId = (widget.userData['id'] ?? widget.userData['user_id']).toString();

    // Create optimistic reply for immediate feedback
    final optimisticReply = {
      'sent_by': userId,
      'reply_text': message,
      'created_at': 'helpdesk.sending'.tr(context),
      'profile_photo': widget.userData['profile_photo'],
      'is_optimistic': true,
    };

    // Store current replies to restore if needed
    final originalReplies = List.from(_replies);

    setState(() {
      _replies.add(optimisticReply);
      _replyController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      const url = '${AppConstants.baseUrl}/add_ticket_reply';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'ticket_id': widget.ticketId,
          'user_id': userId,
          'message': message,
        },
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        // Success: Refresh details to get real data from server
        await _fetchTicketDetails();
      } else {
        // Failure: Revert UI and show error
        setState(() {
          _replies = originalReplies;
          _replyController.text = message; // Put message back in text field
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'helpdesk.failed_reply'.tr(context)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error sending reply: $e');
      setState(() {
        _replies = originalReplies;
        _replyController.text = message;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('helpdesk.failed_reply'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getStatusColor(String status) {
    if (status == '1') return Colors.green;
    if (status == '2') return Colors.red;
    return Colors.grey;
  }

  String _getStatusText(BuildContext context, String status) {
    if (status == '1') return 'helpdesk.open'.tr(context);
    if (status == '2') return 'helpdesk.closed'.tr(context);
    return status;
  }

  String _getPriorityText(BuildContext context, String priority) {
    switch (priority) {
      case '1':
        return 'helpdesk.priority_low'.tr(context);
      case '2':
        return 'helpdesk.priority_medium'.tr(context);
      case '3':
        return 'helpdesk.priority_high'.tr(context);
      case '4':
        return 'helpdesk.priority_critical'.tr(context);
      default:
        return priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        title: _ticketData['ticket_code'] ?? 'helpdesk.title'.tr(context),
      ),
      body: ConnectivityWrapper(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTicketHeader(),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _replies.length,
                      itemBuilder: (context, index) {
                        final reply = _replies[index];
                        final isMe = reply['sent_by'].toString() ==
                            (widget.userData['id'] ?? widget.userData['user_id']).toString();
                        return _buildChatBubble(reply, isMe);
                      },
                    ),
                  ),
                  if (_ticketData['ticket_status'].toString() != '2')
                    _buildReplyInput(),
                ],
              ),
      ),
    );
  }

  Widget _buildTicketHeader() {
    final statusColor = _getStatusColor(_ticketData['ticket_status'].toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_ticketData['first_name'] ?? ''} ${_ticketData['last_name'] ?? ''}'
                    .trim()
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const Spacer(),
              Text(
                _ticketData['ticket_code'] ?? '',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _ticketData['subject'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _getStatusText(context, _ticketData['ticket_status'].toString()),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Theme.of(context).hintColor),
              const SizedBox(width: 4),
              Text(
                _ticketData['created_at'] ?? '',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.flag_outlined, size: 14, color: Theme.of(context).hintColor),
              const SizedBox(width: 4),
              Text(
                _getPriorityText(context, _ticketData['ticket_priority'].toString()),
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> reply, bool isMe) {
    final bool isOptimistic = reply['is_optimistic'] ?? false;

    return Opacity(
      opacity: isOptimistic ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: reply['profile_photo'] != null && reply['profile_photo'] != ''
                        ? CachedNetworkImageProvider(
                            '${AppConstants.serverRoot}/uploads/users/thumb/${reply['profile_photo']}',
                          )
                        : const AssetImage('assets/images/user_placeholder.png') as ImageProvider,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF7E57C2)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey[200]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                    ),
                    child: Text(
                      reply['reply_text'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
                if (isMe) ...[const SizedBox(width: 8)],
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 40,
                right: isMe ? 8 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOptimistic)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  Text(
                    reply['created_at'] ?? '',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_hasPermission('mobile_helpdesk_answer')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Center(
          child: Text(
            'helpdesk.no_permission'.tr(context),
            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _replyController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'helpdesk.reply'.tr(context),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isSending)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FloatingActionButton.small(
                  onPressed: _sendReply,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  child: const Icon(Icons.send, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
