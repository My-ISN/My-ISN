import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/approval_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';

class ApprovalHubPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ApprovalHubPage({
    super.key,
    required this.userData,
  });

  @override
  State<ApprovalHubPage> createState() => _ApprovalHubPageState();
}

class _ApprovalHubPageState extends State<ApprovalHubPage>
    with SingleTickerProviderStateMixin {
  final ApprovalService _service = ApprovalService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  String? _processingApprovalId;

  List<ApprovalItem> _pendingList = [];
  List<ApprovalItem> _selesaiList = [];
  int _totalPendingCount = 0;

  static const Color _iskomOrange = Color(0xFFFF9A2E);
  static const Color _btnAccGreen = Color(0xFF10B981);
  static const Color _btnRejectRed = Color(0xFFEF4444);

  int get _userId {
    final raw = widget.userData['user_id'] ?? widget.userData['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  bool get _isSuperAdmin {
    final String userType =
        (widget.userData['user_type'] ?? '').toString().toLowerCase();
    final String roleName =
        (widget.userData['role_name'] ?? '').toString().toLowerCase();
    final dynamic roleId = widget.userData['user_role_id'];
    return userType == 'super_user' ||
        userType == 'company' ||
        userType == 'superadmin' ||
        userType == 'super_admin' ||
        roleName.contains('super admin') ||
        roleId == 1 ||
        roleId == '1';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadApprovals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovals({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final res = await _service.getApprovals(userId: _userId, all: true);
      if (!mounted) return;

      if (res.status) {
        setState(() {
          _pendingList = res.pending;
          _selesaiList = res.selesai;
          _totalPendingCount = res.totalPending > 0
              ? res.totalPending
              : res.pendingCount;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = res.message ?? 'Gagal memuat daftar persetujuan.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  List<ApprovalItem> _filterList(List<ApprovalItem> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((item) {
      final id = item.approvalId.toLowerCase();
      final agent = item.displayAgent.toLowerCase();
      final task = item.task.toLowerCase();
      final summary = item.summary.toLowerCase();
      final cat = item.category.toLowerCase();
      final divisi = (item.divisi ?? '').toLowerCase();
      final kepala = (item.kepala ?? '').toLowerCase();

      return id.contains(query) ||
          agent.contains(query) ||
          task.contains(query) ||
          summary.contains(query) ||
          cat.contains(query) ||
          divisi.contains(query) ||
          kepala.contains(query);
    }).toList();
  }

  Future<void> _handleDecision(
    ApprovalItem item,
    String decision, {
    String? reason,
  }) async {
    setState(() {
      _processingApprovalId = item.approvalId;
    });

    try {
      final res = await _service.decide(
        userId: _userId,
        approvalId: item.approvalId,
        decision: decision,
        reason: reason,
      );

      if (!mounted) return;

      if (res['status'] == true) {
        final actionText = decision == 'APPROVED' ? 'disetujui' : 'ditolak';
        context.showSuccessSnackBar(
          'Tiket ${item.approvalId} berhasil $actionText.',
        );
        await _loadApprovals(silent: true);
      } else {
        context.showErrorSnackBar(
          res['message'] ?? 'Gagal memproses keputusan.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Gagal memproses keputusan: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingApprovalId = null;
        });
      }
    }
  }

  void _showConfirmDialog(ApprovalItem item, String decision) {
    final bool isApproved = decision == 'APPROVED';
    final TextEditingController reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2026) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isApproved ? _btnAccGreen : _btnRejectRed)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: isApproved ? _btnAccGreen : _btnRejectRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isApproved
                      ? 'Konfirmasi Setujui (ACC)'
                      : 'Konfirmasi Tolak',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isApproved
                      ? 'Apakah Anda yakin ingin menyetujui (ACC) permohonan ini?'
                      : 'Apakah Anda yakin ingin menolak permohonan ini?',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _iskomOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.approvalId,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _iskomOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.displayAgent,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.displayTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: isApproved
                        ? 'Catatan Persetujuan (Opsional)'
                        : 'Alasan Penolakan (Wajib Diisi) *',
                    hintText: isApproved
                        ? 'Contoh: Lanjut merge ke branch main'
                        : 'Tuliskan alasan penolakan agar agen dapat belajar...',
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: !isApproved
                          ? Colors.red
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isApproved ? _btnAccGreen : _btnRejectRed,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproved ? _btnAccGreen : _btnRejectRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (!isApproved && reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Alasan penolakan wajib diisi agar agen dapat memahami dan belajar dari catatan Anda.',
                      ),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                _handleDecision(item, decision, reason: reason);
              },
              child: Text(
                isApproved ? 'Ya, Setujui (ACC)' : 'Ya, Tolak',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: Navigator.canPop(context),
        title: 'Pusat Persetujuan',
      ),
      endDrawer: widget.userData.isNotEmpty
          ? SideDrawer(userData: widget.userData, activePage: 'approval_hub')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildAdminBanner(isDark),
            _buildSearchBar(isDark),
            _buildTabSwitcher(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _iskomOrange,
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorView(isDark)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPendingTab(isDark),
                            _buildHistoryTab(isDark),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _iskomOrange.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _iskomOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _iskomOrange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _iskomOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin (Owner ISKOM)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _isSuperAdmin
                      ? 'Persetujuan instan untuk tiket operasional & tugas agen AI'
                      : 'Mode tinjauan terbatas',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (_totalPendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _iskomOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_totalPendingCount butuh ACC',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2026) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[300]!,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Cari ID, pemohon, tugas, atau kategori...',
            hintStyle: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: _iskomOrange,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [_iskomOrange, Color(0xFFE88920)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _iskomOrange.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Menunggu ACC'),
                if (_pendingList.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _tabController.index == 0
                          ? Colors.white
                          : _iskomOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingList.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _tabController.index == 0
                            ? _iskomOrange
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Riwayat Keputusan'),
                if (_selesaiList.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _tabController.index == 1
                          ? Colors.white
                          : Colors.grey[500],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selesaiList.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _tabController.index == 1
                            ? _iskomOrange
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _btnRejectRed,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal Memuat Antrean',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Terjadi kesalahan sistem.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadApprovals(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _iskomOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab(bool isDark) {
    final filtered = _filterList(_pendingList);

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadApprovals(silent: true),
        color: _iskomOrange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 64,
                      color: _btnAccGreen.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Tidak ada tiket yang sesuai pencarian'
                          : 'Tidak Ada Antrean Persetujuan',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Coba gunakan kata kunci pencarian lain.'
                          : 'Semua permintaan tiket agen & operasional sudah diproses!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
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

    return RefreshIndicator(
      onRefresh: () => _loadApprovals(silent: true),
      color: _iskomOrange,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildPendingCard(item, isDark);
        },
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final filtered = _filterList(_selesaiList);

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadApprovals(silent: true),
        color: _iskomOrange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: isDark ? Colors.white24 : Colors.grey[400],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Tidak ada riwayat yang sesuai pencarian'
                          : 'Belum Ada Riwayat Keputusan',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keputusan ACC atau Tolak yang telah Anda buat akan tampil di sini.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
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

    return RefreshIndicator(
      onRefresh: () => _loadApprovals(silent: true),
      color: _iskomOrange,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildHistoryCard(item, isDark);
        },
      ),
    );
  }

  Widget _buildPendingCard(ApprovalItem item, bool isDark) {
    final isProcessing = _processingApprovalId == item.approvalId;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: ID Badge & Category chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _iskomOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _iskomOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    item.approvalId,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _iskomOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.category.isNotEmpty)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                if (item.createdAt != null && item.createdAt!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.createdAt!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Pemohon / Agent info
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _iskomOrange.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 16,
                    color: _iskomOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayAgent,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if ((item.divisi != null && item.divisi!.isNotEmpty) ||
                          (item.kepala != null && item.kepala!.isNotEmpty))
                        Text(
                          '${item.divisi != null && item.divisi!.isNotEmpty ? 'Divisi ${item.divisi}' : ''}'
                          '${(item.divisi != null && item.divisi!.isNotEmpty) && (item.kepala != null && item.kepala!.isNotEmpty) ? ' • ' : ''}'
                          '${item.kepala != null && item.kepala!.isNotEmpty ? 'Atasan: ${item.kepala}' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.mutuPenjelasan != null &&
                    item.mutuPenjelasan!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Mutu: ${item.mutuPenjelasan}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[400],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: Task Title
            Text(
              item.displayTitle,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Row 4: Summary container
            if (item.summary.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black26
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                ),
                child: Text(
                  item.summary,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
              ),

            // Optional: Next Step Info
            if (item.nextStep != null && item.nextStep!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.nextStep!,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons Row
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _iskomOrange,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Memproses putusan...'),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _btnRejectRed,
                        side: const BorderSide(color: _btnRejectRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _showConfirmDialog(item, 'REJECTED'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        'Tolak',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _btnAccGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 1,
                      ),
                      onPressed: () => _showConfirmDialog(item, 'APPROVED'),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        'Setujui (ACC)',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ApprovalItem item, bool isDark) {
    final bool isApproved = item.isApproved;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2026) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: ID Badge & Status Chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.approvalId,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.category.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isApproved ? _btnAccGreen : _btnRejectRed)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isApproved ? _btnAccGreen : _btnRejectRed)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isApproved
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 13,
                        color: isApproved ? _btnAccGreen : _btnRejectRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isApproved ? 'DISETUJUI' : 'DITOLAK',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? _btnAccGreen : _btnRejectRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Pemohon info
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 15,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.displayAgent,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                if (item.decidedAt != null && item.decidedAt!.isNotEmpty)
                  Text(
                    item.decidedAt!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Task Title
            Text(
              item.displayTitle,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.summary,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (item.nextStep != null && item.nextStep!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.nextStep!,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
