import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/job.dart';
import '../config/app_colors.dart';
import '../widgets/live_trip_map.dart';

class JobDetailsPage extends StatelessWidget {
  final Job job;
  const JobDetailsPage({Key? key, required this.job}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTimeFormatted = TimeOfDay.fromDateTime(job.startTime).format(context);
    final timeFormat = job.endTime != null
        ? '$startTimeFormatted - ${TimeOfDay.fromDateTime(job.endTime!).format(context)}'
        : '$startTimeFormatted - Running';

    final dateFormat = job.endTime != null &&
            job.startTime.year == job.endTime!.year &&
            job.startTime.month == job.endTime!.month &&
            job.startTime.day == job.endTime!.day
        ? '${job.startTime.year}-${job.startTime.month.toString().padLeft(2, '0')}-${job.startTime.day.toString().padLeft(2, '0')}'
        : job.endTime != null
            ? '${job.startTime.year}-${job.startTime.month.toString().padLeft(2, '0')}-${job.startTime.day.toString().padLeft(2, '0')} / ${job.endTime!.year}-${job.endTime!.month.toString().padLeft(2, '0')}-${job.endTime!.day.toString().padLeft(2, '0')}'
            : '${job.startTime.year}-${job.startTime.month.toString().padLeft(2, '0')}-${job.startTime.day.toString().padLeft(2, '0')} (Running)';

    // Placeholder for break calculation (requires pause/resume timestamps)
    // For now, just show 0 min break
    final breakMinutes = 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: Text('Job Details', style: TextStyle(color: AppColors.text)),
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
            Text(job.service, style: TextStyle(fontSize: 22, color: AppColors.text)),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.directions_car, color: AppColors.text),
                SizedBox(width: 8),
                Text('Vehicle: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(job.vehicle, style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.business, color: AppColors.text),
                SizedBox(width: 8),
                Text('Vendor: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(job.vendor, style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_gas_station, color: AppColors.text),
                SizedBox(width: 8),
                Text('Fuel: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text('${job.fuelConsumption.toStringAsFixed(2)} L', style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.directions, color: AppColors.text),
                SizedBox(width: 8),
                Text('Distance: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(job.getDistanceFormatted(), style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, color: AppColors.text),
                SizedBox(width: 8),
                Text('Time: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(timeFormat, style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.text),
                SizedBox(width: 8),
                Text('Date: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text(dateFormat, style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.pause_circle_filled, color: AppColors.text),
                SizedBox(width: 8),
                Text('Break Taken: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text('$breakMinutes min', style: TextStyle(fontSize: 16, color: AppColors.text)),
              ],
            ),
            SizedBox(height: 24),
            // View Route Map button (only for finished jobs with ID)
            if (job.id != null && job.isFinished)
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.map, size: 20),
                  label: Text('View Route Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showRouteMap(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show historical route map for finished job
  void _showRouteMap(BuildContext context) {
    // Parse start location
    LatLng? startPosition;
    if (job.startLatLong.isNotEmpty) {
      final parts = job.startLatLong.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          startPosition = LatLng(lat, lng);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Route Map - ${job.service}'),
              backgroundColor: AppColors.appBar,
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: LiveTripMap(
              jobId: job.id!,
              startTime: job.startTime,
              startPosition: startPosition,
              isRunning: false, // Historical route, not live
            ),
          ),
        );
      },
    );
  }
}