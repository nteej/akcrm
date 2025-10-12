import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:finnerp/services/local_notifications_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as di;
import 'package:finnerp/helper/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FirebaseMessagingService {
  // Private constructor for singleton pattern
  FirebaseMessagingService._internal();

  // Singleton instance
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();

  // Factory constructor to provide singleton instance
  factory FirebaseMessagingService.instance() => _instance;

  // Reference to local notifications service for displaying notifications
  LocalNotificationsService? _localNotificationsService;

  // Secure storage for tracking token sync status
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for secure storage
  static const String _fcmTokenKey = 'fcm_token';
  static const String _tokenSyncedKey = 'fcm_token_synced';
  static const String _notificationPermissionKey = 'notification_permission_granted';

  /// Initialize Firebase Messaging and sets up all message listeners
  Future<void> init({required LocalNotificationsService localNotificationsService}) async {
    // Init local notifications service
    _localNotificationsService = localNotificationsService;

    // Handle FCM token
    _handlePushNotificationsToken();

    // Request user permission for notifications
    _requestPermission();

    // Register handler for background messages (app terminated)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for messages when the app is in foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Listen for notification taps when the app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check for initial message that opened the app from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }
  }

  /// Retrieves and manages the FCM token for push notifications
  Future<void> _handlePushNotificationsToken() async {
    // Get the FCM token for the device
    final token = await FirebaseMessaging.instance.getToken();
    print('Push notifications token: $token');

    if (token != null) {
      // Store token locally
      await _storage.write(key: _fcmTokenKey, value: token);

      // Check if we need to sync the token
      final isSynced = await _storage.read(key: _tokenSyncedKey);
      if (isSynced != 'true') {
        // Attempt to sync token with server
        await _syncTokenWithServer(token);
      }
    }

    // Listen for token refresh events
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      print('FCM token refreshed: $fcmToken');
      // Store new token locally
      await _storage.write(key: _fcmTokenKey, value: fcmToken);
      // Mark as not synced since token changed
      await _storage.write(key: _tokenSyncedKey, value: 'false');
      // Sync new token with server
      await _syncTokenWithServer(fcmToken);
    }).onError((error) {
      // Handle errors during token refresh
      print('Error refreshing FCM token: $error');
    });
  }

  /// Requests notification permission from the user
  Future<void> _requestPermission() async {
    // Request permission for alerts, badges, and sounds
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Log the user's permission decision
    print('User granted permission: ${result.authorizationStatus}');

    // Store permission status
    final isGranted = result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _storage.write(
      key: _notificationPermissionKey,
      value: isGranted.toString(),
    );
  }

  /// Handles messages received while the app is in the foreground
  void _onForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.data.toString()}');
    final notificationData = message.notification;
    if (notificationData != null) {
      // Display a local notification using the service
      _localNotificationsService?.showNotification(
          notificationData.title, notificationData.body, message.data.toString());
    }
  }

  /// Handles notification taps when app is opened from the background or terminated state
  void _onMessageOpenedApp(RemoteMessage message) {
    print('Notification caused the app to open: ${message.data.toString()}');
    // TODO: Add navigation or specific handling based on message data
  }

  /// Syncs FCM token with the server via API
  Future<void> _syncTokenWithServer(String fcmToken) async {
    try {
      // Get auth token
      final authToken = await _storage.read(key: 'auth');
      if (authToken == null) {
        print('No auth token found, cannot sync FCM token');
        return;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Prepare payload
      final payload = {
        'fcm_token': fcmToken,
        'device_id': deviceInfo['device_id'],
        'platform': deviceInfo['platform'],
        'device_info': {
          'model': deviceInfo['model'],
          'os_version': deviceInfo['os_version'],
          'app_version': deviceInfo['app_version'],
        },
        'enabled': true,
      };

      print('Syncing FCM token with server: $payload');

      // Send to server
      final response = await dio().post(
        '/notifications',
        data: json.encode(payload),
        options: di.Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark as synced
        await _storage.write(key: _tokenSyncedKey, value: 'true');
        print('FCM token synced successfully with server');
      }
    } catch (e) {
      print('Error syncing FCM token with server: $e');
      // Keep sync status as false so we can retry later
      await _storage.write(key: _tokenSyncedKey, value: 'false');
    }
  }

  /// Gets device information for the API payload
  Future<Map<String, String>> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = '';
    String platform = '';
    String model = '';
    String osVersion = '';

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
      platform = 'android';
      model = '${androidInfo.brand} ${androidInfo.model}';
      osVersion = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
      platform = 'ios';
      model = iosInfo.model;
      osVersion = 'iOS ${iosInfo.systemVersion}';
    } else {
      platform = 'web';
      deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      model = 'Web Browser';
      osVersion = 'Web';
    }

    // Get app version
    String appVersion = '0.0.0';
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (e) {
      print('Error getting app version: $e');
    }

    return {
      'device_id': deviceId,
      'platform': platform,
      'model': model,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }

  /// Check if notification permission has been granted
  Future<bool> isNotificationPermissionGranted() async {
    final permission = await _storage.read(key: _notificationPermissionKey);
    return permission == 'true';
  }

  /// Check if FCM token has been synced with server
  Future<bool> isTokenSynced() async {
    final synced = await _storage.read(key: _tokenSyncedKey);
    return synced == 'true';
  }

  /// Get the current FCM token
  Future<String?> getCurrentToken() async {
    return await _storage.read(key: _fcmTokenKey);
  }

  /// Manually trigger token sync (useful for retry logic)
  Future<void> retryTokenSync() async {
    final token = await getCurrentToken();
    if (token != null) {
      await _syncTokenWithServer(token);
    }
  }

  /// Reset sync status (useful after logout or when user uninstalls)
  Future<void> resetSyncStatus() async {
    await _storage.delete(key: _tokenSyncedKey);
    await _storage.delete(key: _fcmTokenKey);
    await _storage.delete(key: _notificationPermissionKey);
  }
}

/// Background message handler (must be top-level function or static)
/// Handles messages when the app is fully terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.data.toString()}');
}
