import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/admin/AdminDashboardScreen.dart';
import 'screens/homepage/course_details_screen.dart';
import 'screens/instructor/instructor_dashboard_screen.dart';
import 'screens/instructor/views/edit_course_view.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'auth/ForgotPasswordScreen.dart';
import 'auth/InstructorSignupScreen.dart';
import 'auth/ResetPasswordScreen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'screens/homepage/HomeScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Add this line
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
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<AdminService>(
          create: (_) => AdminService(),
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
      home: const SplashScreen(), // Always start with SplashScreen
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
        '/course-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is int) {
            return CourseDetailsScreen(courseId: args);
          } else if (args is Map<String, dynamic>) {
            return CourseDetailsScreen(courseId: args['courseId']);
          } else {
            throw Exception("Invalid arguments for /course-details");
          }
        },
        '/edit-course': (context) => const EditCourseView(),
      },
    );
  }
}