import 'package:flutter/material.dart';
import 'package:front/screens/instructor/views/CourseAnalyticsView.dart';
import 'package:front/screens/instructor/views/CreateCourseView.dart';
import 'package:front/screens/instructor/views/MyCoursesView.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';


class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({Key? key}) : super(key: key);

  @override
  _InstructorDashboardScreenState createState() => _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Dashboard'),
        backgroundColor: Color(0xFFDB2777),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.logout(context);
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWideScreen)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.selected,
              backgroundColor: Color(0xFFFDF2F8),
              selectedLabelTextStyle: TextStyle(
                color: Color(0xFFDB2777),
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: Colors.grey[600],
              ),
              selectedIconTheme: IconThemeData(
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
                  icon: Icon(Icons.add_box),
                  selectedIcon: Icon(Icons.add_box),
                  label: Text('Create\nCourse'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Analytics'),
                ),
              ],
            ),
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: _buildSelectedView(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWideScreen
          ? null
          : BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Color(0xFFDB2777),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'My Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Create Course',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedView() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: _getView(_selectedIndex),
    );
  }

  Widget _getView(int index) {
    switch (index) {
      case 0:
        return MyCoursesView(key: ValueKey('courses'));
      case 1:
        return CreateCourseView(key: ValueKey('create'));
      case 2:
        return CourseAnalyticsView(key: ValueKey('analytics'));
      default:
        return Center(child: Text('Select a view'));
    }
  }
}

