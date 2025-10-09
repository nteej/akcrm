import 'dart:developer';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helper/dio.dart';

class RunningJobManager {
  final storage = const FlutterSecureStorage();

  /// Check if user has a running job from API
  Future<Map<String, dynamic>?> checkForRunningJob() async {
    try {
      final token = await storage.read(key: 'auth');
      if (token == null) {
        log('No auth token, cannot check for running job');
        return null;
      }

      log('Checking for running job via /my-live-location API...');

      final response = await dio().get(
        '/my-live-location',
        options: dio_lib.Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final hasRunningJob = data['has_running_job'] ?? false;

        if (hasRunningJob) {
          log('✓ Running job found!');
          return data;
        } else {
          log('No running job found');
          return null;
        }
      }
    } catch (e) {
      log('Error checking for running job: $e');
    }
    return null;
  }

  /// Take over a running job on this device
  /// This will start tracking on the current device with the same job ID
  Future<bool> takeOverJob({
    required int jobId,
    required String userId,
    required String deviceId,
  }) async {
    try {
      log('Taking over job $jobId on device $deviceId');

      // The background service will automatically start sending location
      // with the new device_id for the same job_id

      return true;
    } catch (e) {
      log('Error taking over job: $e');
      return false;
    }
  }

  /// Stop a running job (finish it)
  Future<bool> stopRunningJob(int jobId) async {
    try {
      final token = await storage.read(key: 'auth');
      final userId = await storage.read(key: 'user_id');

      if (token == null || userId == null) {
        log('Missing credentials to stop job');
        return false;
      }

      log('Stopping running job $jobId');

      // Call the PUT /runners/{id} endpoint to finish the job
      final response = await dio().put(
        '/runners/$jobId',
        options: dio_lib.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'finished_at': DateTime.now().toIso8601String(),
          'user_id': userId,
          'end_latlong': '0.0,0.0', // Default if we can't get location
        },
      );

      if (response.statusCode == 200) {
        log('✓ Job $jobId stopped successfully');
        return true;
      }
    } catch (e) {
      log('Error stopping job: $e');
    }
    return false;
  }

  /// Get device name/info for display
  String getDeviceInfo(String? deviceId) {
    if (deviceId == null) return 'Unknown Device';

    // Truncate device ID for display
    if (deviceId.length > 20) {
      return deviceId.substring(0, 17) + '...';
    }
    return deviceId;
  }

  /// Format duration from start time
  String formatDuration(String? startedAt) {
    if (startedAt == null) return 'Unknown duration';

    try {
      final startTime = DateTime.parse(startedAt);
      final now = DateTime.now();
      final duration = now.difference(startTime);

      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);

      if (hours > 0) {
        return '$hours hours, $minutes minutes';
      } else {
        return '$minutes minutes';
      }
    } catch (e) {
      return 'Unknown duration';
    }
  }
}
