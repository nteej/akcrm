import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:developer';
import '../helper/dio.dart';
import '../config/app_colors.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool isLoading = true;
  Map<String, dynamic>? aboutData;
  PackageInfo? packageInfo;
  String? errorMessage;
  Set<int> expandedChangelogIndices = {0}; // Only first (latest) changelog is expanded

  @override
  void initState() {
    super.initState();
    _loadAboutData();
  }

  Future<void> _loadAboutData() async {
    try {
      // Get package info
      packageInfo = await PackageInfo.fromPlatform();

      // Fetch about data from API (public endpoint, no auth required)
      dio_lib.Response response = await dio().get('/about');

      if (mounted) {
        setState(() {
          aboutData = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      log('Error loading about data: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load about information';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: Text('About', style: TextStyle(color: AppColors.text)),
      ),
      backgroundColor: AppColors.background,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(errorMessage!),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          _loadAboutData();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Info Section
                      _buildAppInfoCard(),
                      SizedBox(height: 16),

                      // Current Version Section
                      _buildCurrentVersionCard(),
                      SizedBox(height: 16),

                      // Changelog Section
                      _buildChangelogCard(),
                      SizedBox(height: 16),

                      // Support Section
                      _buildSupportCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'App Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            Text(
              aboutData?['app_name'] ?? 'SmartForce',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              aboutData?['description'] ?? 'SmartForce ERP System for employees',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              'Installed Version: ${packageInfo?.version ?? 'Unknown'} (${packageInfo?.buildNumber ?? 'Unknown'})',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVersionCard() {
    final currentVersion = aboutData?['current_version'];
    if (currentVersion == null) return SizedBox.shrink();

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Latest Version',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            if (currentVersion['android'] != null)
              _buildPlatformVersionInfo('Android', currentVersion['android']),
            if (currentVersion['android'] != null && currentVersion['ios'] != null)
              SizedBox(height: 12),
            if (currentVersion['ios'] != null)
              _buildPlatformVersionInfo('iOS', currentVersion['ios']),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformVersionInfo(String platform, Map<String, dynamic> versionInfo) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                platform == 'Android' ? Icons.android : Icons.apple,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                platform,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('Version: ${versionInfo['version']} (${versionInfo['build_number']})'),
          Text('Released: ${versionInfo['release_date']}'),
        ],
      ),
    );
  }

  Widget _buildChangelogCard() {
    final changelog = aboutData?['changelog'] as List?;
    if (changelog == null || changelog.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Changelog',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            ...List.generate(
              changelog.length,
              (index) => _buildChangelogItem(changelog[index], index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogItem(Map<String, dynamic> version, int index) {
    final changes = version['changes'] as List? ?? [];
    final isExpanded = expandedChangelogIndices.contains(index);
    final isLatest = index == 0;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isLatest ? Colors.blue[300]! : Colors.grey[300]!,
          width: isLatest ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                expandedChangelogIndices.add(index);
              } else {
                expandedChangelogIndices.remove(index);
              }
            });
          },
          leading: isLatest
              ? Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star, color: Colors.blue[700], size: 16),
                )
              : Icon(Icons.history, size: 20, color: Colors.grey[600]),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLatest ? Colors.blue[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v${version['version']} (${version['build_number']})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                version['release_date'] ?? '',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: changes.map((change) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            change.toString(),
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    final support = aboutData?['support'];
    if (support == null) return SizedBox.shrink();

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            if (support['email'] != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.email, size: 20),
                title: Text(support['email']),
                contentPadding: EdgeInsets.zero,
              ),
            if (support['website'] != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.language, size: 20),
                title: Text(support['website']),
                contentPadding: EdgeInsets.zero,
              ),
            if (support['privacy_policy'] != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.privacy_tip, size: 20),
                title: Text('Privacy Policy'),
                contentPadding: EdgeInsets.zero,
              ),
            if (support['terms_of_service'] != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.description, size: 20),
                title: Text('Terms of Service'),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
