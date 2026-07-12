import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_service.dart';
import '../widgets/custom_snackbar.dart';

class PasswordDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> account;

  const PasswordDetailPage({
    super.key,
    required this.userData,
    required this.account,
  });

  @override
  State<PasswordDetailPage> createState() => _PasswordDetailPageState();
}

class _PasswordDetailPageState extends State<PasswordDetailPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  final PasswordService _passwordService = PasswordService();

  bool _isLoading = true;
  List<dynamic> _services = []; // Columns
  List<dynamic> _entries = []; // Rows
  
  // Maps entry_id_field_id -> show_plain_text
  final Map<String, bool> _obscuredStates = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (mounted) setState(() => _isLoading = true);
    final idAcc = widget.account['id_acc'];
    final response = await _passwordService.getPasswordDetails(idAcc);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _services = response['services'] ?? [];
          _entries = response['entries'] ?? [];
          
          // Initialize obscured states for sensitive fields
          for (var entry in _entries) {
            final entryId = entry['id_pass'].toString();
            for (var svc in _services) {
              final svcId = svc['id_service'].toString();
              final type = svc['type'] ?? '';
              if (type == 'password' || type == 'pin') {
                _obscuredStates['${entryId}_$svcId'] = true;
              }
            }
          }
          
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value)).then((_) {
      if (mounted) {
        CustomSnackBar.showSuccess(
          context,
          '$label copied to clipboard!',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String accountName = (widget.account['name'] ?? '').toString().toUpperCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          accountName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        color: _primaryColor,
        child: _isLoading
            ? _buildLoadingState()
            : _entries.isEmpty
                ? _buildEmptyState()
                : _buildEntriesList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: _primaryColor),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No credentials saved yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntriesList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final entryId = entry['id_pass'].toString();
        final String description = entry['description'] ?? 'Unnamed Entry';
        final Map<String, dynamic> fields = entry['fields'] ?? {};

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header (Description)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              // Card Body (Fields list)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _services.map((svc) {
                    final svcId = svc['id_service'].toString();
                    final svcName = svc['name'] ?? '';
                    final svcType = svc['type'] ?? '';
                    final value = (fields[svcId] ?? '').toString();
                    
                    if (value.isEmpty) return const SizedBox.shrink();

                    final isSensitive = (svcType == 'password' || svcType == 'pin');
                    final isObscured = _obscuredStates['${entryId}_$svcId'] ?? false;
                    final displayText = isSensitive && isObscured ? '••••••••' : value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  svcName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSensitive)
                                IconButton(
                                  icon: Icon(
                                    isObscured
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscuredStates['${entryId}_$svcId'] = !isObscured;
                                    });
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: _primaryColor,
                                ),
                                onPressed: () => _copyToClipboard(svcName, value),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
