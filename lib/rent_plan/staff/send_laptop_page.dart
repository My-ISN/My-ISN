import 'package:flutter/material.dart';
import 'serah_terima_laptop_page.dart';

/// Wrapper backward-compatibility untuk SendLaptopPage.
/// Seluruh fitur Kirim Laptop dan Instruksi Foto Penyewa kini terpusat di [SerahTerimaLaptopPage].
class SendLaptopPage extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final String? initialBarcode;
  final Map<String, dynamic>? initialRental;

  const SendLaptopPage({
    super.key,
    this.userData,
    this.initialBarcode,
    this.initialRental,
  });

  @override
  Widget build(BuildContext context) {
    return SerahTerimaLaptopPage(
      userData: userData,
      initialTab: 0, // Tab Kirim (Foto Penyewa)
      initialBarcode: initialBarcode,
      initialRental: initialRental,
    );
  }
}
