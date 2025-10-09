import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'job_details_page.dart';
import '../models/job.dart';
import '../helper/dio.dart';
import '../config/app_colors.dart';
import '../providers/job_provider.dart';
import '../services/location_tracking_service.dart';
import '../services/running_job_manager.dart';
import '../providers/auth.dart';

class JobPage extends StatefulWidget {
  const JobPage({super.key});

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  String? _startLatLong;
  String? _endLatLong;
  StreamSubscription<Position>? _locationSubscription;
  List<String> _locationUpdates = [];
  List<Job> jobs = [];
  bool isLoading = true;
  final storage = FlutterSecureStorage();
  final LocationTrackingService _locationTrackingService = LocationTrackingService();
  final RunningJobManager _runningJobManager = RunningJobManager();
  bool _hasCheckedRunningJob = false;

  // Realtime tracking for running job
  Timer? _realtimeTimer;
  double _currentDistance = 0.0;
  double _currentSpeed = 0.0;

  // Live location tracking status
  Timer? _liveLocationTimer;
  Map<String, dynamic>? _liveLocationData;
  bool _isLoadingLiveLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadJobs();
    // Resume realtime tracking if job is already running
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final jobProvider = context.read<JobProvider>();
      if (jobProvider.isJobRunning) {
        _startRealtimeTracking();
        _startLiveLocationUpdates();
      }

      // Check for running jobs from other devices
      _checkForRunningJobFromOtherDevice();
    });
  }

  Future<void> _initializeServices() async {
    await _locationTrackingService.initialize();
  }

  Future<void> _loadJobs() async {
    try {
      final jobsList = await getJobs();
      if (mounted) {
        setState(() {
          jobs = _sortAndLimitJobs(jobsList);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Sort and limit jobs to 5 items
  /// - Unfinished jobs first
  /// - Then finished jobs sorted by end time (latest first)
  /// - Limit to 5 items total
  List<Job> _sortAndLimitJobs(List<Job> jobsList) {
    // Separate unfinished and finished jobs
    final unfinished = jobsList.where((job) => !job.isFinished).toList();
    final finished = jobsList.where((job) => job.isFinished).toList();

    // Sort finished jobs by end time (latest first)
    finished.sort((a, b) {
      if (a.endTime == null && b.endTime == null) return 0;
      if (a.endTime == null) return 1;
      if (b.endTime == null) return -1;
      return b.endTime!.compareTo(a.endTime!);
    });

    // Combine: unfinished first, then finished
    final sortedJobs = [...unfinished, ...finished];

    // Limit to 5 items
    return sortedJobs.take(5).toList();
  }

  Future<void> _finishUnfinishedJob(Job job) async {
    DateTime selectedDateTime = DateTime.now();
    final fuelController = TextEditingController();
    final fuelPriceController = TextEditingController();
    final deliveriesController = TextEditingController();

    // Fetch cities for dropdown
    List<Map<String, dynamic>> cityList = [];
    Map<String, dynamic>? selectedCity;

    try {
      final token = await storage.read(key: 'auth');
      final cityRes = await dio().get(
        '/cities',
        options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (cityRes.statusCode == 200 && cityRes.data['cities'] is List) {
        cityList = (cityRes.data['cities'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (cityList.isNotEmpty) {
          selectedCity = cityList.first;
        }
      }
    } catch (e) {
      log('Error loading cities: $e');
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Finish Unfinished Job'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Job: ${job.service}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Started: ${DateFormat('yyyy-MM-dd HH:mm').format(job.startTime)}',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text('Finished Date & Time'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime),
                      ),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate: job.startTime,
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (pickedTime != null) {
                            setDialogState(() {
                              selectedDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedCity,
                      items: cityList
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCity = val;
                        });
                      },
                      decoration: InputDecoration(labelText: 'City'),
                    ),
                    TextFormField(
                      controller: deliveriesController,
                      decoration: InputDecoration(
                        labelText: 'Deliveries (pcs)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: fuelController,
                      decoration: InputDecoration(
                        labelText: 'Fuel Consumption (L)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: fuelPriceController,
                      decoration: InputDecoration(labelText: 'Fuel Price (€)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate fuel fields
                    final fuelConsumption = fuelController.text.trim();
                    final fuelPrice = fuelPriceController.text.trim();
                    final deliveries = deliveriesController.text.trim();

                    if ((fuelConsumption.isNotEmpty && fuelPrice.isEmpty) ||
                        (fuelConsumption.isEmpty && fuelPrice.isNotEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Both Fuel Consumption and Fuel Price must be filled or both empty',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final token = await storage.read(key: 'auth');
                      final userId = await storage.read(key: 'user_id');
                      final jobId = job.id;

                      await _getCurrentLocation((latLong) async {
                        final dateFormat = DateFormat('yyyy-MM-ddTHH:mm:ss');
                        final payload = {
                          'finished_at': dateFormat.format(selectedDateTime),
                          'end_latlong': latLong,
                          'fuel_consumed': fuelConsumption.isNotEmpty
                              ? double.tryParse(fuelConsumption)
                              : null,
                          'fuel_price': fuelPrice.isNotEmpty
                              ? double.tryParse(fuelPrice)
                              : null,
                          'deliveries':
                              deliveries.isNotEmpty ? int.tryParse(deliveries) ?? 0 : 0,
                          'city_id': selectedCity?['id'],
                          'user_id': userId,
                        };

                        log('PUT /runners/$jobId payload: $payload');
                        final response = await dio().put(
                          '/runners/$jobId',
                          options: dio_lib.Options(
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                          ),
                          data: payload,
                        );
                        log('PUT /runners/$jobId response: ${response.data}');

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Job finished successfully')),
                          );
                          Navigator.of(context).pop();
                          _loadJobs(); // Reload jobs to reflect changes
                        }
                      });
                    } catch (e) {
                      log('Error finishing job: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to finish job: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Finish Job'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Job>> getJobs() async {
    final token = await storage.read(key: 'auth');
    dio_lib.Response res = await dio().get(
      '/runners',
      options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = res.data['runners'];
    if (data is List) {
      return data
          .where((job) => job is Map<String, dynamic>)
          .map((job) => Job.fromJson(job as Map<String, dynamic>))
          .toList();
    } else if (data is Map<String, dynamic> && data['runners'] is List) {
      return (data['runners'] as List)
          .where((job) => job is Map<String, dynamic>)
          .map((job) => Job.fromJson(job as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> _getCurrentLocation(Function(String) onLocation) async {
    try {
      log('Checking location permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          log('Location permission denied');
          onLocation('0.0,0.0'); // Default fallback
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        log('Location permission permanently denied');
        onLocation('0.0,0.0'); // Default fallback
        return;
      }

      log('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
      String latLong = '${position.latitude},${position.longitude}';
      log('Current location: $latLong');
      onLocation(latLong);
    } catch (e) {
      log('Error getting location: $e');
      onLocation('0.0,0.0'); // Default fallback
    }
  }

  Future<void> _startJob() async {
    try {
      // Check for unfinished jobs first
      final unfinishedJobs = jobs.where((job) => !job.isFinished).toList();
      if (unfinishedJobs.isNotEmpty) {
        final shouldFinish = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Unfinished Job Found'),
              content: Text(
                'You have ${unfinishedJobs.length} unfinished job(s). Please finish them before starting a new job.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Finish Now'),
                ),
              ],
            );
          },
        );

        if (shouldFinish == true) {
          await _finishUnfinishedJob(unfinishedJobs.first);
        }
        return;
      }

      log('Starting job...');
      final token = await storage.read(key: 'auth');
      if (token == null) {
        log('No auth token found');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please log in again')));
        }
        return;
      }

      log('Getting current location for job start...');
      String? startLocation;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            startLocation = '0.0,0.0';
          }
        }

        if (permission == LocationPermission.deniedForever) {
          startLocation = '0.0,0.0';
        }

        if (startLocation == null) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 100,
            ),
          );
          startLocation = '${position.latitude},${position.longitude}';
        }
      } catch (e) {
        log('Error getting location: $e');
        startLocation = '0.0,0.0';
      }

      _startLatLong = startLocation;
      log('Start location set: $_startLatLong');

      // Fetch dropdown data from APIs
      List<Map<String, dynamic>> vehicleList = [];
      List<Map<String, dynamic>> vendorList = [];
      List<Map<String, dynamic>> serviceList = [];
      List<Map<String, dynamic>> cityList = [];
      Map<String, dynamic>? selectedVehicle;
      Map<String, dynamic>? selectedVendor;
      Map<String, dynamic>? selectedService;
      Map<String, dynamic>? selectedCity;

      try {
        final vehicleRes = await dio().get(
          '/vehicles',
          options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (vehicleRes.statusCode == 200 &&
            vehicleRes.data['vehicles'] is List) {
          vehicleList = (vehicleRes.data['vehicles'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (vehicleList.isNotEmpty) {
            selectedVehicle = vehicleList.first;
          }
        }
        log('Loaded vehicleList: $vehicleList');
      } catch (e) {
        log('Error loading vehicles: $e');
      }
      try {
        final vendorRes = await dio().get(
          '/vendors',
          options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (vendorRes.statusCode == 200 && vendorRes.data['vendors'] is List) {
          vendorList = (vendorRes.data['vendors'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (vendorList.isNotEmpty) {
            selectedVendor = vendorList.first;
          }
        }
        log('Loaded vendorList: $vendorList');
      } catch (e) {
        log('Error loading vendors: $e');
      }
      try {
        final serviceRes = await dio().get(
          '/services',
          options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (serviceRes.statusCode == 200 &&
            serviceRes.data['services'] is List) {
          serviceList = (serviceRes.data['services'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (serviceList.isNotEmpty) {
            selectedService = serviceList.first;
          }
        }
        log('Loaded services: $serviceList');
      } catch (e) {
        log('Error loading dropdown data: $e');
      }
      try {
        final cityRes = await dio().get(
          '/cities',
          options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (cityRes.statusCode == 200 && cityRes.data['cities'] is List) {
          cityList = (cityRes.data['cities'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          if (cityList.isNotEmpty) {
            selectedCity = cityList.first;
          }
        }
        log('Loaded cities: $cityList');
      } catch (e) {
        log('Error loading cities: $e');
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final fuelController = TextEditingController();
          final fuelPriceController = TextEditingController();
          final deliveriesController = TextEditingController();
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Start New Job'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedVendor,
                    items: vendorList
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => selectedVendor = val,
                    decoration: InputDecoration(labelText: 'Vendor'),
                  ),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedVehicle,
                    items: vehicleList
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => selectedVehicle = val,
                    decoration: InputDecoration(labelText: 'Vehicle'),
                  ),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedService,
                    items: serviceList
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => selectedService = val,
                    decoration: InputDecoration(labelText: 'Service'),
                  ),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedCity,
                    items: cityList
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => selectedCity = val,
                    decoration: InputDecoration(labelText: 'City'),
                  ),
                  TextFormField(
                    controller: deliveriesController,
                    decoration: InputDecoration(
                      labelText: 'Deliveries (pcs)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: fuelController,
                    decoration: InputDecoration(
                      labelText: 'Fuel Consumption (L)',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: false, // Disable textbox on job start
                  ),
                  TextFormField(
                    controller: fuelPriceController,
                    decoration: InputDecoration(labelText: 'Fuel Price (€)'),
                    keyboardType: TextInputType.number,
                    enabled: false,
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (selectedVehicle != null &&
                      selectedVendor != null &&
                      selectedService != null) {
                    // Fire POST request to /runners
                    try {
                      final now = DateTime.now();
                      var userId = await storage.read(key: 'user_id');
                      if (userId == null || userId.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'User ID not found. Please log in again.',
                              ),
                            ),
                          );
                        }
                        log('Error: user_id not found in secure storage.');
                        return;
                      }
                      final payload = {
                        "started_at": now.toIso8601String(),
                        "finished_at": "",
                        "service_id": selectedService!['id'],
                        "vehicle_id": selectedVehicle!['id'],
                        "vendor_id": selectedVendor!['id'],
                        "user_id": userId,
                        "start_latlong": _startLatLong ?? "",
                        "end_latlong": _endLatLong ?? "",
                        "is_editable": true,
                        "fuel_consumed": 0.0,
                        "deliveries": deliveriesController.text.isNotEmpty
                            ? int.tryParse(deliveriesController.text) ?? 0
                            : 0,
                      };
                      log('POST /runners payload: $payload');
                      final response = await dio().post(
                        '/runners',
                        options: dio_lib.Options(
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                        ),
                        data: payload,
                      );
                      log(
                        'POST /runners response: ${response.data['runner']['id']}',
                      );
                      int? jobId;
                      if (response.data['runner'] != null &&
                          response.data['runner']['id'] != null) {
                        jobId = response.data['runner']['id'] is int
                            ? response.data['runner']['id']
                            : int.tryParse(
                                response.data['runner']['id'].toString(),
                              );
                      }
                      // Start job with provider
                      final job = Job(
                        id: jobId,
                        isEditable: false,
                        startTime: now,
                        endTime: null, // No end time for running job
                        startLatLong: _startLatLong ?? '',
                        endLatLong: _endLatLong ?? '',
                        service: selectedService!['name'],
                        vehicle: selectedVehicle!['name'],
                        vendor: selectedVendor!['name'],
                        fuelPrice: 0.0,
                        fuelConsumption: 0.0,
                      );

                      if (mounted) {
                        context.read<JobProvider>().startJob(job, now);
                      }
                      // Start location updates
                      _locationSubscription = Geolocator.getPositionStream()
                          .listen((Position position) {
                            String latLong =
                                '${position.latitude},${position.longitude}';
                            setState(() {
                              _locationUpdates.add(latLong);
                            });
                          });

                      // Start location tracking service (4 times per minute)
                      final authProvider = context.read<Auth>();
                      final deviceId = await authProvider.getDeviceId();

                      // Save job name and start time for notification
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('tracking_job_name', selectedService!['name']);
                      await prefs.setInt('tracking_job_start_time', now.millisecondsSinceEpoch);

                      await _locationTrackingService.startTracking(
                        jobId: jobId!,
                        userId: userId,
                        deviceId: deviceId,
                      );

                      // Start realtime distance and speed tracking
                      _startRealtimeTracking();

                      // Start live location status updates
                      _startLiveLocationUpdates();

                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to start job: $e')),
                        );
                      }
                      log('Error starting job: $e');
                    }
                  }
                },
                child: Text('Submit'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      log('Error in _startJob: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting job: $e')));
      }
    }
  }

  void _pauseJob() {
    context.read<JobProvider>().pauseJob();
  }

  void _resumeJob() {
    context.read<JobProvider>().resumeJob();
  }

  void _stopJob() async {
    final jobProvider = context.read<JobProvider>();
    final currentJob = jobProvider.runningJob;
    final startTime = jobProvider.jobStartTime;

    if (currentJob == null || startTime == null) return;

    await _getCurrentLocation((latLong) {
      _endLatLong = latLong;
    });

    final endTime = DateTime.now();
    final fuelController = TextEditingController();
    final fuelPriceController = TextEditingController();
    final deliveriesController = TextEditingController();

    // Fetch cities for dropdown
    List<Map<String, dynamic>> cityList = [];
    Map<String, dynamic>? selectedCity;

    try {
      final token = await storage.read(key: 'auth');
      final cityRes = await dio().get(
        '/cities',
        options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (cityRes.statusCode == 200 && cityRes.data['cities'] is List) {
        cityList = (cityRes.data['cities'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (cityList.isNotEmpty) {
          selectedCity = cityList.first;
        }
      }
      log('Loaded cities for finish: $cityList');
    } catch (e) {
      log('Error loading cities: $e');
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Finish Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: currentJob.service,
                  decoration: InputDecoration(labelText: 'Service'),
                  enabled: false,
                ),
                TextFormField(
                  initialValue: currentJob.vehicle,
                  decoration: InputDecoration(labelText: 'Vehicle'),
                  enabled: false,
                ),
                TextFormField(
                  initialValue: currentJob.vendor,
                  decoration: InputDecoration(labelText: 'Vendor'),
                  enabled: false,
                ),
                TextFormField(
                  initialValue: DateFormat('yyyy-MM-dd HH:mm').format(startTime),
                  decoration: InputDecoration(labelText: 'Started At'),
                  enabled: false,
                ),
                TextFormField(
                  initialValue: DateFormat('yyyy-MM-dd HH:mm').format(endTime),
                  decoration: InputDecoration(labelText: 'Finished At'),
                  enabled: false,
                ),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedCity,
                  items: cityList
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => selectedCity = val,
                  decoration: InputDecoration(labelText: 'City'),
                ),
                TextFormField(
                  controller: deliveriesController,
                  decoration: InputDecoration(
                    labelText: 'Deliveries (pcs)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: true,
                ),
                TextFormField(
                  controller: fuelController,
                  decoration: InputDecoration(
                    labelText: 'Fuel Consumption (L)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: true,
                ),
                TextFormField(
                  controller: fuelPriceController,
                  decoration: InputDecoration(labelText: 'Fuel Price (€)'),
                  keyboardType: TextInputType.number,
                  enabled: true,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Validate fuel fields
                final fuelConsumption = fuelController.text.trim();
                final fuelPrice = fuelPriceController.text.trim();
                final deliveries = deliveriesController.text.trim();

                if ((fuelConsumption.isNotEmpty && fuelPrice.isEmpty) ||
                    (fuelConsumption.isEmpty && fuelPrice.isNotEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Both Fuel Consumption and Fuel Price must be filled or both empty'),
                    ),
                  );
                  return;
                }

                try {
                  final token = await storage.read(key: 'auth');
                  final userId = await storage.read(key: 'user_id');
                  final jobId = currentJob.id ?? '';
                  final dateFormat = DateFormat('yyyy-MM-ddTHH:mm:ss');
                  final payload = {
                    'finished_at': dateFormat.format(endTime),
                    'end_latlong': _endLatLong ?? '',
                    'fuel_consumed':
                        fuelConsumption.isNotEmpty
                            ? double.tryParse(fuelConsumption)
                            : null,
                    'fuel_price':
                        fuelPrice.isNotEmpty
                            ? double.tryParse(fuelPrice)
                            : null,
                    'deliveries': deliveries.isNotEmpty
                        ? int.tryParse(deliveries) ?? 0
                        : 0,
                    'city_id': selectedCity?['id'],
                    'user_id': userId,
                  };
                  log('PUT /runners/$jobId payload: $payload');
                  final response = await dio().put(
                    '/runners/$jobId',
                    options: dio_lib.Options(
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                    ),
                    data: payload,
                  );
                  log('PUT /runners/$jobId response: ${response.data}');
                } catch (e) {
                  log('Error updating job: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update job: $e')),
                    );
                  }
                }

                if (mounted) {
                  // Reload jobs from API to get updated list with proper sorting
                  _loadJobs();
                  context.read<JobProvider>().stopJob();
                  Navigator.of(context).pop();
                }
                _locationSubscription?.cancel();
                // Stop location tracking service
                await _locationTrackingService.stopTracking();
                // Stop realtime tracking
                _stopRealtimeTracking();
                // Stop live location status updates
                _stopLiveLocationUpdates();
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _startRealtimeTracking() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _updateRealtimeDistance();
    });
    // Update immediately on start
    _updateRealtimeDistance();
  }

  void _stopRealtimeTracking() {
    _realtimeTimer?.cancel();
    setState(() {
      _currentDistance = 0.0;
      _currentSpeed = 0.0;
    });
  }

  Future<void> _updateRealtimeDistance() async {
    if (_startLatLong == null || _startLatLong!.isEmpty) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) return lastPos;
          throw Exception('Unable to get location');
        },
      );

      // Calculate distance from start to current position
      final startParts = _startLatLong!.split(',');
      if (startParts.length == 2) {
        final startLat = double.tryParse(startParts[0].trim());
        final startLng = double.tryParse(startParts[1].trim());

        if (startLat != null && startLng != null) {
          // Calculate distance in meters using Geolocator
          final distanceMeters = Geolocator.distanceBetween(
            startLat,
            startLng,
            position.latitude,
            position.longitude,
          );

          // Calculate speed (km/h)
          if (mounted) {
            final jobProvider = context.read<JobProvider>();
            if (jobProvider.jobStartTime != null) {
              final elapsedMinutes = DateTime.now().difference(jobProvider.jobStartTime!).inMinutes;
              if (elapsedMinutes > 0) {
                final distanceKm = distanceMeters / 1000.0;
                final elapsedHours = elapsedMinutes / 60.0;
                _currentSpeed = distanceKm / elapsedHours;
              }
            }

            setState(() {
              _currentDistance = distanceMeters / 1000.0; // Convert to km
            });
          }

          log('Realtime: Distance=${_currentDistance.toStringAsFixed(2)} km, Speed=${_currentSpeed.toStringAsFixed(1)} km/h');
        }
      }
    } catch (e) {
      log('Error updating realtime distance: $e');
    }
  }

  @override
  void dispose() {
    // Cancel the foreground location subscription only
    // DO NOT stop the background service here - it should continue
    // running even when the page is disposed or app is closed
    _locationSubscription?.cancel();
    _realtimeTimer?.cancel();

    // DO NOT cancel live location timer - it should persist across page navigation
    // Only cancel if job is explicitly stopped
    // _liveLocationTimer?.cancel();

    // The background service should ONLY be stopped when user
    // explicitly clicks "Stop Job" button in _stopJob()
    super.dispose();
  }

  // Fetch live location tracking status
  Future<void> _fetchLiveLocationStatus() async {
    if (_isLoadingLiveLocation) return;

    try {
      setState(() {
        _isLoadingLiveLocation = true;
      });

      final token = await storage.read(key: 'auth');
      final response = await dio().get(
        '/my-live-location',
        options: dio_lib.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (mounted && response.statusCode == 200) {
        setState(() {
          _liveLocationData = response.data;
          _isLoadingLiveLocation = false;
        });
      }
    } catch (e) {
      log('Error fetching live location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLiveLocation = false;
        });
      }
    }
  }

  // Start live location status updates
  void _startLiveLocationUpdates() {
    _fetchLiveLocationStatus();
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchLiveLocationStatus();
    });
  }

  // Stop live location status updates
  void _stopLiveLocationUpdates() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    if (mounted) {
      setState(() {
        _liveLocationData = null;
      });
    }
  }

  // Get status color based on tracking data
  Color _getTrackingStatusColor() {
    if (_liveLocationData == null) return Colors.grey;

    final trackingStatus = _liveLocationData!['tracking_status'];
    final isLive = trackingStatus?['is_live'] ?? false;
    final lastUpdateSecondsAgo = trackingStatus?['last_update_seconds_ago'] ?? 999;
    final locationTrackingActive = trackingStatus?['location_tracking_active'] ?? false;

    if (isLive && lastUpdateSecondsAgo < 30) {
      return Colors.green; // Live tracking active
    } else if (isLive && lastUpdateSecondsAgo < 120) {
      return Colors.blue; // Recently updated
    } else if (locationTrackingActive) {
      return Colors.orange; // Tracking active but delayed
    } else {
      return Colors.red; // Tracking inactive
    }
  }

  // Build status indicator for AppBar
  Widget _buildAppBarStatusIndicator() {
    final jobProvider = context.watch<JobProvider>();
    if (!jobProvider.isJobRunning) return SizedBox.shrink();

    final statusColor = _getTrackingStatusColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 8),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.6),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Check for running jobs from other devices
  Future<void> _checkForRunningJobFromOtherDevice() async {
    if (_hasCheckedRunningJob) return;
    _hasCheckedRunningJob = true;

    final jobProvider = context.read<JobProvider>();

    // Don't check if already running a job on this device
    if (jobProvider.isJobRunning) {
      log('Already running a job on this device, skipping remote check');
      return;
    }

    try {
      log('Checking for running jobs from other devices...');
      final runningJobData = await _runningJobManager.checkForRunningJob();

      if (runningJobData != null && mounted) {
        final runningJob = runningJobData['running_job'];
        final latestLocation = runningJobData['latest_location'];

        if (runningJob != null) {
          _showRunningJobDialog(runningJobData);
        }
      }
    } catch (e) {
      log('Error checking for running jobs: $e');
    }
  }

  // Show dialog for running job from another device
  Future<void> _showRunningJobDialog(Map<String, dynamic> runningJobData) async {
    final runningJob = runningJobData['running_job'];
    final latestLocation = runningJobData['latest_location'];
    final trackingStatus = runningJobData['tracking_status'];

    final jobId = runningJob['id'];
    final serviceName = runningJob['service'] ?? 'Unknown Service';
    final vehicleName = runningJob['vehicle'] ?? 'Unknown Vehicle';
    final duration = runningJob['duration'] ?? 'Unknown';
    final startedAt = runningJob['started_at'];
    final deviceId = latestLocation?['device_id'];
    final lastUpdate = latestLocation?['recorded_at'] ?? 'Unknown';
    final isLive = trackingStatus?['is_live'] ?? false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.phone_android, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Running Job Detected')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have a running job from another device:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Divider(),
                      _buildDetailRow2('Job #', '$jobId'),
                      _buildDetailRow2('Service', serviceName),
                      _buildDetailRow2('Vehicle', vehicleName),
                      _buildDetailRow2('Duration', duration),
                      _buildDetailRow2('Device', _runningJobManager.getDeviceInfo(deviceId)),
                      _buildDetailRow2('Last Update', lastUpdate),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isLive ? Icons.circle : Icons.circle_outlined,
                            color: isLive ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isLive ? 'Tracking Active' : 'Tracking Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'What would you like to do?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• Continue on this device - Take over tracking\n'
                  '• Stop Job - Finish the job now\n'
                  '• View Only - Monitor without changes',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('View Only'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _stopRemoteJob(jobId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Stop Job'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _continueJobOnThisDevice(runningJob);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Continue Here'),
            ),
          ],
        );
      },
    );
  }

  // Helper for dialog detail rows
  Widget _buildDetailRow2(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Continue job on this device
  Future<void> _continueJobOnThisDevice(Map<String, dynamic> runningJob) async {
    try {
      final jobId = runningJob['id'];
      final serviceName = runningJob['service'];
      final vehicleName = runningJob['vehicle'];
      final vendorName = runningJob['vendor'];
      final startedAtStr = runningJob['started_at'];

      if (jobId == null || startedAtStr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid job data')),
          );
        }
        return;
      }

      final startTime = DateTime.parse(startedAtStr);
      final userId = await storage.read(key: 'user_id');
      final authProvider = context.read<Auth>();
      final deviceId = await authProvider.getDeviceId();

      // Create job object
      final job = Job(
        id: jobId,
        isEditable: false,
        startTime: startTime,
        endTime: null,
        startLatLong: runningJob['start_location'] ?? '',
        endLatLong: '',
        service: serviceName ?? 'Unknown',
        vehicle: vehicleName ?? 'Unknown',
        vendor: vendorName ?? 'Unknown',
        fuelPrice: 0.0,
        fuelConsumption: double.tryParse(runningJob['fuel_consumed']?.toString() ?? '0') ?? 0.0,
      );

      if (mounted) {
        context.read<JobProvider>().startJob(job, startTime);
      }

      // Start location tracking service on this device
      await _locationTrackingService.startTracking(
        jobId: jobId,
        userId: userId!,
        deviceId: deviceId,
      );

      // Save job name for notification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tracking_job_name', serviceName ?? 'Unknown');
      await prefs.setInt('tracking_job_start_time', startTime.millisecondsSinceEpoch);

      // Start realtime tracking
      _startRealtimeTracking();
      _startLiveLocationUpdates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tracking continued on this device'),
            backgroundColor: Colors.green,
          ),
        );
      }

      log('✓ Successfully took over job $jobId on this device');
    } catch (e) {
      log('Error continuing job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to continue job: $e')),
        );
      }
    }
  }

  // Stop remote job
  Future<void> _stopRemoteJob(int jobId) async {
    try {
      final success = await _runningJobManager.stopRunningJob(jobId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job stopped successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadJobs(); // Reload jobs
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop job')),
          );
        }
      }
    } catch (e) {
      log('Error stopping remote job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Build live location tracking status card
  Widget _buildLiveLocationStatusCard() {
    if (_liveLocationData == null) return SizedBox.shrink();

    final trackingStatus = _liveLocationData!['tracking_status'];
    final latestLocation = _liveLocationData!['latest_location'];
    final runningJob = _liveLocationData!['running_job'];

    final isLive = trackingStatus?['is_live'] ?? false;
    final lastUpdateSecondsAgo = trackingStatus?['last_update_seconds_ago'] ?? 0;
    final locationTrackingActive = trackingStatus?['location_tracking_active'] ?? false;

    // Determine status color
    Color statusColor;
    String statusText;
    if (isLive && lastUpdateSecondsAgo < 30) {
      statusColor = Colors.green;
      statusText = 'Live Tracking Active';
    } else if (isLive && lastUpdateSecondsAgo < 120) {
      statusColor = Colors.blue;
      statusText = 'Recently Updated';
    } else if (locationTrackingActive) {
      statusColor = Colors.orange;
      statusText = 'Tracking Active';
    } else {
      statusColor = Colors.red;
      statusText = 'Tracking Inactive';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.1),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor,
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: statusColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: statusColor),
                  onPressed: _fetchLiveLocationStatus,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  tooltip: 'Refresh status',
                ),
              ],
            ),

            Divider(height: 16, color: statusColor.withValues(alpha: 0.3)),

            // Latest Location
            if (latestLocation != null) ...[
              _buildInfoRow(
                icon: Icons.location_on,
                iconColor: Colors.blue,
                label: 'GPS Position',
                value: '${latestLocation['latitude']?.toStringAsFixed(4)}, ${latestLocation['longitude']?.toStringAsFixed(4)}',
              ),
              SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.access_time,
                iconColor: lastUpdateSecondsAgo > 60 ? Colors.red : Colors.grey[600]!,
                label: 'Last Update',
                value: '${latestLocation['recorded_at'] ?? 'Unknown'}',
                trailing: lastUpdateSecondsAgo > 60
                    ? Text(
                        '($lastUpdateSecondsAgo sec)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (latestLocation['device_id'] != null) ...[
                SizedBox(height: 6),
                _buildInfoRow(
                  icon: Icons.phone_android,
                  iconColor: Colors.purple,
                  label: 'Device',
                  value: latestLocation['device_id'].toString().length > 20
                      ? latestLocation['device_id'].toString().substring(0, 20) + '...'
                      : latestLocation['device_id'].toString(),
                ),
              ],
            ],

            // Running Job Details
            if (runningJob != null && runningJob['is_tracking_live'] == true) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.work, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Job #${runningJob['id']} Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (runningJob['service'] != null)
                      _buildDetailRow('Service', runningJob['service']),
                    if (runningJob['vehicle'] != null)
                      _buildDetailRow('Vehicle', runningJob['vehicle']),
                    if (runningJob['vendor'] != null)
                      _buildDetailRow('Vendor', runningJob['vendor']),
                    if (runningJob['duration'] != null)
                      _buildDetailRow('Duration', runningJob['duration'], icon: Icons.timer),
                    if (runningJob['deliveries'] != null)
                      _buildDetailRow('Deliveries', '${runningJob['deliveries']} pcs', icon: Icons.local_shipping),
                    if (runningJob['fuel_consumed'] != null && runningJob['fuel_consumed'] > 0)
                      _buildDetailRow('Fuel', '${runningJob['fuel_consumed']} L', icon: Icons.local_gas_station),
                  ],
                ),
              ),
            ],

            // Warning if tracking is not active
            if (!locationTrackingActive) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location tracking is not active. Please check background service.',
                        style: TextStyle(fontSize: 11, color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper widget for info rows
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // Helper widget for job detail rows
  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey[600]),
            SizedBox(width: 4),
          ],
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatJobDate(DateTime start, DateTime end) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    if (dateFormat.format(start) == dateFormat.format(end)) {
      return dateFormat.format(start);
    } else {
      return dateFormat.format(start) + ' - ' + dateFormat.format(end);
    }
  }

  String _formatJobTime(DateTime start, DateTime end) {
    final timeFormat = DateFormat('HH:mm');
    return timeFormat.format(start) + ' - ' + timeFormat.format(end);
  }



  void _openIncomePopup() async {
    double totalHours = 0;
    for (var job in jobs) {
      if (job.endTime != null) {
        final duration = job.endTime!.difference(job.startTime);
        totalHours += duration.inMinutes / 60.0;
      }
    }
    double salary = totalHours * 10.0;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.yellow[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.attach_money, color: Colors.yellow[700], size: 32),
              const SizedBox(width: 8),
              Text(
                'Income Summary',
                style: TextStyle(
                  color: Colors.yellow[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow[900],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      totalHours.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.yellow[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Salary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow[900],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '€' + salary.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.yellow[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  await _claimSalary(salary);
                  Navigator.of(context).pop();
                },
                child: Text('Claim Salary'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _claimSalary(double amount) async {
    // TODO: Implement API request to claim salary
    // Example:
    // await dio().post('/salary/claim', data: {'amount': amount});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Salary claim requested for €${amount.toStringAsFixed(2)}',
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          title: Row(
            children: [
              Text('Duty List', style: TextStyle(color: AppColors.text)),
              _buildAppBarStatusIndicator(),
            ],
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (jobs.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          title: Consumer<JobProvider>(
            builder: (context, jobProvider, child) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      jobProvider.isJobRunning
                          ? 'Duty List - ${jobProvider.getElapsedTimeString()}'
                          : 'Duty List',
                      style: TextStyle(color: AppColors.text),
                    ),
                  ),
                  _buildAppBarStatusIndicator(),
                ],
              );
            },
          ),
        ),
        body: Consumer<JobProvider>(
          builder: (context, jobProvider, child) {
            return Column(
              children: [
                if (jobProvider.isJobRunning)
                  Expanded(
                    child: ListView(
                      children: [
                        Card(
                          color: Colors.orange[200],
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: ListTile(
                            title: Text(
                              jobProvider.runningJob!.service,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Started: ${DateFormat('EEE HH:mm').format(jobProvider.jobStartTime!)}',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                Text(
                                  'Elapsed: ${jobProvider.getElapsedTimeString()}',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.directions, color: AppColors.text, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_currentDistance.toStringAsFixed(2)} km',
                                          style: TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.speed, color: AppColors.text, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_currentSpeed.toStringAsFixed(1)} km/h',
                                          style: TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  'Vehicle: ${jobProvider.runningJob!.vehicle}',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                Text(
                                  'Vendor: ${jobProvider.runningJob!.vendor}',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (!jobProvider.isPaused)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange[400],
                                          foregroundColor: Colors.black,
                                        ),
                                        onPressed: _pauseJob,
                                        child: Text('Pause'),
                                      ),
                                    if (jobProvider.isPaused)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[400],
                                          foregroundColor: Colors.black,
                                        ),
                                        onPressed: _resumeJob,
                                        child: Text('Resume'),
                                      ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[400],
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _stopJob,
                                      child: Text('Stop'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow[400],
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _startJob,
                                child: Text('Start Job'),
                              ),
                            ],
                          ),
                        ),
                        Center(child: Text('No jobs found')),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duty List', style: TextStyle(color: AppColors.text)),
                  Text(
                    'Showing latest 5 jobs',
                    style: TextStyle(color: AppColors.text, fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildAppBarStatusIndicator(),
          ],
        ),
      ),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          return Column(
            children: [
              if (jobProvider.isJobRunning)
                Container(
                  color: AppColors.background,
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(
                      'Current Job: ${jobProvider.runningJob!.service}',
                      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Started: ${DateFormat('EEE HH:mm').format(jobProvider.jobStartTime!)}',
                          style: TextStyle(color: AppColors.text),
                        ),
                        Text(
                          'Elapsed: ${jobProvider.getElapsedTimeString()}',
                          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions, color: AppColors.text, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '${_currentDistance.toStringAsFixed(2)} km',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, color: AppColors.text, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '${_currentSpeed.toStringAsFixed(1)} km/h',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!jobProvider.isPaused)
                          ElevatedButton(
                            onPressed: _pauseJob,
                            child: Text('Pause'),
                          ),
                        if (jobProvider.isPaused)
                          ElevatedButton(
                            onPressed: _resumeJob,
                            child: Text('Resume'),
                          ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _stopJob,
                          child: Text('Stop'),
                        ),
                      ],
                    ),
                  ),
                ),
              // Live Location Tracking Status Card
              if (jobProvider.isJobRunning && _liveLocationData != null)
                _buildLiveLocationStatusCard(),
              if (!jobProvider.isJobRunning)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[400],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _startJob,
                        child: Text('Start Job'),
                      ),
                    ],
                  ),
                ),
              Expanded(
            child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                String serviceName = job.service.length > 25
                    ? job.service.substring(0, 25) + '...'
                    : job.service;
                // Calculate elapsed time rounded to last minute
                final elapsedDuration = job.endTime != null
                    ? job.endTime!.difference(job.startTime)
                    : Duration.zero;
                final roundedMinutes = elapsedDuration.inMinutes;
                final elapsedDisplay =
                    '${roundedMinutes ~/ 60}h | ${roundedMinutes % 60}m';
                log('Job ${job.id} elapsed time: $elapsedDisplay');
                return Card(
                      color: !job.isFinished
                          ? Colors.orange[100]
                          : (job.isEditable ? AppColors.card : Colors.green[200]),
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Row(
                          children: [
                            if (!job.isFinished)
                              Icon(Icons.warning, color: Colors.orange[700], size: 20),
                            if (!job.isFinished) SizedBox(width: 4),
                            Text(
                              serviceName,
                              style: TextStyle(color: AppColors.text),
                            ),
                            SizedBox(width: 8),
                            if (!job.isFinished)
                              Chip(
                                label: Text(
                                  'Unfinished',
                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                ),
                                backgroundColor: Colors.orange[700],
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  job.endTime != null
                                      ? _formatJobDate(job.startTime, job.endTime!)
                                      : DateFormat('yyyy-MM-dd').format(job.startTime),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Fuel: ' +
                                      job.fuelConsumption.toString() +
                                      ' L',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                SizedBox(width: 16),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  job.endTime != null
                                      ? _formatJobTime(job.startTime, job.endTime!)
                                      : '${DateFormat('HH:mm').format(job.startTime)} - Running',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Elapsed: ' + elapsedDisplay,
                                  style: TextStyle(color: AppColors.text),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Vehicle: ' + job.vehicle,
                                  style: TextStyle(color: AppColors.text),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Vendor: ' + job.vendor,
                                  style: TextStyle(color: AppColors.text),
                                ),
                              ],
                            ),

                            Row(
                              children: [
                                Icon(Icons.directions, color: AppColors.text, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Distance: ${job.getDistanceFormatted()}',
                                  style: TextStyle(color: AppColors.text),
                                ),
                              ],
                            ),
                            if (!job.isFinished)
                              SizedBox(height: 8),
                            if (!job.isFinished)
                              ElevatedButton.icon(
                                icon: Icon(Icons.check_circle, size: 16),
                                label: Text('Finish This Job'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[700],
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  _finishUnfinishedJob(job);
                                },
                              ),
                          ],
                        ),
                        onTap: !job.isFinished
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsPage(job: job),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openIncomePopup,
        backgroundColor: AppColors.button,
        child: Icon(Icons.add, color: AppColors.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        tooltip: 'Show Income & Claim',
      ),
    );
  }
}
