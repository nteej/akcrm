
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _currentLocation;
  LatLng _destination = LatLng(60.1699, 24.9384); // Default Helsinki, Finland
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  double _zoom = 15.0;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _setCurrentLocation();
  }

  Future<void> _setCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _zoom = 15.0;
      });
      _fetchRoute();
    } catch (_) {}
  }
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&countrycodes=fi&format=json&addressdetails=1&limit=5');
    final response = await http.get(url, headers: {'User-Agent': 'akcrm-app'});
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      setState(() {
        _suggestions = data.map<Map<String, dynamic>>((item) => item as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final lat = double.tryParse(suggestion['lat'] ?? '');
    final lon = double.tryParse(suggestion['lon'] ?? '');
    if (lat != null && lon != null) {
      setState(() {
        _destination = LatLng(lat, lon);
        _zoom = 16.0;
        _searchController.text = suggestion['display_name'] ?? '';
        _suggestions = [];
      });
      // Only fetch route if current location is available
      if (_currentLocation != null) {
        _fetchRoute();
      }
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_currentLocation!.longitude},${_currentLocation!.latitude};'
      '${_destination.longitude},${_destination.latitude}?overview=full&geometries=geojson'
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        });
      } else {
        setState(() {
          _routePoints = [];
        });
      }
    } else {
      setState(() {
        _routePoints = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Router'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Destination (search OSM)',
                    suffixIcon: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    if (val.length > 2) _searchLocation(val);
                  },
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, idx) {
                        final s = _suggestions[idx];
                        return ListTile(
                          title: Text(s['display_name'] ?? ''),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? _destination,
                    initialZoom: _zoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            child: Icon(Icons.my_location, color: Colors.blue),
                          ),
                          Marker(
                            point: _destination,
                            child: Icon(Icons.location_on, color: Colors.red),
                          ),
                        ],
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: Colors.green,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        child: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _zoom = (_zoom + 1).clamp(1.0, 20.0);
                            _mapController.move(_currentLocation ?? _destination, _zoom);
                          });
                        },
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        child: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            _zoom = (_zoom - 1).clamp(1.0, 23.0);
                            _mapController.move(_currentLocation ?? _destination, _zoom);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
