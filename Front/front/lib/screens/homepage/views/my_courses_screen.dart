import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';
import '../../../services/enrollment_service.dart';
import '../../../services/admin_service.dart'; // Import AdminService
import '../bottom_nav_bar.dart';

class MyCoursesScreen extends StatefulWidget {
  final Function(int)? onIndexChanged; // Callback to reset index

  const MyCoursesScreen({super.key, this.onIndexChanged});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final EnrollmentService enrollmentService = EnrollmentService(baseUrl: 'http://192.168.1.13:8080');
  final AdminService adminService = AdminService(); // Instance for category fetch
  List<Map<String, dynamic>> _enrolledCourses = [];
  Map<int, String> _categoryNames = {}; // Dynamic category name mapping
  Map<int, Color> _categoryColors = {}; // Dynamic category color mapping
  bool _isLoading = true;
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      courseService.setToken(token);
      enrollmentService.setToken(token);
      await _fetchCategories();
      await _fetchEnrolledCourses(token);
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isCategoriesLoading = true;
    });
    try {
      final categories = await adminService.getAllCategories();
      setState(() {
        _categoryNames = {for (var cat in categories) cat['id'] as int: cat['name'] as String};
        _categoryColors = {
          for (var cat in categories) cat['id'] as int: _getDefaultColor(cat['id'] as int),
        };
        _isCategoriesLoading = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _isCategoriesLoading = false;
      });
    }
  }

  Color _getDefaultColor(int categoryId) {
    // Assign default colors based on category ID (can be customized)
    final colors = [Colors.orange, Colors.blue, Colors.green, Colors.purple, Colors.red, Colors.teal];
    return colors[categoryId % colors.length] ?? Colors.grey;
  }

  Future<void> _fetchEnrolledCourses(String token) async {
    final enrollments = await enrollmentService.getEnrolledCourses();
    final courses = await courseService.getAllCourses();

    setState(() {
      _enrolledCourses = enrollments.map((enrollment) {
        final course = courses.firstWhere(
              (c) => c.id == enrollment.courseId,
          orElse: () => CourseDTO(
            id: enrollment.courseId,
            title: enrollment.courseTitle,
            description: enrollment.courseDescription,
            price: Decimal.zero,
            pricingType: PricingType.FREE,
            imageUrl: '',
            level: CourseLevel.BEGINNER,
            language: CourseLanguage.ENGLISH,
            categoryId: 0,
          ),
        );
        return {
          'enrollment': enrollment,
          'course': course,
        };
      }).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            widget.onIndexChanged?.call(0); // Reset to Home index
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'My Course',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading || _isCategoriesLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.black54,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Ongoing'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCourseList(), // Ongoing courses
                _buildCourseList(completedOnly: true), // Completed courses
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Default to My Courses
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/bookmarks');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildCourseList({bool completedOnly = false}) {
    final filteredCourses = _enrolledCourses.where((data) {
      final enrollment = data['enrollment'] as EnrollmentDTO;
      return completedOnly
          ? enrollment.progressPercentage == 100
          : enrollment.progressPercentage < 100;
    }).toList();

    if (filteredCourses.isEmpty) {
      return Center(
        child: Text(
          completedOnly ? 'No completed courses yet' : 'No ongoing courses yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final data = filteredCourses[index];
        final enrollment = data['enrollment'] as EnrollmentDTO;
        final course = data['course'] as CourseDTO;
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/course-details',
              arguments: {
                'courseId': course.id,
                'onEnrollmentChanged': () async {
                  final token = await Provider.of<AuthService>(context, listen: false).getToken();
                  if (token != null) {
                    await _fetchEnrolledCourses(token);
                  }
                },
                'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                  // Update the enrollment in this screen if needed
                },
              },
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      courseService.getImageUrl(course.imageUrl),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _categoryColors[course.categoryId] ?? Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _categoryNames[course.categoryId] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${course.instructorName ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: enrollment.progressPercentage / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${enrollment.progressPercentage}% Complete',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}