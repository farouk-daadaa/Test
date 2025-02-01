import 'package:flutter/material.dart';
import '../pages/login_page.dart';

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header with logo
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: BoxDecoration(
              color: Color(0xFFFDF2F8),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: 40,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildDrawerItem(
                  context,
                  'Home',
                  Icons.home_rounded,
                  isActive: true,
                ),
                _buildDrawerItem(
                  context,
                  'Paths',
                  Icons.route_rounded,
                ),
                _buildDrawerItem(
                  context,
                  'Courses',
                  Icons.school_rounded,
                ),
                _buildDrawerItem(
                  context,
                  'Events',
                  Icons.event_rounded,
                ),
                _buildDrawerItem(
                  context,
                  'Reports',
                  Icons.analytics_rounded,
                ),
                _buildDrawerItem(
                  context,
                  'About us',
                  Icons.info_rounded,
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(
                    color: Colors.grey.shade200,
                    thickness: 1,
                  ),
                ),

                _buildDrawerItem(
                  context,
                  'Account',
                  Icons.person_rounded,
                  showBadge: true,
                ),
              ],
            ),
          ),

          // Version info at bottom
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context,
      String title,
      IconData icon, {
        bool isActive = false,
        bool showBadge = false,
      }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isActive ? Color(0xFFFDF2F8) : Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        leading: Icon(
          icon,
          color: isActive ? Color(0xFFDB2777) : Colors.grey.shade700,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Color(0xFFDB2777) : Colors.black87,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: showBadge
            ? Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDB2777),
          ),
        )
            : null,
        onTap: () {
          Navigator.pop(context);
          if (title == 'Account') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          }
          // Add navigation logic for other items here
        },
      ),
    );
  }
}
