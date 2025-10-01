// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:async';
import '../providers/auth.dart';
import '../main.dart';
import 'register.dart';
import 'location_check_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snack_bar.dart';
import '../widgets/custom_textformfield.dart';
import '../config/app_colors.dart';
import '../services/location_service.dart';

import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _errorMessage;
  Timer? _errorTimer;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _email.text = 'runner01@akaram.fi';
    _password.text = 'password';
  }

  Future submit() async {
    if (_formKey.currentState!.validate()) {
      // Check location access before attempting login
      bool hasLocationAccess = await LocationService.isLocationAvailable();
      if (!hasLocationAccess) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LocationCheckScreen()),
          );
        }
        return;
      }

      await Provider.of<Auth>(
        context,
        listen: false,
      ).login(credential: {'email': _email.text, 'password': _password.text});
      final auth = Provider.of<Auth>(context, listen: false);
      if (auth.authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          customSnackBar(context, 'successfully logged in', false),
        );
        await Future.delayed(const Duration(seconds: 4));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: ((context) => HomePage())),
        );
      } else {
        setState(() {
          _errorMessage = 'Login failed: Unauthorized or invalid credentials.';
        });
        _errorTimer?.cancel();
        _errorTimer = Timer(const Duration(seconds: 3), () {
          setState(() {
            _errorMessage = null;
          });
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(customSnackBar(context, _errorMessage!, true));
      }
    } else {
      setState(() {
        _errorMessage = 'Failed to login: Invalid form.';
      });
      _errorTimer?.cancel();
      _errorTimer = Timer(const Duration(seconds: 3), () {
        setState(() {
          _errorMessage = null;
        });
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(customSnackBar(context, _errorMessage!, true));
  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Text(
                'Sign In',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CustomTextFormField(
                          email: _email,
                          label: 'Email',
                          hint: 'example@gmail.com',
                        ),
                        SizedBox(height: 16),
                        CustomTextFormField(
                          email: _password,
                          hint: 'Enter Your Password',
                          label: 'Password',
                        ),
                        CustomButton(onTap: submit, title: 'Login'),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(child: Text("Don't you have an account yet?")),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: ((context) => Register())),
                    ),
                    child: Text(
                      'Register',
                      style: TextStyle(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
