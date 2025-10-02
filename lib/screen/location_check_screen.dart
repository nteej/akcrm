import 'package:flutter/material.dart';
import 'package:finnerp/services/location_service.dart';
import 'package:finnerp/screen/login_screen.dart';
import 'package:finnerp/config/app_colors.dart';

class LocationCheckScreen extends StatefulWidget {
  const LocationCheckScreen({super.key});

  @override
  State<LocationCheckScreen> createState() => _LocationCheckScreenState();
}

class _LocationCheckScreenState extends State<LocationCheckScreen> {
  bool _isChecking = false;
  bool _locationEnabled = false;
  String _statusMessage = 'Checking location services...';

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking location services...';
    });

    bool isAvailable = await LocationService.isLocationAvailable();

    setState(() {
      _locationEnabled = isAvailable;
      _isChecking = false;
      if (isAvailable) {
        _statusMessage = 'Location services are ready!';
        // Auto navigate to login after brief delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        });
      } else {
        _statusMessage = 'Location services required';
      }
    });
  }

  Future<void> _requestLocationAccess() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Requesting location access...';
    });

    bool granted = await LocationService.checkLocationRequirements(context);

    if (granted) {
      setState(() {
        _locationEnabled = true;
        _statusMessage = 'Location access granted!';
      });

      // Navigate to login screen
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        });
      }
    } else {
      setState(() {
        _isChecking = false;
        _statusMessage = 'Location access is required to continue';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // App Icon/Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Location Access Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'SmartForce needs access to your location to track work activities and provide accurate job management.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Status indicator
              if (_isChecking)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text.withOpacity(0.8),
                      ),
                    ),
                  ],
                )
              else if (_locationEnabled)
                Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.location_disabled_outlined,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // Action buttons
              if (!_isChecking && !_locationEnabled) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _requestLocationAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Enable Location Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkLocationStatus,
                  child: Text(
                    'Check Again',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Requirements list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.text.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requirements:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementItem(
                      '📍 GPS/Location services enabled',
                      'Allows accurate position tracking',
                    ),
                    _buildRequirementItem(
                      '🔐 Location permission granted',
                      'Required for job tracking features',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.text.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}