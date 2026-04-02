import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/connectivity_wrapper.dart';
import '../localization/app_localizations.dart';

class CreateTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreateTicketPage({super.key, required this.userData});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedPriority;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }


  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPriority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('helpdesk.select_priority')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'] ?? widget.userData['user_id'];
      final url = 'https://foxgeen.com/HRIS/mobileapi/create_ticket';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'user_id': userId.toString(),
          'subject': _subjectController.text,
          'priority': _selectedPriority!,
          'department_id': '1', // Default to 1 (Support)
          'description': _descriptionController.text,
        },
      );

      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.translate('helpdesk.success_create')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? AppLocalizations.of(context)!.translate('helpdesk.failed_create')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Helpdesk: Error creating ticket: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n!.translate('helpdesk.create_ticket'),
        showBackButton: true,
        showActions: false,
        userData: widget.userData,
      ),
      body: ConnectivityWrapper(
        child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('helpdesk.subject'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: l10n.translate('helpdesk.hint_subject'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? l10n.translate('main.required') : null,
                    ),
                    const SizedBox(height: 20),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      hint: Text(l10n.translate('helpdesk.select_priority')),
                      items: [
                        {'id': '1', 'name': l10n.translate('helpdesk.priority_low')},
                        {'id': '2', 'name': l10n.translate('helpdesk.priority_medium')},
                        {'id': '3', 'name': l10n.translate('helpdesk.priority_high')},
                        {'id': '4', 'name': l10n.translate('helpdesk.priority_critical')},
                      ].map((item) {
                        return DropdownMenuItem<String>(
                          value: item['id'],
                          child: Text(item['name']!),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedPriority = value),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      l10n.translate('helpdesk.description'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: l10n.translate('helpdesk.hint_description'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? l10n.translate('main.required') : null,
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitTicket,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              l10n.translate('helpdesk.send'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
}
