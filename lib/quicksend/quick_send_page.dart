import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';
import 'quick_send_section.dart';
import 'quick_send_add_page.dart';

class QuickSendPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const QuickSendPage({super.key, required this.userData});

  @override
  State<QuickSendPage> createState() => _QuickSendPageState();
}

class _QuickSendPageState extends State<QuickSendPage> {
  final GlobalKey<QuickSendSectionState> _sectionKey = GlobalKey<QuickSendSectionState>();

  void _showAddModal() async {
    if (!_hasPermission('mobile_quicksend_add')) return;
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuickSendAddPage()),
    );
    if (res == true) {
      _sectionKey.currentState?.fetchData();
    }
  }

  bool _hasPermission(String resource) {
    if (widget.userData['role_access'] == '1' ||
        widget.userData['role_resources'] == 'all') {
      return true;
    }
    final String resources = widget.userData['role_resources'] ?? '';
    final List<String> resourceList = resources.split(',');
    return resourceList.contains(resource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        userData: widget.userData,
        showBackButton: false,
        title: 'quicksend.title'.tr(context),
      ),
      endDrawer: SideDrawer(
        userData: widget.userData,
        activePage: 'quicksend',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: QuickSendSection(
          key: _sectionKey,
          userData: widget.userData,
        ),
      ),
      floatingActionButton: _hasPermission('mobile_quicksend_add')
          ? FloatingActionButton.extended(
              onPressed: _showAddModal,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: Text(
                'quicksend.add_contact'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            )
          : null,
    );
  }
}
