import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Map<String, dynamic> userData;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.userData,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: Colors.black),
      title: const Text(
        'ServerHub',
        style: TextStyle(color: Color(0xFF7E57C2), fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.grey),
          onPressed: () {},
        ),
        InkWell(
          onTap: () {
            Scaffold.of(context).openEndDrawer();
          },
          child: ClipOval(
            child: Container(
              width: 36,
              height: 36,
              color: const Color(0xFFE6D4FA),
              child:
                  (userData['profile_photo'] != null &&
                      userData['profile_photo'].toString().isNotEmpty)
                  ? Image.network(
                      'https://foxgeen.com/HRIS/public/uploads/users/thumb/${userData['profile_photo']}',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
