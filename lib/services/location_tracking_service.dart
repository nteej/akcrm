import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart' as dio_lib;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helper/dio.dart';

class LocationTrackingService {
  Timer? _timer;
  final storage = FlutterSecureStorage();
  bool _isTracking = false;

  bool get isTracking => _isTracking;

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

    // Send location immediately on start
    await _sendLocation(jobId: jobId, userId: userId, deviceId: deviceId);

    // Send location every 15 seconds (4 times per minute)
    _timer = Timer.periodic(Duration(seconds: 15), (timer) async {
      if (_isTracking) {
        await _sendLocation(jobId: jobId, userId: userId, deviceId: deviceId);
      }
    });
  }

  /// Stop tracking location
  void stopTracking() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    _isTracking = false;
    log('Location tracking stopped');
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
