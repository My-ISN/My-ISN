import 'package:flutter/material.dart';
import 'serah_terima_laptop_page.dart';

/// Wrapper backward-compatibility untuk ReceiveLaptopPage.
/// Seluruh fitur Terima / Pengembalian Laptop kini terpusat di [SerahTerimaLaptopPage].
class ReceiveLaptopPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ReceiveLaptopPage({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return SerahTerimaLaptopPage(
      userData: userData,
      initialTab: 1, // Tab Terima (Pengembalian Unit)
    );
  }
}
