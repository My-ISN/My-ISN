import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';

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
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_ticket_details?ticket_id=${widget.ticketId}&user_id=$userId';
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
          const SnackBar(content: Text('Anda tidak memiliki izin untuk membalas tiket ini')),
        );
      }
      return;
    }

    final userId = (widget.userData['id'] ?? widget.userData['user_id']).toString();
    
    // Create optimistic reply for immediate feedback
    final optimisticReply = {
      'sent_by': userId,
      'reply_text': message,
      'created_at': 'Sending...',
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
      final url = 'https://foxgeen.com/HRIS/mobileapi/add_ticket_reply';
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
              content: Text(data['message'] ?? 'Failed to send reply'),
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
          const SnackBar(
            content: Text('Failed to send reply. Please check your connection.'),
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
    if (status == '1') return AppLocalizations.of(context)!.translate('helpdesk.open');
    if (status == '2') return AppLocalizations.of(context)!.translate('helpdesk.closed');
    return status;
  }

  String _getPriorityText(BuildContext context, String priority) {
    switch (priority) {
      case '1': return AppLocalizations.of(context)!.translate('helpdesk.priority_low');
      case '2': return AppLocalizations.of(context)!.translate('helpdesk.priority_medium');
      case '3': return AppLocalizations.of(context)!.translate('helpdesk.priority_high');
      case '4': return AppLocalizations.of(context)!.translate('helpdesk.priority_critical');
      default: return priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: _ticketData['ticket_code'] ?? l10n!.translate('helpdesk.title'),
        showBackButton: true,
        showActions: false,
        userData: widget.userData,
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
                        final isMe = reply['sent_by'].toString() == (widget.userData['id'] ?? widget.userData['user_id']).toString();
                        return _buildChatBubble(reply, isMe);
                      },
                    ),
                  ),
                  if (_ticketData['ticket_status'].toString() != '2') _buildReplyInput(),
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
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(Icons.person, size: 14, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                '${_ticketData['first_name'] ?? ''} ${_ticketData['last_name'] ?? ''}'.trim().toUpperCase(),
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
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _getStatusText(context, _ticketData['ticket_status'].toString()),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                        ? NetworkImage('https://foxgeen.com/HRIS/uploads/users/thumb/${reply['profile_photo']}')
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
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200]),
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
                        color: isMe 
                            ? Colors.white 
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: isMe ? 0 : 40, right: isMe ? 8 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOptimistic) 
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey)),
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
    if (!_hasPermission('mobile_helpdesk_answer')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: const Center(
          child: Text(
            'Anda tidak memiliki izin untuk membalas tiket ini.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.translate('helpdesk.reply'),
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF7E57C2),
            child: IconButton(
              onPressed: _isSending ? null : _sendReply,
              icon: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
