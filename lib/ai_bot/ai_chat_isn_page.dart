import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../localization/app_localizations.dart';
import '../services/ai_chat_isn_service.dart';
import '../services/tracking_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/side_drawer.dart';
import '../constants.dart';

class AiChatIsnPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AiChatIsnPage({super.key, required this.userData});

  @override
  State<AiChatIsnPage> createState() => _AiChatIsnPageState();
}

class _AiChatIsnPageState extends State<AiChatIsnPage>
    with SingleTickerProviderStateMixin {
  final AiChatIsnService _aiChatService = AiChatIsnService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Speech-to-Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  final List<String> _quickQueries = [
    'Daftar karyawan aktif & departemen',
    'Absensi hari ini',
    'Karyawan ultah bulan ini',
    'Total laptop disewa bulanan'
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadHistory();
    try {
      TrackingService().logCurrentFeature('ISN Assistant');
    } catch (_) {}

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
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

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final response = await _aiChatService.getHistory();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response['status'] == true && response['history'] != null) {
          _messages = List<Map<String, dynamic>>.from(response['history']);
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMessageText = text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({
        'role': 'user',
        'content': userMessageText,
        'created_at': DateTime.now().toIso8601String(),
      });
      _isSending = true;
    });
    _scrollToBottom();

    final response = await _aiChatService.sendMessage(userMessageText);

    if (mounted) {
      setState(() {
        _isSending = false;
        if (response['status'] == true && response['data'] != null) {
          final reply = response['data']['reply'] ?? 'Maaf, terjadi kesalahan.';
          _messages.add({
            'role': 'ai',
            'content': reply,
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          context.showErrorSnackBar(
              response['message'] ?? 'Gagal memproses data.');
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      context.showWarningSnackBar('Mikrofon tidak tersedia di perangkat ini.');
      return;
    }

    if (_isListening) {
      // Stop listening → send whatever was recognized
      await _speech.stop();
      setState(() => _isListening = false);
      final text = _messageController.text.trim();
      if (text.isNotEmpty) {
        _sendMessage(text);
      }
    } else {
      // Start listening
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _messageController.text = result.recognizedWords;
              _messageController.selection = TextSelection.fromPosition(
                TextPosition(offset: _messageController.text.length),
              );
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'id_ID',
        listenOptions: stt.SpeechListenOptions(cancelOnError: true),
      );
    }
  }

  Future<void> _clearChatHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('main.confirm'.tr(context)),
        content: const Text(
            'Apakah Anda yakin ingin menghapus semua riwayat percakapan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('aibot.cancel'.tr(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final response = await _aiChatService.clearHistory();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response['status'] == true) {
            _messages.clear();
            context.showSuccessSnackBar(
                response['message'] ?? 'Riwayat chat berhasil dikosongkan.');
          } else {
            context.showErrorSnackBar(
                response['message'] ?? 'Gagal menghapus riwayat.');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final firstName = widget.userData['first_name'] ?? 'Super Admin';

    // Greeting Message HTML
    final greetingHtml =
        'Halo, <b>$firstName</b>! Saya adalah asisten kecerdasan buatan ISN.<br>'
        'Saya memiliki akses penuh dan aman ke seluruh database HRIS. Anda bisa menanyakan apa saja, seperti data karyawan, absensi, gaji, work log, hingga status proyek/penyewaan laptop.<br><br>'
        '<i>Contoh yang bisa Anda tanyakan:</i>'
        '<ul style="margin: 4px 0; padding-left: 20px;">'
        '<li>"Tampilkan daftar 5 karyawan yang memiliki gaji tertinggi beserta jabatannya"</li>'
        '<li>"Siapa saja karyawan yang melakukan clock-in kemarin?"</li>'
        '<li>"Tampilkan total jam kerja (work log) per karyawan bulan ini"</li>'
        '<li>"Berapa banyak laptop yang saat ini disewa dengan status belum lunas?"</li>'
        '</ul>';

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'My ISN',
        extraActions: [
          Transform.translate(
            offset: const Offset(16, 0),
            child: IconButton(
              padding: const EdgeInsets.all(8.0),
              constraints: const BoxConstraints(),
              icon:
                  const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Kosongkan Chat',
              onPressed: _clearChatHistory,
            ),
          ),
        ],
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'ai_chat_isn',
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildGreetingBubble(greetingHtml, isDark);
                      }
                      final msg = _messages[index - 1];
                      final isUser = msg['role'] == 'user';
                      return _buildMessageBubble(
                          msg, isUser, isDark, colorScheme);
                    },
                  ),
          ),
          if (_isSending) _buildThinkingIndicator(isDark),
          // Listening indicator
          if (_isListening) _buildListeningIndicator(isDark),
          _buildQuickQueries(),
          _buildInputArea(isDark, colorScheme),
        ],
      ),
    );
  }



  Widget _buildListeningIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D1B6B).withOpacity(0.8)
            : const Color(0xFFEDE7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6A11CB).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF6A11CB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Mendengarkan... Bicara sekarang atau ketuk mikrofon lagi untuk kirim.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6A11CB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingBubble(String greetingHtml, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.grey.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Html(
                    data: greetingHtml,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(13.5),
                        color: isDark
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                      ),
                      "b": Style(fontWeight: FontWeight.bold),
                      "li": Style(margin: Margins.only(bottom: 4)),
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ISN Assistant',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, bool isDark,
      ColorScheme colorScheme) {
    final String content = msg['content'] ?? '';
    final String timeStr = _formatTime(msg['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isUser ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _buildAvatar(isUser: isUser, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: isUser
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF7E57C2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(4),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6A11CB).withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                  child: isUser
                      ? Text(
                          content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        )
                      : Html(
                          data: content,
                          style: {
                            "body": Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(13.5),
                              color: isDark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black87,
                            ),
                            "b": Style(fontWeight: FontWeight.bold),
                            "li": Style(margin: Margins.only(bottom: 4)),
                            "pre": Style(
                              backgroundColor: isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              padding: HtmlPaddings.all(8),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.withOpacity(0.3)),
                            ),
                          },
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUser ? 'Anda • $timeStr' : 'ISN Assistant • $timeStr',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser, required bool isDark}) {
    if (isUser) {
      final photo = widget.userData['profile_photo']?.toString() ?? '';
      if (photo.isNotEmpty) {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isDark ? Colors.white10 : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl:
                  '${AppConstants.serverRoot}/uploads/users/thumb/$photo',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Icon(
                  Icons.person_rounded,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  size: 20,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Icon(
                  Icons.person_rounded,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          color: isDark ? Colors.white70 : Colors.grey[700],
          size: 20,
        ),
      );
    } else {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8DBFF), Color(0xFFF3EBFF)],
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: Color(0xFF6A11CB),
          size: 20,
        ),
      );
    }
  }

  Widget _buildThinkingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.grey[400]! : Colors.grey[600]!,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sedang memproses data...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQueries() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickQueries.length,
        itemBuilder: (context, index) {
          final query = _quickQueries[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              label: Text(
                query,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? const Color(0xFFB180FF) : const Color(0xFF6A11CB),
                ),
              ),
              backgroundColor:
                  isDark ? Colors.grey[850] : const Color(0xFFF3EBFF),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE8DBFF),
              ),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _sendMessage(query),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(bool isDark, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          // Voice button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isListening
                  ? const Color(0xFF6A11CB)
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isListening
                    ? const Color(0xFF6A11CB)
                    : (isDark
                        ? Colors.white12
                        : Colors.grey.withOpacity(0.3)),
                width: 1.5,
              ),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6A11CB).withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _toggleListening,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.grey[600]),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.grey.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'Mendengarkan...'
                      : 'Ketik pertanyaan database Anda...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: _isListening
                        ? const Color(0xFF6A11CB)
                        : Colors.grey,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF7E57C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: () => _sendMessage(_messageController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}
