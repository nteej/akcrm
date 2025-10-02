import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:provider/provider.dart';
import 'job_details_page.dart';
import '../models/job.dart';
import '../helper/dio.dart';
import '../config/app_colors.dart';
import '../providers/job_provider.dart';
import '../services/location_tracking_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobsList = await getJobs();
      if (mounted) {
        setState(() {
          jobs = jobsList;
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

  String _formatLatLong(String? latLong) {
    if (latLong == null || latLong.isEmpty) return '';
    final parts = latLong.split(',');
    if (parts.length != 2) return latLong;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return latLong;
    return '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
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
      Map<String, dynamic>? selectedVehicle;
      Map<String, dynamic>? selectedVendor;
      Map<String, dynamic>? selectedService;

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

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final fuelController = TextEditingController();
          final fuelPriceController = TextEditingController();
          return AlertDialog(
            title: const Text('Start New Job'),
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
                      await _locationTrackingService.startTracking(
                        jobId: jobId!,
                        userId: userId,
                        deviceId: deviceId,
                      );

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

                final finishedJob = Job(
                  startTime: startTime,
                  endTime: endTime,
                  startLatLong: _startLatLong ?? '',
                  endLatLong: _endLatLong ?? '',
                  service: currentJob.service,
                  vehicle: currentJob.vehicle,
                  vendor: currentJob.vendor,
                  fuelPrice:
                      fuelPrice.isNotEmpty
                          ? double.tryParse(fuelPrice) ?? 0.0
                          : 0.0,
                  fuelConsumption:
                      fuelConsumption.isNotEmpty
                          ? double.tryParse(fuelConsumption) ?? 0.0
                          : 0.0,
                );

                if (mounted) {
                  setState(() {
                    jobs.insert(0, finishedJob);
                  });
                  context.read<JobProvider>().stopJob();
                  Navigator.of(context).pop();
                }
                _locationSubscription?.cancel();
                // Stop location tracking service
                _locationTrackingService.stopTracking();
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationTrackingService.dispose();
    super.dispose();
  }


  String _getStartLatLong() {
    return _startLatLong ?? '';
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
          title: Text('Duty List', style: TextStyle(color: AppColors.text)),
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
              return Text(
                jobProvider.isJobRunning
                    ? 'Duty List - ${jobProvider.getElapsedTimeString()}'
                    : 'Duty List',
                style: TextStyle(color: AppColors.text),
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
                                  'Started: ${DateFormat('yyyy-MM-dd HH:mm').format(jobProvider.jobStartTime!)}',
                                  style: TextStyle(color: AppColors.text),
                                ),
                                Text(
                                  'Elapsed: ${jobProvider.getElapsedTimeString()}',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
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
        title: Text('Duty List', style: TextStyle(color: AppColors.text)),
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
                      style: TextStyle(color: AppColors.text),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Started at: ${jobProvider.jobStartTime}',
                          style: TextStyle(color: AppColors.text),
                        ),
                        Text(
                          'Elapsed: ${jobProvider.getElapsedTimeString()}',
                          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Start LatLong: ${_getStartLatLong()}',
                          style: TextStyle(color: AppColors.text),
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
                )
              else
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
                      color: job.isEditable
                          ? AppColors.card
                          : Colors.green[200],
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              serviceName,
                              style: TextStyle(color: AppColors.text),
                            ),
                            SizedBox(width: 8),
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
                                Text(
                                  'LatLong: ' +
                                      _formatLatLong(
                                        job.startLatLong.toString(),
                                      ) +
                                      (job.endLatLong.toString() != null
                                          ? ' / ' +
                                                _formatLatLong(
                                                  job.endLatLong.toString(),
                                                )
                                          : ''),
                                  style: TextStyle(color: AppColors.text),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
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
