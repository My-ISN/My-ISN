import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/side_drawer.dart';
import '../localization/app_localizations.dart';

class RentPlanPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const RentPlanPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(userData: userData, showBackButton: true),
      endDrawer: SideDrawer(userData: userData, activePage: 'rent_plan'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'masih dalam pengembangan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


