import 'package:flutter/material.dart';

import '../services/intercom_service.dart';
import '../services/tracking_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';

/// Palet resmi UMKM/ISKOM (rujukan: manageumkm-ci4/warna-umkm.css).
class _Warna {
  static const oranye = Color(0xFFFF9A2E);
  static const krem = Color(0xFFFFF8F2);
  static const kremKartu = Color(0xFFFFF2E6);
  static const coklat = Color(0xFF5F4B3D);
  static const garis = Color(0xFFF0DDC9);
  static const hijau = Color(0xFF10B981);
  static const merah = Color(0xFFEF4444);
}

class _Preset {
  final String kode;
  final String label;
  final IconData ikon;
  final String teks;

  const _Preset(this.kode, this.label, this.ikon, this.teks);
}

const List<_Preset> _daftarPreset = <_Preset>[
  _Preset('malam', 'Malam', Icons.nightlight_round,
      'Selamat malam, kantor sudah selesai beroperasi.'),
  _Preset('pagi', 'Pagi', Icons.wb_sunny_rounded,
      'Selamat pagi, mari kita mulai pekerjaan hari ini.'),
  _Preset('pulang', 'Pulang', Icons.logout_rounded,
      'Waktu kerja selesai, silakan bersiap pulang.'),
  _Preset('tamu', 'Tamu', Icons.person_pin_circle_rounded,
      'Mohon perhatian, ada tamu di ruang depan.'),
  _Preset('kunci', 'Kunci', Icons.lock_rounded,
      'Mohon pastikan pintu dan ruangan sudah dikunci.'),
  _Preset('makan', 'Makan', Icons.restaurant_rounded,
      'Waktu istirahat, silakan makan siang.'),
  _Preset('rapat', 'Rapat', Icons.groups_rounded,
      'Mohon berkumpul di ruang rapat sekarang.'),
];

/// Halaman "Panggil Suara": mengirim kalimat/preset ke endpoint HRIS agar
/// speaker PC kantor yang mengucapkannya (bukan TTS di HP ini).
class IntercomSuaraPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const IntercomSuaraPage({super.key, required this.userData});

  @override
  State<IntercomSuaraPage> createState() => _IntercomSuaraPageState();
}

class _IntercomSuaraPageState extends State<IntercomSuaraPage> {
  final TextEditingController _teksController = TextEditingController();
  final FocusNode _teksFocus = FocusNode();
  final IntercomService _service = IntercomService();

  String? _presetDipilih;
  String _suara = 'gadis';
  bool _mengirim = false;
  IntercomSayResult? _hasilTerakhir;

  @override
  void initState() {
    super.initState();
    try {
      TrackingService().logCurrentFeature('Intercom Suara');
    } catch (_) {
      // Tracking tidak boleh menghalangi pemakaian fitur.
    }
    _teksController.addListener(_saatTeksBerubah);
  }

  @override
  void dispose() {
    _teksController.removeListener(_saatTeksBerubah);
    _teksController.dispose();
    _teksFocus.dispose();
    super.dispose();
  }

  /// Kalau teks diubah manual, pilihan preset dilepas supaya tidak dobel ucap.
  void _saatTeksBerubah() {
    final aktif = _presetDipilih;
    if (aktif == null) return;
    final preset = _presetDariKode(aktif);
    if (preset != null && _teksController.text.trim() != preset.teks) {
      setState(() => _presetDipilih = null);
    }
  }

  _Preset? _presetDariKode(String? kode) {
    if (kode == null) return null;
    for (final p in _daftarPreset) {
      if (p.kode == kode) return p;
    }
    return null;
  }

  void _pilihPreset(_Preset preset) {
    setState(() {
      if (_presetDipilih == preset.kode) {
        _presetDipilih = null;
        _teksController.clear();
      } else {
        _presetDipilih = preset.kode;
        _teksController.text = preset.teks;
        _teksController.selection =
            TextSelection.collapsed(offset: preset.teks.length);
      }
    });
    _teksFocus.unfocus();
  }

  String? get _userId {
    for (final kunci in const ['id', 'user_id', 'sup_user_id']) {
      final nilai = widget.userData[kunci];
      if (nilai != null && nilai.toString().isNotEmpty) return nilai.toString();
    }
    return null;
  }

  Future<void> _kirim() async {
    if (_mengirim) return;

    final teks = _teksController.text.trim();
    if (teks.isEmpty && _presetDipilih == null) {
      _tampilkanPesan('Tulis kalimat atau pilih salah satu preset dulu.',
          gagal: true);
      return;
    }

    final preset = _presetDariKode(_presetDipilih);
    // Kalau teks masih sama dengan bawaan preset, cukup kirim preset saja.
    final kirimPresetSaja = preset != null && teks == preset.teks;

    FocusScope.of(context).unfocus();
    setState(() => _mengirim = true);

    final hasil = await _service.sayToPc(
      text: kirimPresetSaja ? null : teks,
      preset: kirimPresetSaja ? preset.kode : null,
      suara: _suara,
      userId: _userId,
    );

    if (!mounted) return;
    setState(() {
      _mengirim = false;
      _hasilTerakhir = hasil;
    });
    _tampilkanPesan(
      hasil.ok ? (hasil.message.isEmpty ? 'Perintah terkirim.' : hasil.message) : hasil.message,
      gagal: !hasil.ok,
    );
  }

  void _tampilkanPesan(String pesan, {bool gagal = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: gagal ? _Warna.merah : _Warna.hijau,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Warna.krem,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: Navigator.canPop(context),
        title: 'Panggil Suara',
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Ucapkan di speaker PC kantor',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _Warna.coklat.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
      endDrawer: widget.userData.isNotEmpty
          ? SideDrawer(
              userData: widget.userData,
              activePage: 'intercom_suara',
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _bannerPeringatan(),
            const SizedBox(height: 16),
            _kartuTeks(),
            const SizedBox(height: 14),
            _kartuPreset(),
            const SizedBox(height: 14),
            _kartuSuara(),
            const SizedBox(height: 18),
            _tombolUtama(),
            const SizedBox(height: 16),
            _kartuStatus(),
            const SizedBox(height: 12),
            Text(
              'Perintah ini diucapkan oleh speaker PC kantor, bukan dari HP ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: _Warna.coklat.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerPeringatan() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _Warna.kremKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Warna.oranye.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _Warna.oranye.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _Warna.oranye, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PC kantor harus menyala',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _Warna.coklat,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Kalimat hanya akan terdengar bila PC kantor dan speakernya aktif.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: _Warna.coklat.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuTeks() {
    return _kartu(
      judul: 'Tulis kalimat',
      ikon: Icons.edit_note_rounded,
      anak: TextField(
        controller: _teksController,
        focusNode: _teksFocus,
        maxLength: 200,
        maxLines: 4,
        minLines: 3,
        cursorColor: _Warna.oranye,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(fontSize: 14.5, height: 1.45, color: _Warna.coklat),
        decoration: InputDecoration(
          hintText: 'Contoh: Mohon berkumpul di ruang rapat sekarang.',
          hintStyle: TextStyle(
            fontSize: 13,
            color: _Warna.coklat.withValues(alpha: 0.42),
          ),
          filled: true,
          fillColor: Colors.white,
          counterStyle: TextStyle(
            fontSize: 11,
            color: _Warna.coklat.withValues(alpha: 0.55),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _Warna.garis),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _Warna.oranye, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _kartuPreset() {
    return _kartu(
      judul: 'Preset cepat',
      ikon: Icons.bolt_rounded,
      anak: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _daftarPreset.map((preset) {
          final aktif = _presetDipilih == preset.kode;
          return ChoiceChip(
            selected: aktif,
            showCheckmark: false,
            onSelected: (_) => _pilihPreset(preset),
            avatar: Icon(
              preset.ikon,
              size: 17,
              color: aktif ? _Warna.oranye : _Warna.coklat.withValues(alpha: 0.65),
            ),
            label: Text(preset.label),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
              color: aktif ? _Warna.coklat : _Warna.coklat.withValues(alpha: 0.8),
            ),
            backgroundColor: Colors.white,
            selectedColor: _Warna.oranye.withValues(alpha: 0.18),
            side: BorderSide(
              color: aktif ? _Warna.oranye : _Warna.garis,
              width: aktif ? 1.4 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          );
        }).toList(),
      ),
    );
  }

  Widget _kartuSuara() {
    return _kartu(
      judul: 'Pilih suara',
      ikon: Icons.record_voice_over_rounded,
      anak: Row(
        children: [
          Expanded(
            child: _opsiSuara(
              kode: 'gadis',
              label: 'Wanita',
              ikon: Icons.face_3_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _opsiSuara(
              kode: 'ardi',
              label: 'Pria',
              ikon: Icons.face_6_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _opsiSuara({
    required String kode,
    required String label,
    required IconData ikon,
  }) {
    final aktif = _suara == kode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _suara = kode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: aktif ? _Warna.oranye.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: aktif ? _Warna.oranye : _Warna.garis,
            width: aktif ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ikon,
              size: 20,
              color: aktif ? _Warna.oranye : _Warna.coklat.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                color: _Warna.coklat,
              ),
            ),
            const Spacer(),
            if (aktif)
              const Icon(Icons.check_circle_rounded,
                  size: 17, color: _Warna.oranye),
          ],
        ),
      ),
    );
  }

  Widget _tombolUtama() {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _mengirim ? null : _kirim,
        style: ElevatedButton.styleFrom(
          backgroundColor: _Warna.oranye,
          disabledBackgroundColor: _Warna.oranye.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _mengirim
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Mengirim…',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_rounded, size: 21),
                  SizedBox(width: 9),
                  Text(
                    'Ucapkan Sekarang',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _kartuStatus() {
    final hasil = _hasilTerakhir;
    final sukses = hasil?.ok ?? false;
    final warnaAksen = hasil == null
        ? _Warna.garis
        : (sukses ? _Warna.hijau : _Warna.merah);

    final String ringkas;
    if (hasil == null) {
      ringkas = 'Belum ada perintah dikirim';
    } else {
      final jam = '${hasil.at.hour.toString().padLeft(2, '0')}:'
          '${hasil.at.minute.toString().padLeft(2, '0')}';
      final bagian = <String>[
        sukses ? 'Terkirim' : 'Gagal',
        if (sukses && hasil.playLabel.isNotEmpty) hasil.playLabel,
        jam,
      ];
      ringkas = bagian.join(' • ');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: warnaAksen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Status terakhir',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _Warna.coklat.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            ringkas,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: hasil == null
                  ? _Warna.coklat.withValues(alpha: 0.55)
                  : _Warna.coklat,
            ),
          ),
          if (hasil != null && hasil.message.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              hasil.message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: sukses
                    ? _Warna.coklat.withValues(alpha: 0.7)
                    : _Warna.merah,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartu({
    required String judul,
    required IconData ikon,
    required Widget anak,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 18, color: _Warna.oranye),
              const SizedBox(width: 7),
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _Warna.coklat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          anak,
        ],
      ),
    );
  }
}
