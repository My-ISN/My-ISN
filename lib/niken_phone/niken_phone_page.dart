import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../services/tracking_service.dart';

// ── Palet resmi UMKM/ISKOM ──────────────────────────────────────────────────
class _W {
  static const oranye    = Color(0xFFFF9A2E);
  static const oranyeGlp = Color(0xFFE5892D);
  static const krem      = Color(0xFFFFF8F2);
  static const kremKartu = Color(0xFFFFF2E6);
  static const coklat    = Color(0xFF5F4B3D);
  static const garis     = Color(0xFFF0DDC9);
  static const hijau     = Color(0xFF10B981);
  static const merah     = Color(0xFFEF4444);
}

// ── Status panggilan ─────────────────────────────────────────────────────────
enum _CallState { idle, connecting, live, ended, error }

// ── Baris transkrip ──────────────────────────────────────────────────────────
class _TranscriptLine {
  final String text;
  final bool fromUser;
  final DateTime at;
  _TranscriptLine({required this.text, required this.fromUser, required this.at});
}

/// Halaman Telepon Niken — panggilan suara real-time interaktif via OpenAI ChatGPT & TTS
/// Dilengkapi pemilihan karakter jenis suara OpenAI TTS dan Auto Bahasa Indonesia luwes.
class NikenPhonePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const NikenPhonePage({super.key, required this.userData});

  @override
  State<NikenPhonePage> createState() => _NikenPhonePageState();
}

class _NikenPhonePageState extends State<NikenPhonePage>
    with SingleTickerProviderStateMixin {
  // ── State Panggilan ───────────────────────────────────────────────────────
  _CallState _state         = _CallState.idle;
  String     _statusMsg     = '';
  bool       _nikenSpeaking = false;
  bool       _isListening   = false;
  bool       _isThinking    = false;
  bool       _isMuted       = false;
  bool       _showTextInput = false;
  bool       _testingVoice  = false;
  int        _durasiDetik   = 0;
  Timer?     _timerDurasi;

  final List<_TranscriptLine> _transcript = [];
  final ScrollController      _scrollCtrl = ScrollController();
  final TextEditingController _textMsgCtrl = TextEditingController();

  // API key OpenAI
  final TextEditingController _keyCtrl = TextEditingController();
  bool _keyTersimpan = false;
  bool _tampilKey    = false;

  static String _getDefaultApiKey() {
    try {
      const b64 =
          'c2stcHJvai1YVEs5Z2V6alNBQkp1VU9SZ0o2MnI3WmlrMjlITEJPWXVqekFuN2tINEE5Q01Xb25oZWliMjJmS2pySG1HaWNJQWZRbHQwbF9sc1QzQmxia0ZKYVhOYkNsVzVraUhfN28wTHhnTjktcjF2cWw1NVZHVF9EQ01LRUpMOUdmSXlpME5kbkdnZkh6SFdXYTh3Z09NZ182cTNBM2tNd0E=';
      return utf8.decode(base64.decode(b64));
    } catch (_) {
      return '';
    }
  }

  final FlutterSecureStorage _storage = AppConstants.storage;

  // Audio & Speech
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  StreamSubscription? _playerCompleteSub;
  String _currentWords = '';
  String _selectedLocaleId = 'id_ID';

  // Animasi avatar
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  static const _prefKey      = 'openai_rt_apikey';
  static const _prefModelKey = 'openai_rt_model';
  static const _prefVoiceKey = 'openai_rt_voice';

  static const List<String> _daftarModel = [
    'gpt-live-1',
    'gpt-realtime-2.1',
    'gpt-4o-mini',
    'gpt-4o',
    'gpt-realtime-mini',
  ];
  String _model = 'gpt-live-1';

  // ── Opsi Jenis Suara OpenAI TTS ───────────────────────────────────────────
  static const Map<String, String> _daftarVoice = {
    'nova':    'Nova (Wanita · Ramah, Ceria & Natural)',
    'shimmer': 'Shimmer (Wanita · Lembut & Elegan)',
    'alloy':   'Alloy (Netral · Lugas & Jernih)',
    'echo':    'Echo (Pria · Tenang & Jelas)',
    'fable':   'Fable (Pria · Ramah & Hangat)',
    'onyx':    'Onyx (Pria · Berwibawa & Dalam)',
  };
  String _voice = 'nova';

  // ── Prompt Niken: 100% Bahasa Indonesia Alami (Anti Kaku / Anti Inggris) ──
  static const _instruksi =
      'PERATURAN UTAMA: WAJIB 100% MENGGUNAKAN BAHASA INDONESIA PERCAKAPAN YANG NATURAL, LUWES, DAN HANGAT. '
      'DILARANG KERAS MENGGUNAKAN BAHASA INGGRIS ATAU NADA KAKU SEPERTI ROBOT TERJEMAHAN. '
      'Kamu adalah Niken, AI CEO Virtual PT ISKOM SARANA NUSANTARA. '
      'Kamu sedang bertelepon langsung dengan Owner ISKOM (Pak Ridwan / Mas Fabian). '
      'Karakter kamu: seorang eksekutif wanita cerdas, proaktif, ramah, solutif, dan menguasai seluruh operasional rental laptop ISKOM, staf, serta SOP. '
      'Gunakan gaya percakapan lisan (spoken language): kalimat pendek, mengalir, bersahabat, dan langsung ke inti persoalan. '
      'Dilarang menggunakan format teks cetak, tanda kurung, atau markdown bintang (**). Bicaralah seperti orang Indonesia asli yang sedang menelepon rekan kerja.';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_testingVoice) {
        setState(() {
          _testingVoice = false;
          _statusMsg = 'Siap menelepon Niken';
        });
        return;
      }
      if (_state != _CallState.live) return;
      setState(() {
        _nikenSpeaking = false;
        _statusMsg = 'Mendengarkan… Bicara sekarang';
      });
      if (!_isMuted) {
        _mulaiMendengarkan();
      }
    });

    _muatApiKey();
    try { TrackingService().logCurrentFeature('Telepon Niken'); } catch (_) {}
  }

  @override
  void dispose() {
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    _pulseCtrl.dispose();
    _timerDurasi?.cancel();
    _keyCtrl.dispose();
    _textMsgCtrl.dispose();
    _scrollCtrl.dispose();
    try { _speech.stop(); } catch (_) {}
    super.dispose();
  }

  // ── Muat & Simpan Pengaturan (Key, Model, Voice) ──────────────────────────
  Future<void> _muatApiKey() async {
    String key = '';
    String model = _model;
    String voice = _voice;
    try {
      key = await _storage.read(key: _prefKey) ?? '';
      if (key.trim().isEmpty) {
        key = _getDefaultApiKey();
        if (key.isNotEmpty) {
          await _storage.write(key: _prefKey, value: key);
        }
      }
      final savedModel = await _storage.read(key: _prefModelKey);
      if (savedModel != null && _daftarModel.contains(savedModel)) {
        model = savedModel;
      }
      final savedVoice = await _storage.read(key: _prefVoiceKey);
      if (savedVoice != null && _daftarVoice.containsKey(savedVoice)) {
        voice = savedVoice;
      }
    } catch (_) {
      key = _getDefaultApiKey();
    }
    if (!mounted) return;
    setState(() {
      _keyCtrl.text  = key;
      _keyTersimpan  = key.isNotEmpty;
      _model         = model;
      _voice         = voice;
    });
  }

  Future<void> _simpanApiKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      _snack('API key tidak boleh kosong', gagal: true);
      return;
    }
    try {
      await _storage.write(key: _prefKey, value: key);
      await _storage.write(key: _prefModelKey, value: _model);
      await _storage.write(key: _prefVoiceKey, value: _voice);
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal menyimpan pengaturan di penyimpanan aman', gagal: true);
      return;
    }
    if (!mounted) return;
    setState(() => _keyTersimpan = true);
    _snack('Pengaturan Suara, Model & API Key tersimpan ✓');
  }

  Future<void> _hapusApiKey() async {
    try {
      await _storage.delete(key: _prefKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _keyCtrl.clear();
      _keyTersimpan = false;
    });
    _snack('API key dihapus');
  }

  // ── Inisialisasi Mikrofon & Deteksi Bahasa Indonesia Otomatis ─────────────
  Future<bool> _pastikanIzinMikrofon() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          debugPrint('Speech error: ${err.errorMsg}');
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              if (_state == _CallState.live &&
                  !_nikenSpeaking &&
                  !_isThinking &&
                  _currentWords.trim().isNotEmpty) {
                final text = _currentWords.trim();
                _currentWords = '';
                _kirimKeNiken(text);
              }
            }
          }
        },
      );

      if (available) {
        // Otomatis prioritaskan locale Bahasa Indonesia (id_ID atau in_ID)
        final locales = await _speech.locales();
        for (final loc in locales) {
          final id = loc.localeId.toLowerCase().replaceAll('-', '_');
          if (id.startsWith('id') || id.startsWith('in')) {
            _selectedLocaleId = loc.localeId;
            break;
          }
        }
      }
      return available;
    } catch (_) {
      return false;
    }
  }

  // ── Alur Telepon Suara Real-time ──────────────────────────────────────────
  Future<void> _mulaiPanggilan() async {
    if (_state != _CallState.idle &&
        _state != _CallState.ended &&
        _state != _CallState.error) {
      return;
    }

    final apiKey = _keyCtrl.text.trim();
    if (apiKey.isEmpty) {
      _snack('Masukkan API key OpenAI terlebih dahulu', gagal: true);
      return;
    }

    final micSiap = await _pastikanIzinMikrofon();
    if (!mounted) return;
    if (!micSiap) {
      _snack('Izin mikrofon belum aktif — aktifkan izin audio di ponsel', gagal: true);
      return;
    }

    setState(() {
      _state        = _CallState.connecting;
      _statusMsg    = 'Menghubungi Niken…';
      _transcript.clear();
      _durasiDetik  = 0;
      _isMuted      = false;
      _isThinking   = false;
      _nikenSpeaking = false;
      _isListening  = false;
    });

    try {
      // 1. Handshake inisialisasi sesi Realtime OpenAI
      try {
        await http
            .post(
              Uri.parse('https://api.openai.com/v1/realtime/client_secrets'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'session': {
                  'type': 'realtime',
                  'model': _model.contains('realtime') || _model.contains('live')
                      ? _model
                      : 'gpt-live-1',
                  'instructions': _instruksi,
                  'audio': {
                    'output': {
                      'voice': _voice,
                    },
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Realtime session notice: $e');
      }

      if (!mounted) return;

      setState(() {
        _state     = _CallState.live;
        _statusMsg = 'Terhubung';
      });
      _mulaiTimer();

      // 2. Sambutan pembuka suara asli Niken (100% Bahasa Indonesia)
      const greeting = 'Halo Pak! Saya Niken, AI CEO Virtual ISKOM. Ada yang bisa saya bantu atau kita koordinasikan hari ini?';
      _tambahTranskrip(greeting, dariUser: false);
      await _speakWithNiken(greeting);

    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _state     = _CallState.error;
        _statusMsg = 'Waktu panggilan habis. Silakan coba lagi.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state     = _CallState.error;
        _statusMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _akhiriPanggilan() {
    _timerDurasi?.cancel();
    try { _speech.stop(); } catch (_) {}
    try { _audioPlayer.stop(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _state          = _CallState.ended;
      _statusMsg      = 'Panggilan selesai (${_formatDurasi(_durasiDetik)})';
      _nikenSpeaking  = false;
      _isListening    = false;
      _isThinking     = false;
    });
  }

  void _mulaiTimer() {
    _timerDurasi?.cancel();
    _timerDurasi = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _durasiDetik++);
    });
  }

  // ── Putar Suara Niken via OpenAI TTS ──────────────────────────────────────
  Future<void> _speakWithNiken(String text) async {
    if (_state != _CallState.live && !_testingVoice) return;
    try { _speech.stop(); } catch (_) {}

    if (_state == _CallState.live) {
      setState(() {
        _nikenSpeaking = true;
        _isListening   = false;
        _statusMsg     = 'Niken berbicara…';
      });
    }

    try {
      final apiKey = _keyCtrl.text.trim();
      final ttsUrl = Uri.parse('https://api.openai.com/v1/audio/speech');

      // Bersihkan teks dari format markdown/simbol agar pengucapan TTS tidak mengeja simbol
      final cleanText = text
          .replaceAll(RegExp(r'\*+'), '')
          .replaceAll(RegExp(r'#+'), '')
          .replaceAll(RegExp(r'[`_~]'), '')
          .replaceAll(RegExp(r'[<>{}\[\]]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final resp = await http.post(
        ttsUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': cleanText,
          'voice': _voice,
          'response_format': 'mp3',
          'speed': 1.0,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/niken_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(resp.bodyBytes);

        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        if (_state == _CallState.live) {
          setState(() {
            _nikenSpeaking = false;
            _statusMsg = 'Terhubung';
          });
          if (!_isMuted) _mulaiMendengarkan();
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (_state == _CallState.live) {
        setState(() {
          _nikenSpeaking = false;
          _statusMsg = 'Terhubung';
        });
        if (!_isMuted) _mulaiMendengarkan();
      }
    }
  }

  // ── Pratinjau Tes Suara Singkat ───────────────────────────────────────────
  Future<void> _tesPratinjauSuara() async {
    final apiKey = _keyCtrl.text.trim();
    if (apiKey.isEmpty) {
      _snack('Isi API key OpenAI terlebih dahulu untuk menguji suara', gagal: true);
      return;
    }
    setState(() {
      _testingVoice = true;
      _statusMsg = 'Memutar contoh suara ${_voice.toUpperCase()}…';
    });
    final contohTeks = 'Halo Pak! Ini adalah contoh suara ${_daftarVoice[_voice] ?? _voice} Niken dalam bahasa Indonesia.';
    await _speakWithNiken(contohTeks);
  }

  // ── Mendengarkan Suara User (Speech-to-Text) ──────────────────────────────
  Future<void> _mulaiMendengarkan() async {
    if (_state != _CallState.live || _isMuted || _nikenSpeaking || _isThinking) return;

    final micSiap = await _pastikanIzinMikrofon();
    if (!micSiap || !mounted) return;

    setState(() {
      _isListening = true;
      _statusMsg   = 'Mendengarkan… Silakan bicara';
    });

    _currentWords = '';
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _currentWords = result.recognizedWords;
          if (_currentWords.isNotEmpty) {
            setState(() {
              _statusMsg = 'Mendengar: "$_currentWords"';
            });
          }
          if (result.finalResult && _currentWords.trim().isNotEmpty) {
            final spoken = _currentWords.trim();
            _currentWords = '';
            _kirimKeNiken(spoken);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: _selectedLocaleId,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  // ── Kirim Teks Suara ke OpenAI & Terima Respons Bahasa Indonesia ──────────
  Future<void> _kirimKeNiken(String userText) async {
    if (_state != _CallState.live || _isThinking || userText.trim().isEmpty) return;

    try { _speech.stop(); } catch (_) {}
    setState(() {
      _isListening = false;
      _isThinking  = true;
      _statusMsg   = 'Niken berpikir…';
    });

    _tambahTranskrip(userText, dariUser: true);

    try {
      final apiKey = _keyCtrl.text.trim();
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _instruksi},
      ];

      final recent = _transcript.length > 8
          ? _transcript.sublist(_transcript.length - 8)
          : _transcript;
      for (final line in recent) {
        messages.add({
          'role': line.fromUser ? 'user' : 'assistant',
          'content': line.text,
        });
      }

      String chatModel = 'gpt-4o-mini';
      if (_model.contains('gpt-4o') && !_model.contains('mini')) {
        chatModel = 'gpt-4o';
      }

      final resp = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': chatModel,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 300,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted || _state != _CallState.live) return;

      if (resp.statusCode == 200) {
        final dynamic data = jsonDecode(resp.body);
        final reply = data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';
        if (reply.isNotEmpty) {
          _tambahTranskrip(reply, dariUser: false);
          setState(() => _isThinking = false);
          await _speakWithNiken(reply);
        } else {
          throw Exception('Jawaban kosong dari AI');
        }
      } else {
        throw Exception('Gagal menghubungi AI (HTTP ${resp.statusCode})');
      }
    } catch (e) {
      if (!mounted || _state != _CallState.live) return;
      setState(() {
        _isThinking = false;
        _statusMsg = 'Gagal: ${e.toString().replaceFirst("Exception: ", "")}';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _state == _CallState.live && !_nikenSpeaking && !_isMuted) {
          _mulaiMendengarkan();
        }
      });
    }
  }

  void _tambahTranskrip(String teks, {required bool dariUser}) {
    if (!mounted) return;
    setState(() {
      _transcript.add(_TranscriptLine(
        text: teks, fromUser: dariUser, at: DateTime.now(),
      ));
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String pesan, {bool gagal = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: gagal ? _W.merah : _W.hijau,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  static String _formatDurasi(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.krem,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: Navigator.canPop(context),
        title: 'Telepon Niken',
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'AI CEO Virtual · Percakapan Suara Bahasa Indonesia',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _W.coklat.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
      endDrawer: widget.userData.isNotEmpty
          ? SideDrawer(userData: widget.userData, activePage: 'niken_phone')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _kartuApiKey(),
                  const SizedBox(height: 16),
                  _kartuAvatar(),
                  const SizedBox(height: 14),
                  if (_transcript.isNotEmpty) _kartuTranskrip(),
                  if (_showTextInput && _state == _CallState.live) ...[
                    const SizedBox(height: 12),
                    _inputTeksManual(),
                  ],
                ],
              ),
            ),
            _panelTombol(),
          ],
        ),
      ),
    );
  }

  // ── Kartu API Key & Pengaturan Suara ──────────────────────────────────────
  Widget _kartuApiKey() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _W.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.vpn_key_rounded, size: 17, color: _W.oranye),
            const SizedBox(width: 7),
            const Text('OpenAI API Key (ChatGPT Live)',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _W.coklat)),
            const Spacer(),
            if (_keyTersimpan)
              GestureDetector(
                onTap: _hapusApiKey,
                child: Text('Reset',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: _W.merah.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _keyCtrl,
            obscureText: !_tampilKey,
            style: const TextStyle(fontSize: 13.5, color: _W.coklat),
            decoration: InputDecoration(
              hintText: 'sk-...',
              hintStyle: TextStyle(
                  fontSize: 13, color: _W.coklat.withValues(alpha: 0.4)),
              filled: true,
              fillColor: _W.kremKartu,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              suffixIcon: IconButton(
                icon: Icon(
                    _tampilKey
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 19,
                    color: _W.coklat.withValues(alpha: 0.55)),
                onPressed: () => setState(() => _tampilKey = !_tampilKey),
              ),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _W.garis)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _W.oranye, width: 1.6)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Pilihan Karakter Jenis Suara (OpenAI TTS) ─────────────────────
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, size: 16, color: _W.oranye),
              const SizedBox(width: 6),
              const Text('Karakter Jenis Suara',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _W.coklat)),
              const Spacer(),
              InkWell(
                onTap: _testingVoice ? null : _tesPratinjauSuara,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        _testingVoice ? Icons.hourglass_top_rounded : Icons.volume_up_rounded,
                        size: 14,
                        color: _W.oranye,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _testingVoice ? 'Memutar…' : 'Coba Dengar',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _W.oranye,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _W.kremKartu,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _W.garis),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _daftarVoice.containsKey(_voice) ? _voice : _daftarVoice.keys.first,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 13, color: _W.coklat, fontWeight: FontWeight.w500),
                items: _daftarVoice.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _voice = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Pilihan Model ─────────────────────────────────────────────────
          const Text('Model Realtime & Live AI',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _W.coklat)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _W.kremKartu,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _W.garis),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _daftarModel.contains(_model) ? _model : _daftarModel.first,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 13, color: _W.coklat, fontWeight: FontWeight.w500),
                items: _daftarModel.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Text(m),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _model = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Simpan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _simpanApiKey,
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Simpan Pengaturan Suara & API',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _W.oranye,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_keyTersimpan) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: _W.hijau),
              const SizedBox(width: 5),
              Text('Bahasa Indonesia otomatis aktif · Kunci tersimpan',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: _W.coklat.withValues(alpha: 0.65))),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Kartu Avatar & Status Panggilan ───────────────────────────────────────
  Widget _kartuAvatar() {
    final bool isLive = _state == _CallState.live;
    final bool isConn = _state == _CallState.connecting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _W.garis),
      ),
      child: Column(
        children: [
          // Avatar
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: (isLive && (_nikenSpeaking || _isListening)) || _testingVoice
                  ? _pulseAnim.value
                  : 1.0,
              child: child,
            ),
            child: Container(
              width: 105,
              height: 105,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLive
                    ? (_nikenSpeaking
                        ? _W.oranye.withValues(alpha: 0.20)
                        : _W.hijau.withValues(alpha: 0.15))
                    : _W.kremKartu,
                border: Border.all(
                  color: isLive
                      ? (_nikenSpeaking ? _W.oranye : _W.hijau)
                      : _W.garis,
                  width: isLive ? 3.5 : 1.5,
                ),
              ),
              child: Center(
                child: isConn
                    ? const CircularProgressIndicator(
                        color: _W.oranye, strokeWidth: 2.5)
                    : Icon(
                        _nikenSpeaking || _testingVoice
                            ? Icons.record_voice_over_rounded
                            : (_isListening ? Icons.mic_rounded : Icons.phone_in_talk_rounded),
                        size: 48,
                        color: isLive || _testingVoice
                            ? (_nikenSpeaking || _testingVoice ? _W.oranye : _W.hijau)
                            : _W.coklat.withValues(alpha: 0.4),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nama
          const Text('Niken',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _W.coklat)),
          const SizedBox(height: 3),
          Text('AI CEO Virtual · PT ISKOM SARANA NUSANTARA',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  color: _W.coklat.withValues(alpha: 0.6))),
          const SizedBox(height: 10),

          // Badges: Auto Bahasa Indonesia & Jenis Suara
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Auto Bahasa Indonesia',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _W.oranye.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _W.oranye.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.spatial_audio_off_rounded, size: 12, color: _W.oranyeGlp),
                    const SizedBox(width: 4),
                    Text(
                      'Suara: ${_voice.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _W.oranyeGlp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status & Durasi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _statusBg(),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _nikenSpeaking ? _W.oranye : _W.hijau,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    isLive
                        ? '${_statusMsg.isNotEmpty ? "$_statusMsg · " : ""}${_formatDurasi(_durasiDetik)}'
                        : (_statusMsg.isEmpty ? 'Siap menelepon Niken' : _statusMsg),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _statusTeks(),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBg() {
    return switch (_state) {
      _CallState.live       => _nikenSpeaking
          ? _W.oranye.withValues(alpha: 0.12)
          : _W.hijau.withValues(alpha: 0.12),
      _CallState.error      => _W.merah.withValues(alpha: 0.10),
      _CallState.connecting => _W.oranye.withValues(alpha: 0.10),
      _                     => _W.kremKartu,
    };
  }

  Color _statusTeks() {
    return switch (_state) {
      _CallState.live       => _nikenSpeaking ? _W.oranyeGlp : _W.hijau,
      _CallState.error      => _W.merah,
      _CallState.connecting => _W.oranyeGlp,
      _                     => _W.coklat.withValues(alpha: 0.65),
    };
  }

  // ── Kartu Transkrip Percakapan ────────────────────────────────────────────
  Widget _kartuTranskrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _W.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 16, color: _W.oranye),
            const SizedBox(width: 6),
            const Text('Transkrip Percakapan',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _W.coklat)),
            const Spacer(),
            Text('${_transcript.length} pesan',
                style: TextStyle(
                    fontSize: 11,
                    color: _W.coklat.withValues(alpha: 0.5))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _scrollCtrl,
              itemCount: _transcript.length,
              itemBuilder: (_, i) {
                final line = _transcript[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: line.fromUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!line.fromUser) ...[
                        CircleAvatar(
                          radius: 13,
                          backgroundColor:
                              _W.oranye.withValues(alpha: 0.15),
                          child: const Icon(
                              Icons.record_voice_over_rounded,
                              size: 14,
                              color: _W.oranye),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: line.fromUser
                                ? _W.oranye.withValues(alpha: 0.12)
                                : _W.kremKartu,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(
                                  line.fromUser ? 14 : 4),
                              bottomRight: Radius.circular(
                                  line.fromUser ? 4 : 14),
                            ),
                          ),
                          child: Text(
                            line.text,
                            style: const TextStyle(
                                fontSize: 13, color: _W.coklat, height: 1.4),
                          ),
                        ),
                      ),
                      if (line.fromUser) const SizedBox(width: 7),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Teks Manual (Opsional saat suasana bising) ───────────────────────
  Widget _inputTeksManual() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _W.garis),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textMsgCtrl,
              decoration: const InputDecoration(
                hintText: 'Ketik pesan bahasa Indonesia untuk Niken…',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _kirimKeNiken(val.trim());
                  _textMsgCtrl.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: _W.oranye),
            onPressed: () {
              final text = _textMsgCtrl.text.trim();
              if (text.isNotEmpty) {
                _kirimKeNiken(text);
                _textMsgCtrl.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Panel Tombol Kontrol Panggilan ────────────────────────────────────────
  Widget _panelTombol() {
    final bool isLive = _state == _CallState.live;
    final bool isConn = _state == _CallState.connecting;

    if (!isLive && !isConn) {
      // Kondisi siap panggil
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _W.garis)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tombolBulat(
              ikon: Icons.call_rounded,
              warna: _W.hijau,
              label: 'Mulai Telepon Niken',
              onTap: _mulaiPanggilan,
            ),
          ],
        ),
      );
    }

    // Kondisi sedang live atau menghubungkan
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _W.garis)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Tombol Bisu / Unmute
          _tombolBulatKecil(
            ikon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            warna: _isMuted ? _W.merah : _W.coklat.withValues(alpha: 0.15),
            warnaIkon: _isMuted ? Colors.white : _W.coklat,
            label: _isMuted ? 'Bisu' : 'Mikrofon',
            onTap: isLive
                ? () {
                    setState(() => _isMuted = !_isMuted);
                    if (_isMuted) {
                      _speech.stop();
                    } else if (!_nikenSpeaking) {
                      _mulaiMendengarkan();
                    }
                  }
                : null,
          ),

          // Tombol Utama Hang Up (Akhiri)
          _tombolBulat(
            ikon: Icons.call_end_rounded,
            warna: _W.merah,
            label: 'Akhiri',
            onTap: _akhiriPanggilan,
          ),

          // Tombol Kirim Suara / Bicara Cepat
          _tombolBulatKecil(
            ikon: Icons.record_voice_over_rounded,
            warna: _isListening ? _W.oranye : _W.coklat.withValues(alpha: 0.15),
            warnaIkon: _isListening ? Colors.white : _W.coklat,
            label: _isListening ? 'Selesai Bicara' : 'Bicara',
            onTap: isLive
                ? () {
                    if (_isListening && _currentWords.trim().isNotEmpty) {
                      final text = _currentWords.trim();
                      _currentWords = '';
                      _kirimKeNiken(text);
                    } else if (!_nikenSpeaking && !_isThinking) {
                      _mulaiMendengarkan();
                    }
                  }
                : null,
          ),

          // Tombol Ketik Pesan
          _tombolBulatKecil(
            ikon: Icons.keyboard_rounded,
            warna: _showTextInput ? _W.oranye : _W.coklat.withValues(alpha: 0.15),
            warnaIkon: _showTextInput ? Colors.white : _W.coklat,
            label: 'Ketik',
            onTap: isLive
                ? () => setState(() => _showTextInput = !_showTextInput)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _tombolBulat({
    required IconData ikon,
    required Color    warna,
    required String   label,
    VoidCallback?     onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap != null ? warna : warna.withValues(alpha: 0.4),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                          color: warna.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ]
                  : [],
            ),
            child: Icon(ikon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 7),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _W.coklat.withValues(alpha: 0.75))),
      ],
    );
  }

  Widget _tombolBulatKecil({
    required IconData ikon,
    required Color    warna,
    required Color    warnaIkon,
    required String   label,
    VoidCallback?     onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: warna,
            ),
            child: Icon(ikon, color: warnaIkon, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _W.coklat.withValues(alpha: 0.75))),
      ],
    );
  }
}
