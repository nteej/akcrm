import 'dart:developer';
import 'package:dio/dio.dart' as di;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helper/dio.dart';
import '../screen/income_page.dart';

class IncomeService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<List<IncomeRecord>> fetchIncomeRecords() async {
    try {
      final token = await _storage.read(key: 'auth');
      if (token == null) {
        log('No auth token found');
        return [];
      }

      final response = await dio().get(
        '/income',
        options: di.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      log('Income API response: ${response.data}');

      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((item) => IncomeRecord.fromJson(item)).toList();
      }

      return [];
    } on di.DioException catch (e) {
      log('Income API error: ${e.message}');
      if (e.response != null) {
        log('Error response: ${e.response!.data}');
      }
      return [];
    } catch (e) {
      log('Unexpected error fetching income records: $e');
      return [];
    }
  }

  static Future<List<String>> fetchIncomeCategories() async {
    try {
      final token = await _storage.read(key: 'auth');
      if (token == null) {
        log('No auth token found');
        return ['ALL'];
      }

      final response = await dio().get(
        '/income/categories',
        options: di.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      log('Income categories API response: ${response.data}');

      if (response.data != null && response.data['categories'] != null) {
        final List<dynamic> categories = response.data['categories'];
        return ['ALL', ...categories.map((category) => category.toString())];
      }

      return ['ALL'];
    } on di.DioException catch (e) {
      log('Income categories API error: ${e.message}');
      // Return default categories as fallback
      return [
        'ALL',
        'SALARY',
        'FUEL REIMBURSE',
        'MONEY REIMBURSE',
        'SALARY ADVANCE',
        'LOAN',
      ];
    } catch (e) {
      log('Unexpected error fetching income categories: $e');
      return ['ALL'];
    }
  }
}