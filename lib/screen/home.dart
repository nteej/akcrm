import '../screen/income_page.dart';
import '../screen/job_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/job_provider.dart';

import '../widgets/navdrawer.dart';
import '../screen/profile_page.dart';
import 'dashboard_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  PageController? _pageController;
  int pageINdex = 0; // Changed from 1 to 0 to default to Dashboard
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: pageINdex);
  }

  onPageChanged(int page) {
    setState(() {
      pageINdex = page;
    });
  }

  onPageTap(int page) {
    _pageController!.animateToPage(page,
        duration: Duration(microseconds: 200), curve: Curves.linearToEaseOut);
  }

  @override
  void dispose() {
    super.dispose();
    _pageController!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        elevation: 0.0,
        centerTitle: true,
        title: Consumer<JobProvider>(
          builder: (context, jobProvider, child) {
            return Column(
              children: [
                Text('SmartForce Oy', style: TextStyle(color: AppColors.text)),
                if (jobProvider.isJobRunning)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Job Running: ${jobProvider.getElapsedTimeString()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      drawer: NavDrawer(),
      backgroundColor: AppColors.background,
      body: PageView(
        onPageChanged: onPageChanged,
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          DashboardPage(),
          JobPage(),
          IncomePage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        onTap: onPageTap,
        currentIndex: pageINdex,
        activeColor: Colors.indigo,
        backgroundColor: AppColors.background,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              FeatherIcons.home,
              size: 30,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              FeatherIcons.briefcase,
              size: 30,
            ),
          ),
          
        ],
      ),
    );
  }
}
