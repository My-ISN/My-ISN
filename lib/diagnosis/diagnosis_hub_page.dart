import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
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
      appBar: AppBar(
        title: Text(
          'diagnosis.title'.tr(context),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white24)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
