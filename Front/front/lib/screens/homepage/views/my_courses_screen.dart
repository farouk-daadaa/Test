import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';
import '../../../services/enrollment_service.dart';
import '../../../services/admin_service.dart';

class MyCoursesScreen extends StatefulWidget {
  final Function(int)? onIndexChanged;

  const MyCoursesScreen({super.key, this.onIndexChanged});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final EnrollmentService enrollmentService = EnrollmentService(baseUrl: 'http://192.168.1.13:8080');
  final AdminService adminService = AdminService();
  List<Map<String, dynamic>> _enrolledCourses = [];
  Map<int, String> _categoryNames = {};
  Map<int, Color> _categoryColors = {};
  bool _isLoading = true;
  bool _isCategoriesLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initializeServices();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
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
          for (var cat in categories) cat['id'] as int: _getCategoryColor(cat['id'] as int),
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

  Color _getCategoryColor(int categoryId) {
    // Brand-aligned color palette
    final colors = [
      const Color(0xFFDB2777), // Primary pink
      const Color(0xFF9D174D), // Darker pink
      const Color(0xFFF472B6), // Lighter pink
      const Color(0xFF831843), // Deep pink
      const Color(0xFFFBCFE8), // Pale pink
      const Color(0xFFBE185D), // Medium pink
    ];
    return colors[categoryId % colors.length];
  }

  Future<void> _fetchEnrolledCourses(String token) async {
    try {
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
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      _showErrorSnackbar('Failed to load courses');
    }
  }

  Future<void> _refreshCourses() async {
    setState(() {
      _isRefreshing = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      await _fetchEnrolledCourses(token);
    } else {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _refreshCourses,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading || _isCategoriesLoading
          ? _buildLoadingState()
          : Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCourseList(),
                _buildCourseList(completedOnly: true),
              ],
            ),
          ),
        ],
      ),
      // Remove bottomNavigationBar to avoid duplication
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          widget.onIndexChanged?.call(0); // Notify HomeScreen to switch to Home tab
        },
      ),
      title: const Text(
        'My Courses',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {
            // Implement search functionality
          },
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
        tabs: const [
          Tab(text: 'Ongoing'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
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
      return _buildEmptyState(completedOnly);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredCourses.length,
        itemBuilder: (context, index) {
          final data = filteredCourses[index];
          final enrollment = data['enrollment'] as EnrollmentDTO;
          final course = data['course'] as CourseDTO;
          return _buildCourseCard(course, enrollment);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCourses,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCompleted ? Icons.school : Icons.menu_book,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCompleted
                        ? 'No completed courses yet'
                        : 'No ongoing courses yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCompleted
                        ? 'Complete your ongoing courses to see them here'
                        : 'Enroll in courses to start learning',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!isCompleted)
                    ElevatedButton(
                      onPressed: () {
                        widget.onIndexChanged?.call(0); // Switch to Home tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Browse Courses',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseDTO course, EnrollmentDTO enrollment) {
    final lastAccessDate = enrollment.lastAccessedDate;
    final formattedDate = '${lastAccessDate.day}/${lastAccessDate.month}/${lastAccessDate.year}';

    return Hero(
      tag: 'course-${course.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        courseService.getImageUrl(course.imageUrl),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _categoryColors[course.categoryId] ?? Colors.grey,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _categoryNames[course.categoryId] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                          Row(
                            children: [
                              const Icon(Icons.person, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  course.instructorName ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Last accessed: $formattedDate',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${enrollment.progressPercentage}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(enrollment.progressPercentage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: enrollment.progressPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(enrollment.progressPercentage),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          enrollment.status == EnrollmentStatus.COMPLETED
                              ? 'Completed'
                              : 'In Progress',
                          style: TextStyle(
                            color: enrollment.status == EnrollmentStatus.COMPLETED
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/course-details',
                              arguments: {'courseId': course.id},
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            children: [
                              Text(
                                enrollment.status == EnrollmentStatus.COMPLETED
                                    ? 'Review'
                                    : 'Continue',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                enrollment.status == EnrollmentStatus.COMPLETED
                                    ? Icons.rate_review
                                    : Icons.play_circle_outline,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(int progress) {
    if (progress < 30) return Colors.red;
    if (progress < 70) return Colors.orange;
    if (progress < 100) return Colors.blue;
    return Colors.green;
  }
}