import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const String _tag = 'LocationService';

  /// Comprehensive location service check that ensures:
  /// 1. Location services are enabled
  /// 2. Permissions are granted
  /// 3. Shows appropriate dialogs for user action
  static Future<bool> checkLocationRequirements(BuildContext context) async {
    try {
      log('$_tag: Checking location requirements...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('$_tag: Location services are disabled');
        if (!context.mounted) return false;
        bool enabled = await _showLocationServiceDialog(context);
        if (!enabled) {
          return false;
        }
        // Recheck after user action
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          log('$_tag: Location services still disabled after prompt');
          return false;
        }
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      log('$_tag: Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        log('$_tag: Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            _showPermissionDeniedDialog(context);
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log('$_tag: Location permission permanently denied');
        if (context.mounted) {
          _showPermissionPermanentlyDeniedDialog(context);
        }
        return false;
      }

      log('$_tag: All location requirements satisfied');
      return true;
    } catch (e) {
      log('$_tag: Error checking location requirements: $e');
      return false;
    }
  }

  /// Shows dialog when location services are disabled
  static Future<bool> _showLocationServiceDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.red),
              SizedBox(width: 8),
              Text('Location Required'),
            ],
          ),
          content: const Text(
            'This app requires location services to track your work activities. '
            'Please enable GPS/Location services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                // Open location settings
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Shows dialog when permission is denied
  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_disabled_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Permission'),
            ],
          ),
          content: const Text(
            'Location permission is required to use this app. '
            'Please grant location permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Shows dialog when permission is permanently denied
  static void _showPermissionPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: const Text(
            'Location permission has been permanently denied. '
            'Please enable it manually in your device settings under App Permissions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Quick check for location availability (without dialogs)
  static Future<bool> isLocationAvailable() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
             permission == LocationPermission.always;
    } catch (e) {
      log('$_tag: Error checking location availability: $e');
      return false;
    }
  }

  /// Get current position with error handling
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await isLocationAvailable()) {
        log('$_tag: Location not available');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );

      log('$_tag: Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      log('$_tag: Error getting current position: $e');
      return null;
    }
  }
}