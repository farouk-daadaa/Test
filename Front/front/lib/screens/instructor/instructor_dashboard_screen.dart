import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:front/screens/instructor/views/CourseAnalyticsView.dart';
import 'package:front/screens/instructor/views/MyCoursesView.dart';
import 'package:front/screens/instructor/views/MySessionsView.dart';
import 'package:front/screens/homepage/views/User Profile/profile_screen.dart';
import 'package:front/screens/homepage/views/notifications_screen.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../../constants/colors.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({Key? key}) : super(key: key);

  @override
  _InstructorDashboardScreenState createState() => _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  int _selectedIndex = 0;

  void onCreateCoursePressed() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    // Set status bar to transparent with light icons
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness: Brightness.light, // Light icons for contrast
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: true);
    final notificationService = Provider.of<NotificationService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      body: Row(
        children: [
          if (isWideScreen)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.selected,
              backgroundColor: const Color(0xFFFDF2F8),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFFDB2777),
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Colors.grey[600],
              ),
              selectedIconTheme: const IconThemeData(
                color: Color(0xFFDB2777),
              ),
              unselectedIconTheme: IconThemeData(
                color: Colors.grey[600],
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.library_books),
                  selectedIcon: Icon(Icons.library_books),
                  label: Text('My\nCourses'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event),
                  selectedIcon: Icon(Icons.event),
                  label: Text('My\nSessions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Analytics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                // Custom header section
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20, // Account for status bar + padding
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${authService.username ?? 'Instructor'} 👋',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                "Let's manage your courses!",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NotificationsScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (notificationService.unreadCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      notificationService.unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Main content
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: _buildSelectedView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFDB2777),
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'My Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: 'My Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Reset status bar style when leaving the screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Reset to default
      statusBarIconBrightness: Brightness.dark, // Reset to default
    ));
    super.dispose();
  }

  Widget _buildSelectedView() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _getView(_selectedIndex),
    );
  }

  Widget _getView(int index) {
    switch (index) {
      case 0:
        return MyCoursesView(
          key: const ValueKey('courses'),
          onCreateCoursePressed: onCreateCoursePressed,
        );
      case 1:
        return MySessionsView(key: const ValueKey('sessions'));
      case 2:
        return CourseAnalyticsView(
          key: const ValueKey('analytics'),
        );
      case 3:
        return const ProfileScreen(
          key: ValueKey('profile'),
          isInstructorContext: true,
        );
      default:
        return const Center(child: Text('Select a view'));
    }
  }
}