class Job {
  final int? id;
  final DateTime startTime;
  final String startLatLong;
  final DateTime? endTime;
  final String endLatLong;
  final String service;
  final String vehicle;
  final String vendor;
  final double fuelConsumption;
  final double fuelPrice;
  final bool isEditable;
  final bool isFinished;
  final int deliveries;
  final String? city;

  Job({
    this.id,
    required this.startTime,
    required this.startLatLong,
    this.endTime,
    required this.endLatLong,
    required this.service,
    required this.vehicle,
    required this.vendor,
    required this.fuelConsumption,
    required this.fuelPrice,
    this.isEditable = true,
    this.isFinished = false,
    this.deliveries = 0,
    this.city,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    double parseFuel(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      if (val is List && val.isNotEmpty) {
        // If API returns a list, take first element if it's num or string
        final first = val.first;
        if (first is num) return first.toDouble();
        if (first is String) return double.tryParse(first) ?? 0.0;
      }
      return 0.0;
    }
    return Job(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      startTime: DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now(),
      endTime: json['finished_at'] != null && json['finished_at'].toString().isNotEmpty
          ? DateTime.tryParse(json['finished_at'].toString())
          : null,
      startLatLong: json['start_latlong']?.toString() ?? '',
      endLatLong: json['end_latlong']?.toString() ?? '',
      service: json['service']['name']?.toString() ?? '',
      vehicle: json['vehicle']['name']?.toString() ?? '',
      vendor: json['vendor']['name']?.toString() ?? '',
      fuelConsumption: parseFuel(json['fuel_consumed']),
      fuelPrice: parseFuel(json['fuel_price']),
      isEditable: json['is_editable'] is bool ? json['is_editable'] : (json['is_editable'] == null ? true : json['is_editable'] == true),
      isFinished: json['is_finished'] is bool ? json['is_finished'] : (json['finished_at'] != null && json['finished_at'].toString().isNotEmpty),
      deliveries: json['deliveries'] is int ? json['deliveries'] : (json['deliveries'] != null ? int.tryParse(json['deliveries'].toString()) ?? 0 : 0),
      city: json['city']?['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'started_at': startTime.toIso8601String(),
      'finished_at': endTime?.toIso8601String(),
      'start_latlong': startLatLong,
      'end_latlong': endLatLong,
      'service': {'name': service},
      'vehicle': {'name': vehicle},
      'vendor': {'name': vendor},
      'fuel_consumed': fuelConsumption,
      'fuel_price': fuelPrice,
      'is_editable': isEditable,
      'is_finished': isFinished,
      'deliveries': deliveries,
    };
  }

  /// Calculate distance traveled in kilometers
  double getDistanceInKm() {
    if (startLatLong.isEmpty || endLatLong.isEmpty) return 0.0;

    try {
      final startParts = startLatLong.split(',');
      final endParts = endLatLong.split(',');

      if (startParts.length != 2 || endParts.length != 2) return 0.0;

      final startLat = double.tryParse(startParts[0].trim());
      final startLng = double.tryParse(startParts[1].trim());
      final endLat = double.tryParse(endParts[0].trim());
      final endLng = double.tryParse(endParts[1].trim());

      if (startLat == null || startLng == null || endLat == null || endLng == null) {
        return 0.0;
      }

      // Use Geolocator's distance calculation (returns meters)
      // Convert to kilometers
      return _calculateDistance(startLat, startLng, endLat, endLng) / 1000.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get formatted distance string
  String getDistanceFormatted() {
    final distanceKm = getDistanceInKm();
    if (distanceKm == 0.0) return 'N/A';
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    const double earthRadiusM = 6371000.0;
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(startLat)) *
            _cos(_toRadians(endLat)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadiusM * c;
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
    // Normalize to -π to π
    while (x > 3.14159265359) {
      x -= 6.28318530718;
    }
    while (x < -3.14159265359) {
      x += 6.28318530718;
    }
    // Taylor series
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _cos(double x) {
    return _sin(x + 3.14159265359 / 2);
  }

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
}
