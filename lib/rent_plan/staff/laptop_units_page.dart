import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/rent_plan_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/side_drawer.dart';
import 'scan_verify_barcode_page.dart';

class LaptopUnitsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const LaptopUnitsPage({super.key, required this.userData});

  @override
  State<LaptopUnitsPage> createState() => _LaptopUnitsPageState();
}

class _LaptopUnitsPageState extends State<LaptopUnitsPage> {
  final _service = RentPlanService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _groupedModels = [];
  final Set<String> _expandedLaptopIds = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  static const int _limit = 20;
  Timer? _debounce;

  bool _hasPermission(String key) {
    if (widget.userData['user_type'] == 'company') return true;
    final List<String> permissions = (widget.userData['role_resources'] ?? '')
        .toString()
        .split(',');
    return permissions.contains(key);
  }

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreUnits();
    }
  }

  void _groupUnits() {
    final Map<String, Map<String, dynamic>> groups = {};
    for (var unit in _units) {
      final laptopId = unit['laptop_id']?.toString() ?? 'unknown';
      if (!groups.containsKey(laptopId)) {
        groups[laptopId] = {
          'laptop_id': laptopId,
          'nama_laptop': unit['nama_laptop'] ?? 'Unknown Model',
          'kode_laptop': unit['kode_laptop'] ?? '-',
          'total': 0,
          'tersedia': 0,
          'disewa': 0,
          'rusak': 0,
          'units': <Map<String, dynamic>>[],
        };
      }
      final group = groups[laptopId]!;
      (group['units'] as List<Map<String, dynamic>>).add(unit);
      group['total'] = (group['total'] as int) + 1;
      
      final status = (unit['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'tersedia') {
        group['tersedia'] = (group['tersedia'] as int) + 1;
      } else if (status == 'disewa') {
        group['disewa'] = (group['disewa'] as int) + 1;
      } else if (status == 'rusak') {
        group['rusak'] = (group['rusak'] as int) + 1;
      }
    }
    setState(() {
      _groupedModels = groups.values.toList();
    });
  }

  Future<void> _loadUnits({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _units = [];
        _hasMore = true;
      });
    }
    final res = await _service.getLaptopUnits(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      limit: _limit,
      offset: 0,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == true) {
          final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _units = list;
          _total = res['total'] ?? 0;
          _hasMore = list.length >= _limit;
          _groupUnits();
        } else {
          context.showErrorSnackBar(
            res['message'] ?? 'Gagal mengambil data unit laptop',
          );
        }
      });
    }
  }

  Future<void> _loadMoreUnits() async {
    setState(() => _isLoadingMore = true);
    final res = await _service.getLaptopUnits(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      limit: _limit,
      offset: _units.length,
    );
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (res['status'] == true) {
          final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _units.addAll(list);
          _hasMore = list.length >= _limit;
          _groupUnits();
        } else {
          context.showErrorSnackBar(
            res['message'] ?? 'Gagal mengambil data unit laptop',
          );
        }
      });
    }
  }

  Future<void> _openScanPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScanVerifyBarcodePage()),
    );
    if (result == true) {
      _loadUnits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'laptop_units'),
      body: Column(
        children: [
          _buildPremiumSearchBar(primaryColor),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _groupedModels.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadUnits(reset: true),
                        color: primaryColor,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _groupedModels.length + 1,
                          itemBuilder: (context, index) {
                            if (index >= _groupedModels.length) {
                              return _isLoadingMore
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: primaryColor),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            return _buildModelCard(_groupedModels[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _hasPermission('mobile_laptop_unit_add')
          ? FloatingActionButton.extended(
              onPressed: _openScanPage,
              backgroundColor: primaryColor,
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              label: const Text(
                'Scan Barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPremiumSearchBar(Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Theme.of(context).dividerColor.withValues(alpha: 0.08),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                _loadUnits(reset: true);
              }
            });
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Cari barcode, SN, atau nama laptop...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadUnits(reset: true);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.laptop_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Tidak ada unit laptop',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _hasPermission('mobile_laptop_unit_add')
                  ? 'Scan barcode untuk menambah atau\nverifikasi unit laptop'
                  : 'Gunakan kolom pencarian di atas untuk mencari unit laptop',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
            ),
            if (_hasPermission('mobile_laptop_unit_add')) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openScanPage,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan Barcode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(Map<String, dynamic> group) {
    final laptopId = group['laptop_id'];
    final isExpanded = _expandedLaptopIds.contains(laptopId);
    final units = group['units'] as List<Map<String, dynamic>>;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2026) : Theme.of(context).cardColor;
    final nestedBg = isDark ? const Color(0xFF15171C) : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header (Tappable to expand) ──
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedLaptopIds.remove(laptopId);
                } else {
                  _expandedLaptopIds.add(laptopId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.laptop_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['nama_laptop'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          group['kode_laptop'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Stat Badges Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _statBadge('${group['total']} Unit', const Color(0xFF7E57C2)),
                            _statBadge('${group['tersedia']} Tersedia', const Color(0xFF2ED8B6)),
                            _statBadge('${group['disewa']} Disewa', const Color(0xFF00BCD4)),
                            _statBadge('${group['rusak']} Rusak', const Color(0xFFFF5376)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Expanded Detail List ──
          if (isExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.06) : Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            Container(
              decoration: BoxDecoration(
                color: nestedBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: units.map((unit) => _buildUnitItem(unit)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUnitItem(Map<String, dynamic> unit) {
    final isVerified = unit['verified'] == 1 || unit['verified'] == '1';
    final status = unit['status'] ?? 'Tersedia';
    final kondisi = unit['kondisi'] ?? 'Baru';

    Color statusColor;
    switch (status) {
      case 'Disewa':
        statusColor = const Color(0xFF00BCD4);
        break;
      case 'Rusak':
        statusColor = const Color(0xFFFF5376);
        break;
      default:
        statusColor = const Color(0xFF2ED8B6);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Barcode: ${unit['barcode'] ?? '-'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              _verifiedChip(isVerified),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'SN: ${unit['serial_number'] ?? '-'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
          if (unit['catatan'] != null && unit['catatan'].toString().trim().isNotEmpty && unit['catatan'] != '--') ...[
            const SizedBox(height: 2),
            Text(
              'Catatan: ${unit['catatan']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _chip(status, statusColor),
              const SizedBox(width: 6),
              _chip(kondisi, kondisi == 'Baru' ? Colors.green : Colors.orange),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.04) : Theme.of(context).dividerColor.withValues(alpha: 0.05)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _verifiedChip(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.help_outline_rounded,
            size: 10,
            color: isVerified ? Colors.green.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 3),
          Text(
            isVerified ? 'Verified' : 'Belum Verifikasi',
            style: TextStyle(
                color: isVerified ? Colors.green.shade700 : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
