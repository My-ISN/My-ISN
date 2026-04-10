import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/secondary_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';
import '../widgets/custom_snackbar.dart';


class CreateTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CreateTicketPage({super.key, required this.userData});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedPriority;
  bool _isSubmitting = false;

  final List<Map<String, String>> _priorities = [
    {'id': '1', 'name': 'helpdesk.priority_low'},
    {'id': '2', 'name': 'helpdesk.priority_medium'},
    {'id': '3', 'name': 'helpdesk.priority_high'},
    {'id': '4', 'name': 'helpdesk.priority_critical'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate() || _selectedPriority == null) {
      if (_selectedPriority == null) {
        context.showWarningSnackBar('helpdesk.select_priority'.tr(context));
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = (widget.userData['id'] ?? widget.userData['user_id']).toString();
      final url = '${AppConstants.baseUrl}/create_ticket';

      final response = await http.post(
        Uri.parse(url),
        body: {
          'user_id': userId,
          'subject': _subjectController.text,
          'priority': _selectedPriority,
          'description': _descriptionController.text,
        },
      );

      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          context.showSuccessSnackBar('helpdesk.success_create'.tr(context));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          context.showErrorSnackBar(data['message'] ?? 'helpdesk.failed_create'.tr(context));
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error creating ticket: $e');
      if (mounted) {
        context.showErrorSnackBar('helpdesk.failed_create'.tr(context));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(title: 'helpdesk.create_ticket'.tr(context)),
      body: ConnectivityWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('helpdesk.subject'.tr(context)),
                TextFormField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    hintText: 'helpdesk.hint_subject'.tr(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'main.required_field'.tr(context);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildLabel('helpdesk.priority'.tr(context)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPriority,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _priorities.map((priority) {
                    return DropdownMenuItem(
                      value: priority['id'],
                      child: Text(priority['name']!.tr(context)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedPriority = value),
                  validator: (value) => value == null ? 'main.required_field'.tr(context) : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('helpdesk.description'.tr(context)),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'helpdesk.hint_description'.tr(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'main.required_field'.tr(context);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      foregroundColor: Theme.of(context).dividerColor.withAlpha(25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'helpdesk.send'.tr(context),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
