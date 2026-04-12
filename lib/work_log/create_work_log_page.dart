import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/custom_snackbar.dart';

import '../widgets/secondary_app_bar.dart';

class CreateWorkLogPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? estimateId;
  final Map<String, dynamic>? initialData;

  const CreateWorkLogPage({
    super.key,
    required this.userData,
    this.estimateId,
    this.initialData,
  });

  @override
  State<CreateWorkLogPage> createState() => _CreateWorkLogPageState();
}

class _CreateWorkLogPageState extends State<CreateWorkLogPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  DateTime _selectedDate = DateTime.now();
  final List<TextEditingController> _itemControllers = [
    TextEditingController(),
  ];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final estimate = widget.initialData!['estimate'];
      final items = widget.initialData!['items'] as List?;

      if (estimate != null && estimate['estimate_date'] != null) {
        try {
          _selectedDate = DateTime.parse(estimate['estimate_date']);
        } catch (e) {
          debugPrint('Error parsing date: $e');
        }
      }

      if (items != null && items.isNotEmpty) {
        _itemControllers.clear();
        for (var item in items) {
          _itemControllers.add(
            TextEditingController(text: item['item_name'] ?? ''),
          );
        }
      }
    }
  }

  Future<void> _saveLog() async {
    final items = _itemControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      context.showWarningSnackBar('work_log.fill_required'.tr(context));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, String> body = {
        'user_id': (widget.userData['id'] ?? widget.userData['user_id'])
            .toString(),
        'date': _selectedDate.toIso8601String().split('T')[0],
        'items': json.encode(items),
      };

      if (widget.estimateId != null) {
        body['estimate_id'] = widget.estimateId!;
      }

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/save_worklog'),
        body: body,
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200 && result['status'] == true) {
        context.showSuccessSnackBar(result['message'] ?? 'work_log.save_success'.tr(context));
        Navigator.pop(context, true);
      } else {
        context.showErrorSnackBar(result['message'] ?? 'work_log.save_failed'.tr(context));
      }
    } catch (e) {
      context.showErrorSnackBar('work_log.conn_error'.tr(context));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      setState(() {
        _itemControllers.removeAt(index);
      });
    }
  }

  void _showTodoPicker() {
    _showQuickAddPicker(
      title: 'work_log.select_todo'.tr(context),
      endpoint: '/get_todos',
      isTodo: true,
    );
  }

  void _showJobDeskPicker() {
    _showQuickAddPicker(
      title: 'work_log.select_job'.tr(context),
      endpoint: '/get_jobdesks',
      isTodo: false,
    );
  }

  void _showQuickAddPicker({
    required String title,
    required String endpoint,
    required bool isTodo,
  }) {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final userId = (widget.userData['id'] ?? widget.userData['user_id'])
        .toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<dynamic> modalItems = [];
        bool modalLoading = true;
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!hasFetched) {
              hasFetched = true;
              final url = isTodo
                  ? '${AppConstants.baseUrl}$endpoint?user_id=$userId&date=$dateStr'
                  : '${AppConstants.baseUrl}$endpoint?user_id=$userId';
              http
                  .get(Uri.parse(url))
                  .then((response) {
                    if (!ctx.mounted) return;
                    if (response.statusCode == 200) {
                      final result = json.decode(response.body);
                      if (result['status'] == true) {
                        setModalState(() {
                          modalItems = List<dynamic>.from(result['data']);
                          modalLoading = false;
                        });
                      } else {
                        setModalState(() => modalLoading = false);
                      }
                    } else {
                      setModalState(() => modalLoading = false);
                    }
                  })
                  .catchError((e) {
                    if (ctx.mounted) setModalState(() => modalLoading = false);
                  });
            }

            final currentSelectedItems = _itemControllers
                .map((c) => c.text.trim())
                .toList();
            return _QuickAddPicker(
              title: title,
              items: modalItems,
              isLoading: modalLoading,
              selectedItems: currentSelectedItems,
              isTodo: isTodo,
              onSelect: (itemNames) {
                setState(() {
                  for (var itemName in itemNames) {
                    bool added = false;
                    for (var controller in _itemControllers) {
                      if (controller.text.isEmpty) {
                        controller.text = itemName;
                        added = true;
                        break;
                      }
                    }
                    if (!added) {
                      _itemControllers.add(
                        TextEditingController(text: itemName),
                      );
                    }
                  }
                });
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(
        title: widget.estimateId == null
            ? 'work_log.create_title'.tr(context)
            : 'work_log.edit_title'.tr(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark
                            ? ColorScheme.dark(
                                primary: _primaryColor,
                                onPrimary: Colors.white,
                                surface: const Color(0xFF1E1E26), // Premium dark surface
                                onSurface: Colors.white,
                              )
                            : ColorScheme.light(primary: _primaryColor),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: _primaryColor,
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'work_log.select_date'.tr(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedDate.toIso8601String().split('T')[0],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickAddButton(
                    onTap: _showTodoPicker,
                    icon: Icons.playlist_add_check_rounded,
                    label: 'work_log.from_todo_list'.tr(context),
                  ),
                  _buildQuickAddButton(
                    onTap: _showJobDeskPicker,
                    icon: Icons.assignment_outlined,
                    label: 'work_log.from_job_desk'.tr(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Dynamic Items
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemControllers[index],
                          decoration: InputDecoration(
                            hintText: 'work_log.item_hint'.tr(context),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).scaffoldBackgroundColor,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: _primaryColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_itemControllers.length > 1)
                        IconButton(
                          onPressed: () => _removeItem(index),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline),
              label: Text('work_log.add_item'.tr(context)),
              style: TextButton.styleFrom(foregroundColor: _primaryColor),
            ),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'work_log.save_log'.tr(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddPicker extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final bool isLoading;
  final List<String> selectedItems;
  final bool isTodo;
  final Function(List<String>) onSelect;

  const _QuickAddPicker({
    required this.title,
    required this.items,
    required this.isLoading,
    required this.selectedItems,
    required this.isTodo,
    required this.onSelect,
  });

  @override
  State<_QuickAddPicker> createState() => _QuickAddPickerState();
}

class _QuickAddPickerState extends State<_QuickAddPicker> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      final name = (item['item_name'] ?? '').toString();
      final matchesSearch = name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final isAlreadySelected = widget.selectedItems.contains(name);
      return matchesSearch && !isAlreadySelected;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  widget.isTodo
                      ? Icons.playlist_add_check_rounded
                      : Icons.assignment_outlined,
                  color: const Color(0xFF7E57C2),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (widget.isTodo && filteredItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    final names = filteredItems
                        .map((e) => (e['item_name'] ?? '').toString())
                        .toList();
                    widget.onSelect(names);
                  },
                  icon: const Icon(Icons.library_add_check_rounded, size: 18),
                  label: Text(
                    'work_log.select_all'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7E57C2),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'work_log.search_job'.tr(context),
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: const Color(0xFF7E57C2).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isTodo
                              ? Icons.assignment_turned_in_outlined
                              : Icons.assignment_late_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'todo_list.no_todos'.tr(context)
                              : 'main.no_results'.tr(context),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final bool isDone = widget.isTodo &&
                          (item['status'] == 1 || item['status'] == '1');

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDone ? Colors.green : Colors.grey)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : widget.isTodo
                                    ? Icons.radio_button_unchecked
                                    : Icons.assignment_turned_in_rounded,
                            color: isDone
                                ? Colors.green
                                : widget.isTodo
                                    ? Colors.grey
                                    : const Color(0xFF7E57C2),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item['item_name'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: isDone
                            ? Text(
                                'work_log.status_completed'.tr(context),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                ),
                              )
                            : widget.isTodo
                                ? Row(
                                    children: [
                                      Text(
                                        _getTimeAgo(
                                          context,
                                          item['created_at']?.toString() ?? '',
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: _getPriorityColor(
                                            item['priority'],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                        trailing: Icon(
                          Icons.add_circle_outline_rounded,
                          size: 22,
                          color: const Color(0xFF7E57C2).withValues(alpha: 0.6),
                        ),
                        onTap: () => widget.onSelect([item['item_name'] ?? '']),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _getPriorityColor(dynamic priority) {
    // 1: Tinggi (Red), 2: Normal (Yellow), 3: Rendah (Grey)
    final p = int.tryParse(priority?.toString() ?? '2') ?? 2;
    if (p == 1) return Colors.red;
    if (p == 3) return Colors.grey;
    return Colors.orange; // Default/Normal: Kuning (Orange visual)
  }

  String _getTimeAgo(BuildContext context, String datetime) {
    if (datetime.isEmpty) return '';
    try {
      final past = DateTime.parse(datetime);
      final diff = DateTime.now().difference(past);

      if (diff.inDays >= 30) {
        return '${(diff.inDays / 30).floor()} bln lalu';
      } else if (diff.inDays >= 1) {
        return '${diff.inDays} hr lalu';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} jam lalu';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes} mnt lalu';
      }
      return 'baru saja';
    } catch (e) {
      return '';
    }
  }
}
