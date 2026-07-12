import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/password_service.dart';
import '../widgets/custom_snackbar.dart';
import '../constants.dart';

class PasswordShareSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> account;
  final VoidCallback onShareUpdated;

  const PasswordShareSheet({
    super.key,
    required this.userData,
    required this.account,
    required this.onShareUpdated,
  });

  @override
  State<PasswordShareSheet> createState() => _PasswordShareSheetState();
}

class _PasswordShareSheetState extends State<PasswordShareSheet> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  final PasswordService _passwordService = PasswordService();

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _staffList = [];
  List<dynamic> _filteredStaffList = [];
  final List<int> _selectedIds = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShareList();
  }

  Future<void> _loadShareList() async {
    if (mounted) setState(() => _isLoading = true);
    final idAcc = widget.account['id_acc'];
    final response = await _passwordService.getPasswordShareList(idAcc);
    if (response['status'] == true) {
      if (mounted) {
        setState(() {
          _staffList = response['all_staff'] ?? [];
          final List<dynamic> shared = response['shared_ids'] ?? [];
          _selectedIds.clear();
          for (var id in shared) {
            _selectedIds.add(int.parse(id.toString()));
          }
          _filterStaff(_searchQuery);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(
          context,
          response['message'] ?? 'Failed to load staff list',
        );
      }
    }
  }

  void _filterStaff(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStaffList = _staffList.where((staff) {
        final name = '${staff['first_name']} ${staff['last_name'] ?? ''}'.toLowerCase();
        final email = (staff['email'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _saveShare() async {
    if (mounted) setState(() => _isSaving = true);
    final idAcc = widget.account['id_acc'];
    final response = await _passwordService.sharePasswordAccount(idAcc, _selectedIds);
    if (mounted) {
      setState(() => _isSaving = false);
      if (response['status'] == true) {
        CustomSnackBar.showSuccess(
          context,
          'Sharing settings updated successfully',
        );
        widget.onShareUpdated();
        Navigator.pop(context);
      } else {
        CustomSnackBar.showError(
          context,
          response['message'] ?? 'Failed to update sharing settings',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountName = (widget.account['name'] ?? '').toString().toUpperCase();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle and Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share Account Access',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountName,
                            style: TextStyle(
                              fontSize: 12,
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterStaff,
                decoration: InputDecoration(
                  hintText: 'Search employee...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Employees List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredStaffList.isEmpty
                    ? _buildEmptyState()
                    : _buildStaffList(),
          ),
          // Save Button Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Sharing Options',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: _primaryColor),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No employees found',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredStaffList.length,
      itemBuilder: (context, index) {
        final staff = _filteredStaffList[index];
        final id = int.parse(staff['user_id'].toString());
        final String firstName = staff['first_name'] ?? '';
        final String lastName = staff['last_name'] ?? '';
        final String name = '$firstName $lastName'.trim();
        final String email = staff['email'] ?? '';
        final String? photo = staff['profile_photo'];

        final isSelected = _selectedIds.contains(id);

        return Column(
          children: [
            CheckboxListTile(
              value: isSelected,
              activeColor: _primaryColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(id);
                  } else {
                    _selectedIds.remove(id);
                  }
                });
              },
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: (photo != null && photo.isNotEmpty && !photo.contains('default'))
                          ? CachedNetworkImage(
                              imageUrl: '${AppConstants.serverRoot}/uploads/users/thumb/$photo',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => _buildInitialsPlaceholder(name),
                              errorWidget: (context, url, error) => _buildInitialsPlaceholder(name),
                            )
                          : _buildInitialsPlaceholder(name),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[150]),
          ],
        );
      },
    );
  }

  Widget _buildInitialsPlaceholder(String name) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }
}
