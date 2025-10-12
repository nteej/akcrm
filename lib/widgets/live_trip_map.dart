import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helper/dio.dart';
import '../config/app_colors.dart';
import 'van_marker.dart';

/// Live trip map showing user's journey from job start to current position
/// Supports two modes:
/// 1. Running job: Shows live updates with is_running=true
/// 2. Finished job: Shows historical route with job_id
class LiveTripMap extends StatefulWidget {
  final int? jobId;
  final String? userId;
  final LatLng? startPosition;
  final DateTime startTime;
  final bool isRunning;

  const LiveTripMap({
    super.key,
    this.jobId,
    this.userId,
    required this.startTime,
    this.startPosition,
    this.isRunning = true,
  });

  @override
  State<LiveTripMap> createState() => _LiveTripMapState();
}

class _LiveTripMapState extends State<LiveTripMap> {
  final storage = const FlutterSecureStorage();
  final MapController _mapController = MapController();

  List<UserLocation> _locationHistory = [];
  UserLocation? _currentLocation;
  Timer? _updateTimer;
  bool _isLoading = true;
  String? _error;
  bool _isMapReady = false;
  bool _showGpsPoints = true; // Toggle to show/hide individual GPS points

  // Trip statistics
  double _totalDistance = 0.0;
  Duration _tripDuration = Duration.zero;
  double _averageSpeed = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchLocationHistory();
    // Update every 10 seconds only for running jobs
    if (widget.isRunning) {
      _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchLocationHistory();
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Fetch location history from API
  /// For running jobs: uses is_running=true
  /// For finished jobs: uses job_id={id}
  Future<void> _fetchLocationHistory() async {
    try {
      final token = await storage.read(key: 'auth');
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Build query parameters based on mode
      final Map<String, dynamic> queryParams = {};
      if (widget.isRunning) {
        queryParams['is_running'] = 'true';
      } else if (widget.jobId != null) {
        queryParams['job_id'] = widget.jobId;
      }

      final response = await dio().get(
        '/user-location',
        queryParameters: queryParams,
        options: dio_lib.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> locations = data['locations'] ?? [];

        setState(() {
          _locationHistory = locations
              .map((loc) => UserLocation.fromJson(loc))
              .toList()
            ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

          if (_locationHistory.isNotEmpty) {
            _currentLocation = _locationHistory.last;
          }

          _calculateStatistics();
          _isLoading = false;
          _error = null;
        });

        // Center map on current location (only if map is ready)
        if (_currentLocation != null && mounted && _isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isMapReady) {
              _mapController.move(
                LatLng(_currentLocation!.lat, _currentLocation!.long),
                15,
              );
            }
          });
        }
      }
    } catch (e) {
      log('Error fetching location history: $e');
      setState(() {
        _error = 'Failed to load location data';
        _isLoading = false;
      });
    }
  }

  /// Fit map bounds to show all GPS points
  void _fitBounds() {
    if (_locationHistory.isEmpty || !_isMapReady) return;

    // Calculate bounds
    double minLat = _locationHistory[0].lat;
    double maxLat = _locationHistory[0].lat;
    double minLng = _locationHistory[0].long;
    double maxLng = _locationHistory[0].long;

    for (final loc in _locationHistory) {
      if (loc.lat < minLat) minLat = loc.lat;
      if (loc.lat > maxLat) maxLat = loc.lat;
      if (loc.long < minLng) minLng = loc.long;
      if (loc.long > maxLng) maxLng = loc.long;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - latPadding, minLng - lngPadding),
          LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  /// Calculate trip statistics
  void _calculateStatistics() {
    if (_locationHistory.isEmpty) return;

    // Calculate total distance
    _totalDistance = 0.0;
    for (int i = 1; i < _locationHistory.length; i++) {
      final prev = _locationHistory[i - 1];
      final curr = _locationHistory[i];
      _totalDistance += _calculateDistance(
        prev.lat,
        prev.long,
        curr.lat,
        curr.long,
      );
    }

    // Calculate duration
    final now = DateTime.now();
    _tripDuration = now.difference(widget.startTime);

    // Calculate average speed (km/h)
    final hours = _tripDuration.inSeconds / 3600;
    _averageSpeed = hours > 0 ? _totalDistance / hours : 0.0;

    // Current speed from latest location
    _currentSpeed = _currentLocation?.speed ?? 0.0;

    // Max speed from history
    _maxSpeed = _locationHistory
        .map((loc) => loc.speed)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Calculate distance between two coordinates (Haversine formula)
  /// Returns distance in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.14159265359 / 180.0;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double result = x / 2;
    for (int i = 0; i < 10; i++) {
      result = (result + x / result) / 2;
    }
    return result;
  }

  static double _sin(double x) {
    while (x > 3.14159265359) {
      x -= 6.28318530718;
    }
    while (x < -3.14159265359) {
      x += 6.28318530718;
    }
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _cos(double x) => _sin(x + 3.14159265359 / 2);

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }

  static double _atan(double x) {
    if (x.abs() > 1) {
      final sign = x > 0 ? 1 : -1;
      return sign * 3.14159265359 / 2 - _atan(1 / x);
    }
    double result = 0;
    double term = x;
    for (int i = 0; i < 15; i++) {
      final sign = i.isEven ? 1 : -1;
      result += sign * term / (2 * i + 1);
      term *= x * x;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchLocationHistory();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_locationHistory.isEmpty) {
      return const Center(
        child: Text('No location data yet. Waiting for updates...'),
      );
    }

    return Column(
      children: [
        // Statistics Panel
        _buildStatisticsPanel(),

        // Map
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation != null
                      ? LatLng(_currentLocation!.lat, _currentLocation!.long)
                      : widget.startPosition ?? LatLng(60.1699, 24.9384),
                  initialZoom: 15,
                  minZoom: 5,
                  maxZoom: 19,
                  onMapReady: () {
                    setState(() {
                      _isMapReady = true;
                    });
                    // If we have a current location, center on it now that map is ready
                    if (_currentLocation != null && mounted) {
                      _mapController.move(
                        LatLng(_currentLocation!.lat, _currentLocation!.long),
                        15,
                      );
                    }
                  },
                ),
                children: [
                  // OpenStreetMap tiles
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.smartforce.akcrm',
                  ),

                  // Route polyline - connects all GPS points
                  if (_locationHistory.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _locationHistory
                              .map((loc) => LatLng(loc.lat, loc.long))
                              .toList(),
                          strokeWidth: 5.0,
                          color: Colors.blue,
                          borderStrokeWidth: 2.0,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),

                  // Individual GPS point markers - shows each recorded location
                  if (_showGpsPoints && _locationHistory.length > 1)
                    CircleLayer(
                      circles: _locationHistory
                          .asMap()
                          .entries
                          .where((entry) =>
                              entry.key != 0 && // Skip start point (has its own marker)
                              entry.key != _locationHistory.length - 1) // Skip current position (has van marker)
                          .map((entry) {
                        final index = entry.key;
                        final loc = entry.value;
                        final totalPoints = _locationHistory.length;

                        // Color gradient from light to dark blue (older to newer)
                        final progress = index / totalPoints;
                        final color = Color.lerp(
                          Colors.blue.withValues(alpha: 0.4),
                          Colors.blue.withValues(alpha: 0.9),
                          progress,
                        )!;

                        return CircleMarker(
                          point: LatLng(loc.lat, loc.long),
                          radius: 4,
                          color: color,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: false,
                        );
                      }).toList(),
                    ),

                  // Markers
                  MarkerLayer(
                    markers: [
                      // Start marker
                      if (widget.startPosition != null)
                        Marker(
                          point: widget.startPosition!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),

                      // Current position with van marker
                      if (_currentLocation != null)
                        Marker(
                          point: LatLng(
                            _currentLocation!.lat,
                            _currentLocation!.long,
                          ),
                          width: 48,
                          height: 48,
                          child: VanMarkerPainted(
                            heading: _currentLocation!.heading,
                            status: _currentSpeed > 5
                                ? VanStatus.active
                                : VanStatus.idle,
                            size: 48,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Map controls
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'zoom_in',
                      mini: true,
                      onPressed: _isMapReady
                          ? () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              );
                            }
                          : null,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'zoom_out',
                      mini: true,
                      onPressed: _isMapReady
                          ? () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              );
                            }
                          : null,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'center',
                      mini: true,
                      onPressed: _isMapReady && _currentLocation != null
                          ? () {
                              _mapController.move(
                                LatLng(
                                    _currentLocation!.lat, _currentLocation!.long),
                                15,
                              );
                            }
                          : null,
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'toggle_points',
                      mini: true,
                      onPressed: () {
                        setState(() {
                          _showGpsPoints = !_showGpsPoints;
                        });
                      },
                      backgroundColor: _showGpsPoints
                          ? Colors.blue
                          : Colors.grey.shade400,
                      child: const Icon(Icons.my_location_outlined),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'fit_bounds',
                      mini: true,
                      onPressed: _isMapReady && _locationHistory.length > 1
                          ? () {
                              _fitBounds();
                            }
                          : null,
                      child: const Icon(Icons.fit_screen),
                    ),
                  ],
                ),
              ),

              // Legend
              if (_showGpsPoints && _locationHistory.length > 1)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GPS Points',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Start',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Recent',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                icon: Icons.timer,
                label: 'Duration',
                value: _formatDuration(_tripDuration),
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.route,
                label: 'Distance',
                value: '${_totalDistance.toStringAsFixed(2)} km',
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                icon: Icons.speed,
                label: 'Current',
                value: '${_currentSpeed.toStringAsFixed(1)} km/h',
                color: Colors.orange,
              ),
              _buildStatItem(
                icon: Icons.show_chart,
                label: 'Average',
                value: '${_averageSpeed.toStringAsFixed(1)} km/h',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.location_searching,
                  label: 'Updates',
                  value: '${_locationHistory.length} points',
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Max Speed',
                  value: '${_maxSpeed.toStringAsFixed(1)} km/h',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// User location data model
class UserLocation {
  final int id;
  final double lat;
  final double long;
  final int jobId;
  final String userId;
  final String deviceId;
  final DateTime recordedAt;
  final double speed; // km/h
  final double heading; // degrees

  UserLocation({
    required this.id,
    required this.lat,
    required this.long,
    required this.jobId,
    required this.userId,
    required this.deviceId,
    required this.recordedAt,
    this.speed = 0.0,
    this.heading = 0.0,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      lat: json['lat'] is double
          ? json['lat']
          : double.parse(json['lat'].toString()),
      long: json['long'] is double
          ? json['long']
          : double.parse(json['long'].toString()),
      jobId: json['job_id'] is int
          ? json['job_id']
          : int.parse(json['job_id'].toString()),
      userId: json['user_id'].toString(),
      deviceId: json['device_id'].toString(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'].toString())
          : DateTime.now(),
      speed: json['speed'] != null
          ? (json['speed'] is double
              ? json['speed']
              : double.tryParse(json['speed'].toString()) ?? 0.0)
          : 0.0,
      heading: json['heading'] != null
          ? (json['heading'] is double
              ? json['heading']
              : double.tryParse(json['heading'].toString()) ?? 0.0)
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': lat,
      'long': long,
      'job_id': jobId,
      'user_id': userId,
      'device_id': deviceId,
      'recorded_at': recordedAt.toIso8601String(),
      'speed': speed,
      'heading': heading,
    };
  }
}
