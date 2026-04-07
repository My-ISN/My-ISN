import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'log_service.dart';
import '../announcement_page.dart';
import '../todo_list/todo_list_page.dart';
import '../constants.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Log.i("Handling a background message: ${message.messageId}");
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
      Log.e("Error initializing local notifications: $e");
    }

    await createChannel();

    // 5. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      Log.i("Foreground message received: ${message.notification?.title}");
      Log.d("Message data: ${message.data}");
      
      // Get the latest channel to ensure correct sound
      const storage = FlutterSecureStorage();
      String? sound = await storage.read(key: 'notification_sound');
      
      String soundResource = (sound == null || sound == 'default') 
          ? 'notification_tone_swift_gesture' 
          : sound;
      
      String channelId = 'foxgeen_push_channel_$soundResource';

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        'My ISN Push Notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResource),
      );

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
      Log.i("FCM Token Refreshed: $newToken");
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: 'user_data');
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        await updateTokenOnServer(userData);
      }
    });
  }

  Future<void> createChannel() async {
    const storage = FlutterSecureStorage();
    String? sound = await storage.read(key: 'notification_sound');
    
    // Default to swift gesture if nothing is selected or 'default' is chosen
    String soundResource = (sound == null || sound == 'default') 
        ? 'notification_tone_swift_gesture' 
        : sound;
    
    String channelId = 'foxgeen_push_channel_$soundResource';

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      'My ISN Push Notifications',
      description: 'Digunakan untuk notifikasi pengumuman penting.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundResource),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    Log.i("Notification Clicked Data: $data");
    if (data.containsKey('announcement_id')) {
      final id = int.tryParse(data['announcement_id'].toString());
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (context) => AnnouncementPage(initialAnnouncementId: id),
        ),
      );
    } else if (data['type'] == 'todo' || data.containsKey('todo_id')) {
      navigatorKey?.currentState?.push(
        MaterialPageRoute(builder: (context) => const TodoListPage()),
      );
    }
  }

  Future<void> _showLocalNotification(
    RemoteMessage message,
    AndroidNotificationChannel channel,
  ) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      const storage = FlutterSecureStorage();
      String? sound = await storage.read(key: 'notification_sound');

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
            playSound: true,
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

      // Get current channel ID
      const storage = FlutterSecureStorage();
      String? sound = await storage.read(key: 'notification_sound');
      
      String soundResource = (sound == null || sound == 'default') 
          ? 'notification_tone_swift_gesture' 
          : sound;
      
      String channelId = 'foxgeen_push_channel_$soundResource';

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
        '${AppConstants.baseUrl}/save_fcm_token',
      );
      final response = await http.post(
        url,
        body: {
          'user_id': userId.toString(),
          'fcm_token': token,
          'device_id': deviceId,
          'device_name': deviceName,
          'notification_channel': channelId,
        },
      );

      Log.i("FCM Token update response: ${response.body}");
    } catch (e) {
      Log.e("Error updating FCM token: $e");
    }
  }
}
