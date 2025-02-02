import 'package:flutter/material.dart';
import 'package:front/widgets/custom_app_bar.dart';
import 'package:front/widgets/custom_drawer.dart';
import 'package:front/screens/home_screen.dart';
import 'package:front/pages/login_page.dart';
import 'package:front/pages/signup_page.dart';
import 'package:front/pages/forgot_password_page.dart';
import 'package:front/pages/reset_password_page.dart';
import 'package:front/pages/verify_reset_code_page.dart';
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
      routes: {
        '/': (context) => MainScreen(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/forgot-password': (context) => ForgotPasswordPage(),
        '/reset-password': (context) => ResetPasswordPage(
          token: ModalRoute.of(context)!.settings.arguments as String,
        ),
        '/verify-reset-code': (context) => VerifyResetCodePage(
          email: ModalRoute.of(context)!.settings.arguments as String,
        ),
      },
      initialRoute: '/',
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

