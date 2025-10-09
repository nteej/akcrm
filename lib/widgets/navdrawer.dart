import '../../screen/job_page.dart';
import '../../screen/invoice_page.dart';
import '../../screen/about_page.dart';
import 'package:flutter/material.dart';
import '../../screen/login_screen.dart';
import '../../screen/register.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NavDrawer extends StatefulWidget {
  const NavDrawer({super.key});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  String _formatMemberSince(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MM/yy').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getReleaseDate() {
    // Parse release date from version (format: MM/YY)
    // For now, return current date formatted as MM/YY
    // In production, this should be read from a config or build metadata
    return DateFormat('10/25').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.yellow[200],
      child: Consumer<Auth>(
        builder: ((context, auth, child) {
          if (auth.authenticated) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(color: Colors.yellow[400]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        auth.user?.name ?? '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        auth.user?.email ?? '',
                                        style: TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (auth.user?.registeredDate != null &&
                                          _formatMemberSince(auth.user?.registeredDate).isNotEmpty)
                                        SizedBox(height: 4),
                                      if (auth.user?.registeredDate != null &&
                                          _formatMemberSince(auth.user?.registeredDate).isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 12, color: Colors.black54),
                                            SizedBox(width: 4),
                                            Text(
                                              'Member Since: ${_formatMemberSince(auth.user?.registeredDate)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text('Jobs'),
                        leading: Icon(Icons.work),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: ((context) => JobPage())),
                        ),
                      ),
                      ListTile(
                        title: Text('Invoice'),
                        leading: Icon(Icons.receipt_long),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: ((context) => InvoicePage())),
                        ),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Logout'),
                        leading: Icon(Icons.logout),
                        onTap: () {
                          Provider.of<Auth>(context, listen: false).logout();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                // Version info stuck at bottom
                Divider(height: 1),
                Container(
                  color: Colors.yellow[100],
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.info_outline, size: 20),
                    title: Text(
                      'Version ${_packageInfo?.version ?? '...'} (${_packageInfo?.buildNumber ?? '...'})',
                      style: TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      'Released: ${_getReleaseDate()}',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: ((context) => AboutPage())),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return ListView(
              children: [
                ListTile(
                  title: Text('register'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => Register())),
                  ),
                ),
                ListTile(
                  title: Text('Login'),
                  onTap: (() => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => LoginScreen())),
                  )),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}
