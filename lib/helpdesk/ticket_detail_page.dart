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

  Future<void> _fetchTicketDetails() async {
    try {
      final url = 'https://foxgeen.com/HRIS/mobileapi/get_ticket_details?ticket_id=${widget.ticketId}';
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

    setState(() => _isSending = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = 'https://foxgeen.com/HRIS/mobileapi/add_ticket_reply';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'ticket_id': widget.ticketId,
          'user_id': userId.toString(),
          'message': message,
        },
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        _replyController.clear();
        await _fetchTicketDetails();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to send reply')),
          );
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error sending reply: $e');
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
                  if (_ticketData['ticket_status'].toString() != '2') _buildReplyBox(),
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _ticketData['subject'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
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
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _ticketData['created_at'] ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.flag_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _getPriorityText(context, _ticketData['ticket_priority'].toString()),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> reply, bool isMe) {
    return Padding(
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
                    color: isMe ? const Color(0xFF1E88E5) : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 16),
                    ),
                  ),
                  child: Text(
                    reply['reply_text'] ?? '',
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87),
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
            child: Text(
              reply['created_at'] ?? '',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.translate('helpdesk.reply'),
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
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
            backgroundColor: const Color(0xFF1E88E5),
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
