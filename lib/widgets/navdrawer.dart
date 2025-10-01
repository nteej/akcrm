import '../../screen/job_page.dart';
import '../../screen/google_map_page.dart';
import '../../screen/profile_page.dart';
import 'package:flutter/material.dart';
import '../../screen/login_screen.dart';
import '../../screen/posts_screen.dart';
import '../../screen/register.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import 'dart:async';

class NavDrawer extends StatefulWidget {
  const NavDrawer({super.key});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  bool isJobRunning = false;
  bool isPaused = false;
  bool showJobHandler = false;
  Duration elapsed = Duration.zero;
  Timer? _timer;

  void _startJob() {
    setState(() {
      isJobRunning = true;
      isPaused = false;
      elapsed = Duration.zero;
    });
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && isJobRunning && !isPaused) {
        setState(() {
          elapsed += Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.yellow[200],
      child: Consumer<Auth>(
        builder: ((context, auth, child) {
          if (auth.authenticated) {
            return ListView(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.yellow[400]),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue),
                    title: Text(auth.user?.name ?? ''),
                    subtitle: Text(auth.user?.email ?? ''),
                    trailing: Text(auth.user?.id ?? ''),
                  ),
                ),

                ListTile(
                  title: Text('Profile'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => ProfilePage())),
                  ),
                ),
                ListTile(
                  title: Text('Settings'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => PostsScreen())),
                  ),
                ),
                ListTile(
                  title: Text('My Location'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => GoogleMapPage())),
                  ),
                ),
                ListTile(
                  title: Text('Jobs'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: ((context) => JobPage())),
                  ),
                ),
                ListTile(
                  title: Text('logout'),
                  onTap: () {
                    Provider.of<Auth>(context, listen: false).logout();
                    Navigator.pop(context);
                  },
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
