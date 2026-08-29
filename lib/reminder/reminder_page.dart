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
import '../localization/app_localizations.dart';

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

  bool _isStatsExpanded = true;
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
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
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
    return int.tryParse(
          (_currentUserData!['id'] ??
                  _currentUserData!['user_id'] ??
                  _currentUserData!['sup_user_id'] ??
                  0)
              .toString(),
        ) ??
        0;
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
          context.showErrorSnackBar(
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
    final index = _reminders.indexWhere(
      (r) => int.tryParse(r['reminder_id'].toString()) == reminderId,
    );
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
        context.showErrorSnackBar(
          res['message'] ?? 'Gagal memperbarui status',
        );
        _fetchReminders();
      }
    }
  }

  Future<void> _deleteReminder(int reminderId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'main.delete'.tr(context) != 'main.delete'
                  ? 'Hapus Pengingat'
                  : 'Hapus Pengingat',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text('Yakin ingin menghapus reminder "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'main.cancel'.tr(context) != 'main.cancel'
                  ? 'main.cancel'.tr(context)
                  : 'Batal',
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'main.delete'.tr(context) != 'main.delete'
                  ? 'main.delete'.tr(context)
                  : 'Hapus',
            ),
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
          context.showSuccessSnackBar('Reminder berhasil dihapus');
          _fetchReminders();
        } else {
          context.showErrorSnackBar(
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
    if (isEditing &&
        existingReminder['reminder_time'] != null &&
        existingReminder['reminder_time'].toString().isNotEmpty) {
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
                  listenFor: const Duration(hours: 1),
                  pauseFor: const Duration(seconds: 60),
                  listenMode: stt.ListenMode.dictation,
                  onResult: (val) {
                    setModalState(() {
                      String newText = val.recognizedWords;
                      if (_speechRecognitionText.isNotEmpty) {
                        titleController.text =
                            '$_speechRecognitionText $newText';
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
                  color: isDark ? const Color(0xFF1E1E2C) : theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
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
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_calendar_rounded
                                  : Icons.alarm_add_rounded,
                              color: _primaryColor,
                              size: 22,
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
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Catat pengingat dengan cepat & praktis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                      Row(
                        children: [
                          Text(
                            'Nama Pengingat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isListening
                                ? Colors.redAccent
                                : theme.dividerColor.withValues(alpha: 0.12),
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
                                    color: _isListening ? Colors.redAccent : Colors.grey[400],
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            // MIC / VOICE TO TEXT BUTTON
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: toggleListening,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _isListening
                                          ? Colors.redAccent.withValues(alpha: 0.15)
                                          : _primaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isListening
                                          ? Icons.mic_rounded
                                          : Icons.mic_none_rounded,
                                      color: _isListening
                                          ? Colors.redAccent
                                          : _primaryColor,
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
                      const SizedBox(height: 20),

                      // FIELD 2: WAKTU (TANGGAL WAJIB & JAM OPSIONAL)
                      Row(
                        children: [
                          Text(
                            'Waktu Pengingat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
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
                              onSelect: (d) =>
                                  setModalState(() => selectedDate = d),
                            ),
                            const SizedBox(width: 8),
                            _buildDateChip(
                              label: 'Besok',
                              date: DateTime.now().add(const Duration(days: 1)),
                              selectedDate: selectedDate,
                              onSelect: (d) =>
                                  setModalState(() => selectedDate = d),
                            ),
                            const SizedBox(width: 8),
                            _buildDateChip(
                              label: 'Lusa',
                              date: DateTime.now().add(const Duration(days: 2)),
                              selectedDate: selectedDate,
                              onSelect: (d) =>
                                  setModalState(() => selectedDate = d),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date & Time Picker Row
                      Row(
                        children: [
                          // TANGGAL (WAJIB)
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 3),
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: isDark
                                            ? ColorScheme.dark(
                                                primary: _primaryColor,
                                                onPrimary: Colors.white,
                                                surface: const Color(0xFF1E1E2C),
                                                onSurface: Colors.white,
                                              )
                                            : ColorScheme.light(
                                                primary: _primaryColor,
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black87,
                                              ),
                                        dialogBackgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A3C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.dividerColor.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 19,
                                      color: _primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat(
                                          'dd MMM yyyy',
                                          'id_ID',
                                        ).format(selectedDate),
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
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: isDark
                                            ? ColorScheme.dark(
                                                primary: _primaryColor,
                                                onPrimary: Colors.white,
                                                surface: const Color(0xFF1E1E2C),
                                                onSurface: Colors.white,
                                                surfaceContainerHighest: const Color(0xFF2A2A3C),
                                              )
                                            : ColorScheme.light(
                                                primary: _primaryColor,
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black87,
                                              ),
                                        timePickerTheme: TimePickerThemeData(
                                          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                          hourMinuteTextColor: isDark ? Colors.white : Colors.black87,
                                          hourMinuteColor: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                                          dayPeriodTextColor: isDark ? Colors.white : Colors.black87,
                                          dayPeriodColor: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                                          dialTextColor: isDark ? Colors.white : Colors.black87,
                                          dialHandColor: _primaryColor,
                                          dialBackgroundColor: isDark ? const Color(0xFF2A2A3C) : Colors.grey[100],
                                          entryModeIconColor: _primaryColor,
                                        ),
                                        dialogBackgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A3C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selectedTime != null
                                        ? _primaryColor.withValues(alpha: 0.5)
                                        : theme.dividerColor.withValues(
                                            alpha: 0.12,
                                          ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 18,
                                      color: selectedTime != null
                                          ? _primaryColor
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        selectedTime != null
                                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                            : 'Jam (Ops)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selectedTime != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: selectedTime != null
                                              ? _primaryColor
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                    if (selectedTime != null)
                                      GestureDetector(
                                        onTap: () => setModalState(
                                          () => selectedTime = null,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
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
                                    context.showErrorSnackBar(
                                      'Nama pengingat tidak boleh kosong',
                                    );
                                    return;
                                  }

                                  if (_isListening) _speech.stop();

                                  setModalState(() => isSubmitting = true);

                                  final dateStr = DateFormat('yyyy-MM-dd')
                                      .format(selectedDate);
                                  final timeStr = selectedTime != null
                                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00'
                                      : null;

                                  Map<String, dynamic> res;
                                  if (isEditing) {
                                    res = await _reminderService.updateReminder(
                                      reminderId: int.parse(
                                        existingReminder['reminder_id']
                                            .toString(),
                                      ),
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
                                    context.showSuccessSnackBar(
                                      isEditing
                                          ? 'Reminder berhasil diperbarui'
                                          : 'Reminder berhasil ditambahkan',
                                    );
                                    _fetchReminders();
                                  } else {
                                    context.showErrorSnackBar(
                                      res['message'] ??
                                          'Gagal menyimpan reminder',
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEditing
                                          ? Icons.save_rounded
                                          : Icons.check_circle_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditing
                                          ? 'Simpan Perubahan'
                                          : 'Buat Pengingat',
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
    ).whenComplete(() => _speech.stop());
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
        color: isSelected ? _primaryColor : Colors.grey.withValues(alpha: 0.25),
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

    final int totalCount = _stats['total'] ?? 0;
    final int completedCount = _stats['completed'] ?? 0;
    final int todayCount = _stats['today'] ?? 0;
    final int upcomingCount = _stats['upcoming'] ?? 0;
    final int activeCount = _stats['active'] ?? (totalCount - completedCount);

    final double progress =
        totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: _currentUserData ?? {},
        title: 'MY ISN',
      ),
      endDrawer: SideDrawer(
        userData: _currentUserData ?? {},
        activePage: 'reminder',
      ),
      body: RefreshIndicator(
        onRefresh: _fetchReminders,
        color: _primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATS CARD (Harmonious with TodoStatsCard)
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: isDark
                          ? theme.primaryColor.withValues(alpha: 0.05)
                          : theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _isStatsExpanded = !_isStatsExpanded,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ringkasan Pengingat',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Akumulasi Status Pengingat',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isStatsExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            child: _isStatsExpanded
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      18,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _buildStatMiniRow(
                                                'Total Pengingat',
                                                totalCount.toString(),
                                                Colors.blueAccent,
                                              ),
                                              const SizedBox(height: 10),
                                              _buildStatMiniRow(
                                                'Hari Ini',
                                                todayCount.toString(),
                                                Colors.orangeAccent,
                                              ),
                                              const SizedBox(height: 10),
                                              _buildStatMiniRow(
                                                'Mendatang',
                                                upcomingCount.toString(),
                                                _primaryColor,
                                              ),
                                              const SizedBox(height: 10),
                                              _buildStatMiniRow(
                                                'Selesai',
                                                completedCount.toString(),
                                                Colors.green,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                            begin: 0,
                                            end: progress,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 1000,
                                          ),
                                          curve: Curves.easeOutQuart,
                                          builder: (context, value, child) {
                                            return Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 86,
                                                  height: 86,
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: value,
                                                    strokeWidth: 9,
                                                    backgroundColor: theme
                                                        .dividerColor
                                                        .withValues(alpha: 0.1),
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      _primaryColor,
                                                    ),
                                                    strokeCap: StrokeCap.round,
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${(value * 100).toInt()}%',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 17,
                                                      ),
                                                    ),
                                                    Text(
                                                      'SELESAI',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SEARCH BAR
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A3C)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari pengingat...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _fetchReminders();
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // FILTER CHIPS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'all',
                            'Semua ($totalCount)',
                            Icons.all_inbox_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'today',
                            'Hari Ini ($todayCount)',
                            Icons.today_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'upcoming',
                            'Mendatang ($upcomingCount)',
                            Icons.upcoming_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'completed',
                            'Selesai ($completedCount)',
                            Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // LIST CONTENT
            _isLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _reminders.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildReminderCard(_reminders[index]);
                            },
                            childCount: _reminders.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showReminderFormModal(),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Tambah Pengingat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatMiniRow(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryColor
              : _primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _primaryColor
                : _primaryColor.withValues(alpha: 0.12),
          ),
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
      final remDay =
          DateTime(reminderDate.year, reminderDate.month, reminderDate.day);
      isToday = remDay.isAtSameMomentAs(today);
      isOverdue = remDay.isBefore(today) && !isDone;
    }

    // Format date display
    String formattedDate = dateStr;
    if (reminderDate != null) {
      if (isToday) {
        formattedDate = 'Hari Ini';
      } else {
        formattedDate =
            DateFormat('dd MMM yyyy', 'id_ID').format(reminderDate);
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        await _deleteReminder(id, title);
        return false;
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: isDark ? const Color(0xFF1E1E2C) : theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDone
                ? theme.dividerColor.withValues(alpha: 0.05)
                : isOverdue
                    ? Colors.redAccent.withValues(alpha: 0.35)
                    : isToday
                        ? Colors.orangeAccent.withValues(alpha: 0.35)
                        : theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showReminderFormModal(existingReminder: item),
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
                        color: isDone
                            ? Colors.green
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
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
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                )
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Date badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.grey.withValues(alpha: 0.12)
                                  : isOverdue
                                      ? Colors.redAccent.withValues(alpha: 0.12)
                                      : isToday
                                          ? Colors.orangeAccent.withValues(
                                              alpha: 0.15,
                                            )
                                          : _primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : theme.dividerColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Creator badge if available
                          if (item['first_name'] != null &&
                              item['first_name'].toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : theme.dividerColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item['first_name']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
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

                // Action Menu (Edit / Delete)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 52,
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
              'Gunakan tombol (+) di bawah untuk membuat pengingat baru dengan cepat atau gunakan input suara.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              onPressed: () => _showReminderFormModal(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Buat Pengingat Pertama',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
