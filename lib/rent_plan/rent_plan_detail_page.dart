import 'package:flutter/material.dart';
import '../services/rent_plan_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';


class RentPlanDetailPage extends StatefulWidget {
  final int rentalId;
  final String? invoiceNumber;
  const RentPlanDetailPage({super.key, required this.rentalId, this.invoiceNumber});

  @override
  State<RentPlanDetailPage> createState() => _RentPlanDetailPageState();
}

class _RentPlanDetailPageState extends State<RentPlanDetailPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  bool _isLoading = true;
  bool _isExpanded = false;
  String _activeTab = 'OVERVIEW';
  Map<String, dynamic>? _rentalData;
  Map<String, dynamic>? _debtData;
  final Map<String, DateTime> _lastUpdateTimes = {};

  final List<String> _menuTabs = [
    'OVERVIEW', 'EDIT', 'RENTAL EXTEND', 'INVOICE', 'VIEW DOKUMEN', 
    'HANDOVER', 'PERJANJIAN SEWA', 'SP-1', 'SP-3 / SOMASI', 'HUTANG'
  ];

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final response = await _rentPlanService.getRentPlanDetail(widget.rentalId);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _rentalData = response['data']['rental'];
          _debtData = response['data']['debt'];
          if (!silent) _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        if (!silent) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal mengambil detail')),
        );
      }
    }
  }

  Future<void> _updateStatus(String field, dynamic value) async {
    // Rate Limiting: Minimal 2 detik antar request untuk field yang sama
    final now = DateTime.now();
    if (_lastUpdateTimes.containsKey(field)) {
      final lastUpdate = _lastUpdateTimes[field]!;
      if (now.difference(lastUpdate).inSeconds < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mohon tunggu sebentar...'), duration: Duration(seconds: 1)),
        );
        return;
      }
    }
    _lastUpdateTimes[field] = now;

    // Optimistic UI: Update state secara lokal dulu
    final originalValue = _rentalData![field];
    setState(() {
      _rentalData![field] = value;
    });

    final response = await _rentPlanService.updateRentPlanStatus(widget.rentalId, field, value);
    if (response['status'] == true) {
      // Refresh data di background untuk memastikan sinkronisasi
      _fetchDetail(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status berhasil diperbarui'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
        );
      }
    } else {
      // Rollback jika gagal
      setState(() {
        _rentalData![field] = originalValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal memperbarui status'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.invoiceNumber ?? 'Detail Rental', style: const TextStyle(fontSize: 16))),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_rentalData == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.invoiceNumber ?? 'Detail Rental', style: const TextStyle(fontSize: 16))),
        body: const Center(child: Text('Data tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_rentalData!['invoice_number'] ?? widget.invoiceNumber ?? 'Detail Rental', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCombinedControlCard(),
            const SizedBox(height: 20),
            _buildHorizontalMenu(),
            const SizedBox(height: 16),
            _buildActiveTabContent(),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _menuTabs.map((tab) {
          final bool isActive = _activeTab == tab;
          final bool isHutang = tab == 'HUTANG';
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () async {
                if (['INVOICE', 'PERJANJIAN SEWA', 'SP-1', 'SP-3 / SOMASI'].contains(tab)) {
                  _launchDocumentUrl(tab);
                } else {
                  setState(() => _activeTab = tab);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isHutang 
                    ? (isActive ? Colors.red : Colors.red.withOpacity(0.1))
                    : (isActive ? _primaryColor : Theme.of(context).cardColor),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHutang 
                      ? Colors.red 
                      : (isActive ? _primaryColor : Theme.of(context).dividerColor.withOpacity(0.1))
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? Colors.white : (isHutang ? Colors.red : Colors.grey[500]),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _launchDocumentUrl(String tab) async {
    String endpoint = '';
    switch (tab) {
      case 'INVOICE':
        endpoint = 'invoice';
        break;
      case 'VIEW DOKUMEN':
        endpoint = 'ktp';
        break;
      case 'PERJANJIAN SEWA':
        endpoint = 'agreement';
        break;
      case 'SP-1':
        endpoint = 'sp1';
        break;
      case 'SP-3 / SOMASI':
        endpoint = 'sp3';
        break;
      case 'HANDOVER':
        endpoint = 'handover';
        break;
    }

    if (endpoint.isEmpty) return;

    final String secret = '${widget.rentalId}foxgeen_mobile_invoice_secret_2024';
    final String token = md5.convert(utf8.encode(secret)).toString();
    final url = Uri.parse('https://foxgeen.com/HRIS/erp/rentals/$endpoint/${widget.rentalId}?token=$token');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka ${tab.toLowerCase()}')),
        );
      }
    }
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'OVERVIEW':
        return _buildOverviewTab();
      case 'VIEW DOKUMEN':
        return _buildViewDokumenTab();
      case 'HANDOVER':
      case 'HUTANG':
        // Update: Sementara buat jadi konten dalam pengembangan
        return _buildPlaceholderTab();
      default:
        return _buildPlaceholderTab();
    }
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isPerusahaan = _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';

    return Column(
      children: [
        // 1. Identitas Penyewa
        _buildSectionTitle(Icons.person_pin_rounded, 'IDENTITAS PENYEWA'),
        _buildOverviewCard([
          _buildRowTwoFields(
            isPerusahaan ? 'NAMA PERUSAHAAN' : 'NAMA PELANGGAN', 
            _rentalData!['first_name'] ?? _rentalData!['nama_pribadi'] ?? _rentalData!['nama_perusahaan'] ?? '-',
            isPerusahaan ? 'NPWP' : 'NIK', 
            _rentalData!['npwp'] ?? _rentalData!['nik'] ?? '-'
          ),
          _buildRowTwoFields(
            'WHATSAPP', 
            _rentalData!['whatsapp'] ?? _rentalData!['renter_contact'] ?? '-',
            '', ''
          ),
          _buildRowTwoFields(
            'ALAMAT KTP', 
            _rentalData!['alamat_ktp_formatted'] ?? _rentalData!['alamat_ktp'] ?? '-',
            'ALAMAT DOMISILI', 
            _rentalData!['alamat_current_formatted'] ?? _rentalData!['alamat_domisili'] ?? _rentalData!['alamat_instansi'] ?? '-'
          ),
        ]),

        const SizedBox(height: 20),

        // 2. Detail Sewa
        _buildSectionTitle(Icons.laptop_rounded, 'DETAIL SEWA'),
        _buildOverviewCard([
          _buildRowTwoFields(
            'LAPTOP', 
            _rentalData!['nama_laptop'] ?? _rentalData!['laptop_name'] ?? _rentalData!['item_name'] ?? '-',
            'INVOICE NUMBER', 
            _rentalData!['invoice_number'] ?? '-'
          ),
          _buildRowTwoFields(
            'JENIS PENYEWA', 
            (_rentalData!['jenis_sewa']?.toString() ?? '-').toUpperCase(),
            'TANGGAL MULAI', 
            _rentalData!['invoice_date'] ?? '-'
          ),
          _buildRowTwoFields(
            'TANGGAL SELESAI', 
            _rentalData!['tanggal_berakhir'] ?? '-',
            'JUMLAH UNIT', 
            '${_rentalData!['total_laptop'] ?? 0} unit'
          ),
          _buildRowTwoFields(
            'DURASI', 
            '${_rentalData!['lama_sewa'] ?? 0} hari',
            '', ''
          ),
        ]),

        const SizedBox(height: 20),

          // 3. Harga & Status
        _buildSectionTitle(Icons.monetization_on_rounded, 'HARGA & STATUS'),
        _buildOverviewCard([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _rentalData!['status_pembayaran'] == 'sudah'
                  ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                  : [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _rentalData!['status_pembayaran'] == 'sudah'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2)
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL BIAYA', 
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Text(currencyFormat.format(double.tryParse(_rentalData!['grand_total']?.toString() ?? '0') ?? 0), 
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w900, 
                        color: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red,
                        letterSpacing: -0.5,
                      )),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _rentalData!['status_pembayaran'] == 'sudah' ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          _buildRowTwoFields(
            'STATUS PEMBAYARAN', 
            _rentalData!['status_pembayaran'] == 'sudah' ? 'Lunas' : 'Belum Bayar',
            'STATUS DENDA', 
            _rentalData!['status_denda'] == 'yes' ? 'Denda' : 'Aman',
            valColor1: _rentalData!['status_pembayaran'] == 'sudah' ? Colors.green : Colors.orange,
            valColor2: _rentalData!['status_denda'] == 'yes' ? Colors.red : Colors.green
          ),
          _buildRowTwoFields(
            'STATUS APPROVAL', 
            (_rentalData!['status_approve'] ?? '-').toUpperCase(),
            'STATUS RENTAL', 
            _getRentalStatusLabel(_rentalData!['status'] ?? '-'),
            valColor1: _rentalData!['status_approve'] == 'disetujui' ? Colors.green : Colors.orange,
            valColor2: _getRentalStatusColor(_rentalData!['status'] ?? '')
          ),
        ]),
      ],
    );
  }


  Widget _buildPlaceholderTab() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.construction_rounded, size: 64, color: Theme.of(context).dividerColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('Konten Tab $_activeTab sedang dalam pengembangan', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRowTwoFields(String label1, String val1, String label2, String val2, {Color? valColor1, Color? valColor2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(val1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valColor1)),
              ],
            ),
          ),
          if (label2.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label2, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(val2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valColor2)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getRentalStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new': return 'New';
      case 'pending': return 'Pending';
      case 'confirmed': return 'Aktif';
      case 'masalah': return 'Masalah';
      case 'completed': return 'Selesai';
      default: return status.toUpperCase();
    }
  }

  Color _getRentalStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new': return Colors.blue;
      case 'confirmed':
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'masalah': return Colors.red;
      case 'completed': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildCombinedControlCard() {
    final double progress = double.tryParse(_rentalData!['progress_day_calc']?.toString() ?? '0') ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(top: const Radius.circular(20), bottom: Radius.circular(_isExpanded ? 0 : 20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progres Masa Sewa', 
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      Row(
                        children: [
                          Text('${progress.toStringAsFixed(0)}%', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                          const SizedBox(width: 8),
                          Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
                            color: Colors.grey[500]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 12,
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDateInfo('Mulai', _rentalData!['invoice_date'] ?? '-'),
                      _buildDateInfo('Berakhir', _rentalData!['tanggal_berakhir'] ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Pembayaran', 
                  _rentalData!['status_pembayaran'] == 'sudah' ? 'Lunas' : 'Belum Bayar',
                  _rentalData!['status_pembayaran'] == 'sudah',
                  Icons.account_balance_wallet_rounded,
                  Colors.green,
                  (val) => _updateStatus('status_pembayaran', val ? 'sudah' : 'belum')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Denda', 
                  _rentalData!['status_denda'] == 'yes' ? 'Kena Denda' : 'Aman',
                  _rentalData!['status_denda'] == 'yes',
                  Icons.report_problem_rounded,
                  Colors.red,
                  (val) => _updateStatus('status_denda', val ? 'yes' : 'no')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildStatusItem(
                  'Status Approve', 
                  _rentalData!['status_approve'] == 'disetujui' ? 'Disetujui' : 'Pending',
                  _rentalData!['status_approve'] == 'disetujui',
                  Icons.verified_user_rounded,
                  Colors.blue,
                  (val) => _updateStatus('status_approve', val ? 'disetujui' : 'pending')
                ),
                Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildMultiChoiceStatus(),
                const SizedBox(height: 8),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: label == 'Mulai' ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusItem(String title, String subtitle, bool value, IconData icon, Color color, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: value ? color : Colors.grey[500])),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }

  Widget _buildMultiChoiceStatus() {
    final String currentStatus = (_rentalData!['status'] ?? 'new').toLowerCase();
    final List<Map<String, dynamic>> statusOptions = [
      {'val': 'new', 'label': 'New', 'icon': Icons.star_border_rounded, 'color': Colors.blue},
      {'val': 'pending', 'label': 'Pending', 'icon': Icons.timer_outlined, 'color': Colors.orange},
      {'val': 'confirmed', 'label': 'Aktif', 'icon': Icons.bolt_rounded, 'color': Colors.green},
      {'val': 'masalah', 'label': 'Masalah', 'icon': Icons.report_problem_outlined, 'color': Colors.red},
      {'val': 'completed', 'label': 'Selesai', 'icon': Icons.check_circle_outline_rounded, 'color': Colors.purple},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_rounded, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Status Rental', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusOptions.map((opt) {
              final bool isSelected = currentStatus == opt['val'];
              final Color color = opt['color'];
              
              return InkWell(
                onTap: () => _updateStatus('status', opt['val']),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt['icon'], size: 16, color: isSelected ? color : Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        opt['label'],
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewDokumenTab() {
    final isPerusahaan = _rentalData!['jenis_sewa']?.toString().toLowerCase() == 'perusahaan';
    final String baseUrl = 'https://foxgeen.com/HRIS/uploads/rentals/';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.badge_rounded, 'DOKUMEN IDENTITAS'),
        
        // KTP Image Card
        _buildDocumentImageCard(
          title: isPerusahaan ? 'KTP PERUSAHAAN / PENANGGUNG JAWAB' : 'KTP PELANGGAN',
          fileName: _rentalData!['file_ktp'],
          baseUrl: baseUrl,
        ),
        
        if (isPerusahaan) ...[
          const SizedBox(height: 16),
          _buildDocumentImageCard(
            title: 'NPWP PERUSAHAAN',
            fileName: _rentalData!['file_npwp'],
            baseUrl: baseUrl,
          ),
          const SizedBox(height: 16),
          _buildDocumentImageCard(
            title: 'PURCHASE ORDER (PO)',
            fileName: _rentalData!['file_po'],
            baseUrl: baseUrl,
          ),
        ],

        const SizedBox(height: 24),
        _buildSectionTitle(Icons.location_on_rounded, 'ALAMAT TERDAFTAR'),
        _buildOverviewCard([
          _buildAddressRow('ALAMAT KTP', _rentalData!['alamat_ktp_formatted'] ?? _rentalData!['alamat_ktp'] ?? '-'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildAddressRow('ALAMAT DOMISILI / SEKARANG', _rentalData!['alamat_current_formatted'] ?? _rentalData!['alamat_domisili'] ?? '-'),
        ]),
      ],
    );
  }

  Widget _buildDocumentImageCard({required String title, String? fileName, required String baseUrl}) {
    if (fileName == null || fileName.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.no_photography_outlined, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Text('Dokumen $title tidak tersedia', 
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final String imageUrl = '$baseUrl$fileName';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                Text('ZOOM ENABLED', style: TextStyle(fontSize: 8, color: _primaryColor.withOpacity(0.6), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              height: 180, // Fixed height to prevent being too large
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.contain, // Contain keeps aspect ratio within 180 height
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[50],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[50],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: Colors.red, size: 30),
                          const SizedBox(height: 6),
                          Text('Gagal memuat gambar', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
      ],
    );
  }
}

