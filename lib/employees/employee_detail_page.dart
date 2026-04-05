import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import 'employee_edit_page.dart';
import '../widgets/secondary_app_bar.dart';

class EmployeeDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int employeeId;

  const EmployeeDetailPage({
    super.key,
    required this.userData,
    required this.employeeId,
  });

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Color _primaryColor = const Color(0xFF7E57C2); // Matching purple theme
  bool _isLoading = true;
  Map<String, dynamic>? _employeeData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchEmployeeDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_resources'] == 'all') return true;
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  Future<void> _fetchEmployeeDetail() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      const url = 'https://foxgeen.com/HRIS/mobileapi/get_employee_detail';
      final response = await http
          .post(Uri.parse(url), body: {'user_id': widget.employeeId.toString()})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _errorMessage = 'main.error_with_msg'.tr(
              context,
              args: {
                'message': 'main.server_error_status'.tr(
                  context,
                  args: {'status': response.statusCode.toString()},
                ),
              },
            );
            _isLoading = false;
          });
        }
        return;
      }

      try {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          if (mounted) {
            setState(() {
              _employeeData = data;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage =
                  data['message'] ?? 'employees.fetch_error'.tr(context);
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage =
                '${'main.json_parse_error'.tr(context)}: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee detail: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'profile.conn_error'.tr(context);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildRedesignedAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty || _employeeData == null) {
      return Scaffold(
        appBar: _buildRedesignedAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'employees.fetch_error'.tr(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchEmployeeDetail,
                icon: const Icon(Icons.refresh),
                label: Text('employees.try_again'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildRedesignedAppBar(),
      body: Column(
        children: [
          _buildModernMenuBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildContractTab(),
                _buildEmploymentTab(),
                _buildPersonalTab(),
                _buildHistoryTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildRedesignedAppBar() {
    return SecondaryAppBar(
      title: 'employees.detail_title'.tr(context),
      actions: [
        if (_hasPermission('mobile_employees_add'))
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF7E57C2),
              size: 22,
            ),
            onPressed: () {
              String section = 'profil';
              switch (_tabController.index) {
                case 0:
                  section = 'profil';
                  break;
                case 1:
                  section = 'kontrak';
                  break;
                case 2:
                  section = 'pekerjaan';
                  break;
                case 3:
                  section = 'pribadi';
                  break;
                case 4:
                  section = 'riwayat';
                  break;
                case 5:
                  section = 'dokumen';
                  break;
                default:
                  return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeEditPage(
                    employeeData: _employeeData!,
                    section: section,
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  _fetchEmployeeDetail();
                }
              });
            },
          ),
        if (_hasPermission('mobile_employees_delete'))
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: () {
              _showDeleteConfirmation();
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildModernMenuBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.05), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorPadding: EdgeInsets.zero,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        padding: const EdgeInsets.only(left: 0, right: 8),
        tabs: [
          Tab(text: 'employees.tabs.profile'.tr(context)),
          Tab(text: 'employees.tabs.contract'.tr(context)),
          Tab(text: 'employees.tabs.employment'.tr(context)),
          Tab(text: 'employees.tabs.personal'.tr(context)),
          Tab(text: 'employees.tabs.history'.tr(context)),
          Tab(text: 'employees.tabs.documents'.tr(context)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final info = _employeeData?['user_info'];
    if (info == null)
      return Center(
        child: Text(
          'employees.overview.profile_data_not_available'.tr(context),
        ),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProfileHeader(info),
          const SizedBox(height: 24),
          _buildInfoSection('employees.overview.contact_info'.tr(context), [
            _buildInfoRow(
              Icons.email_outlined,
              'profile.email'.tr(context),
              info['email'],
            ),
            _buildInfoRow(
              Icons.phone_android_outlined,
              'profile.phone'.tr(context),
              info['contact_number'],
            ),
            _buildInfoRow(
              Icons.location_on_outlined,
              'profile.address'.tr(context),
              '${info['address_1'] ?? ''} ${info['city'] ?? ''}',
            ),
            _buildInfoRow(
              Icons.person_pin_circle_outlined,
              'register.username'.tr(context),
              info['username'],
              last: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF512DA8), Color(0xFF7E57C2)],
              ),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              backgroundImage:
                  (info['profile_photo'] != null &&
                      !info['profile_photo'].contains('default_profile'))
                  ? CachedNetworkImageProvider(info['profile_photo'])
                  : null,
              child:
                  (info['profile_photo'] == null ||
                      info['profile_photo'].contains('default_profile'))
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey.withOpacity(0.5),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            info['full_name'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            (info['role_name'] ?? '--').toString().roleTr(context),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: info['is_active'] == '1'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              info['is_active'] == '1'
                  ? 'main.active'.tr(context).toUpperCase()
                  : 'main.inactive'.tr(context).toUpperCase(),
              style: TextStyle(
                color: info['is_active'] == '1' ? Colors.green : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value, {
    bool last = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.08),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (value == null || value.trim().isEmpty)
                      ? 'employees.none'.tr(context)
                      : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatusWork(int? status) {
    switch (status) {
      case 1:
        return 'employees.status_work.contract'.tr(context);
      case 2:
        return 'employees.status_work.probation'.tr(context);
      case 3:
        return 'employees.status_work.trainee'.tr(context);
      default:
        return 'employees.none'.tr(context);
    }
  }

  Widget _buildContractTab() {
    final emp = _employeeData?['employment'];
    final options = _employeeData?['salary_options'];

    if (emp == null)
      return Center(
        child: Text('employees.contract_data.not_available'.tr(context)),
      );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildInfoSection('employees.contract_data.title'.tr(context), [
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'profile.contract_date'.tr(context),
              emp['contract_date'],
            ),
            _buildInfoRow(
              Icons.business_outlined,
              'profile.department'.tr(context),
              emp['department_name'],
            ),
            _buildInfoRow(
              Icons.badge_outlined,
              'profile.designation'.tr(context),
              emp['designation_name'],
            ),
            _buildInfoRow(
              Icons.analytics_outlined,
              'employees.work_log'.tr(context),
              emp['worklog'].toString(),
            ),
            _buildInfoRow(
              Icons.check_circle_outline,
              'employees.status_target_worklog'.tr(context),
              emp['worklog_active'] == 1
                  ? 'main.active'.tr(context)
                  : 'main.inactive'.tr(context),
              last: true,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.salary_shift.title'.tr(context), [
            _buildInfoRow(
              Icons.payments_outlined,
              'profile.basic_salary'.tr(context),
              'Rp ${emp['basic_salary'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            ),
            _buildInfoRow(
              Icons.timer_outlined,
              'profile.hourly_rate'.tr(context),
              'Rp ${emp['hourly_rate'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
            ),
            _buildInfoRow(
              Icons.description_outlined,
              'employees.payslip_type'.tr(context),
              emp['salay_type'],
            ),
            _buildInfoRow(
              Icons.schedule_outlined,
              'profile.office_shift'.tr(context),
              emp['shift_name'],
            ),
            _buildInfoRow(
              Icons.work_outline,
              'employees.status_work_label'.tr(context),
              _formatStatusWork(emp['status_work']),
              last: true,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.period_leave.title'.tr(context), [
            _buildInfoRow(
              Icons.start_outlined,
              'employees.start_contract'.tr(context),
              emp['contract_date'],
            ),
            _buildInfoRow(
              Icons.event_available_outlined,
              'profile.contract_end'.tr(context),
              emp['contract_end'],
            ),
            _buildInfoRow(
              Icons.beach_access_outlined,
              'employees.leave_categories'.tr(context),
              emp['leave_categories'] == 'all'
                  ? 'employees.all'.tr(context)
                  : (emp['leave_categories'] ?? 'employees.none'.tr(context)),
              last: true,
            ),
          ]),
          const SizedBox(height: 24),
          if (options != null && options['allowances'].isNotEmpty) ...[
            _buildListSection(
              'payroll.allowances'.tr(context),
              options['allowances'],
            ),
            const SizedBox(height: 24),
          ],
          if (options != null && options['commissions'].isNotEmpty) ...[
            _buildListSection(
              'payroll.commissions'.tr(context),
              options['commissions'],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.08),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      item['month_year'] ?? 'employees.none'.tr(context),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: Text(
                      'Rp ${item['amount'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmploymentTab() {
    final emp = _employeeData?['employment'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (emp == null)
      return Center(
        child: Text('employees.employment_detail.not_available'.tr(context)),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildInfoSection(
            'employees.employment_detail.detail_title'.tr(context),
            [
              _buildInfoRow(
                Icons.badge_outlined,
                'profile.employee_id'.tr(context),
                emp['employee_id'],
              ),
              _buildInfoRow(
                Icons.business_outlined,
                'profile.department'.tr(context),
                emp['department_name'],
              ),
              _buildInfoRow(
                Icons.work_outline,
                'profile.designation'.tr(context),
                emp['designation_name'],
              ),
              _buildInfoRow(
                Icons.schedule_outlined,
                'profile.office_shift'.tr(context),
                emp['shift_name'],
              ),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                'profile.contract_date'.tr(context),
                emp['date_of_joining'],
              ),
              _buildInfoRow(
                Icons.person_outline,
                'profile.manager'.tr(context),
                emp['manager'],
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection('employees.role_desc'.tr(context), [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                emp['role_description'] ??
                    'announcement.no_description'.tr(context),
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPersonalTab() {
    final personal = _employeeData?['personal'];
    final bank = _employeeData?['bank_account'];
    final info = _employeeData?['user_info'];

    if (personal == null || bank == null || info == null) {
      return Center(
        child: Text('employees.personal_info_not_available'.tr(context)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildInfoSection('employees.personal_info'.tr(context), [
            _buildInfoRow(
              Icons.wc_outlined,
              'profile.gender'.tr(context),
              info['gender'],
            ),
            _buildInfoRow(
              Icons.cake_outlined,
              'profile.dob'.tr(context),
              personal['date_of_birth'],
            ),
            _buildInfoRow(
              Icons.favorite_border,
              'profile.marital_status'.tr(context),
              personal['marital_status'],
            ),
            _buildInfoRow(
              Icons.mosque_outlined,
              'profile.religion'.tr(context),
              personal['religion'],
            ),
            _buildInfoRow(
              Icons.bloodtype_outlined,
              'profile.blood_group'.tr(context),
              personal['blood_group'],
              last: true,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.bank_info'.tr(context), [
            _buildInfoRow(
              Icons.account_balance_outlined,
              'profile.bank_name'.tr(context),
              bank['bank_name'],
            ),
            _buildInfoRow(
              Icons.account_circle_outlined,
              'profile.account_title'.tr(context),
              bank['account_title'],
            ),
            _buildInfoRow(
              Icons.numbers_outlined,
              'profile.account_number'.tr(context),
              bank['account_number'],
            ),
            _buildInfoRow(
              Icons.code_outlined,
              'SWIFT/IBAN',
              '${bank['swift_code'] ?? 'employees.none'.tr(context)} / ${bank['iban'] ?? 'employees.none'.tr(context)}',
              last: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final exp = _employeeData?['experience'] as List? ?? [];
    final edu = _employeeData?['education'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHistorySection(
            'employees.work_exp'.tr(context),
            exp,
            (item) => '${item['company_name']} - ${item['post']}',
          ),
          const SizedBox(height: 24),
          _buildHistorySection(
            'employees.education'.tr(context),
            edu,
            (item) =>
                '${item['school_university']} - ${item['education_level']}',
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
    String title,
    List<dynamic> items,
    String Function(dynamic) subtitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'attendance.no_data'.tr(context),
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.08),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final years =
                        (item['from_year'] == null ||
                            item['from_year'].toString() == 'null' ||
                            item['from_year'].toString().isEmpty)
                        ? '-'
                        : '${item['from_year']} - ${item['to_year'] ?? '-'}';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      title: Text(
                        subtitle(item),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        years,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    final docs = _employeeData?['documents'] as List? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'employees.emp_docs'.tr(context),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'attendance.no_data'.tr(context),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.08),
                    ),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.insert_drive_file_outlined,
                            color: _primaryColor,
                          ),
                        ),
                        title: Text(
                          doc['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          doc['type'],
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.download_rounded,
                            color: _primaryColor,
                          ),
                          onPressed: () {
                            debugPrint('Download: ${doc['file']}');
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'employees.delete_title'.tr(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'employees.delete_confirm'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('main.cancel'.tr(context)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteEmployee();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text('main.delete'.tr(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEmployee() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      const url = 'https://foxgeen.com/HRIS/mobileapi/delete_employee';
      final response = await http
          .post(Uri.parse(url), body: {'user_id': widget.employeeId.toString()})
          .timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('employees.delete_success'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'employees.delete_error'.tr(context),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.conn_error'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
