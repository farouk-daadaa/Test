import 'package:flutter/material.dart';
import 'package:front/widgets/custom_app_bar.dart';
import 'package:front/widgets/custom_drawer.dart';
import 'package:front/screens/home_screen.dart';
import 'package:front/pages/login_page.dart';  // Add this import
import 'package:front/pages/signup_page.dart'; // Add this import
import 'theme/app_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Bridge',
      theme: AppTheme.lightTheme,
      // Define your routes here
      routes: {
        '/': (context) => MainScreen(),       // Main screen route
        '/login': (context) => LoginPage(),   // Login page route
        '/signup': (context) => SignupPage(), // Signup page route
      },
      initialRoute: '/', // Set initial route
    );
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      endDrawer: CustomDrawer(),
      body: HomeScreen(),
    );
  }
}