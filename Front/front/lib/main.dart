import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front/screens/admin/AdminDashboardScreen.dart';
import 'package:front/screens/homepage/course_details_screen.dart';
import 'package:front/screens/homepage/views/User%20Profile/profile_screen.dart';
import 'package:front/screens/homepage/views/bookmarks_screen.dart';
import 'package:front/screens/homepage/views/my_courses_screen.dart';
import 'package:front/screens/homepage/views/ongoing_courses_screen.dart';
import 'package:front/screens/homepage/views/popular_courses_screen.dart';
import 'package:front/screens/instructor/instructor_dashboard_screen.dart';
import 'package:front/screens/instructor/views/CreateCourseView.dart';
import 'package:front/screens/instructor/views/MySessionsView.dart';
import 'package:front/screens/instructor/views/edit_course_view.dart';
import 'package:front/screens/instructor/views/instructor_course_details_screen.dart';
import 'package:front/screens/splash_screen.dart';
import 'package:front/screens/welcome_screen.dart';
import 'package:front/auth/ForgotPasswordScreen.dart';
import 'package:front/auth/InstructorSignupScreen.dart';
import 'package:front/auth/ResetPasswordScreen.dart';
import 'package:front/auth/login_screen.dart';
import 'package:front/auth/signup_screen.dart';
import 'package:front/services/admin_service.dart';
import 'package:front/services/auth_service.dart';
import 'package:front/screens/homepage/HomeScreen.dart';
import 'package:front/services/course_service.dart';
import 'package:front/services/notification_service.dart';
import 'package:front/services/review_service.dart';
import 'package:front/services/SessionService.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    // Initialize NotificationService first
    final notificationService = NotificationService(baseUrl: 'http://192.168.1.13:8080');
    // Initialize AuthService with NotificationService
    final authService = AuthService(notificationService: notificationService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => authService,
        ),
        ChangeNotifierProvider<AdminService>(
          create: (_) => AdminService(),
        ),
        Provider<ReviewService>(
          create: (_) => ReviewService(baseUrl: 'http://192.168.1.13:8080'),
        ),
        Provider<SessionService>(
          create: (_) => SessionService(baseUrl: 'http://192.168.1.13:8080'),
        ),
        ChangeNotifierProvider<NotificationService>(
          create: (_) => notificationService,
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
      scaffoldMessengerKey: scaffoldMessengerKey,
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
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/instructor-signup': (context) => const InstructorSignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/my-courses': (context) => const MyCoursesScreen(),
        '/popular-courses': (context) => const PopularCoursesScreen(),
        '/ongoing-courses': (context) => const OngoingCoursesScreen(),
        '/bookmarks': (context) => const BookmarksScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/instructor-dashboard': (context) => const InstructorDashboardScreen(),
        '/my_sessions': (context) => const MySessionsView(),
        '/course-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is int) {
            return CourseDetailsScreen(courseId: args);
          } else if (args is Map<String, dynamic>) {
            return CourseDetailsScreen(
              courseId: args['courseId'],
              onEnrollmentChanged: args['onEnrollmentChanged'],
              onLessonCompleted: args['onLessonCompleted'],
            );
          } else {
            throw Exception("Invalid arguments for /course-details");
          }
        },
        '/instructor-course-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is CourseDTO) {
            return InstructorCourseDetailsScreen();
          } else {
            throw Exception("Invalid arguments for /instructor-course-details; expected CourseDTO");
          }
        },
        '/edit-course': (context) => const EditCourseView(),
        '/create-course': (context) => const CreateCourseView(),
      },
      onGenerateRoute: (settings) {
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Page not found: ${settings.name}'),
            ),
          ),
        );
      },
    );
  }
}