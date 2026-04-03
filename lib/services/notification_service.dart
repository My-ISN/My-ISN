import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../announcement_page.dart';
import '../todo_list/todo_list_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;

    // 1. Request permissions (especially for Android 13+)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 1b. Subscribe to App Updates topic
    await _fcm.subscribeToTopic('app_updates');

    // 2. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Initialize Local Notifications Plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            final data = json.decode(response.payload!);
            _handleNotificationClick(data);
          }
        },
      );
    } catch (e) {
      debugPrint("Error initializing local notifications: $e");
    }

    // 4. Create a High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'foxgeen_push_channel', // id
      'My ISN Push Notifications', // title
      description:
          'Digunakan untuk notifikasi pengumuman penting.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // 5. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");
      debugPrint("Message data: ${message.data}");
      _showLocalNotification(message, channel);
    });

    // 6. Handle clicks when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    // 7. Check for initial message (if app was terminated)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data);
    }

    // 8. Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint("FCM Token Refreshed: $newToken");
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: 'user_data');
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        await updateTokenOnServer(userData);
      }
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint("Notification Clicked Data: $data");
    if (data.containsKey('announcement_id')) {
      final id = int.tryParse(data['announcement_id'].toString());
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (context) => AnnouncementPage(initialAnnouncementId: id),
        ),
      );
    } else if (data['type'] == 'todo' || data.containsKey('todo_id')) {
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const TodoListPage(),
        ),
      );
    }
  }

  Future<void> _showLocalNotification(
    RemoteMessage message,
    AndroidNotificationChannel channel,
  ) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: 'ic_notification',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> updateTokenOnServer(Map<String, dynamic> userData) async {
    try {
      String? token = await _fcm.getToken();
      if (token == null) return;

      final userId = userData['user_id'] ?? userData['id'];
      if (userId == null) return;

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = "unknown";
      String deviceName = "Unknown Device";

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "unknown_ios";
        deviceName = iosInfo.name;
      }

      final url = Uri.parse(
        'https://foxgeen.com/HRIS/mobileapi/save_fcm_token',
      );
      final response = await http.post(
        url,
        body: {
          'user_id': userId.toString(),
          'fcm_token': token,
          'device_id': deviceId,
          'device_name': deviceName,
        },
      );

      debugPrint("FCM Token update response: ${response.body}");
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }
}
