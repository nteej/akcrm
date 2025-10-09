import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'dart:developer';
import '../helper/dio.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final storage = FlutterSecureStorage();
  double totalIncome = 0;
  double workedHours = 0;
  double totalJourney = 0;
  double totalFuelConsumption = 0;
  double fuelReimbursements = 0;
  int totalDeliveredParcels = 0;
  bool isLoading = true;

  // Latest job info
  Map<String, dynamic>? latestFinishedJob;
  Map<String, dynamic>? unfinishedJob;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final token = await storage.read(key: 'auth');
      
      // Fetch worked hours from runners API
      dio_lib.Response runnersRes = await dio().get(
        '/runners',
        options: dio_lib.Options(headers: {'Authorization': 'Bearer $token'}),
      );
     
      //final runnersRes = await dio().get('/runners');
      if (runnersRes.statusCode == 200 && runnersRes.data['runners'] is List) {
        double totalHours = 0;
        double fuelConsumption = 0;
        double fuelCost = 0;
        int parcels = 0;

        for (var runner in runnersRes.data['runners']) {
          // Calculate worked hours
          if (runner['started_at'] != null && runner['finished_at'] != null) {
            final startTime = DateTime.parse(runner['started_at']);
            final endTime = DateTime.parse(runner['finished_at']);
            final diff = endTime.difference(startTime).inMinutes / 60.0;
            totalHours += diff;
          }

          // Calculate fuel consumption
          if (runner['fuel_consumed'] != null) {
            final fuel = runner['fuel_consumed'];
            if (fuel is num) {
              fuelConsumption += fuel.toDouble();
            } else if (fuel is String) {
              fuelConsumption += double.tryParse(fuel) ?? 0.0;
            } else if (fuel is List && fuel.isNotEmpty) {
              final first = fuel.first;
              if (first is num) {
                fuelConsumption += first.toDouble();
              } else if (first is String) {
                fuelConsumption += double.tryParse(first) ?? 0.0;
              }
            }
          }

          // Calculate fuel reimbursements (fuel price only)
          if (runner['fuel_price'] != null) {
            double price = 0;

            final fuelPrice = runner['fuel_price'];
            if (fuelPrice is num) {
              price = fuelPrice.toDouble();
            } else if (fuelPrice is String) {
              price = double.tryParse(fuelPrice) ?? 0.0;
            } else if (fuelPrice is List && fuelPrice.isNotEmpty) {
              final first = fuelPrice.first;
              if (first is num) {
                price = first.toDouble();
              } else if (first is String) {
                price = double.tryParse(first) ?? 0.0;
              }
            }

            fuelCost += price;
          }

          // Calculate total delivered parcels
          if (runner['deliveries'] != null) {
            final deliveries = runner['deliveries'];
            if (deliveries is int) {
              parcels += deliveries;
            } else if (deliveries is String) {
              parcels += int.tryParse(deliveries) ?? 0;
            } else if (deliveries is num) {
              parcels += deliveries.toInt();
            }
          }

          // Calculate total journey
          if (runner['distance_km'] != null) {
          totalJourney += runner['distance_km'] is num
              ? (runner['distance_km'] as num).toDouble()
              : (runner['distance_km'] is String
                  ? double.tryParse(runner['distance_km']) ?? 0.0
                  : 0.0);
          }
          
        }

        workedHours = totalHours;
        totalFuelConsumption = fuelConsumption;
        fuelReimbursements = fuelCost;
        totalDeliveredParcels = parcels;

        // Find latest finished job and any unfinished job
        for (var runner in runnersRes.data['runners']) {
          bool isFinished = runner['is_finished'] is bool
              ? runner['is_finished']
              : (runner['finished_at'] != null && runner['finished_at'].toString().isNotEmpty);

          if (!isFinished && unfinishedJob == null) {
            // First unfinished job found
            unfinishedJob = runner;
          } else if (isFinished) {
            // Check if this is the latest finished job
            if (latestFinishedJob == null) {
              latestFinishedJob = runner;
            } else {
              try {
                final currentFinished = DateTime.parse(runner['finished_at'].toString());
                final latestFinished = DateTime.parse(latestFinishedJob!['finished_at'].toString());
                if (currentFinished.isAfter(latestFinished)) {
                  latestFinishedJob = runner;
                }
              } catch (e) {
                // Skip if date parsing fails
              }
            }
          }
        }
      }

      // Fetch total income
      try {
        final incomeRes = await dio().get('/income');
        if (incomeRes.statusCode == 200 && incomeRes.data is List) {
          totalIncome = (incomeRes.data as List)
              .map((item) => (item['amount'] as num?)?.toDouble() ?? 0.0)
              .fold(0.0, (sum, amount) => sum + amount);
        }
      } catch (e) {
        log('Error fetching income: $e');
      }

      

    } catch (e) {
      log('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.yellow[300],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard(
                          icon: Icons.euro,
                          iconColor: Colors.green,
                          backgroundColor: Colors.green[100]!,
                          title: 'Total Income',
                          value: '€${totalIncome.toStringAsFixed(2)}',
                        ),
                        _buildStatCard(
                          icon: Icons.access_time,
                          iconColor: Colors.blue,
                          backgroundColor: Colors.blue[100]!,
                          title: 'Worked Hours',
                          value: '${workedHours.toStringAsFixed(1)} h',
                        ),
                        _buildStatCard(
                          icon: Icons.local_gas_station,
                          iconColor: Colors.orange,
                          backgroundColor: Colors.orange[100]!,
                          title: 'Fuel Consumed',
                          value: '${totalFuelConsumption.toStringAsFixed(2)} L',
                        ),
                        _buildStatCard(
                          icon: Icons.attach_money,
                          iconColor: Colors.purple,
                          backgroundColor: Colors.purple[100]!,
                          title: 'Fuel Reimbursement',
                          value: '€${fuelReimbursements.toStringAsFixed(2)}',
                        ),
                        _buildStatCard(
                          icon: Icons.inventory_2,
                          iconColor: Colors.teal,
                          backgroundColor: Colors.teal[100]!,
                          title: 'Parcels Delivered',
                          value: '$totalDeliveredParcels',
                        ),
                        _buildStatCard(
                          icon: Icons.money_off,
                          iconColor: Colors.red,
                          backgroundColor: Colors.red[100]!,
                          title: 'Total Journey',
                          value: '${totalJourney.toStringAsFixed(2)} km',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Latest Job Summary Card
                    _buildJobSummaryCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildJobSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_history, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Job Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),

            // Unfinished Job Section
            if (unfinishedJob != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Unfinished Job',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildJobDetailRow('Service', unfinishedJob!['service']?['name']?.toString() ?? 'N/A'),
                    _buildJobDetailRow('Vehicle', unfinishedJob!['vehicle']?['name']?.toString() ?? 'N/A'),
                    _buildJobDetailRow('Started', _formatDateTime(unfinishedJob!['started_at']?.toString())),
                    _buildJobDetailRow('Status', 'In Progress - Please finish this job'),
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],

            // Latest Finished Job Section
            if (latestFinishedJob != null) ...[
              Text(
                'Latest Completed Job',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJobDetailRow('Service', latestFinishedJob!['service']?['name']?.toString() ?? 'N/A'),
                    _buildJobDetailRow('Vehicle', latestFinishedJob!['vehicle']?['name']?.toString() ?? 'N/A'),
                    _buildJobDetailRow('Completed', _formatDateTime(latestFinishedJob!['finished_at']?.toString())),
                    _buildJobDetailRow('Deliveries', '${latestFinishedJob!['deliveries'] ?? 0} parcels'),
                    _buildJobDetailRow('Fuel', '${_formatFuel(latestFinishedJob!['fuel_consumed'])} L'),
                  ],
                ),
              ),
            ],

            // No jobs message
            if (unfinishedJob == null && latestFinishedJob == null)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No job records found',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatFuel(dynamic fuel) {
    if (fuel == null) return '0.0';
    if (fuel is num) return fuel.toStringAsFixed(2);
    if (fuel is String) return (double.tryParse(fuel) ?? 0.0).toStringAsFixed(2);
    if (fuel is List && fuel.isNotEmpty) {
      final first = fuel.first;
      if (first is num) return first.toStringAsFixed(2);
      if (first is String) return (double.tryParse(first) ?? 0.0).toStringAsFixed(2);
    }
    return '0.0';
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String value,
  }) {
    return Card(
      color: backgroundColor,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}