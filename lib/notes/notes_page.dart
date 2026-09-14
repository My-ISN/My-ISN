import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notes_service.dart';
import '../services/tracking_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Note model
// ─────────────────────────────────────────────────────────────────────────────
class NoteItem {
  final int noteId;
  final String title;
  final String text;
  final String color;
  final bool isPinned;
  final bool isShared;
  final String? authorName;
  final String? sharedByName;
  final String? updatedAt;

  const NoteItem({
    required this.noteId,
    required this.title,
    required this.text,
    required this.color,
    required this.isPinned,
    required this.isShared,
    this.authorName,
    this.sharedByName,
    this.updatedAt,
  });

  factory NoteItem.fromMap(Map<String, dynamic> m) => NoteItem(
        noteId: (m['note_id'] as num).toInt(),
        title: m['title'] ?? '',
        text: m['text'] ?? '',
        color: m['color'] ?? '#ffffff',
        isPinned: m['is_pinned'] == true || m['is_pinned'] == 1,
        isShared: m['is_shared'] == true || m['is_shared'] == 1,
        authorName: m['author_name'],
        sharedByName: m['shared_by_name'],
        updatedAt: m['updated_at'],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// NotesPage
// ─────────────────────────────────────────────────────────────────────────────
class NotesPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const NotesPage({super.key, this.userData});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NotesService _service = NotesService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;
  List<NoteItem> _pinned = [];
  List<NoteItem> _others = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    try { TrackingService().logCurrentFeature('Notes'); } catch (_) {}
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    if (widget.userData != null) {
      _currentUserData = widget.userData;
      _fetchNotes();
    } else {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final str = await storage.read(key: 'user_data');
      if (str != null && mounted) {
        setState(() => _currentUserData = json.decode(str));
        _fetchNotes();
      }
    }
  }

  int get _userId {
    final ud = _currentUserData;
    if (ud == null) return 0;
    return (ud['id'] ?? ud['user_id'] ?? 0) is String
        ? int.tryParse(ud['id'] ?? ud['user_id'] ?? '0') ?? 0
        : (ud['id'] ?? ud['user_id'] ?? 0) as int;
  }

  Future<void> _fetchNotes({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    final res = await _service.getNotes(
      userId: _userId,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    if (!mounted) return;
    if (res['status'] == true) {
      final data = res['data'];
      setState(() {
        _pinned = (data['pinned'] as List? ?? []).map((e) => NoteItem.fromMap(e)).toList();
        _others = (data['others'] as List? ?? []).map((e) => NoteItem.fromMap(e)).toList();
        _totalCount = data['total'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (!silent) context.showErrorSnackBar(res['message'] ?? 'Gagal memuat catatan');
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _fetchNotes(silent: true));
  }

  // ── Toggle pin ──────────────────────────────────────────────────────────
  Future<void> _togglePin(NoteItem note) async {
    if (note.isShared) {
      context.showErrorSnackBar('Hanya pemilik catatan yang bisa pin/unpin');
      return;
    }
    final res = await _service.togglePin(userId: _userId, noteId: note.noteId);
    if (mounted) {
      if (res['status'] == true) {
        _fetchNotes(silent: true);
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Gagal mengubah pin');
      }
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────
  Future<void> _deleteNote(NoteItem note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Catatan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          note.isShared
              ? 'Catatan ini akan dihapus dari daftar Anda (bukan catatan milik orang lain).'
              : 'Catatan "${note.title.isEmpty ? '(tanpa judul)' : note.title}" akan dihapus permanen.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final res = await _service.deleteNote(userId: _userId, noteId: note.noteId);
    if (mounted) {
      if (res['status'] == true) {
        context.showSuccessSnackBar(res['message'] ?? 'Catatan dihapus');
        _fetchNotes(silent: true);
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Gagal menghapus catatan');
      }
    }
  }

  // ── Add / Edit bottom sheet ─────────────────────────────────────────────
  Future<void> _openEditor({NoteItem? note}) async {
    if (note != null && note.isShared) {
      context.showErrorSnackBar('Anda tidak bisa mengedit catatan milik orang lain');
      return;
    }

    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final textCtrl = TextEditingController(text: note?.text ?? '');
    String selectedColor = note?.color ?? '#ffffff';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final colors = [
      '#ffffff', '#fef9c3', '#dcfce7', '#dbeafe',
      '#fce7f3', '#ede9fe', '#ffedd5', '#f1f5f9',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),

                Text(
                  note == null ? 'Catatan Baru' : 'Edit Catatan',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Color picker
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: colors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = colors[i];
                      final colorVal = Color(int.parse('FF${c.substring(1)}', radix: 16));
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: colorVal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF7E57C2) : Colors.grey.shade300,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Color(0xFF7E57C2))
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                TextFormField(
                  controller: titleCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Judul (opsional)',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Text
                TextFormField(
                  controller: textCtrl,
                  maxLines: 6,
                  style: GoogleFonts.poppins(fontSize: 14),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Isi catatan tidak boleh kosong' : null,
                  decoration: InputDecoration(
                    hintText: 'Tulis catatan Anda...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => isSaving = true);

                            final res = await _service.saveNote(
                              userId: _userId,
                              noteId: note?.noteId,
                              title: titleCtrl.text.trim(),
                              text: textCtrl.text.trim(),
                              color: selectedColor,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              if (res['status'] == true) {
                                if (mounted) {
                                  context.showSuccessSnackBar(res['message'] ?? 'Catatan disimpan');
                                  _fetchNotes(silent: true);
                                }
                              } else {
                                if (mounted) context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan');
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Simpan Catatan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        userData: _currentUserData ?? {},
        showBackButton: true,
        title: 'My ISN',
      ),
      endDrawer: SideDrawer(
        userData: _currentUserData ?? {},
        activePage: 'notes',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF7E57C2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Catatan Baru', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF7E57C2),
        onRefresh: _fetchNotes,
        child: CustomScrollView(
          slivers: [
            // ── Header strip ──
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E57C2).withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.sticky_note_2_outlined, color: Color(0xFF7E57C2), size: 26),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Catatan Saya',
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('$_totalCount catatan tersimpan',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari catatan...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchNotes(silent: true);
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Loading ──
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7E57C2))),
              )
            else if (_pinned.isEmpty && _others.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isNotEmpty ? 'Tidak ada catatan ditemukan' : 'Belum ada catatan',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15),
                      ),
                      if (_searchController.text.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Tekan tombol + untuk membuat catatan baru',
                            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
              )
            else ...[
              // ── Pinned section ──
              if (_pinned.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, size: 16, color: Color(0xFF7E57C2)),
                        const SizedBox(width: 6),
                        Text('Disematkan',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7E57C2))),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _NoteCard(
                        note: _pinned[i],
                        isDark: isDark,
                        onEdit: () => _openEditor(note: _pinned[i]),
                        onDelete: () => _deleteNote(_pinned[i]),
                        onTogglePin: () => _togglePin(_pinned[i]),
                      ),
                      childCount: _pinned.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Others section ──
              if (_others.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Lainnya',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _NoteCard(
                        note: _others[i],
                        isDark: isDark,
                        onEdit: () => _openEditor(note: _others[i]),
                        onDelete: () => _deleteNote(_others[i]),
                        onTogglePin: () => _togglePin(_others[i]),
                      ),
                      childCount: _others.length,
                    ),
                  ),
                ),
              ],

              // Bottom padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final NoteItem note;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _NoteCard({
    required this.note,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFFFFFFFF);
    }
  }

  bool _isDarkColor(Color c) => c.computeLuminance() < 0.4;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2A2A2A) : _parseColor(note.color);
    final onBg = _isDarkColor(bgColor) ? Colors.white : Colors.black87;
    final onBgMuted = onBg.withAlpha(153);

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withAlpha(15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header: pin + menu ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (note.isShared)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Dibagikan',
                          style: GoogleFonts.poppins(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  const SizedBox(width: 10),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: onBgMuted),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'pin') onTogglePin();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (!note.isShared)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                        ]),
                      ),
                    if (!note.isShared)
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(children: [
                          Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text(note.isPinned ? 'Lepas Pin' : 'Sematkan',
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(note.isShared ? 'Hapus dari daftar' : 'Hapus',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.redAccent)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.isNotEmpty) ...[
                      Text(
                        note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.bold, color: onBg),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Expanded(
                      child: Text(
                        note.text,
                        maxLines: note.title.isNotEmpty ? 4 : 6,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: onBgMuted, height: 1.4),
                      ),
                    ),
                    if (note.updatedAt != null)
                      Text(
                        _formatDate(note.updatedAt!),
                        style: GoogleFonts.poppins(fontSize: 9, color: onBgMuted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Hari ini ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
