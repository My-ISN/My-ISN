import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/ai_bot_service.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/limit_dropdown_widget.dart';
import '../widgets/pagination_header.dart';
import '../constants.dart';

class AiBotPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AiBotPage({super.key, required this.userData});

  @override
  State<AiBotPage> createState() => _AiBotPageState();
}

class _AiBotPageState extends State<AiBotPage> {
  final AiBotService _aiService = AiBotService();
  final _storage = const FlutterSecureStorage();

  // List State
  List<dynamic> _knowledgeList = [];
  bool _isFetching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Pagination
  int _currentPage = 1;
  int _selectedLimit = 10;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _isiController = TextEditingController();
  final TextEditingController _customKategoriController = TextEditingController();
  
  final List<String> _hardcodedCategories = ['Harga', 'Laptop', 'SOP', 'FAQ', 'Info'];
  final String _addNewLabel = 'Lainnya (Tambah Baru)';
  String? _selectedKategori;
  int? _editingId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchKnowledge();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _judulController.dispose();
    _isiController.dispose();
    _customKategoriController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchKnowledge({int? page}) async {
    final int targetPage = page ?? _currentPage;
    setState(() => _isFetching = true);
    
    final result = await _aiService.getKnowledgeList(
      search: _searchController.text,
      page: targetPage,
      limit: _selectedLimit,
    );
    
    if (mounted) {
      setState(() {
        _knowledgeList = result['data'] ?? [];
        _totalCount = result['pagination']?['total'] ?? 0;
        _currentPage = targetPage;
        _isFetching = false;
      });
    }
  }

  int get _totalPages => (_totalCount / _selectedLimit).ceil();

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchKnowledge(page: 1);
    });
  }

  Widget _buildPaginationFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_totalPages <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            icon: Icons.chevron_left_rounded,
            onPressed: _currentPage > 1 ? () => _fetchKnowledge(page: _currentPage - 1) : null,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(50),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Page $_currentPage of $_totalPages',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          _buildPageButton(
            icon: Icons.chevron_right_rounded,
            onPressed: _currentPage < _totalPages ? () => _fetchKnowledge(page: _currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: onPressed == null
          ? (isDark ? Colors.white12 : Colors.grey[200])
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withAlpha(25),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? (isDark ? Colors.white24 : Colors.grey[400])
                : colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationHeader() {
    return PaginationHeader(
      limit: _selectedLimit,
      limitOptions: _limitOptions,
      totalCount: _totalCount,
      onLimitChanged: (val) {
        if (val != null) {
          setState(() => _selectedLimit = val);
          _fetchKnowledge(page: 1);
        }
      },
      primaryColor: Theme.of(context).colorScheme.primary,
      totalLabel: '$_totalCount Total',
    );
  }



  void _editKnowledge(Map<String, dynamic> item) {
    setState(() {
      _editingId = int.tryParse(item['id'].toString());
      _judulController.text = item['judul'] ?? '';
      _isiController.text = item['isi'] ?? '';
      
      String kat = item['kategori'] ?? '';
      if (_hardcodedCategories.contains(kat)) {
        _selectedKategori = kat;
        _customKategoriController.clear();
      } else {
        _selectedKategori = _addNewLabel;
        _customKategoriController.text = kat;
      }
    });
    _showKnowledgeForm();
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _judulController.clear();
      _isiController.clear();
      _customKategoriController.clear();
      _selectedKategori = null;
    });
  }

  Future<void> _saveKnowledge() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if category is selected
    if (_selectedKategori == null) {
      context.showWarningSnackBar('Silakan pilih kategori');
      return;
    }

    setState(() => _isSaving = true);
    
    String finalKategori = _selectedKategori == _addNewLabel 
        ? _customKategoriController.text.trim() 
        : (_selectedKategori ?? '');

    final result = await _aiService.saveKnowledge({
      if (_editingId != null) 'id': _editingId.toString(),
      'kategori': finalKategori,
      'judul': _judulController.text.trim(),
      'isi': _isiController.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (result['status'] == true) {
        Navigator.pop(context); // Close BottomSheet
        context.showSuccessSnackBar(result['message'] ?? 'Berhasil disimpan');
        _resetForm();
        _fetchKnowledge(page: 1);
      } else {
        context.showErrorSnackBar(result['message'] ?? 'Gagal menyimpan');
      }
    }
  }

  Future<void> _deleteKnowledge(int id) async {
    final bool confirm = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hapus Knowledge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Apakah Anda yakin ingin menghapus data ini?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ) ??
        false;

    if (confirm == true) {
      final result = await _aiService.deleteKnowledge(id);
      if (mounted) {
        if (result['status'] == true) {
          _fetchKnowledge(page: 1);
          context.showSuccessSnackBar('Berhasil dihapus');
        } else {
          context.showErrorSnackBar(result['message'] ?? 'Gagal menghapus');
        }
      }
    }
  }

  void _showKnowledgeForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final colorScheme = Theme.of(context).colorScheme;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(50),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _editingId != null ? 'Edit Knowledge' : 'Ngajarin AI (Tambah Knowledge)',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    
                    // Dropdown Kategori
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedKategori,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: [..._hardcodedCategories, _addNewLabel]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() => _selectedKategori = val);
                        setState(() => _selectedKategori = val); // Sync with outer state
                      },
                      validator: (val) => val == null ? 'Pilih kategori' : null,
                      hint: const Text('Pilih Kategori'),
                    ),
                    
                    // Text Field for Custom Kategori
                    if (_selectedKategori == _addNewLabel) ...[
                      const SizedBox(height: 16),
                      const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customKategoriController,
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama kategori baru...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Nama kategori wajib diisi' : null,
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    const Text('Judul / Topik', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Harga Sewa Laptop Core i5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Judul wajib diisi' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    const Text('Isi Pengetahuan', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _isiController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan detail informasi di sini agar AI bisa mempelajarinya...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Isi wajib diisi' : null,
                    ),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveKnowledge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_editingId != null ? 'PERBARUI DATA' : 'SIMPAN PENGETAHUAN'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    ).then((_) {
      if (!_isSaving) _resetForm(); // Reset only if not saving (closing manual)
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'Knowledge Base AI',
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'ai_bot',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _resetForm();
          _showKnowledgeForm();
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ngajarin AI'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari knowledge...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildPaginationHeader(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchKnowledge(page: 1),
              child: _isFetching
                  ? const Center(child: CircularProgressIndicator())
                  : _knowledgeList.isEmpty
                      ? const Center(child: Text('Belum ada data knowledge.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Space for FAB
                          itemCount: _knowledgeList.length + 1, // +1 for footer
                          itemBuilder: (context, index) {
                            if (index == _knowledgeList.length) {
                              return _buildPaginationFooter();
                            }
                            final item = _knowledgeList[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.withAlpha(50)),
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['judul'] ?? '-',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                              onPressed: () => _editKnowledge(item),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              onPressed: () => _deleteKnowledge(int.parse(item['id'].toString())),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item['isi'] ?? '-',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 24), // Space for category badge at bottom right
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      constraints: const BoxConstraints(maxWidth: 120),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['kategori'] ?? '-',
                                        style: TextStyle(
                                          fontSize: 10, 
                                          fontWeight: FontWeight.bold, 
                                          color: colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
