import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import '../services/password_service.dart';
import 'password_detail_page.dart';
import 'password_share_sheet.dart';

class PasswordListPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PasswordListPage({super.key, required this.userData});

  @override
  State<PasswordListPage> createState() => _PasswordListPageState();
}

class _PasswordListPageState extends State<PasswordListPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  final PasswordService _passwordService = PasswordService();

  bool _isLoading = true;
  List<dynamic> _accounts = [];
  List<dynamic> _filteredAccounts = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPasswords();
  }

  Future<void> _fetchPasswords() async {
    if (mounted) setState(() => _isLoading = true);
    final response = await _passwordService.getPasswords();
    if (response['status'] == true && response['data'] != null) {
      if (mounted) {
        setState(() {
          _accounts = response['data'];
          _filterAccounts(_searchQuery);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterAccounts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredAccounts = _accounts.where((acc) {
        final name = (acc['name'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _openShareSheet(Map<String, dynamic> account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PasswordShareSheet(
        userData: widget.userData,
        account: account,
        onShareUpdated: _fetchPasswords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompany = widget.userData['user_type'] == 'company';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: widget.userData, showBackButton: false),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'passwords'),
      body: RefreshIndicator(
        onRefresh: _fetchPasswords,
        color: _primaryColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'main.xin_passwords'.tr(context),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBar(isDark),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredAccounts.isEmpty
                      ? _buildEmptyState()
                      : _buildAccountList(isCompany, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final fillColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.grey[100]!;

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterAccounts,
        decoration: InputDecoration(
          hintText: 'Search account...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _filterAccounts('');
                  },
                  child: Icon(
                    Icons.clear_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.vpn_key_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No accounts found',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Try checking your search query or spelling',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountList(bool isCompany, bool isDark) {
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Colors.white;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _filteredAccounts.length,
      itemBuilder: (context, index) {
        final acc = _filteredAccounts[index];
        final String name = (acc['name'] ?? '').toString().toUpperCase();
        final int totalPass = acc['total_passwords'] ?? 0;
        final List<dynamic> sharedStaff = acc['shared_to_staff'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: isDark
                ? Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  )
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PasswordDetailPage(
                    userData: widget.userData,
                    account: acc,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$totalPass entries',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isCompany) ...[
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                sharedStaff.isEmpty
                                    ? Icons.lock_outline_rounded
                                    : Icons.people_outline_rounded,
                                size: 16,
                                color: sharedStaff.isEmpty
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                                    : Colors.green[500],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sharedStaff.isEmpty
                                      ? 'Private (Hanya Anda)'
                                      : 'Dibagikan ke: ${sharedStaff.join(', ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(
                                      alpha: sharedStaff.isEmpty ? 0.4 : 0.7,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openShareSheet(acc),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              size: 16,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.lock_person_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Shared with you',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
