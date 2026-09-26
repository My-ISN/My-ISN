import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service untuk mengatur System UI Android/iOS,
/// khususnya menyembunyikan / auto-hide tombol navigasi (3-button navigation)
/// agar tidak menutupi atau menghalangi menu di bagian bawah aplikasi.
class SystemUiService {
  static const MethodChannel _channel =
      MethodChannel('com.myisn/navigation_bar');

  /// Menyembunyikan tombol navigasi sistem dan mengaktifkan mode auto-hide (immersive sticky)
  static Future<void> hideNavigationBar() async {
    try {
      // 1. Flutter SystemChrome: tampilkan top overlay (status bar), sembunyikan bottom overlay
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
    } catch (e) {
      debugPrint('Error setting Flutter SystemUiMode: $e');
    }

    try {
      // 2. Set bar transparan agar jika muncul sesaat tidak menutupi dengan warna solid
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    } catch (_) {}

    try {
      // 3. Panggil native Android WindowInsetsController untuk BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
      await _channel.invokeMethod('hideNavigationBar');
    } catch (_) {
      // Abaikan jika tidak di Android atau method tidak tersedia
    }
  }
}

/// NavigatorObserver untuk memastikan navigasi tombol sistem tetap auto-hide
/// setiap kali pengguna berpindah halaman (push / pop route).
class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    SystemUiService.hideNavigationBar();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    SystemUiService.hideNavigationBar();
  }
}
