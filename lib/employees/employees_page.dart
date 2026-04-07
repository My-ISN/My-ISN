import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';

import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import '../constants.dart';

import 'employee_detail_page.dart';
import 'employee_add_page.dart';

class EmployeesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EmployeesPage({super.key, required this.userData});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final Color _primaryColor = const Color(0xFF7E57C2);
  bool _isLoading = true;
  List<dynamic> _employees = [];
  List<dynamic> _filteredEmployees = [];
  String _searchQuery = '';
  int _selectedLimit = 10;
  int _currentPage = 1;
  int _totalCount = 0;
  final List<int> _limitOptions = [10, 25, 50, 100];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchEmployees() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final companyId = widget.userData['company_id'] ?? 2;
      final offset = (_currentPage - 1) * _selectedLimit;

      // If we want "Show All", we could send a very large limit, but let's stick to the requested values.
      // The user wants pagination to disappear if displaying everything.

      final url =
          '${AppConstants.baseUrl}/get_employees?company_id=$companyId&limit=$_selectedLimit&offset=$offset';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == true) {
        if (mounted) {
          setState(() {
            _employees = data['data'];
            _totalCount = data['total_count'] ?? 0;
            _filteredEmployees = _employees;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query;
      _filteredEmployees = _employees.where((employee) {
        final name =
            (employee['first_name'] + ' ' + (employee['last_name'] ?? ''))
                .toLowerCase();
        final role = (employee['role_name'] ?? '').toLowerCase();
        final dept = (employee['department_name'] ?? '').toLowerCase();
        return name.contains(query.toLowerCase()) ||
            role.contains(query.toLowerCase()) ||
            dept.contains(query.toLowerCase());
      }).toList();
    });
  }

  int get _totalPages => (_totalCount / _selectedLimit).ceil();

  @override
  Widget build(BuildContext context) {
    bool showPagination = _totalCount > _selectedLimit;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: widget.userData, showBackButton: false),
      endDrawer: SideDrawer(userData: widget.userData, activePage: 'employees'),
      body: RefreshIndicator(
        onRefresh: () async {
          _currentPage = 1;
          await _fetchEmployees();
        },
        color: _primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildPremiumSearchBar(),
                    const SizedBox(height: 32),
                    _buildListHeader(),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      _buildLoadingState()
                    else if (_filteredEmployees.isEmpty)
                      _buildEmptyState()
                    else
                      _buildEmployeeList(),
                    if (showPagination && !_isLoading) ...[
                      const SizedBox(height: 24),
                      _buildPagination(),
                    ],
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _hasPermission('mobile_employees_add')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EmployeeAddPage(userData: widget.userData),
                  ),
                );
                if (result == true) {
                  _fetchEmployees();
                }
              },
              backgroundColor: _primaryColor,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: Text(
                'employees.add_employee'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPremiumSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterEmployees,
        decoration: InputDecoration(
          hintText: 'employees.search_hint'.tr(context),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _filterEmployees('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'employees.show'.tr(context),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            _buildPremiumDropdown(),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'employees.total'.tr(
              context,
              args: {'count': _totalCount.toString()},
            ),
            style: TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLimit,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: _primaryColor,
          ),
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLimit = newValue;
                _currentPage = 1;
              });
              _fetchEmployees();
            }
          },
          items: _limitOptions.map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'employees.no_employees'.tr(context),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildEmployeeCard(
            context,
            name: '${employee['first_name']} ${employee['last_name'] ?? ''}',
            role:
                (employee['designation_name'] ??
                        employee['role_name'] ??
                        'employees.default_role'.tr(context))
                    .toString()
                    .roleTr(context),
            dept:
                employee['department_name'] ??
                'employees.default_dept'.tr(context),
            photo: employee['profile_photo'],
            email: employee['email'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeDetailPage(
                    userData: widget.userData,
                    employeeId: int.parse(employee['user_id'].toString()),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1
              ? () {
                  setState(() => _currentPage--);
                  _fetchEmployees();
                }
              : null,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'employees.page_x_of_y'.tr(
              context,
              args: {
                'current': _currentPage.toString(),
                'total': _totalPages.toString(),
              },
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildPageButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() => _currentPage++);
                  _fetchEmployees();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: onPressed == null
          ? (isDark ? Colors.white12 : Colors.grey[200])
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? (isDark ? Colors.white24 : Colors.grey[400])
                : _primaryColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context, {
    required String name,
    required String role,
    required String dept,
    String? photo,
    String? email,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: _primaryColor.withValues(alpha: 0.05),
                backgroundImage:
                    (photo != null &&
                        photo.isNotEmpty &&
                        !photo.contains('default'))
                    ? CachedNetworkImageProvider(
                        '${AppConstants.serverRoot}/uploads/users/thumb/$photo',
                      )
                    : null,
                child:
                    (photo == null ||
                        photo.isEmpty ||
                        photo.contains('default'))
                    ? Text(
                        name.isNotEmpty
                            ? name.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dept,
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildCardAction(Icons.email_outlined, () {}),
                const SizedBox(height: 8),
                _buildCardAction(Icons.chat_bubble_outline_rounded, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _primaryColor, size: 18),
      ),
    );
  }
}
