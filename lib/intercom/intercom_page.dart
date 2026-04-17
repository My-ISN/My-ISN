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
  final TextEditingController _presetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _history = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;

  List<dynamic> _presets = [];
  bool _isLoadingPresets = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _fetchPresets();
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
    _presetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1') return true;
    final dynamic resources = widget.userData['role_resources'];
    if (resources == null || resources == '') return false;

    if (resources is String) {
      final List<String> resourceList =
          resources.split(',').map((e) => e.trim()).toList();
      return resourceList.contains(resource);
    }

    if (resources is List) {
      return resources.any(
        (r) => r is Map
            ? r['resource_slug'] == resource
            : r.toString() == resource,
      );
    }

    return false;
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

  Future<void> _fetchPresets() async {
    if (mounted) setState(() => _isLoadingPresets = true);
    try {
      final presets = await _intercomService.getIntercomPresets();
      if (mounted) {
        setState(() {
          _presets = presets;
          _isLoadingPresets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPresets = false);
        // Fallback or silent error for presets
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

  Future<void> _showAddPresetSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isSaving = false;
    _presetController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E57C2).withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_comment_rounded,
                            color: Color(0xFF7E57C2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tambah Preset',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Isi text preset yang ingin dipakai cepat.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _presetController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Ada paket di depan pintu',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF7F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: const Color(0xFF7E57C2).withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final message = _presetController.text.trim();
                                if (message.isEmpty) {
                                  context.showErrorSnackBar(
                                    'Preset tidak boleh kosong',
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                try {
                                  final result = await _intercomService
                                      .addIntercomPreset(message);
                                  if (!mounted) return;

                                  if (result['status'] == true) {
                                    Navigator.pop(modalContext);
                                    context.showSuccessSnackBar(
                                      result['message']?.toString() ??
                                          'Preset berhasil ditambahkan',
                                    );
                                    _fetchPresets();
                                  } else {
                                    context.showErrorSnackBar(
                                      result['message']?.toString() ??
                                          'Gagal menambah preset',
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    context.showErrorSnackBar(
                                      'Gagal menambah preset',
                                    );
                                  }
                                } finally {
                                  if (mounted && modalContext.mounted) {
                                    setModalState(() => isSaving = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Simpan Preset',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(modalContext),
                        child: Text(
                          'Batal',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
      floatingActionButton: _hasPermission('mobile_intercom_send')
          ? FloatingActionButton.extended(
              onPressed: _showAddPresetSheet,
              backgroundColor: const Color(0xFF7E57C2),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.speaker_notes_rounded),
              label: const Text(
                'Tambah Preset',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            )
          : null,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _buildInputSection(theme, isDark),
          ),
          SliverToBoxAdapter(
            child: _buildPresetsSection(theme),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
          if (_isLoading && _history.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_history.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyHistory(theme),
            )
          else ...[
            SliverToBoxAdapter(
              child: _buildHistoryHeader(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildHistoryItem(_history[index], theme, isDark),
                  childCount: _history.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: 96),
          ),
        ],
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
              if (_isLoadingPresets)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _presets.isEmpty && !_isLoadingPresets
              ? _buildEmptyPresets()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map<Widget>((preset) {
                    final String name = (preset['name'] ?? '').toString();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _sendMessage(name),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF7E57C2).withValues(alpha: isDark ? 0.18 : 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyPresets() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text(
          'Belum ada preset. Atur di web.',
          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.history_rounded,
            size: 64,
            color: theme.primaryColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'empty_history'.tr(context),
            style: TextStyle(
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
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
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    dynamic item,
    ThemeData theme,
    bool isDark,
  ) {
    final isUnplayed = item['is_played'] == 0 || item['is_played'] == '0';
    final dateStr = item['created_at'] ?? '';
    final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
    final formattedDate =
        date != null ? DateFormat('HH:mm').format(date) : '';

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
            size: 20,
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
                  fontWeight: FontWeight.w500,
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
                      isUnplayed
                          ? 'unplayed'.tr(context)
                          : 'played'.tr(context),
                      style: TextStyle(
                        fontSize: 9,
                        color: isUnplayed
                            ? Colors.orange[400]
                            : Colors.green[400],
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
