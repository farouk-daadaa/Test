import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front/screens/admin/AdminDashboardScreen.dart';
import 'package:front/screens/instructor/instructor_dashboard_screen.dart';
import 'package:front/screens/instructor/views/course_details_screen.dart';
import 'package:front/screens/instructor/views/edit_course_view.dart';
import 'package:front/screens/splash_screen.dart';
import 'package:front/screens/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'auth/ForgotPasswordScreen.dart';
import 'auth/InstructorSignupScreen.dart';
import 'auth/ResetPasswordScreen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'services/admin_service.dart'; // Import your AdminService
import 'services/auth_service.dart'; // Import your AuthService
import 'screens/homepage/HomeScreen.dart'; // Import your HomeScreen

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService()..loadToken(),
        ),
        ChangeNotifierProvider<AdminService>(
          create: (_) => AdminService(), // Provide AdminService
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Learning App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFDB2777),
        fontFamily: 'System',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
        ),
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          return FutureBuilder<bool>(
            future: authService.isLoggedIn(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (snapshot.hasData && snapshot.data == true) {
                return FutureBuilder<String?>(
                  future: authService.getToken(),
                  builder: (context, tokenSnapshot) {
                    if (tokenSnapshot.connectionState == ConnectionState.waiting) {
                      return const SplashScreen();
                    }

                    if (tokenSnapshot.hasData) {
                      final userRole = authService.userRole;

                      if (userRole == 'ADMIN') {
                        return const AdminDashboardScreen();
                      } else if (userRole == 'INSTRUCTOR') {
                        return const InstructorDashboardScreen();
                      } else {
                        return const HomeScreen();
                      }
                    }
                    return const WelcomeScreen();
                  },
                );
              }

              return const WelcomeScreen();
            },
          );
        },
      ),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/instructor-signup': (context) => const InstructorSignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/instructor-dashboard': (context) => const InstructorDashboardScreen(),
        '/course-details': (context) => const CourseDetailsScreen(),
        '/edit-course': (context) => const EditCourseView(),
      },
    );
  }
}