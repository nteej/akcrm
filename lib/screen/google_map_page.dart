import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({Key? key}) : super(key: key);

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _destination;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  double _zoom = 13.0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

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
        _markers.add(Marker(
          markerId: MarkerId('current'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      });
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
    final apiKey = "AIzaSyCzBJGU7CpogIUEwW01ZaHqSLVlVC2nXF4"; // Replace with your own key
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:fi'
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'] as List;
      setState(() {
        _suggestions = predictions.map<Map<String, dynamic>>((item) => item as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final description = suggestion['description'] ?? '';
    final apiKey = "AIzaSyCzBJGU7CpogIUEwW01ZaHqSLVlVC2nXF4"; // Replace with your own key
    // Get place details for lat/lng
    final detailsUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey'
    );
    final detailsResponse = await http.get(detailsUrl);
    if (detailsResponse.statusCode == 200) {
      final detailsData = json.decode(detailsResponse.body);
      final location = detailsData['result']['geometry']['location'];
      final lat = location['lat'];
      final lon = location['lng'];
      setState(() {
        _destination = LatLng(lat, lon);
        _searchController.text = description;
        _suggestions = [];
        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _markers.add(Marker(
          markerId: MarkerId('destination'),
          position: _destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      });
      if (_currentLocation != null) {
        await _fetchRoute();
        _mapController?.animateCamera(CameraUpdate.newLatLng(_destination!));
      }
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    // Use OSRM for routing (same as OSM)
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_currentLocation!.longitude},${_currentLocation!.latitude};'
      '${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=geojson'
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        List<LatLng> points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: PolylineId('route'),
            points: points,
            color: Colors.green,
            width: 4,
          ));
        });
      } else {
        setState(() {
          _polylines.clear();
        });
      }
    } else {
      setState(() {
        _polylines.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Maps Router'),
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
                          title: Text(s['description'] ?? ''),
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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? LatLng(60.1699, 24.9384),
                    zoom: _zoom,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
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
                            _zoom = (_zoom + 1).clamp(1.0, 18.0);
                            _mapController?.moveCamera(CameraUpdate.zoomTo(_zoom));
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
                            _zoom = (_zoom - 1).clamp(1.0, 18.0);
                            _mapController?.moveCamera(CameraUpdate.zoomTo(_zoom));
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
