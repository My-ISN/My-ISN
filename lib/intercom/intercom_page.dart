import 'dart:async';
import 'package:flutter/material.dart';
import '../services/intercom_service.dart';
import '../localization/app_localizations.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';

class IntercomPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const IntercomPage({super.key, required this.userData});

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
          context.showErrorSnackBar('fetch_error'.tr(context));
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
        context.showSuccessSnackBar('send_success'.tr(context));
        _fetchHistory(silent: true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('send_error'.tr(context));
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
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'intercom',
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
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'placeholder'.tr(context),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'listener_info'.tr(context),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getIconData(preset['icon']!), color: const Color(0xFF7E57C2), size: 28),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _getPresetLabel(preset['key']!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7E57C2),
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
              final isUnplayed = item['is_played'] == 0 || item['is_played'] == '0';
              final dateStr = item['created_at'] ?? '';
              final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
              final formattedDate = date != null ? DateFormat('HH:mm').format(date) : '';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isUnplayed
                        ? theme.primaryColor.withValues(alpha: 0.3)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                color: isUnplayed
                    ? theme.primaryColor.withValues(alpha: 0.05)
                    : Theme.of(context).cardColor,
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
                        '${item['first_name']} • $formattedDate',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isUnplayed ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
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
