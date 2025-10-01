import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:finnerp/helper/dio.dart';
import 'package:finnerp/models/error.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/user.dart';

class Auth extends ChangeNotifier {
  bool _authenticated = false;
  User? _user;
  ValidationError? _validationError;
  ValidationError? get validationError => _validationError;
  User? get user => _user;
  final storage = FlutterSecureStorage();
  bool get authenticated => _authenticated;
  bool _obscureText = false;

  bool get obscureText => _obscureText;

  Future register({credential}) async {
    String deviceId = await getDeviceId();
    try {
      di.Response res = await dio().post('/auth/register',
          data: json.encode(credential..addAll({'deviceId': deviceId})));
      String token = await res.data['token'];
      await attempt(token);
      await storeToken(token);
    } on di.DioException catch (e) {
      if (e.response?.statusCode == 422) {
        _validationError = ValidationError.fromJson(e.response!.data['errors']);
        notifyListeners();
      }
    }
  }

  Future login({required Map credential}) async {
    String deviceId = await getDeviceId();
    log('Attempting login with credentials: $credential');
    try {
      di.Response response = await dio().post('/auth/login',
          data: json.encode(credential..addAll({'deviceId': deviceId})));
      log('Login response: $response');
      if (response.data != null && response.data['token'] != null) {
        String token = response.data['token'];
        await attempt(token);
        await storeToken(token);
      } else {
        _authenticated = false;
        _user = null;
        await deleteToken();
        notifyListeners();
      }
    } on di.DioException catch (e) {
      log('Login error: $e');
      if (e.response != null) {
        log('Error response data: ${e.response!.data}');
      }
      _authenticated = false;
      _user = null;
      await deleteToken();
      if (e.response?.statusCode == 422) {
        _validationError = ValidationError.fromJson(e.response!.data['errors']);
      }
      notifyListeners();
    }
  }

  Future attempt(String? token) async {
    try {
      di.Response res = await dio().get(
        '/user',
        options: di.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _user = User.fromJson(res.data);
      if (_user?.id != null) {
        await storage.write(key: 'user_id', value: _user!.id);
        log('Saved user_id to storage: ${_user!.id}');
      }
      _authenticated = true;
    } catch (e) {
      log('error log ${e.toString()}');
      _authenticated = false;
    }
    notifyListeners();
  }

  Future getDeviceId() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = '';

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    }

    return deviceId;
  }

  Future storeToken(String token) async {
    await storage.write(key: 'auth', value: token);
  }

  Future getToken() async {
    final token = await storage.read(key: 'auth');
    return token;
  }

  Future deleteToken() async {
    await storage.delete(key: 'auth');
  }

  Future logout() async {
    final token = await storage.read(key: 'auth');
    _authenticated = false;
    await dio().post('/logout',
        data: {'deviceId': await getDeviceId()},
        options: di.Options(headers: {
          'Authorization': 'Bearer $token',
        }));
    await deleteToken();
    notifyListeners();
  }

  void toggleText() {
    _obscureText = !_obscureText;
    notifyListeners();
  }
}
