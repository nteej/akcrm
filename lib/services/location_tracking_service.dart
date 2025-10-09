import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart' as dio_lib;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/dio.dart';
import 'background_location_service.dart';

class LocationTrackingService {
  final storage = const FlutterSecureStorage();
  final BackgroundLocationService _backgroundService = BackgroundLocationService();
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Initialize the service (call once at app start)
  Future<void> initialize() async {
    await _backgroundService.initialize();
  }

  /// Start tracking location with 4 calls per minute (every 15 seconds)
  Future<void> startTracking({
    required int jobId,
    required String userId,
    required String deviceId,
  }) async {
    if (_isTracking) {
      log('Location tracking already running');
      return;
    }

    _isTracking = true;
    log('Starting location tracking for job $jobId');

    // Persist tracking state
    await _saveTrackingState(
      jobId: jobId,
      userId: userId,
      deviceId: deviceId,
      isTracking: true,
    );

    // Send location immediately on start
    await _sendLocation(jobId: jobId, userId: userId, deviceId: deviceId);

    // Start background service
    await _backgroundService.startTracking(
      jobId: jobId,
      userId: userId,
      deviceId: deviceId,
    );

    log('Location tracking started successfully');
  }

  /// Stop tracking location
  Future<void> stopTracking() async {
    _isTracking = false;

    // Stop background service
    await _backgroundService.stopTracking();

    // Clear tracking state
    await _clearTrackingState();

    log('Location tracking stopped');
  }

  /// Save tracking state to SharedPreferences
  Future<void> _saveTrackingState({
    required int jobId,
    required String userId,
    required String deviceId,
    required bool isTracking,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tracking_job_id', jobId);
    await prefs.setString('tracking_user_id', userId);
    await prefs.setString('tracking_device_id', deviceId);
    await prefs.setBool('is_tracking', isTracking);
    log('Tracking state saved: jobId=$jobId, isTracking=$isTracking');
  }

  /// Clear tracking state
  Future<void> _clearTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_job_id');
    await prefs.remove('tracking_user_id');
    await prefs.remove('tracking_device_id');
    await prefs.setBool('is_tracking', false);
    log('Tracking state cleared');
  }

  /// Resume tracking from saved state (call on app start)
  Future<void> resumeTrackingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final isTracking = prefs.getBool('is_tracking') ?? false;

    if (isTracking) {
      final jobId = prefs.getInt('tracking_job_id');
      final userId = prefs.getString('tracking_user_id');
      final deviceId = prefs.getString('tracking_device_id');

      if (jobId != null && userId != null && deviceId != null) {
        log('Resuming tracking for job $jobId');
        await startTracking(
          jobId: jobId,
          userId: userId,
          deviceId: deviceId,
        );
      }
    }
  }

  /// Send current location to API
  Future<void> _sendLocation({
    required int jobId,
    required String userId,
    required String deviceId,
  }) async {
    try {
      // Get current location
      Position position = await _getCurrentPosition();

      final token = await storage.read(key: 'auth');
      if (token == null) {
        log('No auth token found, skipping location update');
        return;
      }

      // Prepare payload
      final payload = {
        'lat': position.latitude,
        'long': position.longitude,
        'user_id': userId,
        'job_id': jobId,
        'device_id': deviceId,
      };

      log('Sending location: lat=${position.latitude}, long=${position.longitude}, job_id=$jobId,payload: $payload');

      // Send to API
      await dio().post(
        '/user-location',
        options: dio_lib.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: payload,
        
      );

      log('Location sent successfully');
    } catch (e) {
      log('Error sending location: $e');
      // Continue tracking even if one request fails
    }
  }

  /// Get current GPS position
  Future<Position> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      return position;
    } catch (e) {
      log('Error getting location: $e');
      rethrow;
    }
  }

  /// Dispose the service
  void dispose() {
    stopTracking();
  }
}
