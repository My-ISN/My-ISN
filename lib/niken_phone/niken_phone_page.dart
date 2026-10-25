import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

/// Halaman Telepon Niken — panggilan suara real-time via OpenAI Realtime API
/// (WebRTC ephemeral-token flow, model gpt-4o-realtime-preview-2024-12-17).
class NikenPhonePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const NikenPhonePage({super.key, required this.userData});

  @override
  State<NikenPhonePage> createState() => _NikenPhonePageState();
}

class _NikenPhonePageState extends State<NikenPhonePage>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  _CallState _state       = _CallState.idle;
  String     _statusMsg   = '';
  bool       _nikenSpeaking = false;
  int        _durasiDetik = 0;
  Timer?     _timerDurasi;

  final List<_TranscriptLine> _transcript = [];
  final ScrollController      _scrollCtrl = ScrollController();

  // API key
  final TextEditingController _keyCtrl = TextEditingController();
  bool _keyTersimpan = false;
  bool _tampilKey    = false;

  /// API key disimpan terenkripsi memakai konvensi [AppConstants.storage]
  /// (encryptedSharedPreferences), bukan SharedPreferences biasa.
  final FlutterSecureStorage _storage = AppConstants.storage;

  /// Dipakai hanya untuk memicu permintaan izin mikrofon Android
  /// (RECORD_AUDIO sudah dideklarasikan di AndroidManifest).
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Animasi avatar
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  static const _prefKey      = 'openai_rt_apikey';
  static const _prefModelKey = 'openai_rt_model';
  static const List<String> _daftarModel = [
    'gpt-4o-realtime-preview',
    'gpt-4o-mini-realtime-preview',
    'gpt-realtime',
    'gpt-realtime-mini',
  ];
  String _model = 'gpt-4o-realtime-preview';
  static const _instruksi =
      'Kamu adalah Niken, AI CEO Virtual PT ISKOM SARANA NUSANTARA. '
      'Kamu berbicara dengan Owner (Ridwan). Karakter kamu: proaktif, tegas, '
      'santai-profesional, selalu siap membantu membangun sistem internal perusahaan. '
      'Jawab singkat dan langsung ke poin. Gunakan Bahasa Indonesia.';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _muatApiKey();
    try { TrackingService().logCurrentFeature('Telepon Niken'); } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timerDurasi?.cancel();
    _keyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── API Key (FlutterSecureStorage / terenkripsi) ─────────────────────────
  Future<void> _muatApiKey() async {
    String key = '';
    String model = _model;
    try {
      key = await _storage.read(key: _prefKey) ?? '';
      final savedModel = await _storage.read(key: _prefModelKey);
      if (savedModel != null && savedModel.isNotEmpty) {
        model = savedModel;
      }
    } catch (_) {
      key = '';
    }
    if (!mounted) return;
    setState(() {
      _keyCtrl.text  = key;
      _keyTersimpan  = key.isNotEmpty;
      _model         = model;
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
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal menyimpan API key di penyimpanan aman', gagal: true);
      return;
    }
    if (!mounted) return;
    setState(() => _keyTersimpan = true);
    _snack('Pengaturan & API key tersimpan ✓');
  }

  Future<void> _hapusApiKey() async {
    try {
      await _storage.delete(key: _prefKey);
    } catch (_) {
      // Diabaikan: kalau entri memang tidak ada, hasil akhirnya sama.
    }
    if (!mounted) return;
    setState(() {
      _keyCtrl.clear();
      _keyTersimpan = false;
    });
    _snack('API key dihapus');
  }

  /// Minta izin mikrofon lewat `speech_to_text` (dependency yang sudah ada),
  /// menggantikan `permission_handler`. Tidak pernah melempar exception.
  Future<bool> _pastikanIzinMikrofon() async {
    try {
      return await _speech.initialize(onError: (_) {});
    } catch (_) {
      return false;
    }
  }

  // ── Panggilan (HTTP + mic simulation) ────────────────────────────────────
  // Catatan: WebRTC penuh butuh package `flutter_webrtc` yang belum ada di
  // pubspec. Halaman ini menyiapkan UI lengkap dan alur ephemeral-token;
  // integrasi WebRTC aktif ditandai TODO agar bisa ditambahkan nanti tanpa
  // merombak struktur.

  Future<void> _mulaiPanggilan() async {
    if (_state != _CallState.idle &&
        _state != _CallState.ended &&
        _state != _CallState.error) {
      return;
    }

    final apiKey = _keyCtrl.text.trim();
    if (apiKey.isEmpty) {
      _snack('Masukkan API key OpenAI dulu', gagal: true);
      return;
    }

    // Izin mikrofon: diminta via speech_to_text (tanpa permission_handler).
    final micSiap = await _pastikanIzinMikrofon();
    if (!mounted) return;
    if (!micSiap) {
      _snack('Izin mikrofon belum aktif — periksa izin aplikasi', gagal: true);
      return;
    }

    setState(() {
      _state      = _CallState.connecting;
      _statusMsg  = 'Menghubungi Niken…';
      _transcript.clear();
      _durasiDetik = 0;
    });

    try {
      // 1. Ambil ephemeral token dari OpenAI (GA Realtime client_secrets endpoint)
      final tokenResp = await http
          .post(
            Uri.parse('https://api.openai.com/v1/realtime/client_secrets'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'session': {
                'type': 'realtime',
                'model': _model,
                'voice': 'shimmer',
                'instructions': _instruksi,
                'modalities': ['audio', 'text'],
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (tokenResp.statusCode != 200) {
        final body = jsonDecode(tokenResp.body);
        throw Exception(body['error']?['message'] ?? 'Gagal ambil token');
      }

      final tokenData  = jsonDecode(tokenResp.body) as Map<String, dynamic>;
      final ephKey     = (tokenData['value'] as String?) ??
          ((tokenData['client_secret'] as Map?)?['value'] as String? ?? '');
      if (ephKey.isEmpty) throw Exception('Token kosong dari OpenAI');

      // 2. TODO: Buka RTCPeerConnection menggunakan flutter_webrtc
      //    Saat ini simulasikan "live" agar UI bisa diuji.
      //    Ganti blok di bawah ini setelah flutter_webrtc ditambahkan ke pubspec.
      if (!mounted) return;
      setState(() {
        _state     = _CallState.live;
        _statusMsg = 'Terhubung';
      });
      _mulaiTimer();
      _tambahTranskrip('Halo Pak Ridwan, ada yang bisa saya bantu?', dariUser: false);

      // ── TODO: WebRTC integration ──────────────────────────────────────────
      // final pc = await createPeerConnection({...});
      // final stream = await navigator.mediaDevices.getUserMedia({'audio': true});
      // stream.getAudioTracks().forEach((t) => pc.addTrack(t, stream));
      // ...sdp exchange via WHIP/WHEP atau custom signaling ke OpenAI endpoint
      // ─────────────────────────────────────────────────────────────────────

    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _state     = _CallState.error;
        _statusMsg = 'Waktu habis. Coba lagi.';
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
    setState(() {
      _state     = _CallState.ended;
      _statusMsg = 'Panggilan selesai (${_formatDurasi(_durasiDetik)})';
      _nikenSpeaking = false;
    });
    // TODO: tutup RTCPeerConnection
  }

  void _mulaiTimer() {
    _timerDurasi = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _durasiDetik++);
    });
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

  // ── Helpers ───────────────────────────────────────────────────────────────
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
            'AI CEO Virtual — Bicara langsung',
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
                ],
              ),
            ),
            _panelTombol(),
          ],
        ),
      ),
    );
  }

  // ── Kartu API Key ─────────────────────────────────────────────────────────
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
            const Text('OpenAI API Key',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _W.coklat)),
            const Spacer(),
            if (_keyTersimpan)
              GestureDetector(
                onTap: _hapusApiKey,
                child: Text('Hapus',
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
          const Text('Model Realtime',
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _simpanApiKey,
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Simpan Pengaturan',
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
              Text('Key tersimpan di perangkat',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: _W.coklat.withValues(alpha: 0.65))),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Kartu Avatar ──────────────────────────────────────────────────────────
  Widget _kartuAvatar() {
    final bool isLive = _state == _CallState.live;
    final bool isConn = _state == _CallState.connecting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
              scale: isLive && _nikenSpeaking ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLive ? _W.oranye.withValues(alpha: 0.15) : _W.kremKartu,
                border: Border.all(
                  color: isLive ? _W.oranye : _W.garis,
                  width: isLive ? 3 : 1.5,
                ),
              ),
              child: Center(
                child: isConn
                    ? const CircularProgressIndicator(
                        color: _W.oranye, strokeWidth: 2.5)
                    : Icon(
                        Icons.record_voice_over_rounded,
                        size: 52,
                        color: isLive ? _W.oranye : _W.coklat.withValues(alpha: 0.4),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nama
          const Text('Niken',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _W.coklat)),
          const SizedBox(height: 4),
          Text('AI CEO Virtual · PT ISKOM SARANA NUSANTARA',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  color: _W.coklat.withValues(alpha: 0.6))),
          const SizedBox(height: 14),

          // Status / timer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                    decoration: const BoxDecoration(
                        color: _W.hijau, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  isLive
                      ? '${_nikenSpeaking ? "Niken bicara  " : "Mendengarkan  "}${_formatDurasi(_durasiDetik)}'
                      : (_statusMsg.isEmpty ? 'Siap menelepon' : _statusMsg),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _statusTeks(),
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
      _CallState.live       => _W.hijau.withValues(alpha: 0.12),
      _CallState.error      => _W.merah.withValues(alpha: 0.10),
      _CallState.connecting => _W.oranye.withValues(alpha: 0.10),
      _          => _W.kremKartu,
    };
  }

  Color _statusTeks() {
    return switch (_state) {
      _CallState.live       => _W.hijau,
      _CallState.error      => _W.merah,
      _CallState.connecting => _W.oranyeGlp,
      _          => _W.coklat.withValues(alpha: 0.65),
    };
  }

  // ── Kartu Transkrip ───────────────────────────────────────────────────────
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
            const Text('Transkrip',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _W.coklat)),
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

  // ── Panel tombol ──────────────────────────────────────────────────────────
  Widget _panelTombol() {
    final bool isLive = _state == _CallState.live;
    final bool isConn = _state == _CallState.connecting;
    final bool busy   = isLive || isConn;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _W.garis)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Tombol mulai / hangup
          _tombolBulat(
            ikon: isLive ? Icons.call_end_rounded : Icons.call_rounded,
            warna: isLive ? _W.merah : _W.hijau,
            label: isLive
                ? 'Akhiri'
                : (isConn ? 'Menghubungi…' : 'Mulai'),
            onTap: busy
                ? (isLive ? _akhiriPanggilan : null)
                : _mulaiPanggilan,
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
              color: onTap != null
                  ? warna
                  : warna.withValues(alpha: 0.4),
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
}
