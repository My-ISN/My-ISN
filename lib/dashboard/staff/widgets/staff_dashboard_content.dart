import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_profile_header.dart';
import 'dashboard_welcome_card.dart';
import 'dashboard_stats_grid.dart';
import 'dashboard_quick_menu.dart';
import '../../../widgets/connectivity_wrapper.dart';

class StaffDashboardContent extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> dashboardData;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;
  final bool Function(String) hasPermission;

  const StaffDashboardContent({
    super.key,
    required this.userData,
    required this.dashboardData,
    required this.onRefresh,
    required this.onProfileTap,
    required this.hasPermission,
  });

  @override
  State<StaffDashboardContent> createState() => _StaffDashboardContentState();
}

class _StaffDashboardContentState extends State<StaffDashboardContent> {
  static const String _storageKey = 'staff_dashboard_cards_order';
  static const List<String> _defaultOrder = ['welcome', 'stats', 'quick_menu'];

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<String> _cardOrder = List.from(_defaultOrder);
  bool _isLoadingOrder = true;

  @override
  void initState() {
    super.initState();
    _loadCardOrder();
  }

  Future<void> _loadCardOrder() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final List<String> loadedList = decoded.map((e) => e.toString()).toList();
        
        // Validate all default cards exist in the loaded list
        final validList = loadedList.where((k) => _defaultOrder.contains(k)).toList();
        for (final defKey in _defaultOrder) {
          if (!validList.contains(defKey)) {
            validList.add(defKey);
          }
        }
        if (mounted) {
          setState(() {
            _cardOrder = validList;
            _isLoadingOrder = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _cardOrder = List.from(_defaultOrder);
        _isLoadingOrder = false;
      });
    }
  }

  Future<void> _saveCardOrder(List<String> newOrder) async {
    setState(() {
      _cardOrder = List.from(newOrder);
    });
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(newOrder));
    } catch (_) {}
  }

  void _moveCard(int index, int delta, StateSetter setModalState) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _cardOrder.length) return;

    final updated = List<String>.from(_cardOrder);
    final item = updated.removeAt(index);
    updated.insert(newIndex, item);

    setModalState(() {
      _cardOrder = updated;
    });
    _saveCardOrder(updated);
  }

  void _onReorder(int oldIndex, int newIndex, StateSetter setModalState) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updated = List<String>.from(_cardOrder);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    setModalState(() {
      _cardOrder = updated;
    });
    _saveCardOrder(updated);
  }

  String _getCardTitle(String key) {
    switch (key) {
      case 'welcome':
        return 'Absensi & Jam Kerja';
      case 'stats':
        return 'Statistik & Cuti';
      case 'quick_menu':
        return 'Menu Cepat';
      default:
        return key;
    }
  }

  String _getCardSubtitle(String key) {
    switch (key) {
      case 'welcome':
        return 'Selamat datang, tombol masuk, pulang, istirahat';
      case 'stats':
        return 'Durasi kerja, cuti saya, lembur, perjalanan';
      case 'quick_menu':
        return 'Shortcut akses fitur cepat';
      default:
        return '';
    }
  }

  IconData _getCardIcon(String key) {
    switch (key) {
      case 'welcome':
        return Icons.fingerprint_rounded;
      case 'stats':
        return Icons.insights_rounded;
      case 'quick_menu':
        return Icons.grid_view_rounded;
      default:
        return Icons.widgets_outlined;
    }
  }

  Color _getCardColor(String key) {
    switch (key) {
      case 'welcome':
        return const Color(0xFF7E57C2);
      case 'stats':
        return const Color(0xFF10B981);
      case 'quick_menu':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showReorderBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final itemBg = isDark ? const Color(0xFF000000) : Colors.white;
        final itemBorder = isDark
            ? theme.dividerColor.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0);

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.swap_vert_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Atur Posisi Card Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Gunakan panah ▲ / ▼ atau geser untuk ubah urutan',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Reorderable Card List
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cardOrder.length,
                    onReorder: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx, setModalState),
                    itemBuilder: (context, index) {
                      final key = _cardOrder[index];
                      final title = _getCardTitle(key);
                      final subtitle = _getCardSubtitle(key);
                      final icon = _getCardIcon(key);
                      final color = _getCardColor(key);
                      final isFirst = index == 0;
                      final isLast = index == _cardOrder.length - 1;

                      return Container(
                        key: ValueKey(key),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: itemBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Number Badge & Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),

                              // Title & Description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Up / Down Button Controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                    color: isFirst
                                        ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                                        : theme.colorScheme.primary,
                                    tooltip: 'Pindah ke Atas',
                                    onPressed: isFirst
                                        ? null
                                        : () => _moveCard(index, -1, setModalState),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                    color: isLast
                                        ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                                        : theme.colorScheme.primary,
                                    tooltip: 'Pindah ke Bawah',
                                    onPressed: isLast
                                        ? null
                                        : () => _moveCard(index, 1, setModalState),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _cardOrder = List.from(_defaultOrder);
                            });
                            _saveCardOrder(_defaultOrder);
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text(
                            'Reset Default',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            backgroundColor: itemBg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: itemBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardByKey(String key, Map<String, dynamic> user, dynamic attendance) {
    switch (key) {
      case 'welcome':
        return DashboardWelcomeCard(
          key: const ValueKey('card_welcome'),
          user: user,
          stats: widget.dashboardData['stats'],
          attendance: attendance,
        );
      case 'stats':
        return DashboardStatsGrid(
          key: const ValueKey('card_stats'),
          stats: widget.dashboardData['stats'],
        );
      case 'quick_menu':
        return DashboardQuickMenu(
          key: const ValueKey('card_quick_menu'),
          userData: widget.userData,
          dashboardData: widget.dashboardData,
          hasPermission: widget.hasPermission,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.dashboardData['user'] ?? widget.userData;
    final attendance = widget.dashboardData['attendance'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            DashboardProfileHeader(
              user: user,
              onTap: widget.onProfileTap,
            ),
            const SizedBox(height: 16),

            // Edit Layout Action Header Row with Pencil Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
                InkWell(
                  onTap: _showReorderBottomSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Atur Posisi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dynamic Cards Rendered in Customized Order
            if (_isLoadingOrder)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._cardOrder.map((key) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _buildCardByKey(key, user, attendance),
                );
              }),

            // Bottom Safe Padding for Floating Nav Bar & FAB
            ValueListenableBuilder<double>(
              valueListenable: ConnectivityStatus.bottomPadding,
              builder: (context, padding, _) =>
                  SizedBox(height: (padding + 20).clamp(60.0, double.infinity)),
            ),
          ],
        ),
      ),
    );
  }
}
