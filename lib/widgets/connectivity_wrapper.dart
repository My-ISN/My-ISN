import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

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
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityStatus(
      isConnected: _isConnected,
      child: Stack(
        children: [
          widget.child,
          ValueListenableBuilder<double>(
            valueListenable: ConnectivityStatus.bottomPadding,
            builder: (context, padding, _) {
              final bottomSafeArea = MediaQuery.of(context).padding.bottom;
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: 16,
                right: 16,
                bottom: _isConnected ? -100 : (padding + bottomSafeArea + 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tidak ada koneksi internet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Global connectivity state provider
class ConnectivityStatus extends InheritedWidget {
  final bool isConnected;
  static final ValueNotifier<double> bottomPadding = ValueNotifier<double>(0.0);

  const ConnectivityStatus({
    super.key,
    required this.isConnected,
    required super.child,
  });

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ConnectivityStatus>()
            ?.isConnected ??
        true;
  }

  @override
  bool updateShouldNotify(ConnectivityStatus oldWidget) =>
      isConnected != oldWidget.isConnected;
}
