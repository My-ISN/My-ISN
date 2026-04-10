import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'connectivity_wrapper.dart';

class CustomSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF2ECC71),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFE74C3C),
      icon: Icons.error_outline_rounded,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFF1C40F),
      icon: Icons.warning_amber_rounded,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 10, // Lowered even further to 10
          top: 16,
        ),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
    );
  }
}

extension SnackBarExtension on BuildContext {
  void showSuccessSnackBar(String message) => CustomSnackBar.showSuccess(this, message);
  void showErrorSnackBar(String message) => CustomSnackBar.showError(this, message);
  void showWarningSnackBar(String message) => CustomSnackBar.showWarning(this, message);
  void clearSnackBars() => ScaffoldMessenger.of(this).clearSnackBars();
}
