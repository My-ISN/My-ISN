import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  final Battery _battery = Battery();
  final Uuid _uuid = const Uuid();

  String? _sessionId;
  Map<String, dynamic>? _userData;
  Timer? _syncTimer;
  bool _isSyncing = false;

  String? _currentFeature;
  
  List<Map<String, dynamic>> _eventQueue = [];
  List<Map<String, dynamic>> _healthQueue = [];

  String? get sessionId => _sessionId;

  Future<void> initialize() async {
    _sessionId = _uuid.v4();
    await _loadQueuesFromDisk();
    debugPrint('TrackingService initialized. Session ID: $_sessionId');
  }

  // Start tracking session
  Future<void> startSession(Map<String, dynamic>? userData) async {
    _userData = userData;
    if (_sessionId == null) {
      _sessionId = _uuid.v4();
    }

    // Capture battery start level
    int? batteryStart;
    try {
      batteryStart = await _battery.batteryLevel;
    } catch (e) {
      debugPrint('TrackingService: Failed to get battery level: $e');
    }

    // Capture device & OS info
    String deviceId = 'Unknown';
    String deviceModel = 'Unknown';
    String osName = 'Unknown';
    String osVersion = 'Unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osName = 'Android';
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'Unknown';
        deviceModel = iosInfo.name;
        osName = 'iOS';
        osVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      debugPrint('TrackingService: Failed to get device info: $e');
    }

    // Capture app version
    String appVersion = '1.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('TrackingService: Failed to get package info: $e');
    }

    // Track session start API
    final url = Uri.parse('${AppConstants.baseUrl}/track_session');
    try {
      final response = await http.post(url, body: {
        'session_id': _sessionId!,
        'user_id': (_userData?['user_id'] ?? _userData?['id'] ?? '').toString(),
        'device_id': deviceId,
        'device_model': deviceModel,
        'os_name': osName,
        'os_version': osVersion,
        'app_version': appVersion,
        'battery_start': batteryStart?.toString() ?? '',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('TrackingService: Session registered on server successfully.');
      } else {
        debugPrint('TrackingService: Server session track returned: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('TrackingService: Error registering session: $e');
    }

    // Start periodic sync timer (every 30 seconds)
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncOutbox();
    });

    // Record initial battery and memory logs
    logPerformance('app_startup', 0);
    logMemoryAndBattery();
  }

  // Stop tracking session
  Future<void> stopSession() async {
    _syncTimer?.cancel();
    _syncTimer = null;

    int? batteryEnd;
    try {
      batteryEnd = await _battery.batteryLevel;
    } catch (e) {
      debugPrint('TrackingService: Failed to get battery level: $e');
    }

    // Sync remaining data immediately with end battery status
    await syncOutbox(batteryEnd: batteryEnd);
    _sessionId = null;
    _userData = null;
    debugPrint('TrackingService: Session stopped.');
  }

  // Set current active feature/screen name
  void logCurrentFeature(String featureName) {
    _currentFeature = featureName;
    debugPrint('TrackingService: Feature changed to: $featureName');
  }

  // Log custom actions (e.g. APK download clicked, button clicked)
  void logEvent(String eventName, [Map<String, dynamic>? metadata]) {
    _eventQueue.add({
      'event_name': eventName,
      'event_metadata': metadata,
      'created_at': DateTime.now().toIso8601String(),
    });
    _saveQueuesToDisk();
  }

  // Log health events (crashes)
  void logCrash(String message, String stackTrace) {
    _healthQueue.add({
      'log_type': 'crash',
      'message': message,
      'stack_trace': stackTrace,
      'created_at': DateTime.now().toIso8601String(),
    });
    _saveQueuesToDisk();
    
    // Attempt instant sync for crashes
    syncOutbox();
  }

  // Log performance (screen loading speed)
  void logPerformance(String actionName, int durationMs) {
    _healthQueue.add({
      'log_type': 'performance',
      'message': actionName,
      'loading_time_ms': durationMs,
      'created_at': DateTime.now().toIso8601String(),
    });
    _saveQueuesToDisk();
  }

  // Log system resources usage
  Future<void> logMemoryAndBattery() async {
    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {}

    double memoryUsageMb = 0.0;
    try {
      // Get Resident Set Size (RSS) in MB (only available on Android/iOS/Desktop, not Web)
      memoryUsageMb = ProcessInfo.currentRss / (1024 * 1024);
    } catch (e) {
      debugPrint('TrackingService: Failed to get memory RSS: $e');
    }

    _healthQueue.add({
      'log_type': 'memory',
      'message': 'Memory Usage',
      'memory_used_mb': memoryUsageMb,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (batteryLevel != null) {
      _healthQueue.add({
        'log_type': 'battery',
        'message': 'Battery Status',
        'battery_level': batteryLevel,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    _saveQueuesToDisk();
  }

  // Sync queues to CI4 Server
  Future<void> syncOutbox({int? batteryEnd}) async {
    if (_sessionId == null || _isSyncing) return;
    if (_eventQueue.isEmpty && _healthQueue.isEmpty && _currentFeature == null && batteryEnd == null) return;

    _isSyncing = true;
    
    // Freeze current queues for sync
    final eventsToSync = List<Map<String, dynamic>>.from(_eventQueue);
    final healthToSync = List<Map<String, dynamic>>.from(_healthQueue);

    int? currentBattery = batteryEnd;
    if (currentBattery == null) {
      try {
        currentBattery = await _battery.batteryLevel;
      } catch (_) {}
    }

    final url = Uri.parse('${AppConstants.baseUrl}/track_events_batch');
    try {
      final response = await http.post(url, body: {
        'session_id': _sessionId!,
        'current_feature': _currentFeature ?? '',
        'battery_level': currentBattery?.toString() ?? '',
        'events': json.encode(eventsToSync),
        'health_logs': json.encode(healthToSync),
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Remove synced items from queue
        _eventQueue.removeRange(0, eventsToSync.length);
        _healthQueue.removeRange(0, healthToSync.length);
        await _saveQueuesToDisk();
        debugPrint('TrackingService: Synced ${eventsToSync.length} events and ${healthToSync.length} health logs.');
      } else {
        debugPrint('TrackingService: Sync batch returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('TrackingService: Sync failed due to connection error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── LOCAL PERSISTENCE HELPERS ──
  Future<File> get _outboxFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tracking_outbox.json');
  }

  Future<void> _saveQueuesToDisk() async {
    try {
      final file = await _outboxFile;
      final data = {
        'events': _eventQueue,
        'health': _healthQueue,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('TrackingService: Failed to save queue to disk: $e');
    }
  }

  Future<void> _loadQueuesFromDisk() async {
    try {
      final file = await _outboxFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        if (data is Map) {
          if (data['events'] is List) {
            _eventQueue = List<Map<String, dynamic>>.from(data['events']);
          }
          if (data['health'] is List) {
            _healthQueue = List<Map<String, dynamic>>.from(data['health']);
          }
        }
      }
    } catch (e) {
      debugPrint('TrackingService: Failed to load queue from disk: $e');
    }
  }
}
