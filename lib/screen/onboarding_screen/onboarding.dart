import 'package:flutter/material.dart';
import '../../helper/images.dart';
import '../login_screen.dart';
import '../onboarding_screen/first_screen.dart';
import '../../widgets/custom_button.dart';
import '../../config/string.dart' as AppString;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController _controller = PageController();
  List<Widget> screens = [
    BuildPage(images: Images.hit, text: AppString.Text.onboard_1),
    BuildPage(
        images: Images.catchp,
        text: AppString.Text.onboard_2),
    BuildPage(images: Images.freinds, text: AppString.Text.onboard_3),
  ];

  bool isLastPage = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  navigate() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: ((context) => LoginScreen())));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _controller,
          itemCount: screens.length,
          onPageChanged: (value) {
            setState(() {
              isLastPage = value == 2;
            });
          },
          itemBuilder: ((context, pageindex) {
            return Stack(
              children: [
                screens[pageindex],
                Positioned(
                  right: 25,
                  top: MediaQuery.of(context).size.height * 0.35,
                  child: Column(
                    children: List.generate(
                      3,
                      (index) {
                        return Padding(
                          padding: EdgeInsets.all(2),
                          child: GestureDetector(
                            onTap: () => _controller.animateToPage(index,
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeIn),
                            child: Container(
                              width: 8,
                              height: pageindex == index ? 25 : 8,
                              decoration: BoxDecoration(
                                  color: pageindex == index
                                      ? Colors.indigo
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      bottomSheet: isLastPage
          ? CustomButton(
              title: 'Get Started',
              onTap: navigate,
            )
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _controller.nextPage(
                        duration: Duration(microseconds: 1000),
                        curve: Curves.easeInOut),
                    child: Text('Next'),
                  ),
                  TextButton(
                    onPressed: () => _controller.jumpToPage(2),
                    child: Text('Skip'),
                  ),
                ],
              ),
            ),
    );
  }
}
