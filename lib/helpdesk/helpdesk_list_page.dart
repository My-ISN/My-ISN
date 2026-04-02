import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import 'create_ticket_page.dart';
import 'ticket_detail_page.dart';

class HelpdeskListPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HelpdeskListPage({super.key, required this.userData});

  @override
  State<HelpdeskListPage> createState() => _HelpdeskListPageState();
}

class _HelpdeskListPageState extends State<HelpdeskListPage> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url =
          'https://foxgeen.com/HRIS/mobileapi/get_tickets?user_id=$userId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        setState(() {
          _tickets = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Helpdesk: Error fetching tickets: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == '1') return Colors.green;
    if (status == '2') return Colors.red;
    return Colors.grey;
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    if (status == '1') return l10n?.translate('helpdesk.open') ?? 'Open';
    if (status == '2') return l10n?.translate('helpdesk.closed') ?? 'Closed';
    return status;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.deepOrange;
      case '4':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(BuildContext context, String priority) {
    final l10n = AppLocalizations.of(context);
    switch (priority) {
      case '1':
        return l10n?.translate('helpdesk.priority_low') ?? 'Low';
      case '2':
        return l10n?.translate('helpdesk.priority_medium') ?? 'Medium';
      case '3':
        return l10n?.translate('helpdesk.priority_high') ?? 'High';
      case '4':
        return l10n?.translate('helpdesk.priority_critical') ?? 'Critical';
      default:
        return priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n?.translate('helpdesk.title') ?? 'Helpdesk',
        showBackButton: false,
        userData: widget.userData,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTicketPage(userData: widget.userData),
            ),
          );
          if (result == true) {
            _fetchTickets();
          }
        },
        backgroundColor: const Color(0xFF1E88E5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ConnectivityWrapper(
        child: RefreshIndicator(
          onRefresh: _fetchTickets,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.translate('helpdesk.no_tickets') ?? 'No tickets',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    return _buildTicketCard(ticket);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final statusColor = _getStatusColor(ticket['ticket_status'].toString());
    final priorityColor = _getPriorityColor(
      ticket['ticket_priority'].toString(),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailPage(
                userData: widget.userData,
                ticketId: ticket['ticket_id'].toString(),
              ),
            ),
          ).then((_) => _fetchTickets());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      _getStatusText(
                        context,
                        ticket['ticket_status'].toString(),
                      ),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    ticket['ticket_code'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket['subject'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 14, color: priorityColor),
                  const SizedBox(width: 4),
                  Text(
                    _getPriorityText(
                      context,
                      ticket['ticket_priority'].toString(),
                    ),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ticket['created_at'] ?? '',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
