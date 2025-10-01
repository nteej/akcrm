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
    };
  }
}
