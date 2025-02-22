// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'views/pending_instructors_view.dart';
import 'views/all_instructors_view.dart';
import 'views/students_view.dart';
import 'views/categories_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Color(0xFFDB2777),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.logout(context); // Pass the context here
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
                  icon: Icon(Icons.pending),
                  selectedIcon: Icon(Icons.pending),
                  label: Text('Pending\nInstructors'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.school),
                  selectedIcon: Icon(Icons.school),
                  label: Text('All\nInstructors'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Students'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category),
                  selectedIcon: Icon(Icons.category),
                  label: Text('Categories'),
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
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFDB2777),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending),
            label: 'Pending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Instructors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
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
        return PendingInstructorsView(key: ValueKey('pending'));
      case 1:
        return AllInstructorsView(key: ValueKey('instructors'));
      case 2:
        return StudentsView(key: ValueKey('students'));
      case 3:
        return CategoriesView(key: ValueKey('categories'));
      default:
        return Center(child: Text('Select a view'));
    }
  }
}