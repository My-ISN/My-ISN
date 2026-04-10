import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants.dart';

import '../../../localization/app_localizations.dart';

class DashboardProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const DashboardProfileHeader({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 60,
                  height: 60,
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFF1F5F9)
                      : Theme.of(context).scaffoldBackgroundColor,
                  child: (user['profile_photo'] != null &&
                          user['profile_photo'].toString().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl:
                              '${AppConstants.serverRoot}/public/uploads/users/thumb/${user['profile_photo']}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 36,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['nama'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${user['username'] ?? 'username'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  (user['role_name'] ?? 'Staff').toString().roleTr(context),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
