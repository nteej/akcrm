import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart' as dio;
import '../helper/dio.dart' as http_client;
import '../config/app_colors.dart';
class ManualJobEntry extends StatefulWidget {
  const ManualJobEntry({super.key});

  @override
  State<ManualJobEntry> createState() => _ManualJobEntryState();
}

class _ManualJobEntryState extends State<ManualJobEntry> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();

  final jobNameController = TextEditingController();
  final startDateController = TextEditingController();
  final startTimeController = TextEditingController();
  final endDateController = TextEditingController();
  final endTimeController = TextEditingController();
  final startLocationController = TextEditingController();
  final endLocationController = TextEditingController();
  final fuelConsumptionController = TextEditingController();
  final fuelPriceController = TextEditingController();
  final notesController = TextEditingController();

  List<Map<String, dynamic>> vehicleList = [];
  List<Map<String, dynamic>> vendorList = [];
  List<Map<String, dynamic>> serviceList = [];

  Map<String, dynamic>? selectedVehicle;
  Map<String, dynamic>? selectedVendor;
  Map<String, dynamic>? selectedService;

  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    await _loadDropdownData();
    _setDefaultDateTime();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadDropdownData() async {
    try {
      final token = await storage.read(key: 'auth');
      if (token == null) return;

      final responses = await Future.wait([
        http_client.dio().get('/vehicles', options: dio.Options(headers: {'Authorization': 'Bearer $token'})),
        http_client.dio().get('/vendors', options: dio.Options(headers: {'Authorization': 'Bearer $token'})),
        http_client.dio().get('/services', options: dio.Options(headers: {'Authorization': 'Bearer $token'})),
      ]);

      if (responses[0].statusCode == 200 && responses[0].data['vehicles'] is List) {
        vehicleList = (responses[0].data['vehicles'] as List).whereType<Map<String, dynamic>>().toList();
        if (vehicleList.isNotEmpty) selectedVehicle = vehicleList.first;
      }

      if (responses[1].statusCode == 200 && responses[1].data['vendors'] is List) {
        vendorList = (responses[1].data['vendors'] as List).whereType<Map<String, dynamic>>().toList();
        if (vendorList.isNotEmpty) selectedVendor = vendorList.first;
      }

      if (responses[2].statusCode == 200 && responses[2].data['services'] is List) {
        serviceList = (responses[2].data['services'] as List).whereType<Map<String, dynamic>>().toList();
        if (serviceList.isNotEmpty) selectedService = serviceList.first;
      }
    } catch (e) {
      log('Error loading dropdown data: $e');
    }
  }

  void _setDefaultDateTime() {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final currentTime = DateFormat('HH:mm').format(now);
    final oneHourAgo = DateFormat('HH:mm').format(now.subtract(const Duration(hours: 1)));

    startDateController.text = today;
    endDateController.text = today;
    startTimeController.text = oneHourAgo;
    endTimeController.text = currentTime;
    startLocationController.text = '0.0,0.0';
    endLocationController.text = '0.0,0.0';
    fuelConsumptionController.text = '0.0';
    fuelPriceController.text = '0.0';
  }

  Future<void> _selectDateTime(TextEditingController controller, bool isDate) async {
    if (isDate) {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (picked != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    } else {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  Future<void> _submitManualJob() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedVehicle == null || selectedVendor == null || selectedService == null) {
      _showMessage('Please select all required fields');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final token = await storage.read(key: 'auth');
      final userId = await storage.read(key: 'user_id');

      if (token == null || userId == null) {
        _showMessage('Authentication required');
        return;
      }

      // Parse date and time
      final startDateTime = DateTime.parse('${startDateController.text}T${startTimeController.text}:00');
      final endDateTime = DateTime.parse('${endDateController.text}T${endTimeController.text}:00');

      if (endDateTime.isBefore(startDateTime)) {
        _showMessage('End time must be after start time');
        return;
      }

      // Submit to server
      final payload = {
        'started_at': startDateTime.toIso8601String(),
        'finished_at': endDateTime.toIso8601String(),
        'service_id': selectedService!['id'],
        'vehicle_id': selectedVehicle!['id'],
        'vendor_id': selectedVendor!['id'],
        'user_id': userId,
        'start_latlong': startLocationController.text.trim(),
        'end_latlong': endLocationController.text.trim(),
        'fuel_consumed': double.tryParse(fuelConsumptionController.text) ?? 0.0,
        'fuel_price': double.tryParse(fuelPriceController.text) ?? 0.0,
        'is_editable': false,
        'notes': notesController.text.trim(),
      };

      final response = await http_client.dio().post(
        '/runners',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Manual job entry submitted successfully');
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        _showMessage('Failed to submit job entry');
      }
    } catch (e) {
      log('Error submitting manual job: $e');
      _showMessage('Error submitting job: $e');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          title: Text('Manual Job Entry', style: TextStyle(color: AppColors.text)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: Text('Manual Job Entry', style: TextStyle(color: AppColors.text)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use this form to manually enter job data when automatic tracking fails or for recovery situations.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Job Name
              TextFormField(
                controller: jobNameController,
                decoration: const InputDecoration(
                  labelText: 'Job Name (Optional)',
                  hintText: 'Enter a descriptive name for this job',
                ),
                validator: (value) => null, // Optional field
              ),
              const SizedBox(height: 16),

              // Service, Vehicle, Vendor dropdowns
              if (serviceList.isNotEmpty)
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedService,
                  items: serviceList
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s['name']),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedService = value),
                  decoration: const InputDecoration(labelText: 'Service *'),
                  validator: (value) => value == null ? 'Please select a service' : null,
                ),
              const SizedBox(height: 16),

              if (vehicleList.isNotEmpty)
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedVehicle,
                  items: vehicleList
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v['name']),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                  decoration: const InputDecoration(labelText: 'Vehicle *'),
                  validator: (value) => value == null ? 'Please select a vehicle' : null,
                ),
              const SizedBox(height: 16),

              if (vendorList.isNotEmpty)
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedVendor,
                  items: vendorList
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v['name']),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedVendor = value),
                  decoration: const InputDecoration(labelText: 'Vendor *'),
                  validator: (value) => value == null ? 'Please select a vendor' : null,
                ),
              const SizedBox(height: 20),

              // Start Date and Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: startDateController,
                      decoration: const InputDecoration(labelText: 'Start Date *'),
                      readOnly: true,
                      onTap: () => _selectDateTime(startDateController, true),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: startTimeController,
                      decoration: const InputDecoration(labelText: 'Start Time *'),
                      readOnly: true,
                      onTap: () => _selectDateTime(startTimeController, false),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // End Date and Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: endDateController,
                      decoration: const InputDecoration(labelText: 'End Date *'),
                      readOnly: true,
                      onTap: () => _selectDateTime(endDateController, true),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: endTimeController,
                      decoration: const InputDecoration(labelText: 'End Time *'),
                      readOnly: true,
                      onTap: () => _selectDateTime(endTimeController, false),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location fields
              TextFormField(
                controller: startLocationController,
                decoration: const InputDecoration(
                  labelText: 'Start Location (lat,lng)',
                  hintText: 'e.g., 60.1699,24.9384',
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: endLocationController,
                decoration: const InputDecoration(
                  labelText: 'End Location (lat,lng)',
                  hintText: 'e.g., 60.1699,24.9384',
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Fuel fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: fuelConsumptionController,
                      decoration: const InputDecoration(labelText: 'Fuel Consumption (L)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (double.tryParse(value!) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: fuelPriceController,
                      decoration: const InputDecoration(labelText: 'Fuel Price (€)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (double.tryParse(value!) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional information about this job',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitManualJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Submit Manual Job Entry',
                          style: TextStyle(color: AppColors.text),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}