import 'dart:async';
import 'package:flutter/material.dart';
import '../services/intercom_service.dart';
import '../localization/app_localizations.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;

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
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) setState(() => _isListening = false);
          debugPrint("Speech error: $val");
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  void _listen() async {
    if (!_isSpeechInitialized) return;

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _messageController.text = val.recognizedWords;
            });
          },
          localeId: 'id_ID', // Default to Indonesian
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
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
        color: isDark ? const Color(0xFF161616) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.08 : 0.05),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.05 : 0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'placeholder'.tr(context),
                        hintStyle: TextStyle(
                          color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: _isSpeechInitialized 
                          ? IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isListening ? Colors.red : const Color(0xFF7E57C2),
                              ),
                              onPressed: _listen,
                            )
                          : null,
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E57C2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, 
                    size: 13, 
                    color: isDark ? Colors.grey[500] : Colors.grey[600]
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'listener_info'.tr(context),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'send_to_speaker'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _presets.length,
            itemBuilder: (context, index) {
              final preset = _presets[index];
              return InkWell(
                onTap: () => _sendMessage('presets.${preset['key']}'.tr(context)),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF7E57C2).withValues(alpha: isDark ? 0.15 : 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getIconData(preset['icon']!), color: const Color(0xFF7E57C2), size: 32),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _getPresetLabel(preset['key']!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87,
                          ),
                          maxLines: 1,
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
            const SizedBox(height: 60),
            Icon(Icons.history_rounded, size: 64, color: theme.primaryColor.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'empty_history'.tr(context), 
              style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'history'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: _history.length,
          itemBuilder: (context, index) {
              final item = _history[index];
              final isUnplayed = item['is_played'] == 0 || item['is_played'] == '0';
              final dateStr = item['created_at'] ?? '';
              final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
              final formattedDate = date != null ? DateFormat('HH:mm').format(date) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnplayed
                        ? const Color(0xFF7E57C2).withValues(alpha: 0.2)
                        : theme.dividerColor.withValues(alpha: isDark ? 0.05 : 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnplayed 
                          ? const Color(0xFF7E57C2).withValues(alpha: 0.1) 
                          : theme.dividerColor.withValues(alpha: isDark ? 0.05 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.volume_up_rounded, 
                      color: isUnplayed ? const Color(0xFF7E57C2) : theme.hintColor, 
                      size: 20
                    ),
                  ),
                  title: Text(
                    item['message'] ?? '',
                    style: TextStyle(
                      fontWeight: isUnplayed ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item['first_name']} • $formattedDate',
                          style: TextStyle(
                            fontSize: 11, 
                            color: theme.hintColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUnplayed 
                                ? Colors.orange.withValues(alpha: 0.15) 
                                : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isUnplayed 
                                  ? Colors.orange.withValues(alpha: 0.2) 
                                  : Colors.green.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isUnplayed ? Colors.orange : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isUnplayed ? 'unplayed'.tr(context) : 'played'.tr(context),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isUnplayed ? Colors.orange[400] : Colors.green[400],
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
