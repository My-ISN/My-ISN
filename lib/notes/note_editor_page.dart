import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/notes_service.dart';
import '../widgets/custom_snackbar.dart';
import 'notes_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color palette matching web Keep colors
// ─────────────────────────────────────────────────────────────────────────────
class NoteColorOption {
  final String hex;
  final String name;
  const NoteColorOption(this.hex, this.name);
}

const List<NoteColorOption> kNoteColors = [
  NoteColorOption('#ffffff', 'Putih'),
  NoteColorOption('#faafa8', 'Flamingo'),
  NoteColorOption('#f39f76', 'Tangerine'),
  NoteColorOption('#fff8b8', 'Banana'),
  NoteColorOption('#e2f6d3', 'Sage'),
  NoteColorOption('#b4ddd3', 'Basil'),
  NoteColorOption('#d4e4ed', 'Peacock'),
  NoteColorOption('#aeccdc', 'Blueberry'),
  NoteColorOption('#d3bfdb', 'Lavender'),
  NoteColorOption('#f6e2dd', 'Grape'),
];

Color parseHexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFFFFFFFF);
  }
}

class NoteEditorPage extends StatefulWidget {
  final int userId;
  final NoteItem? note;

  const NoteEditorPage({
    super.key,
    required this.userId,
    this.note,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final NotesService _service = NotesService();
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();

  late String _selectedColor;
  bool _isSaving = false;
  bool _isPreviewMode = false;

  bool get _isEdit => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _textController = TextEditingController(text: widget.note?.text ?? '');
    _selectedColor = widget.note?.color ?? '#ffffff';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Color _resolveBg(bool isDark) {
    if (isDark) {
      if (_selectedColor.toLowerCase() == '#ffffff') {
        return const Color(0xFF1E1E1E);
      }
      return Color.alphaBlend(parseHexColor(_selectedColor).withAlpha(45), const Color(0xFF1A1A1A));
    }
    return parseHexColor(_selectedColor);
  }

  bool _isDarkColor(Color c) => c.computeLuminance() < 0.4;

  // ── Rich Text Formatting Helpers ───────────────────────────────────────────
  void _applyTag(String openTag, String closeTag) {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.isValid ? selection.baseOffset.clamp(0, text.length) : text.length;
      final newText = text.replaceRange(cursor, cursor, '$openTag$closeTag');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + openTag.length),
      );
    } else {
      final start = selection.start;
      final end = selection.end;
      final selectedStr = text.substring(start, end);
      final newText = text.replaceRange(start, end, '$openTag$selectedStr$closeTag');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + openTag.length,
          extentOffset: start + openTag.length + selectedStr.length,
        ),
      );
    }
    _textFocusNode.requestFocus();
  }

  void _applyList(bool isOrdered) {
    final text = _textController.text;
    final selection = _textController.selection;
    final openTag = isOrdered ? '<ol>' : '<ul>';
    final closeTag = isOrdered ? '</ol>' : '</ul>';

    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.isValid ? selection.baseOffset.clamp(0, text.length) : text.length;
      final snippet = '$openTag\n  <li></li>\n$closeTag';
      final newText = text.replaceRange(cursor, cursor, snippet);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + openTag.length + 7),
      );
    } else {
      final start = selection.start;
      final end = selection.end;
      final selectedStr = text.substring(start, end);
      final lines = selectedStr.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return;
      final listItems = lines.map((l) => '  <li>${l.trim()}</li>').join('\n');
      final formatted = '$openTag\n$listItems\n$closeTag';
      final newText = text.replaceRange(start, end, formatted);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + formatted.length),
      );
    }
    _textFocusNode.requestFocus();
  }

  void _clearFormatting() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;
    final selectedStr = text.substring(start, end);
    final stripped = selectedStr.replaceAll(RegExp(r'<[^>]*>'), '');
    final newText = text.replaceRange(start, end, stripped);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + stripped.length,
      ),
    );
    _textFocusNode.requestFocus();
  }

  void _chooseTextColor() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textColors = [
          {'name': 'Hitam', 'hex': '#000000'},
          {'name': 'Merah', 'hex': '#d32f2f'},
          {'name': 'Biru', 'hex': '#1976d2'},
          {'name': 'Hijau', 'hex': '#388e3c'},
          {'name': 'Oranye', 'hex': '#f57c00'},
          {'name': 'Ungu', 'hex': '#7b1fa2'},
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Warna Teks', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: textColors.map((tc) {
                    final colorVal = parseHexColor(tc['hex']!);
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyTag('<span style="color: ${tc['hex']};">', '</span>');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorVal.withAlpha(25),
                          border: Border.all(color: colorVal),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 16, height: 16, decoration: BoxDecoration(color: colorVal, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(tc['name']!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: colorVal)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openColorPicker() {
    showModalBottomSheet(
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
                  final isSelected = _selectedColor.toLowerCase() == c.hex.toLowerCase();
                  final swatchColor = parseHexColor(c.hex);
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedColor = c.hex);
                      Navigator.pop(ctx);
                    },
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
  }

  // Format content for saving: if user typed plain lines without HTML tags, wrap in <p>
  String _prepareHtmlForSave(String raw) {
    if (raw.trim().isEmpty) return '';
    final hasHtmlTags = RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(raw);
    if (!hasHtmlTags) {
      final paragraphs = raw.split('\n');
      return paragraphs.map((p) => p.isEmpty ? '<br>' : '<p>${_escapeHtml(p)}</p>').join();
    }
    return raw;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  // ── Save note ──────────────────────────────────────────────────────────────
  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final rawText = _textController.text.trim();

    if (rawText.isEmpty) {
      context.showErrorSnackBar('Isi catatan tidak boleh kosong');
      return;
    }

    setState(() => _isSaving = true);

    final htmlContent = _prepareHtmlForSave(rawText);

    final res = await _service.saveNote(
      userId: widget.userId,
      noteId: widget.note?.noteId,
      title: title,
      text: htmlContent,
      color: _selectedColor,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['status'] == true) {
      context.showSuccessSnackBar(res['message'] ?? 'Catatan berhasil disimpan');
      Navigator.pop(context, true);
    } else {
      context.showErrorSnackBar(res['message'] ?? 'Gagal menyimpan catatan');
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
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEdit ? 'Edit Catatan' : 'Catatan Baru',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: onBg),
          ),
          actions: [
            // Color picker
            IconButton(
              tooltip: 'Warna Catatan',
              icon: Icon(Icons.palette_outlined, color: onBg),
              onPressed: _openColorPicker,
            ),
            // Preview / Edit Toggle
            IconButton(
              tooltip: _isPreviewMode ? 'Mode Tulis' : 'Pratinjau Rich Text',
              icon: Icon(
                _isPreviewMode ? Icons.edit_note : Icons.visibility_outlined,
                color: _isPreviewMode ? const Color(0xFF7E57C2) : onBg,
              ),
              onPressed: () {
                setState(() => _isPreviewMode = !_isPreviewMode);
              },
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7E57C2)),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Simpan',
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF7E57C2), size: 28),
                      onPressed: _saveNote,
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Main Content Area ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Title input
                      TextField(
                        controller: _titleController,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: onBg,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Judul',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: onBgMuted.withAlpha(100),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      Divider(color: onBg.withAlpha(20), height: 1),
                      const SizedBox(height: 8),

                      // Body: Either Editor or Live Rich Text Preview
                      Expanded(
                        child: _isPreviewMode
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: SingleChildScrollView(
                                  child: Html(
                                    data: _prepareHtmlForSave(_textController.text.isEmpty ? '<p><i>(Belum ada teks)</i></p>' : _textController.text),
                                    style: {
                                      "body": Style(
                                        fontSize: FontSize(15),
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                        color: onBg,
                                        lineHeight: const LineHeight(1.6),
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                      ),
                                      "p": Style(margin: Margins.only(bottom: 12)),
                                      "h1": Style(fontSize: FontSize(22), fontWeight: FontWeight.bold),
                                      "h2": Style(fontSize: FontSize(19), fontWeight: FontWeight.bold),
                                      "h3": Style(fontSize: FontSize(17), fontWeight: FontWeight.w600),
                                      "blockquote": Style(
                                        backgroundColor: onBg.withAlpha(20),
                                        border: const Border(left: BorderSide(color: Color(0xFF7E57C2), width: 4)),
                                        padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 8),
                                        margin: Margins.symmetric(vertical: 8),
                                      ),
                                    },
                                  ),
                                ),
                              )
                            : TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                maxLines: null,
                                expands: true,
                                keyboardType: TextInputType.multiline,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: onBg,
                                  height: 1.6,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tulis catatan Anda...\nGunakan toolbar di bawah untuk format teks tebal, miring, poin, judul, warna.',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: onBgMuted.withAlpha(100),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Rich Text Formatting Toolbar (docked above keyboard) ──
              if (!_isPreviewMode)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        _toolbarButton(
                          icon: Icons.format_bold,
                          tooltip: 'Tebal (Bold)',
                          onTap: () => _applyTag('<b>', '</b>'),
                        ),
                        _toolbarButton(
                          icon: Icons.format_italic,
                          tooltip: 'Miring (Italic)',
                          onTap: () => _applyTag('<i>', '</i>'),
                        ),
                        _toolbarButton(
                          icon: Icons.format_underlined,
                          tooltip: 'Garis Bawah (Underline)',
                          onTap: () => _applyTag('<u>', '</u>'),
                        ),
                        _toolbarButton(
                          icon: Icons.format_strikethrough,
                          tooltip: 'Coret (Strikethrough)',
                          onTap: () => _applyTag('<s>', '</s>'),
                        ),
                        _toolbarDivider(isDark),
                        _toolbarButton(
                          icon: Icons.title,
                          tooltip: 'Judul Sub (Heading)',
                          onTap: () => _applyTag('<h3>', '</h3>'),
                        ),
                        _toolbarButton(
                          icon: Icons.format_list_bulleted,
                          tooltip: 'Daftar Poin (Bullet List)',
                          onTap: () => _applyList(false),
                        ),
                        _toolbarButton(
                          icon: Icons.format_list_numbered,
                          tooltip: 'Daftar Nomor (Numbered List)',
                          onTap: () => _applyList(true),
                        ),
                        _toolbarButton(
                          icon: Icons.format_quote,
                          tooltip: 'Kutipan (Quote)',
                          onTap: () => _applyTag('<blockquote>', '</blockquote>'),
                        ),
                        _toolbarDivider(isDark),
                        _toolbarButton(
                          icon: Icons.format_color_text,
                          tooltip: 'Warna Teks',
                          onTap: _chooseTextColor,
                        ),
                        _toolbarButton(
                          icon: Icons.format_clear,
                          tooltip: 'Hapus Format',
                          onTap: _clearFormatting,
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

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon, size: 20, color: const Color(0xFF7E57C2)),
        ),
      ),
    );
  }

  Widget _toolbarDivider(bool isDark) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? Colors.white24 : Colors.grey.shade300,
    );
  }
}
