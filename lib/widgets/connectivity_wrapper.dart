import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../localization/app_localizations.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    setState(() {
      _isConnected = result != ConnectivityResult.none;
    });
    ConnectivityStatus.isConnected.value = _isConnected;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<double>(
          valueListenable: ConnectivityStatus.bottomPadding,
          builder: (context, padding, _) {
            // We use a small extra bottom padding only if not in dashboard
            // But for dashboard, we rely on the integrated Column (upcoming step)
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              left: 16,
              right: 16,
              bottom: _isConnected ? -120 : 104, // Fixed height above nav bar
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE74C3C).withValues(alpha: 0.85),
                          const Color(0xFFC0392B).withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Builder(builder: (context) {
                            String message = 'main.no_internet'.tr(context);
                            // Fallback if localization is not ready or key is missing
                            if (message == 'main.no_internet') {
                              try {
                                final locale = Localizations.localeOf(context);
                                message = locale.languageCode == 'en'
                                    ? 'No internet connection'
                                    : 'Tidak ada koneksi internet';
                              } catch (_) {
                                message = 'Tidak ada koneksi internet';
                              }
                            }
                            return Text(
                              message,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                                letterSpacing: 0.2,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// Global connectivity state provider
// Global connectivity state provider
class ConnectivityStatus {
  static final ValueNotifier<double> bottomPadding = ValueNotifier<double>(0.0);
  static final ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);

  static bool of(BuildContext context) {
    return isConnected.value;
  }
}
