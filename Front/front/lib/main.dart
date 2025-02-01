import 'package:flutter/material.dart';
import 'package:front/widgets/custom_app_bar.dart';
import 'package:front/widgets/custom_drawer.dart';
import 'screens/home_screen.dart';
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
      home: MainScreen(),
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

