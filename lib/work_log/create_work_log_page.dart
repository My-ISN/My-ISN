import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../localization/app_localizations.dart';

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
  final List<TextEditingController> _itemControllers = [TextEditingController()];
  bool _isSaving = false;
  List<dynamic> _jobDesks = [];
  bool _isLoadingJobs = false;

  @override
  void initState() {
    super.initState();
    _fetchJobDesks();
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
          _itemControllers.add(TextEditingController(text: item['item_name'] ?? ''));
        }
      }
    }
  }

  Future<void> _fetchJobDesks() async {
    setState(() => _isLoadingJobs = true);
    try {
      final response = await http.get(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/get_job_desk_list?designation_id=${widget.userData['designation_id']}'),
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          setState(() {
            _jobDesks = result['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching job desks: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _saveLog() async {
    final items = _itemControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();


    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('work_log.fill_required'.tr(context))),
      );
      return;
    }


    setState(() => _isSaving = true);
    try {
      final Map<String, String> body = {
        'user_id': (widget.userData['id'] ?? widget.userData['user_id']).toString(),
        'date': _selectedDate.toIso8601String().split('T')[0],
        'items': json.encode(items),
      };

      if (widget.estimateId != null) {
        body['estimate_id'] = widget.estimateId!;
      }

      final response = await http.post(
        Uri.parse('https://foxgeen.com/HRIS/mobileapi/save_worklog'),
        body: body,
      );

      final result = json.decode(response.body);
      if (response.statusCode == 200 && result['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'work_log.save_success'.tr(context)), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'work_log.save_failed'.tr(context)), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('work_log.conn_error'.tr(context)), backgroundColor: Colors.red),
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

  void _showJobDeskPicker() {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return _JobDeskPicker(
          jobDesks: _jobDesks,
          onSelect: (jobName) {

            setState(() {
              // Add to the last empty controller or add a new one
              bool added = false;
              for (var controller in _itemControllers) {
                if (controller.text.isEmpty) {
                  controller.text = jobName;
                  added = true;
                  break;
                }
              }
              if (!added) {
                _itemControllers.add(TextEditingController(text: jobName));
              }
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        userData: widget.userData, 
        showBackButton: true,
        title: widget.estimateId == null 
          ? 'work_log.create_title'.tr(context)
          : 'work_log.edit_title'.tr(context),
        showActions: false,
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
                if (date != null) setState(() => _selectedDate = date);
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
                          Text('work_log.select_date'.tr(context), style: TextStyle(color: Colors.grey[600], fontSize: 12)),

                          Text(
                            _selectedDate.toIso8601String().split('T')[0],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showJobDeskPicker,
                  icon: const Icon(Icons.list_alt, size: 18),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_itemControllers.length > 1)
                        IconButton(
                          onPressed: () => _removeItem(index),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'work_log.save_log'.tr(context),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),

              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobDeskPicker extends StatefulWidget {
  final List<dynamic> jobDesks;
  final Function(String) onSelect;

  const _JobDeskPicker({required this.jobDesks, required this.onSelect});


  @override
  State<_JobDeskPicker> createState() => _JobDeskPickerState();
}

class _JobDeskPickerState extends State<_JobDeskPicker> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredJobs = widget.jobDesks.where((job) {
      final name = (job['event_title'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('work_log.select_job'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),

          const SizedBox(height: 15),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'work_log.search_job'.tr(context),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.jobDesks.isEmpty
                ? Center(child: Text('employees.no_employees'.tr(context))) // Reuse common label

                : ListView.builder(
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = filteredJobs[index];
                      return ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(job['event_title'] ?? '-'),
                        onTap: () => widget.onSelect(job['event_title']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
