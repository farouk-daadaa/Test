import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/course_service.dart';
import '../../../services/enrollment_service.dart';
import '../../../services/admin_service.dart'; // Use AdminService instead of CategoryService
import '../bottom_nav_bar.dart';

class OngoingCoursesScreen extends StatefulWidget {
  const OngoingCoursesScreen({super.key});

  @override
  State<OngoingCoursesScreen> createState() => _OngoingCoursesScreenState();
}

class _OngoingCoursesScreenState extends State<OngoingCoursesScreen> {
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final BookmarkService bookmarkService = BookmarkService(baseUrl: 'http://192.168.1.13:8080');
  final EnrollmentService enrollmentService = EnrollmentService(baseUrl: 'http://192.168.1.13:8080');
  final AdminService adminService = AdminService(); // Add AdminService
  List<Map<String, dynamic>> _ongoingCourses = [];
  Map<int, String> _categoryNames = {}; // Dynamic map for category names
  Map<int, Color> _categoryColors = {}; // Dynamic map for category colors
  bool _isLoading = true;
  bool _isCategoriesLoading = true; // Track category loading state
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      courseService.setToken(token);
      bookmarkService.setToken(token);
      enrollmentService.setToken(token);
      await _fetchCategories(); // Fetch categories first
      await _fetchOngoingCourses(token);
    } else {
      setState(() {
        _isLoading = false;
        _isCategoriesLoading = false;
        _errorMessage = 'Please log in to view ongoing courses';
      });
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

  Future<void> _fetchOngoingCourses(String token) async {
    try {
      final enrollments = await enrollmentService.getEnrolledCourses();
      final courses = await courseService.getAllCourses();
      final bookmarks = await bookmarkService.getBookmarkedCourses();

      final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
      final ongoing = enrollments.where((enrollment) => enrollment.progressPercentage < 100).toList();

      setState(() {
        _ongoingCourses = ongoing.map((enrollment) {
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
          course.isBookmarked = bookmarkedIds.contains(course.id);
          return {
            'enrollment': enrollment,
            'course': course,
          };
        }).toList();
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Failed to load courses: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshCourses() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      await _fetchOngoingCourses(token);
    } else {
      setState(() {
        _isRefreshing = false;
        _errorMessage = 'Please log in to view ongoing courses';
      });
    }
  }

  Future<void> _toggleBookmark(CourseDTO course) async {
    final newState = !course.isBookmarked;
    final courseId = course.id!;

    try {
      if (newState) {
        await bookmarkService.addBookmark(courseId);
      } else {
        await bookmarkService.removeBookmark(courseId);
      }

      setState(() {
        course.isBookmarked = newState;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState ? 'Course added to bookmarks' : 'Course removed from bookmarks',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary.withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bookmark'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _toggleBookmark(course),
            ),
          ),
        );
      }
      setState(() {
        course.isBookmarked = !newState; // Revert on failure
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: (_isLoading || _isCategoriesLoading)
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildCourseList(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/my-courses');
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

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Ongoing Courses',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
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

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
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

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCourses,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage ?? 'Failed to load courses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshCourses,
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
                      'Try Again',
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

  Widget _buildCourseList() {
    if (_ongoingCourses.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshCourses,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ongoing courses yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enroll in courses to start learning',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ongoingCourses.length,
        itemBuilder: (context, index) {
          final data = _ongoingCourses[index];
          final enrollment = data['enrollment'] as EnrollmentDTO;
          final course = data['course'] as CourseDTO;
          return _buildCourseCard(course, enrollment);
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseDTO course, EnrollmentDTO enrollment) {
    final lastAccessDate = enrollment.lastAccessedDate;
    final formattedDate = '${lastAccessDate.day}/${lastAccessDate.month}/${lastAccessDate.year}';

    return Card(
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
                  await _fetchOngoingCourses(token);
                }
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
                ],
              ),
            ],
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