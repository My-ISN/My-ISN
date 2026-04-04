import 'package:flutter/material.dart';
import '../../services/rent_plan_service.dart';
import '../../localization/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class RentPlanDetailPage extends StatefulWidget {
  final int rentalId;
  final String? invoiceNumber;
  const RentPlanDetailPage({
    super.key,
    required this.rentalId,
    this.invoiceNumber,
  });

  @override
  State<RentPlanDetailPage> createState() => _RentPlanDetailPageState();
}

class _RentPlanDetailPageState extends State<RentPlanDetailPage> {
  final RentPlanService _rentPlanService = RentPlanService();
  bool _isLoading = true;
  String _activeTab = 'OVERVIEW';
  Map<String, dynamic>? _rentalData;
  Map<String, dynamic>? _debtData;

  final List<String> _menuTabs = [
    'OVERVIEW',
    'INVOICE',
    'VIEW_DOKUMEN',
    'PERJANJIAN_SEWA',
  ];

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final response = await _rentPlanService.getRentPlanDetail(widget.rentalId);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _rentalData = response['data']['rental'];
          _debtData = response['data']['debt'];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  'rent_plan.failed_fetch_detail'.tr(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.invoiceNumber ?? 'rent_plan.rental_detail'.tr(context),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (_rentalData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.invoiceNumber ?? 'rent_plan.rental_detail'.tr(context),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: Center(child: Text('rent_plan.data_not_found'.tr(context))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _rentalData!['invoice_number'] ??
              widget.invoiceNumber ??
              'rent_plan.rental_detail'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusProgressCard(),
            const SizedBox(height: 20),
            _buildHorizontalMenu(),
            const SizedBox(height: 16),
            _buildActiveTabContent(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusProgressCard() {
    final double progress =
        double.tryParse(_rentalData!['progress_day_calc']?.toString() ?? '0') ??
        0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'rent_plan.rental_progress'.tr(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: _primaryColor.withOpacity(0.1),
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo(
                'rent_plan.start'.tr(context),
                _rentalData!['invoice_date'] ?? '-',
              ),
              _buildDateInfo(
                'rent_plan.end'.tr(context),
                _rentalData!['tanggal_berakhir'] ?? '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: label == 'rent_plan.start'.tr(context)
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHorizontalMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _menuTabs.map((tab) {
          final bool isActive = _activeTab == tab;

          String label = tab;
          if (tab == 'OVERVIEW') {
            label = 'rent_plan.overview'.tr(context);
          } else if (tab == 'INVOICE')
            label = 'rent_plan.invoice'.tr(context);
          else if (tab == 'VIEW_DOKUMEN')
            label = 'rent_plan.view_document'.tr(context);
          else if (tab == 'PERJANJIAN_SEWA')
            label = 'rent_plan.rental_agreement'.tr(context);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                if (isActive && ['INVOICE', 'PERJANJIAN_SEWA'].contains(tab)) {
                  _launchDocumentUrl(tab);
                } else if (['INVOICE', 'PERJANJIAN_SEWA'].contains(tab)) {
                  _launchDocumentUrl(tab);
                } else {
                  setState(() => _activeTab = tab);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? _primaryColor : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? _primaryColor
                        : Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey[500],
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
    if (tab == 'INVOICE') {
      endpoint = 'invoice';
    } else if (tab == 'PERJANJIAN_SEWA')
      endpoint = 'agreement';

    if (endpoint.isEmpty) return;

    final String secret =
        '${widget.rentalId}foxgeen_mobile_invoice_secret_2024';
    final String token = md5.convert(utf8.encode(secret)).toString();
    final url = Uri.parse(
      'https://foxgeen.com/HRIS/erp/rentals/$endpoint/${widget.rentalId}?token=$token',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'rent_plan.opening'.tr(context)} ${tab.toLowerCase()}',
            ),
          ),
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
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        _buildSectionTitle(
          Icons.laptop_rounded,
          'rent_plan.rental_detail'.tr(context).toUpperCase(),
        ),
        _buildOverviewCard([
          _buildRowTwoFields(
            'LAPTOP',
            _rentalData!['nama_laptop'] ?? '-',
            'INVOICE',
            _rentalData!['invoice_number'] ?? '-',
          ),
          _buildRowTwoFields(
            'rent_plan.unit_count'.tr(context).toUpperCase(),
            '${_rentalData!['total_laptop'] ?? 0} unit',
            'rent_plan.duration'.tr(context).toUpperCase(),
            '${_rentalData!['lama_sewa'] ?? 0} hari',
          ),
          _buildRowTwoFields(
            'rent_plan.start'.tr(context).toUpperCase(),
            _rentalData!['invoice_date'] ?? '-',
            'rent_plan.end'.tr(context).toUpperCase(),
            _rentalData!['tanggal_berakhir'] ?? '-',
          ),
        ]),

        const SizedBox(height: 20),

        _buildSectionTitle(
          Icons.payments_rounded,
          'rent_plan.price_status'.tr(context).toUpperCase(),
        ),
        _buildOverviewCard([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color:
                  (_rentalData!['status_pembayaran'] == 'sudah'
                          ? Colors.green
                          : Colors.red)
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'rent_plan.total_cost'.tr(context).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(
                    double.tryParse(
                          _rentalData!['grand_total']?.toString() ?? '0',
                        ) ??
                        0,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _rentalData!['status_pembayaran'] == 'sudah'
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          _buildRowTwoFields(
            'rent_plan.payment_status'.tr(context).toUpperCase(),
            _rentalData!['status_pembayaran'] == 'sudah'
                ? 'rent_plan.paid'.tr(context)
                : 'rent_plan.unpaid'.tr(context),
            'rent_plan.rental_status'.tr(context).toUpperCase(),
            _getRentalStatusLabel(_rentalData!['status'] ?? '-'),
            valColor1: _rentalData!['status_pembayaran'] == 'sudah'
                ? Colors.green
                : Colors.red,
            valColor2: _getRentalStatusColor(_rentalData!['status'] ?? ''),
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRowTwoFields(
    String label1,
    String val1,
    String label2,
    String val2, {
    Color? valColor1,
    Color? valColor2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label1,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  val1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valColor1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label2,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  val2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valColor2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRentalStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'rent_plan.status_new'.tr(context);
      case 'pending':
        return 'rent_plan.status_pending'.tr(context);
      case 'confirmed':
        return 'rent_plan.status_active'.tr(context);
      case 'masalah':
        return 'rent_plan.status_problem'.tr(context);
      case 'completed':
        return 'rent_plan.status_completed'.tr(context);
      default:
        return status.toUpperCase();
    }
  }

  Color _getRentalStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'masalah':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildViewDokumenTab() {
    final String baseUrl = 'https://foxgeen.com/HRIS/uploads/rentals/';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          Icons.badge_rounded,
          'rent_plan.document'.tr(context).toUpperCase(),
        ),
        _buildDocumentImageCard(
          title: 'rent_plan.customer_ktp'.tr(context).toUpperCase(),
          fileName: _rentalData!['file_ktp'],
          baseUrl: baseUrl,
        ),
      ],
    );
  }

  Widget _buildDocumentImageCard({
    required String title,
    String? fileName,
    required String baseUrl,
  }) {
    if (fileName == null || fileName.isEmpty) return const SizedBox.shrink();

    final String imageUrl = '$baseUrl$fileName';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[50],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
