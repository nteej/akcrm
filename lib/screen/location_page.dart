import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied.';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied.';
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[100],
      appBar: AppBar(
        title: const Text('Current Location'),
        backgroundColor: Colors.yellow[700],
        elevation: 2,
      ),
      body: Center(
        
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 18),
                ),
              )
            : _currentPosition == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.yellow[700],
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your Current Location',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow[900],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Latitude:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(6)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Longitude:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.longitude.toStringAsFixed(6)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.speed, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Accuracy:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.accuracy.toStringAsFixed(2)} m',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.landscape, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Altitude:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.altitude.toStringAsFixed(2)} m',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.directions_run, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Speed:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.speed.toStringAsFixed(2)} m/s',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.yellow[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Timestamp:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text('${_currentPosition!.timestamp.toLocal()}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
