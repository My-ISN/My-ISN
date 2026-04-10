import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants.dart';
import '../main.dart';
import '../maintenance_page.dart';


class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  Timer? _timer;
  bool _isPaused = false;
  Map<String, dynamic>? _userData;

  void start(Map<String, dynamic> userData) {
    _userData = userData;
    _stopTimer();
    _startTimer();
    debugPrint('HeartbeatService: Started for user ${_userData!['user_id']}');
  }

  void stop() {
    _stopTimer();
    debugPrint('HeartbeatService: Stopped');
  }

  void pause() {
    _isPaused = true;
    debugPrint('HeartbeatService: Paused');
  }

  void resume() {
    _isPaused = false;
    debugPrint('HeartbeatService: Resumed');
    _sendHeartbeat(); // Send immediately on resume
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isPaused) {
        _sendHeartbeat();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendHeartbeat() async {
    if (_userData == null) return;

    try {
      final userId = _userData!['user_id'].toString();
      const url = '${AppConstants.baseUrl}/heartbeat';

      final response = await http.post(
        Uri.parse(url),
        body: {'user_id': userId},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('HeartbeatService: Sent successfully at ${DateTime.now()}');
      } else if (response.statusCode == 503) {
        debugPrint('HeartbeatService: Maintenance mode detected');
        final data = json.decode(response.body);
        
        // Trigger global redirect using navigatorKey
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MaintenancePage(message: data['message']),
          ),
          (route) => false,
        );
        
        stop(); // Stop heartbeat if maintenance is on
      } else {
        debugPrint('HeartbeatService: Failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('HeartbeatService: Error sending heartbeat: $e');
    }
  }
}
