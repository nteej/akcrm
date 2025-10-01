import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'screen/login_screen.dart';
import 'screen/location_check_screen.dart';
import 'providers/auth.dart';
import 'providers/job_provider.dart';
import 'screen/home.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: ((context) => Auth())),
      ChangeNotifierProvider(create: ((context) => JobProvider())),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.yellow),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitializing = true;
  bool _hasLocationAccess = false;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if location services are available
      bool locationAvailable = await LocationService.isLocationAvailable();

      setState(() {
        _hasLocationAccess = locationAvailable;
        _isInitializing = false;
      });
    } catch (e) {
      // If initialization fails, continue
      bool locationAvailable = await LocationService.isLocationAvailable();
      setState(() {
        _hasLocationAccess = locationAvailable;
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasLocationAccess) {
      return const LocationCheckScreen();
    }

    return Consumer<Auth>(
      builder: (context, auth, _) {
        if (auth.authenticated) {
          return const Home();
        } else {
          return const HomePage(); // This handles auto-login attempt
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final storage = FlutterSecureStorage();

  Future<void> _checkLocationAccess() async {
    // Since we already passed the location check screen,
    // we just need a lightweight validation
    bool isAvailable = await LocationService.isLocationAvailable();
    if (!isAvailable && mounted) {
      // Location was disabled after initial check - redirect back to location screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LocationCheckScreen()),
      );
    }
  }

  void _attemptAuthentication() async {
    // First check location access
    await _checkLocationAccess();

    // Then attempt authentication if location is still available
    if (mounted) {
      String? key = await storage.read(key: 'auth');
      if (mounted) {
        Provider.of<Auth>(context, listen: false).attempt(key);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _attemptAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Consumer<Auth>(
          builder: (context, value, child) {
            if (value.authenticated) {
              return Home();
            } else {
              return LoginScreen();
            }
          },
        ),
      ),
    );
  }
}
