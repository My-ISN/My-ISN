import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';

import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../services/reminder_service.dart';
import '../services/tracking_service.dart';

class ReminderPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ReminderPage({super.key, this.userData});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  final ReminderService _reminderService = ReminderService();
  
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;
  List<dynamic> _reminders = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'completed': 0,
    'today': 0,
    'upcoming': 0,
    'active': 0,
  };

  String _currentFilter = 'all'; // 'all', 'today', 'upcoming', 'completed'
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  String _speechRecognitionText = '';

  @override
  void initState() {
    super.initState();
    try {
      TrackingService().logCurrentFeature('Reminder');
    } catch (_) {}
    _initSpeech();
    _loadUserData();
  }

  void _initSpeech() async {
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (e) {
      debugPrint("Speech initialization error: $e");
    }
  }

  Future<void> _loadUserData() async {
    if (widget.userData != null) {
      _currentUserData = widget.userData;
      _fetchReminders();
    } else {
      const storage = FlutterSecureStorage();
      final userDataStr = await storage.read(key: 'user_data');
      if (userDataStr != null && mounted) {
        setState(() {
          _currentUserData = json.decode(userDataStr);
        });
        _fetchReminders();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  int get _userId {
    if (_currentUserData == null) return 0;
    return int.tryParse((_currentUserData!['id'] ?? _currentUserData!['user_id'] ?? 0).toString()) ?? 0;
  }

  Future<void> _fetchReminders() async {
    if (_userId == 0) return;
    setState(() => _isLoading = true);

    final res = await _reminderService.getReminders(
      userId: _userId,
      filter: _currentFilter,
      search: _searchController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == true) {
          _reminders = res['data'] ?? [];
          if (res['stats'] != null) {
            _stats = Map<String, dynamic>.from(res['stats']);
          }
        } else {
          CustomSnackBar.showError(
            context,
            res['message'] ?? 'Gagal memuat reminder',
          );
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchReminders();
    });
  }

  Future<void> _toggleDone(int reminderId) async {
    // Optimistic UI update
    final index = _reminders.indexWhere((r) => int.tryParse(r['reminder_id'].toString()) == reminderId);
    if (index != -1) {
      final currentDone = _reminders[index]['is_done'].toString() == '1';
      setState(() {
        _reminders[index]['is_done'] = currentDone ? 0 : 1;
      });
    }

    final res = await _reminderService.toggleReminder(
      reminderId: reminderId,
      userId: _userId,
    );

    if (res['status'] == true) {
      _fetchReminders();
    } else {
      if (mounted) {
        CustomSnackBar.showError(
          context,
          res['message'] ?? 'Gagal memperbarui status',
        );
        _fetchReminders(); // Revert
      }
    }
  }

  Future<void> _deleteReminder(int reminderId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Hapus Pengingat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Yakin ingin menghapus reminder "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _reminderService.deleteReminder(
        reminderId: reminderId,
        userId: _userId,
      );

      if (mounted) {
        if (res['status'] == true) {
          CustomSnackBar.showSuccess(
            context,
            'Reminder berhasil dihapus',
          );
          _fetchReminders();
        } else {
          CustomSnackBar.showError(
            context,
            res['message'] ?? 'Gagal menghapus reminder',
          );
        }
      }
    }
  }

  void _showReminderFormModal({Map<String, dynamic>? existingReminder}) {
    final bool isEditing = existingReminder != null;
    final TextEditingController titleController = TextEditingController(
      text: isEditing ? (existingReminder['title'] ?? '') : '',
    );

    DateTime selectedDate = isEditing && existingReminder['reminder_date'] != null
        ? DateTime.tryParse(existingReminder['reminder_date']) ?? DateTime.now()
        : DateTime.now();

    TimeOfDay? selectedTime;
    if (isEditing && existingReminder['reminder_time'] != null && existingReminder['reminder_time'].toString().isNotEmpty) {
      final parts = existingReminder['reminder_time'].toString().split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final theme = Theme.of(dialogCtx);
            final isDark = theme.brightness == Brightness.dark;

            void toggleListening() async {
              if (!_isSpeechInitialized) {
                _isSpeechInitialized = await _speech.initialize();
              }

              if (!_isListening) {
                setModalState(() {
                  _isListening = true;
                  _speechRecognitionText = titleController.text;
                });
                _speech.listen(
                  localeId: 'id_ID',
                  onResult: (val) {
                    setModalState(() {
                      String newText = val.recognizedWords;
                      if (_speechRecognitionText.isNotEmpty) {
                        titleController.text = '$_speechRecognitionText $newText';
                      } else {
                        titleController.text = newText;
                      }
                      titleController.selection = TextSelection.fromPosition(
                        TextPosition(offset: titleController.text.length),
                      );
                    });
                  },
                );
              } else {
                setModalState(() => _isListening = false);
                _speech.stop();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_calendar_rounded : Icons.alarm_add_rounded,
                              color: _primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit Pengingat' : 'Tambah Pengingat',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Catat pengingat dengan cepat & praktis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              if (_isListening) _speech.stop();
                              Navigator.pop(modalContext);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // FIELD 1: NAMA REMINDER (WITH VOICE TO TEXT)
                      const Text(
                        'Nama Pengingat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isListening
                                ? Colors.redAccent
                                : isDark
                                    ? Colors.white10
                                    : Colors.grey[300]!,
                            width: _isListening ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: titleController,
                                autofocus: !isEditing,
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: _isListening
                                      ? 'Mendengarkan suara Anda...'
                                      : 'Contoh: Hubungi Pak Budi jam 2 siang...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: _isListening ? Colors.redAccent : Colors.grey[500],
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            // MIC / VOICE TO TEXT BUTTON
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: toggleListening,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isListening
                                          ? Colors.redAccent.withValues(alpha: 0.2)
                                          : _primaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                      color: _isListening ? Colors.redAccent : _primaryColor,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isListening)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Perekaman suara aktif (Bahasa Indonesia)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),

                      // FIELD 2: WAKTU (TANGGAL WAJIB & JAM OPSIONAL)
                      const Text(
                        'Waktu Pengingat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Date Selection Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildDateChip(
                              label: 'Hari Ini',
                              date: DateTime.now(),
                              selectedDate: selectedDate,
                              onSelect: (d) => setModalState(() => selectedDate = d),
                            ),
                            const SizedBox(width: 8),
                            _buildDateChip(
                              label: 'Besok',
                              date: DateTime.now().add(const Duration(days: 1)),
                              selectedDate: selectedDate,
                              onSelect: (d) => setModalState(() => selectedDate = d),
                            ),
                            const SizedBox(width: 8),
                            _buildDateChip(
                              label: 'Lusa',
                              date: DateTime.now().add(const Duration(days: 2)),
                              selectedDate: selectedDate,
                              onSelect: (d) => setModalState(() => selectedDate = d),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Date & Time Picker Pickers Row
                      Row(
                        children: [
                          // TANGGAL (WAJIB)
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: _primaryColor,
                                          onPrimary: Colors.white,
                                          surface: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(() => selectedDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, size: 20, color: _primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // JAM (OPSIONAL)
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: _primaryColor,
                                          onPrimary: Colors.white,
                                          surface: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(() => selectedTime = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedTime != null
                                        ? _primaryColor.withValues(alpha: 0.5)
                                        : isDark
                                            ? Colors.white10
                                            : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 18,
                                      color: selectedTime != null ? _primaryColor : Colors.grey[500],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        selectedTime != null
                                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                            : 'Jam (Ops)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                                          color: selectedTime != null ? null : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                    if (selectedTime != null)
                                      GestureDetector(
                                        onTap: () => setModalState(() => selectedTime = null),
                                        child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[600]),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) {
                                    CustomSnackBar.showError(
                                      context,
                                      'Nama pengingat tidak boleh kosong',
                                    );
                                    return;
                                  }

                                  if (_isListening) _speech.stop();

                                  setModalState(() => isSubmitting = true);

                                  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                                  final timeStr = selectedTime != null
                                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00'
                                      : null;

                                  Map<String, dynamic> res;
                                  if (isEditing) {
                                    res = await _reminderService.updateReminder(
                                      reminderId: int.parse(existingReminder['reminder_id'].toString()),
                                      userId: _userId,
                                      title: title,
                                      reminderDate: dateStr,
                                      reminderTime: timeStr,
                                    );
                                  } else {
                                    res = await _reminderService.addReminder(
                                      userId: _userId,
                                      title: title,
                                      reminderDate: dateStr,
                                      reminderTime: timeStr,
                                    );
                                  }

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }

                                  if (!mounted) return;

                                  if (res['status'] == true) {
                                    CustomSnackBar.showSuccess(
                                      context,
                                      isEditing ? 'Reminder berhasil diperbarui' : 'Reminder berhasil ditambahkan',
                                    );
                                    _fetchReminders();
                                  } else {
                                    CustomSnackBar.showError(
                                      context,
                                      res['message'] ?? 'Gagal menyimpan reminder',
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditing ? 'Simpan Perubahan' : 'Buat Pengingat',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateChip({
    required String label,
    required DateTime date,
    required DateTime selectedDate,
    required Function(DateTime) onSelect,
  }) {
    final bool isSelected = date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? _primaryColor : null,
      ),
      side: BorderSide(
        color: isSelected ? _primaryColor : Colors.grey.withValues(alpha: 0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onSelect(date),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    if (_isListening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: _currentUserData ?? {},
        title: 'Reminder',
      ),
      endDrawer: SideDrawer(
        userData: _currentUserData ?? {},
        activePage: 'reminder',
      ),
      body: Column(
        children: [
          // STATS & SEARCH HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                ),
              ),
            ),
            child: Column(
              children: [
                // Quick Search Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari pengingat...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[500]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetchReminders();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Tabs (Semua, Hari Ini, Mendatang, Selesai)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Semua (${_stats['total'] ?? 0})', Icons.all_inbox_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('today', 'Hari Ini (${_stats['today'] ?? 0})', Icons.today_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('upcoming', 'Mendatang (${_stats['upcoming'] ?? 0})', Icons.upcoming_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'Selesai (${_stats['completed'] ?? 0})', Icons.check_circle_outline_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // REMINDERS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reminders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchReminders,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _reminders.length,
                          itemBuilder: (context, index) {
                            return _buildReminderCard(_reminders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _showReminderFormModal(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Reminder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final bool isSelected = _currentFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (_currentFilter != key) {
          setState(() => _currentFilter = key);
          _fetchReminders();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : _primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final int id = int.tryParse(item['reminder_id'].toString()) ?? 0;
    final bool isDone = item['is_done'].toString() == '1';
    final String title = item['title'] ?? '';
    final String dateStr = item['reminder_date'] ?? '';
    final String? timeStr = item['reminder_time'];

    // Check date status
    DateTime? reminderDate = DateTime.tryParse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool isToday = false;
    bool isOverdue = false;

    if (reminderDate != null) {
      final remDay = DateTime(reminderDate.year, reminderDate.month, reminderDate.day);
      isToday = remDay.isAtSameMomentAs(today);
      isOverdue = remDay.isBefore(today) && !isDone;
    }

    // Format date display
    String formattedDate = dateStr;
    if (reminderDate != null) {
      if (isToday) {
        formattedDate = 'Hari Ini';
      } else {
        formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(reminderDate);
      }
    }

    String formattedTime = '';
    if (timeStr != null && timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        formattedTime = '${parts[0]}:${parts[1]}';
      }
    }

    return Dismissible(
      key: Key('reminder_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        await _deleteReminder(id, title);
        return false; // Let fetchReminders handle rebuild
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? Colors.transparent
                : isOverdue
                    ? Colors.redAccent.withValues(alpha: 0.3)
                    : isToday
                        ? Colors.orangeAccent.withValues(alpha: 0.3)
                        : isDark
                            ? Colors.white10
                            : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox Toggle
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _toggleDone(id),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? Colors.green : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: isDone ? Colors.white : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Date/Time Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? Colors.grey[500]
                            : isDark
                                ? Colors.white
                                : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Date badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.grey.withValues(alpha: 0.15)
                                : isOverdue
                                    ? Colors.redAccent.withValues(alpha: 0.12)
                                    : isToday
                                        ? Colors.orangeAccent.withValues(alpha: 0.15)
                                        : _primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: isDone
                                    ? Colors.grey
                                    : isOverdue
                                        ? Colors.redAccent
                                        : isToday
                                            ? Colors.orange[800]
                                            : _primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDone
                                      ? Colors.grey
                                      : isOverdue
                                          ? Colors.redAccent
                                          : isToday
                                              ? Colors.orange[800]
                                              : _primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Time badge if available
                        if (formattedTime.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action Options Menu (Edit / Delete)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey[500]),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showReminderFormModal(existingReminder: item);
                  } else if (val == 'delete') {
                    _deleteReminder(id, title);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 54,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum Ada Pengingat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan tombol (+) di bawah untuk membuat pengingat dengan cepat atau gunakan input suara.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showReminderFormModal(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Pengingat Pertama'),
            ),
          ],
        ),
      ),
    );
  }
}
