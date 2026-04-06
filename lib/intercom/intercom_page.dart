import 'dart:async';
import 'package:flutter/material.dart';
import '../services/intercom_service.dart';
import '../localization/app_localizations.dart';
import 'package:intl/intl.dart';

class IntercomPage extends StatefulWidget {
  const IntercomPage({super.key});

  @override
  State<IntercomPage> createState() => _IntercomPageState();
}

class _IntercomPageState extends State<IntercomPage> {
  final IntercomService _intercomService = IntercomService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _history = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;

  final List<Map<String, String>> _presets = [
    {'key': 'package', 'icon': 'inventory_2'},
    {'key': 'guest', 'icon': 'person_search'},
    {'key': 'meal', 'icon': 'restaurant'},
    {'key': 'leaving', 'icon': 'exit_to_app'},
    {'key': 'lights', 'icon': 'lightbulb'},
    {'key': 'phone', 'icon': 'phone_forwarded'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _fetchHistory(silent: true);
      }
    });
  }

  Future<void> _fetchHistory({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final history = await _intercomService.getIntercomHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('fetch_error'.tr(context))),
          );
        }
      }
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _intercomService.sendIntercomMessage(message);
      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('send_success'.tr(context)),
            backgroundColor: Colors.green,
          ),
        );
        _fetchHistory(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('send_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('title'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _fetchHistory(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Input Section
            _buildInputSection(theme, isDark),
            
            // Presets Grid
            _buildPresetsSection(theme),
  
            const Divider(height: 1),
  
            // History Section
            _isLoading && _history.isEmpty
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                : _buildHistorySection(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'placeholder'.tr(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'listener_info'.tr(context),
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'send_to_speaker'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: _presets.length,
            itemBuilder: (context, index) {
              final preset = _presets[index];
              return InkWell(
                onTap: () => _sendMessage('presets.${preset['key']}'.tr(context)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getIconData(preset['icon']!), color: Colors.purple, size: 28),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _getPresetLabel(preset['key']!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme, bool isDark) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('empty_history'.tr(context), style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'history'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];
            final isPlayedVal = item['is_played'];
            final isUnplayed = isPlayedVal.toString() == '0' || isPlayedVal == 0 || isPlayedVal == false;

            final dateStr = item['created_at'] ?? '';
            final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
            final formattedDate = date != null ? DateFormat('HH:mm').format(date) : '';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isUnplayed ? theme.primaryColor.withOpacity(0.3) : Colors.transparent,
                    width: 1,
                  ),
                ),
                color: isUnplayed 
                  ? theme.primaryColor.withOpacity(0.05) 
                  : (isDark ? Colors.grey[900] : Colors.white),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isUnplayed ? theme.primaryColor : Colors.grey[400],
                    radius: 18,
                    child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    item['message'] ?? '',
                    style: TextStyle(
                      fontWeight: isUnplayed ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        '${item['first_name'] ?? 'Staff'} • $formattedDate',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isUnplayed ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUnplayed ? 'unplayed'.tr(context) : 'played'.tr(context),
                          style: TextStyle(
                            fontSize: 9,
                            color: isUnplayed ? Colors.orange[800] : Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
        ),
      ],
    );
  }

  IconData _getIconData(String key) {
    switch (key) {
      case 'inventory_2': return Icons.inventory_2;
      case 'person_search': return Icons.person_search;
      case 'restaurant': return Icons.restaurant;
      case 'exit_to_app': return Icons.exit_to_app;
      case 'lightbulb': return Icons.lightbulb;
      case 'phone_forwarded': return Icons.phone_forwarded;
      default: return Icons.message;
    }
  }

  String _getPresetLabel(String key) {
    switch (key) {
      case 'package': return 'Paket'.tr(context);
      case 'guest': return 'Tamu'.tr(context);
      case 'meal': return 'Makan'.tr(context);
      case 'leaving': return 'Pergi'.tr(context);
      case 'lights': return 'Lampu'.tr(context);
      case 'phone': return 'Telepon'.tr(context);
      default: return key;
    }
  }
}
