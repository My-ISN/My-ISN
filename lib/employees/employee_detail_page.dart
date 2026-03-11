import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../localization/app_localizations.dart';
import 'employee_edit_page.dart';

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

class _EmployeeDetailPageState extends State<EmployeeDetailPage> with TickerProviderStateMixin {
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
      final response = await http.post(
        Uri.parse(url),
        body: {'user_id': widget.employeeId.toString()},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Server Error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
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
              _errorMessage = data['message'] ?? 'Gagal mengambil data';
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'JSON Error: ${e.toString()}\nResponse: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee detail: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Koneksi Error: $e';
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
              Text('employees.fetch_error'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchEmployeeDetail,
                icon: const Icon(Icons.refresh),
                label: Text('employees.try_again'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return AppBar(
      title: Text(
        'employees.detail_title'.tr(context),
        style: TextStyle(
          color: _primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: Theme.of(context).cardColor,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_hasPermission('mobile_employees_add'))
          IconButton(
            icon: Icon(Icons.edit_outlined, color: _primaryColor, size: 22),
            onPressed: () {
              String section = 'profil';
              switch (_tabController.index) {
                case 0: section = 'profil'; break;
                case 1: section = 'kontrak'; break;
                case 2: section = 'pekerjaan'; break;
                case 3: section = 'pribadi'; break;
                case 4: section = 'riwayat'; break;
                case 5: section = 'dokumen'; break;
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
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
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
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
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
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
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
    if (info == null) return Center(child: Text('employees.overview.profile_data_not_available'.tr(context)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileHeader(info),
          const SizedBox(height: 24),
          _buildInfoSection('employees.overview.contact_info'.tr(context), [
            _buildInfoRow(Icons.email_outlined, 'profile.email'.tr(context), info['email']),
            _buildInfoRow(Icons.phone_android_outlined, 'profile.phone'.tr(context), info['contact_number']),
            _buildInfoRow(Icons.location_on_outlined, 'profile.address'.tr(context), '${info['address_1'] ?? ''} ${info['city'] ?? ''}'),
            _buildInfoRow(Icons.person_pin_circle_outlined, 'register.username'.tr(context), info['username']),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primaryColor.withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: _primaryColor.withOpacity(0.05),
              backgroundImage: (info['profile_photo'] != null && !info['profile_photo'].contains('default_profile'))
                  ? NetworkImage(info['profile_photo'])
                  : null,
              child: (info['profile_photo'] == null || info['profile_photo'].contains('default_profile'))
                  ? Text(
                      info['full_name'].substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor),
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
            info['role_name'] ?? '--',
            style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: info['is_active'] == '1' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              info['is_active'] == '1' ? 'main.active'.tr(context).toUpperCase() : 'main.inactive'.tr(context).toUpperCase(),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  (value == null || value.trim().isEmpty) ? 'employees.none'.tr(context) : value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
      case 1: return 'employees.status_work.contract'.tr(context);
      case 2: return 'employees.status_work.probation'.tr(context);
      case 3: return 'employees.status_work.trainee'.tr(context);
      default: return 'employees.none'.tr(context);
    }
  }

  Widget _buildContractTab() {
    final emp = _employeeData?['employment'];
    final options = _employeeData?['salary_options'];
    
    if (emp == null) return Center(child: Text('employees.contract_data.not_available'.tr(context)));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoSection('employees.contract_data.title'.tr(context), [
            _buildInfoRow(Icons.calendar_today_outlined, 'profile.contract_date'.tr(context), emp['contract_date']),
            _buildInfoRow(Icons.business_outlined, 'profile.department'.tr(context), emp['department_name']),
            _buildInfoRow(Icons.badge_outlined, 'profile.designation'.tr(context), emp['designation_name']),
            _buildInfoRow(Icons.analytics_outlined, 'employees.work_log'.tr(context), emp['worklog'].toString()),
            _buildInfoRow(Icons.check_circle_outline, 'employees.status_target_worklog'.tr(context), emp['worklog_active'] == 1 ? 'main.active'.tr(context) : 'main.inactive'.tr(context)),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.salary_shift.title'.tr(context), [
            _buildInfoRow(Icons.payments_outlined, 'profile.basic_salary'.tr(context), 'Rp ${emp['basic_salary'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}'),
            _buildInfoRow(Icons.timer_outlined, 'profile.hourly_rate'.tr(context), 'Rp ${emp['hourly_rate'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}'),
            _buildInfoRow(Icons.description_outlined, 'employees.payslip_type'.tr(context), emp['salay_type']),
            _buildInfoRow(Icons.schedule_outlined, 'profile.office_shift'.tr(context), emp['shift_name']),
            _buildInfoRow(Icons.work_outline, 'employees.status_work_label'.tr(context), _formatStatusWork(emp['status_work'])),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.period_leave.title'.tr(context), [
            _buildInfoRow(Icons.start_outlined, 'employees.start_contract'.tr(context), emp['contract_date']),
            _buildInfoRow(Icons.event_available_outlined, 'profile.contract_end'.tr(context), emp['contract_end']),
            _buildInfoRow(Icons.beach_access_outlined, 'employees.leave_categories'.tr(context), emp['leave_categories'] == 'all' ? 'employees.all'.tr(context) : (emp['leave_categories'] ?? 'employees.none'.tr(context))),
          ]),
          const SizedBox(height: 24),
          if (options != null && options['allowances'].isNotEmpty) ...[
            _buildListSection('payroll.allowances'.tr(context), options['allowances']),
            const SizedBox(height: 24),
          ],
          if (options != null && options['commissions'].isNotEmpty) ...[
            _buildListSection('payroll.commissions'.tr(context), options['commissions']),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(item['month_year'] ?? 'employees.none'.tr(context), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: Text(
                  'Rp ${item['amount'].toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                  style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTab() {
    final emp = _employeeData?['employment'];
    if (emp == null) return Center(child: Text('employees.employment_detail.not_available'.tr(context)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoSection('employees.employment_detail.title'.tr(context), [
            _buildInfoRow(Icons.badge_outlined, 'profile.employee_id'.tr(context), emp['employee_id']),
            _buildInfoRow(Icons.business_outlined, 'profile.department'.tr(context), emp['department_name']),
            _buildInfoRow(Icons.work_outline, 'profile.designation'.tr(context), emp['designation_name']),
            _buildInfoRow(Icons.schedule_outlined, 'profile.office_shift'.tr(context), emp['shift_name']),
            _buildInfoRow(Icons.calendar_today_outlined, 'profile.contract_date'.tr(context), emp['date_of_joining']),
            _buildInfoRow(Icons.person_outline, 'profile.manager'.tr(context), emp['manager']),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.role_desc'.tr(context), [
            Text(
              emp['role_description'] ?? 'announcement.no_description'.tr(context),
              style: TextStyle(color: Colors.grey[700], height: 1.5),
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
      return Center(child: Text('employees.personal_info_not_available'.tr(context)));
    }
 
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoSection('employees.personal_info'.tr(context), [
            _buildInfoRow(Icons.wc_outlined, 'profile.gender'.tr(context), info['gender']),
            _buildInfoRow(Icons.cake_outlined, 'profile.dob'.tr(context), personal['date_of_birth']),
            _buildInfoRow(Icons.favorite_border, 'profile.marital_status'.tr(context), personal['marital_status']),
            _buildInfoRow(Icons.mosque_outlined, 'profile.religion'.tr(context), personal['religion']),
            _buildInfoRow(Icons.bloodtype_outlined, 'profile.blood_group'.tr(context), personal['blood_group']),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('employees.bank_info'.tr(context), [
            _buildInfoRow(Icons.account_balance_outlined, 'profile.bank_name'.tr(context), bank['bank_name']),
            _buildInfoRow(Icons.account_circle_outlined, 'profile.account_title'.tr(context), bank['account_title']),
            _buildInfoRow(Icons.numbers_outlined, 'profile.account_number'.tr(context), bank['account_number']),
            _buildInfoRow(Icons.code_outlined, 'SWIFT/IBAN', '${bank['swift_code'] ?? 'employees.none'.tr(context)} / ${bank['iban'] ?? 'employees.none'.tr(context)}'),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final exp = _employeeData?['experience'] as List? ?? [];
    final edu = _employeeData?['education'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHistorySection('employees.work_exp'.tr(context), exp, (item) => '${item['company_name']} - ${item['post']}'),
          const SizedBox(height: 24),
          _buildHistorySection('employees.education'.tr(context), edu, (item) => '${item['school_university']} - ${item['education_level']}'),
        ],
      ),
    );
  }

  Widget _buildHistorySection(String title, List<dynamic> items, String Function(dynamic) subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text('attendance.no_data'.tr(context), style: const TextStyle(color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                final years = (item['from_year'] == null || item['from_year'].toString() == 'null' || item['from_year'].toString().isEmpty) 
                    ? '-' 
                    : '${item['from_year']} - ${item['to_year'] ?? '-'}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(subtitle(item), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    years,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final docs = _employeeData?['documents'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('employees.emp_docs'.tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Text('attendance.no_data'.tr(context), style: const TextStyle(color: Colors.grey))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.insert_drive_file_outlined, color: _primaryColor),
                    ),
                    title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(doc['type'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    trailing: IconButton(
                      icon: Icon(Icons.download_rounded, color: _primaryColor),
                      onPressed: () {
                        // Implement download link if needed, or just show the URL
                        debugPrint('Download: ${doc['file']}');
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('employees.delete_title'.tr(context)),
        content: Text('employees.delete_confirm'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('announcement.cancel'.tr(context)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('announcement.delete'.tr(context), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee() async {
    try {
      setState(() => _isLoading = true);
      const url = 'https://foxgeen.com/HRIS/mobileapi/delete_employee';
      final response = await http.post(
        Uri.parse(url),
        body: {'user_id': widget.employeeId.toString()},
      );
      
      final data = json.decode(response.body);
      if (data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('employees.delete_success'.tr(context)), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'employees.delete_error'.tr(context)), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('employees.delete_conn_error'.tr(context)), backgroundColor: Colors.red),
      );
    }
  }
}
