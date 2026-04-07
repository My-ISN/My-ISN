import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import '../constants.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('work_log.fill_required'.tr(context))),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'work_log.save_success'.tr(context),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'work_log.save_failed'.tr(context),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('work_log.conn_error'.tr(context)),
          backgroundColor: Colors.red,
        ),
      );
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
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final userId = (widget.userData['id'] ?? widget.userData['user_id'])
        .toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<dynamic> modalTodos = [];
        bool modalLoading = true;
        bool hasFetched = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!hasFetched) {
              hasFetched = true;
              final url =
                  '${AppConstants.baseUrl}/get_todos?user_id=$userId&date=$dateStr';
              http
                  .get(Uri.parse(url))
                  .then((response) {
                    if (!ctx.mounted) return;
                    if (response.statusCode == 200) {
                      final result = json.decode(response.body);
                      if (result['status'] == true) {
                        setModalState(() {
                          modalTodos = List<dynamic>.from(result['data']);
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
            return _TodoPicker(
              todoItems: modalTodos,
              isLoading: modalLoading,
              selectedItems: currentSelectedItems,
              onSelect: (todoName) {
                setState(() {
                  bool added = false;
                  for (var controller in _itemControllers) {
                    if (controller.text.isEmpty) {
                      controller.text = todoName;
                      added = true;
                      break;
                    }
                  }
                  if (!added) {
                    _itemControllers.add(TextEditingController(text: todoName));
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
            const SizedBox(height: 10),

            const SizedBox(height: 25),

            // Date Picker
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(primary: _primaryColor),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: _primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'work_log.select_date'.tr(context),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),

                          Text(
                            _selectedDate.toIso8601String().split('T')[0],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'work_log.items'.tr(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showTodoPicker,
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
                  label: Text('work_log.from_job_desk'.tr(context)),
                  style: TextButton.styleFrom(foregroundColor: _primaryColor),
                ),
              ],
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
                            filled: true,

                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_itemControllers.length > 1)
                        IconButton(
                          onPressed: () => _removeItem(index),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
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
                    borderRadius: BorderRadius.circular(15),
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

class _TodoPicker extends StatefulWidget {
  final List<dynamic> todoItems;
  final bool isLoading;
  final List<String> selectedItems;
  final Function(String) onSelect;

  const _TodoPicker({
    required this.todoItems,
    required this.isLoading,
    required this.selectedItems,
    required this.onSelect,
  });

  @override
  State<_TodoPicker> createState() => _TodoPickerState();
}

class _TodoPickerState extends State<_TodoPicker> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredTodos = widget.todoItems.where((todo) {
      final name = (todo['item_name'] ?? '').toString();
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
                const Icon(
                  Icons.playlist_add_check_rounded,
                  color: Color(0xFF7E57C2),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'work_log.select_job'.tr(context),
                    style: const TextStyle(
                      fontSize: 20,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'work_log.search_job'.tr(context),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTodos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'todo_list.no_todos'.tr(context)
                              : 'main.no_results'.tr(context),
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];
                      final bool isDone =
                          todo['status'] == 1 || todo['status'] == '1';

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
                                : Icons.radio_button_unchecked,
                            color: isDone ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          todo['item_name'] ?? '-',
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
                            : null,
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                          color: Color(0xFF7E57C2),
                        ),
                        onTap: () => widget.onSelect(todo['item_name'] ?? ''),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
