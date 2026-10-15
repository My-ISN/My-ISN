import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_localizations.dart';
import '../services/handoff_service.dart';
import '../services/tracking_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/secondary_app_bar.dart';

/// Halaman "Pesan Perlu Dibalas" — antrean nomor yang menunggu dibalas staf.
///
/// Hak akses TIDAK ditentukan di sisi aplikasi: halaman ini menampilkan apa pun
/// yang dijawab server (`akses` pada GET handoff-antrean). Bila server menjawab
/// `akses: false` (staf tidak punya menu rent_plan), halaman menampilkan pesan
/// tanpa daftar.
class PesanPerluDibalasPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PesanPerluDibalasPage({super.key, required this.userData});

  @override
  State<PesanPerluDibalasPage> createState() => _PesanPerluDibalasPageState();
}

class _PesanPerluDibalasPageState extends State<PesanPerluDibalasPage> {
  static const Color _primary = Color(0xFFFF9A2E);
  static const Color _garisKrem = Color(0xFFF0DDC9);

  final HandoffService _service = HandoffService();

  bool _isLoading = true;
  bool _akses = false;
  bool _responsValid = false;
  bool _demo = false;
  String? _galat;
  List<HandoffItem> _items = [];
  final Set<String> _sedangProses = <String>{};

  @override
  void initState() {
    super.initState();
    try {
      TrackingService().logCurrentFeature('Pesan Perlu Dibalas');
    } catch (_) {}
    _muat();
  }

  Future<void> _muat() async {
    if (mounted) setState(() => _isLoading = true);
    final HandoffRingkasan hasil = await _service.getAntrean();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _akses = hasil.akses;
      _responsValid = hasil.responsValid;
      _demo = hasil.demo;
      _items = hasil.items;
      _galat = hasil.akses ? null : hasil.pesan;
    });
    // Badge menu mengikuti jawaban server — tidak ada daftar staf di app.
    NotificationManager().setHandoffCount(hasil.jumlah, akses: hasil.akses);
  }

  /// 08xx / +62xx / 62xx → 62xxxxxxxxxx (digit saja).
  String _nomorBersih(String nomor) {
    String digit = nomor.replaceAll(RegExp(r'[^0-9]'), '');
    if (digit.startsWith('0')) {
      digit = '62${digit.substring(1)}';
    } else if (!digit.startsWith('62') && digit.startsWith('8')) {
      digit = '62$digit';
    }
    return digit;
  }

  String _formatWaktu(BuildContext context, DateTime? waktu) {
    if (waktu == null) return 'handoff.waktu_kosong'.tr(context);
    final DateTime lokal = waktu.toLocal();
    final DateTime sekarang = DateTime.now();
    final bool hariIni = lokal.year == sekarang.year &&
        lokal.month == sekarang.month &&
        lokal.day == sekarang.day;
    if (hariIni) return DateFormat('HH:mm').format(lokal);
    final String kodeLocale =
        Localizations.localeOf(context).languageCode == 'id' ? 'id_ID' : 'en_US';
    return DateFormat('dd MMM HH:mm', kodeLocale).format(lokal);
  }

  Future<void> _bukaWhatsApp(HandoffItem item) async {
    final String nomor = _nomorBersih(item.nomor);
    if (nomor.isEmpty) {
      context.showErrorSnackBar('handoff.nomor_kosong'.tr(context));
      return;
    }

    final Uri waAppUri = Uri.parse('whatsapp://send?phone=$nomor');
    final Uri waWebUri = Uri.parse('https://wa.me/$nomor');

    try {
      if (await canLaunchUrl(waAppUri)) {
        await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!mounted) return;
      context.showErrorSnackBar('handoff.wa_gagal'.tr(context));
    }
  }

  Future<void> _tandaiSelesai(HandoffItem item) async {
    setState(() => _sedangProses.add(item.id));
    final Map<String, dynamic> hasil = await _service.tandaiSelesai(id: item.id);
    if (!mounted) return;
    setState(() => _sedangProses.remove(item.id));

    if (hasil['status'] == true) {
      setState(() {
        _items = _items.where((e) => e.id != item.id).toList();
      });
      NotificationManager().setHandoffCount(_items.length, akses: _akses);
      context.showSuccessSnackBar('handoff.tandai_berhasil'.tr(context));
    } else {
      context.showErrorSnackBar(
        'handoff.tandai_gagal'.tr(context, args: {
          'error': (hasil['message'] ?? '-').toString(),
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title: 'handoff.title'.tr(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'handoff.muat_ulang'.tr(context),
            onPressed: _isLoading ? null : _muat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_demo) _buildBannerDemo(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBannerDemo(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'handoff.banner_demo'.tr(context),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F4B3D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_responsValid) return _buildGalat(context);
    if (!_akses) return _buildTanpaAkses(context);
    if (_items.isEmpty) return _buildKosong(context);

    return RefreshIndicator(
      onRefresh: _muat,
      color: _primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildKartu(context, _items[index]),
      ),
    );
  }

  Widget _buildKartu(BuildContext context, HandoffItem item) {
    final bool sedangProses = _sedangProses.contains(item.id);
    final String namaTrim = item.nama.trim();
    final String inisial = namaTrim.isNotEmpty
        ? namaTrim.substring(0, 1).toUpperCase()
        : '#';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : _garisKrem.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    inisial,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama.trim().isNotEmpty ? item.nama : item.nomor,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.nomor,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatWaktu(context, item.waktu),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                item.pesan.trim().isNotEmpty
                    ? '"${item.pesan.trim()}"'
                    : 'handoff.kutipan_kosong'.tr(context),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontStyle:
                      item.pesan.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'handoff.belum_dibalas'.tr(context, args: {
                      'count': item.belumDibalas.toString(),
                    }),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: sedangProses ? null : () => _tandaiSelesai(item),
                  icon: sedangProses
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(
                    'handoff.tandai'.tr(context),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F4B3D),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _bukaWhatsApp(item),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text(
                    'handoff.buka_wa'.tr(context),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKosong(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      color: _primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_chat_read_rounded,
                  size: 80,
                  color: _primary.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'handoff.kosong_judul'.tr(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'handoff.kosong_hint'.tr(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanpaAkses(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'handoff.akses_judul'.tr(context),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'handoff.akses_hint'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalat(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'handoff.galat_judul'.tr(context),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _galat ?? 'handoff.galat_hint'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _muat,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('handoff.coba_lagi'.tr(context)),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
