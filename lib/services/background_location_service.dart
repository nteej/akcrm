import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/dio.dart';

// Top-level entry point functions for background service
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  log('==================================================');
  log('==== iOS BACKGROUND SERVICE ====');
  log('Time: ${DateTime.now()}');
  log('==================================================');

  // iOS background location updates will continue
  // iOS does not support custom notification updates like Android
  // The system will show a standard location tracking indicator

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  log('==================================================');
  log('==== BACKGROUND SERVICE STARTED ====');
  log('Service instance type: ${service.runtimeType}');
  log('Time: ${DateTime.now()}');
  log('Process ID: ${service.hashCode}');
  log('==================================================');

  // CRITICAL: Set as foreground service IMMEDIATELY
  // This prevents Android from killing the service
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    log('✓ Service set as FOREGROUND immediately');
    log('✓ Service will survive app close and device reboot');
  }

  // Initial notification with persistent info
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'SmartForce - Starting Tracking 🔄',
      content: 'Initializing... Service will run independently even when app is closed',
    );
    log('✓ Initial notification set');
  }

  // Load tracking state
  final prefs = await SharedPreferences.getInstance();
  final jobId = prefs.getInt('tracking_job_id');
  final userId = prefs.getString('tracking_user_id');
  final deviceId = prefs.getString('tracking_device_id');
  final isTracking = prefs.getBool('is_tracking') ?? false;
  final jobName = prefs.getString('tracking_job_name') ?? 'Unknown Job';
  final jobStartTime = prefs.getInt('tracking_job_start_time');

  log('Loaded state: isTracking=$isTracking, jobId=$jobId, userId=$userId, jobName=$jobName');

  if (!isTracking || jobId == null || userId == null || deviceId == null) {
    log('⚠️ WARNING: No active tracking job found. Service will wait for job start.');
  }

  // Track timer state
  int timerCount = 0;
  int successCount = 0;
  int errorCount = 0;

  // Timer for updating notification with elapsed time
  Timer? notificationUpdateTimer;

  // Timer for fetching live location status
  Timer? liveStatusTimer;

  // Live location status data
  Map<String, dynamic>? liveLocationData;

  // Handle stop command - ONLY way to stop the service
  service.on('stopService').listen((event) {
    log('⚠ Stop service command received - stopping service');
    notificationUpdateTimer?.cancel();
    liveStatusTimer?.cancel();
    log('✓ Notification and status timers canceled');
    service.stopSelf();
  });

  // Function to calculate elapsed time
  String getElapsedTime(int? startTimeMs) {
    if (startTimeMs == null) return '00:00:00';
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
    final now = DateTime.now();
    final elapsed = now.difference(startTime);

    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Function to fetch live location status from API
  Future<Map<String, dynamic>?> fetchLiveLocationStatus() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth');

      if (token == null) {
        log('No auth token for live status fetch');
        return null;
      }

      final response = await dio().get(
        '/my-live-location',
        options: dio_lib.Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      log('Error fetching live status: $e');
    }
    return null;
  }

  // Function to update notification with live status
  void updateNotificationWithStatus(AndroidServiceInstance androidService, String jobName, int? startTimeMs, Map<String, dynamic>? liveData) {
    final elapsedTime = getElapsedTime(startTimeMs);

    String statusEmoji = '🟢';
    String statusText = 'Active';

    if (liveData != null) {
      final trackingStatus = liveData['tracking_status'];
      final latestLocation = liveData['latest_location'];
      final lastUpdateSecondsAgo = trackingStatus?['last_update_seconds_ago'] ?? 999;

      // Determine status
      if (lastUpdateSecondsAgo < 30) {
        statusEmoji = '🟢';
        statusText = 'Live';
      } else if (lastUpdateSecondsAgo < 120) {
        statusEmoji = '🔵';
        statusText = 'Recent';
      } else {
        statusEmoji = '🟠';
        statusText = 'Delayed';
      }

      final recordedAt = latestLocation?['recorded_at'] ?? 'Unknown';

      androidService.setForegroundNotificationInfo(
        title: '$statusEmoji $jobName - $statusText',
        content: '⏱️ $elapsedTime | 📍 Last: $recordedAt',
      );
    } else {
      androidService.setForegroundNotificationInfo(
        title: '🏃 $jobName - Running',
        content: '⏱️ $elapsedTime | Sending location...',
      );
    }
  }

  // Start notification update timer (Android only)
  // iOS does not support custom notification updates - system shows standard location indicator
  if (service is AndroidServiceInstance && isTracking && jobId != null) {
    updateNotificationWithStatus(service, jobName, jobStartTime, liveLocationData);

    // Timer for updating notification every second (for elapsed time)
    notificationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stillTracking = prefs.getBool('is_tracking') ?? false;
        final isPaused = prefs.getBool('is_paused') ?? false;
        final currentJobName = prefs.getString('tracking_job_name') ?? jobName;
        final currentStartTime = prefs.getInt('tracking_job_start_time') ?? jobStartTime;

        if (!stillTracking) {
          timer.cancel();
          return;
        }

        // Show paused notification if job is paused
        if (isPaused) {
          final pausedAt = prefs.getInt('paused_at');
          final pausedTime = pausedAt != null
              ? DateTime.fromMillisecondsSinceEpoch(pausedAt)
              : DateTime.now();
          final pauseDuration = DateTime.now().difference(pausedTime);
          final pauseMinutes = pauseDuration.inMinutes;
          final pauseSeconds = pauseDuration.inSeconds.remainder(60);

          service.setForegroundNotificationInfo(
            title: '⏸️ $currentJobName - PAUSED',
            content: 'Paused for ${pauseMinutes}m ${pauseSeconds}s | Tracking stopped',
          );
          return;
        }

        updateNotificationWithStatus(service, currentJobName, currentStartTime, liveLocationData);
      } catch (e) {
        log('Error updating notification: $e');
      }
    });

    // Timer for fetching live location status every 15 seconds
    liveStatusTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stillTracking = prefs.getBool('is_tracking') ?? false;

        if (!stillTracking) {
          timer.cancel();
          return;
        }

        log('Fetching live location status for notification...');
        liveLocationData = await fetchLiveLocationStatus();
        if (liveLocationData != null) {
          log('✓ Live status fetched successfully');
        }
      } catch (e) {
        log('Error fetching live status: $e');
      }
    });

    // Fetch initial status
    Future.microtask(() async {
      liveLocationData = await fetchLiveLocationStatus();
    });
  }

  // Send location immediately on start
  try {
    final prefs = await SharedPreferences.getInstance();
    final jobId = prefs.getInt('tracking_job_id');
    final userId = prefs.getString('tracking_user_id');
    final deviceId = prefs.getString('tracking_device_id');

    if (jobId != null && userId != null && deviceId != null) {
      log('Sending initial location for job $jobId');
      await _sendLocationFromBackground(
        service: service,
        jobId: jobId,
        userId: userId,
        deviceId: deviceId,
      );
      successCount++;
    }
  } catch (e) {
    log('Error sending initial location: $e');
    errorCount++;
  }

  // Send location every 10 seconds (6 times per minute)
  // Using Timer.periodic with extensive error handling and recovery
  // This timer runs INDEPENDENTLY of app state
  log('⏰ Starting timer - will fire every 10 seconds');
  log('⏰ Timer is INDEPENDENT of app lifecycle');

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      timerCount++;
      log('');
      log('════════════════════════════════════════════════');
      log('⏰ Timer tick #$timerCount at ${DateTime.now()}');
      log('📊 Stats: Success=$successCount, Errors=$errorCount');
      log('════════════════════════════════════════════════');

      final prefs = await SharedPreferences.getInstance();
      final isTracking = prefs.getBool('is_tracking') ?? false;
      final isPaused = prefs.getBool('is_paused') ?? false;

      if (!isTracking) {
        log('⚠️ Tracking disabled in SharedPreferences, stopping service');
        timer.cancel();
        service.stopSelf();
        return;
      }

      // Check if job is paused
      if (isPaused) {
        log('⏸️ Job is PAUSED - skipping location send');
        // Update notification to show paused status
        if (service is AndroidServiceInstance) {
          final jobName = prefs.getString('tracking_job_name') ?? 'Unknown Job';
          final pausedAt = prefs.getInt('paused_at');
          final pausedTime = pausedAt != null
              ? DateTime.fromMillisecondsSinceEpoch(pausedAt)
              : DateTime.now();
          final pauseDuration = DateTime.now().difference(pausedTime);
          final pauseMinutes = pauseDuration.inMinutes;

          service.setForegroundNotificationInfo(
            title: '⏸️ $jobName - PAUSED',
            content: 'Job paused for ${pauseMinutes}m | Location tracking stopped',
          );
        }
        return; // Skip sending location when paused
      }

      final jobId = prefs.getInt('tracking_job_id');
      final userId = prefs.getString('tracking_user_id');
      final deviceId = prefs.getString('tracking_device_id');

      if (jobId == null || userId == null || deviceId == null) {
        log('⚠️ WARNING: Missing tracking data');
        log('   jobId: $jobId');
        log('   userId: $userId');
        log('   deviceId: $deviceId');
        log('   Skipping this tick, will retry in 10 seconds');
        return;
      }

      log('📍 Attempting to send location for job #$jobId');

      await _sendLocationFromBackground(
        service: service,
        jobId: jobId,
        userId: userId,
        deviceId: deviceId,
      );

      successCount++;
      log('✅ Location sent successfully (total success: $successCount)');

    } catch (e, stackTrace) {
      errorCount++;
      log('✗ ERROR in timer tick #$timerCount: $e');
      log('Stack trace: $stackTrace');

      // Keep service foreground even on error
      if (service is AndroidServiceInstance) {
        try {
          await service.setAsForegroundService();

          final prefs = await SharedPreferences.getInstance();
          final currentJobName = prefs.getString('tracking_job_name') ?? 'Unknown Job';

          service.setForegroundNotificationInfo(
            title: '🟠 $currentJobName - Retry',
            content: 'Tick #$timerCount error, retrying... | Errors: $errorCount',
          );
        } catch (notificationError) {
          log('⚠ Could not update notification: $notificationError');
        }
      }

      // Don't cancel timer on error - keep trying
      // Timer will continue and retry on next tick
    }
  });

  log('Timer started - will tick every 10 seconds');
}

@pragma('vm:entry-point')
Future<void> _sendLocationFromBackground({
  required ServiceInstance service,
  required int jobId,
  required String userId,
  required String deviceId,
}) async {
  final startTime = DateTime.now();
  log('→ Starting location send for job $jobId');

  try {
    // Step 1: Get auth token
    log('  Step 1: Reading auth token...');
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth');

    if (token == null) {
      log('  ✗ No auth token found');
      throw Exception('No auth token');
    }
    log('  ✓ Auth token retrieved');

    // Step 2: Check location permission
    log('  Step 2: Checking location permission...');
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      log('  ✗ Location permission denied: $permission');
      throw Exception('Location permission denied');
    }
    log('  ✓ Location permission granted: $permission');

    // Step 3: Get current position
    log('  Step 3: Getting GPS position...');
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          log('  ✗ GPS timeout, using last known position');
          throw TimeoutException('GPS timeout');
        },
      );
      log('  ✓ GPS position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      // Fallback to last known position
      log('  ! Trying last known position...');
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition == null) {
        log('  ✗ No last known position available');
        throw Exception('Unable to get location');
      }
      position = lastPosition;
      log('  ✓ Using last known position: ${position.latitude}, ${position.longitude}');
    }

    final payload = {
      'lat': position.latitude,
      'long': position.longitude,
      'user_id': userId,
      'job_id': jobId,
      'device_id': deviceId,
    };

    // Step 4: Send to API
    log('  Step 4: Sending to API...');
    log('  Payload: $payload');

    final response = await dio().post(
      '/user-location',
      options: dio_lib.Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
      data: payload,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        log('  ✗ API request timeout');
        throw TimeoutException('API timeout');
      },
    );

    log('  ✓ API Response: ${response.statusCode}');

    // Step 5: Update notification - will be updated by notification timer with full status
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;

    log('✓ Location send completed in ${elapsed}ms');
  } catch (e, stackTrace) {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    log('✗ Location send FAILED after ${elapsed}ms: $e');
    log('Stack: $stackTrace');

    // Update notification with error but keep service running
    if (service is AndroidServiceInstance) {
      // Force service to stay foreground even on error
      await service.setAsForegroundService();

      final prefs = await SharedPreferences.getInstance();
      final currentJobName = prefs.getString('tracking_job_name') ?? 'Unknown Job';

      service.setForegroundNotificationInfo(
        title: '🔴 $currentJobName - Error',
        content: 'Job #$jobId | Retrying location send...',
      );
    }

    // Re-throw to be caught by timer handler
    rethrow;
  }
}

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final storage = const FlutterSecureStorage();

  /// Initialize the background service
  Future<void> initialize() async {
    log('Initializing background location service');

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'Location Tracking',
        initialNotificationContent: 'Starting location tracking service...',
        foregroundServiceNotificationId: 888,
        autoStartOnBoot: true, // Restart service after device reboot
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    log('Background service initialized');
  }

  /// Start tracking location
  Future<void> startTracking({
    required int jobId,
    required String userId,
    required String deviceId,
  }) async {
    log('============================================');
    log('START TRACKING REQUEST');
    log('Job ID: $jobId');
    log('User ID: $userId');
    log('Device ID: $deviceId');
    log('============================================');

    // Save tracking state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tracking_job_id', jobId);
    await prefs.setString('tracking_user_id', userId);
    await prefs.setString('tracking_device_id', deviceId);
    await prefs.setBool('is_tracking', true);

    log('Tracking state saved to SharedPreferences');

    final isRunning = await _service.isRunning();
    log('Service running status: $isRunning');

    if (!isRunning) {
      log('Starting background service...');
      final started = await _service.startService();
      log('Service start result: $started');
    } else {
      log('Service already running - tracking will continue');
    }

    log('============================================');
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    log('============================================');
    log('STOP TRACKING REQUEST');
    log('============================================');

    // Clear tracking state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_job_id');
    await prefs.remove('tracking_user_id');
    await prefs.remove('tracking_device_id');
    await prefs.remove('tracking_job_name');
    await prefs.remove('tracking_job_start_time');
    await prefs.setBool('is_tracking', false);

    log('Tracking state cleared from SharedPreferences');

    _service.invoke('stopService');
    log('Stop service command sent');

    log('============================================');
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}
