import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/notes_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/confirm_delete_bottom_sheet.dart';
import 'notes_page.dart';
import 'note_editor_page.dart';

class NoteDetailPage extends StatefulWidget {
  final NoteItem note;
  final int userId;
  final bool canEdit;
  final bool canDelete;

  const NoteDetailPage({
    super.key,
    required this.note,
    required this.userId,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  final NotesService _service = NotesService();
  late NoteItem _currentNote;
  bool _hasChanges = false;
  bool _isPinning = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
  }

  Color _resolveBg(bool isDark) {
    if (isDark) {
      if (_currentNote.color.toLowerCase() == '#ffffff') {
        return const Color(0xFF1E1E1E);
      }
      return Color.alphaBlend(parseHexColor(_currentNote.color).withAlpha(45), const Color(0xFF1A1A1A));
    }
    return parseHexColor(_currentNote.color);
  }

  bool _isDarkColor(Color c) => c.computeLuminance() < 0.4;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Hari ini ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _togglePin() async {
    if (_currentNote.isShared) {
      context.showErrorSnackBar('Hanya pemilik catatan yang bisa pin/unpin');
      return;
    }
    setState(() => _isPinning = true);
    final res = await _service.togglePin(userId: widget.userId, noteId: _currentNote.noteId);
    if (!mounted) return;
    setState(() => _isPinning = false);

    if (res['status'] == true) {
      setState(() {
        _currentNote = _currentNote.copyWith(isPinned: !_currentNote.isPinned);
        _hasChanges = true;
      });
      context.showSuccessSnackBar(_currentNote.isPinned ? 'Catatan disematkan' : 'Sematkan dilepas');
    } else {
      context.showErrorSnackBar(res['message'] ?? 'Gagal mengubah pin');
    }
  }

  Future<void> _changeColor() async {
    if (_currentNote.isShared || !widget.canEdit) {
      context.showErrorSnackBar('Anda tidak dapat mengubah warna catatan ini');
      return;
    }

    final newHex = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Warna Catatan', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kNoteColors.map((c) {
                  final isSelected = _currentNote.color.toLowerCase() == c.hex.toLowerCase();
                  final swatchColor = parseHexColor(c.hex);
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, c.hex),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: swatchColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF7E57C2) : Colors.grey.shade400,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 22, color: Color(0xFF7E57C2))
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    if (newHex != null && newHex != _currentNote.color) {
      final res = await _service.saveNote(
        userId: widget.userId,
        noteId: _currentNote.noteId,
        title: _currentNote.title,
        text: _currentNote.text,
        color: newHex,
      );
      if (res['status'] == true && mounted) {
        setState(() {
          _currentNote = _currentNote.copyWith(color: newHex);
          _hasChanges = true;
        });
      }
    }
  }

  Future<void> _deleteNote() async {
    if (!widget.canDelete) {
      context.showErrorSnackBar('Anda tidak memiliki izin untuk menghapus catatan');
      return;
    }

    final confirm = await showConfirmDeleteBottomSheet(
      context: context,
      title: 'Hapus Catatan',
      message: _currentNote.isShared
          ? 'Catatan ini akan dihapus dari daftar Anda.'
          : 'Catatan "${_currentNote.title.isEmpty ? '(tanpa judul)' : _currentNote.title}" akan dihapus permanen.',
    );

    if (confirm != true || !mounted) return;

    final res = await _service.deleteNote(userId: widget.userId, noteId: _currentNote.noteId);
    if (mounted) {
      if (res['status'] == true) {
        context.showSuccessSnackBar(res['message'] ?? 'Catatan dihapus');
        Navigator.pop(context, true);
      } else {
        context.showErrorSnackBar(res['message'] ?? 'Gagal menghapus catatan');
      }
    }
  }

  Future<void> _openEdit() async {
    if (_currentNote.isShared || !widget.canEdit) {
      context.showErrorSnackBar('Anda tidak memiliki izin untuk mengedit catatan ini');
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(
          userId: widget.userId,
          note: _currentNote,
        ),
      ),
    );

    if (result == true && mounted) {
      _hasChanges = true;
      // Refresh this note by fetching notes or updating state
      final res = await _service.getNotes(userId: widget.userId);
      if (res['status'] == true && mounted) {
        final all = [
          ...(res['data']['pinned'] as List? ?? []),
          ...(res['data']['others'] as List? ?? []),
        ];
        final match = all.firstWhere(
          (m) => (m['note_id'] as num).toInt() == _currentNote.noteId,
          orElse: () => null,
        );
        if (match != null) {
          setState(() {
            _currentNote = NoteItem.fromMap(match);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = _resolveBg(isDark);
    final onBg = isDark ? Colors.white : (_isDarkColor(bgColor) ? Colors.white : Colors.black87);
    final onBgMuted = onBg.withAlpha(160);

    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: onBg),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          actions: [
            // Pin toggle
            if (!_currentNote.isShared)
              IconButton(
                tooltip: _currentNote.isPinned ? 'Lepas Pin' : 'Sematkan Catatan',
                icon: Icon(
                  _currentNote.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: _currentNote.isPinned ? const Color(0xFF7E57C2) : onBg,
                ),
                onPressed: _isPinning ? null : _togglePin,
              ),

            // Color palette
            if (!_currentNote.isShared && widget.canEdit)
              IconButton(
                tooltip: 'Ubah Warna',
                icon: Icon(Icons.palette_outlined, color: onBg),
                onPressed: _changeColor,
              ),

            // Edit icon in AppBar
            if (!_currentNote.isShared && widget.canEdit)
              IconButton(
                tooltip: 'Edit Catatan',
                icon: Icon(Icons.edit_outlined, color: onBg),
                onPressed: _openEdit,
              ),

            // Delete
            if (widget.canDelete)
              IconButton(
                tooltip: 'Hapus Catatan',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _deleteNote,
              ),
          ],
        ),
        floatingActionButton: (!_currentNote.isShared && widget.canEdit)
            ? FloatingActionButton.extended(
                onPressed: _openEdit,
                backgroundColor: const Color(0xFF7E57C2),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: Text(
                  'Edit Catatan',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                if (_currentNote.title.isNotEmpty)
                  Text(
                    _currentNote.title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: onBg,
                      height: 1.3,
                    ),
                  )
                else
                  Text(
                    '(Tanpa Judul)',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: onBgMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const SizedBox(height: 10),

                // Meta badges: shared by & updated time
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_currentNote.isShared)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Dibagikan oleh ${_currentNote.sharedByName ?? _currentNote.authorName ?? "Rekan"}',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    if (_currentNote.updatedAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 13, color: onBgMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Diedit: ${_formatDate(_currentNote.updatedAt)}',
                            style: GoogleFonts.poppins(fontSize: 11, color: onBgMuted),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: onBg.withAlpha(25), height: 1),
                const SizedBox(height: 16),

                // Rich HTML Content
                Html(
                  data: _currentNote.text.isEmpty ? '<p><i>(Catatan kosong)</i></p>' : _currentNote.text,
                  style: {
                    "body": Style(
                      fontSize: FontSize(15),
                      fontFamily: GoogleFonts.poppins().fontFamily,
                      color: onBg,
                      lineHeight: const LineHeight(1.7),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    "p": Style(margin: Margins.only(bottom: 12)),
                    "h1": Style(fontSize: FontSize(22), fontWeight: FontWeight.bold, margin: Margins.only(bottom: 8)),
                    "h2": Style(fontSize: FontSize(19), fontWeight: FontWeight.bold, margin: Margins.only(bottom: 8)),
                    "h3": Style(fontSize: FontSize(17), fontWeight: FontWeight.w600, margin: Margins.only(bottom: 6)),
                    "blockquote": Style(
                      backgroundColor: onBg.withAlpha(20),
                      border: const Border(left: BorderSide(color: Color(0xFF7E57C2), width: 4)),
                      padding: HtmlPaddings.symmetric(horizontal: 14, vertical: 10),
                      margin: Margins.symmetric(vertical: 10),
                    ),
                    "ul": Style(margin: Margins.only(bottom: 10)),
                    "ol": Style(margin: Margins.only(bottom: 10)),
                    "li": Style(margin: Margins.only(bottom: 4)),
                  },
                ),
              ],
            ),
          ),
        ),
      );
  }
}
