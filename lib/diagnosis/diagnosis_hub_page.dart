import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../widgets/secondary_app_bar.dart';
import 'notification_diagnosis_page.dart';
import 'internet_diagnosis_page.dart';
import 'storage_diagnosis_page.dart';
import 'version_diagnosis_page.dart';

class DiagnosisHubPage extends StatelessWidget {
  const DiagnosisHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7E57C2);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SecondaryAppBar(title: 'diagnosis.title'.tr(context)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildDiagnosisCard(
            context,
            title: 'diagnosis.notification_title'.tr(context),
            desc: 'diagnosis.notification_desc'.tr(context),
            icon: Icons.notifications_active_outlined,
            color: primaryColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationDiagnosisPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDiagnosisCard(
            context,
            title: 'diagnosis.internet_title'.tr(context),
            desc: 'diagnosis.internet_desc'.tr(context),
            icon: Icons.wifi,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InternetDiagnosisPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDiagnosisCard(
            context,
            title: 'diagnosis.version_title'.tr(context),
            desc: 'diagnosis.version_desc'.tr(context),
            icon: Icons.system_update_alt_outlined,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VersionDiagnosisPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDiagnosisCard(
            context,
            title: 'diagnosis.storage_title'.tr(context),
            desc: 'diagnosis.storage_desc'.tr(context),
            icon: Icons.storage_outlined,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StorageDiagnosisPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
