import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:front/screens/homepage/views/popular_courses_screen.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';
import 'bottom_nav_bar.dart';
import 'categories_section.dart';
import 'course_card.dart';
import 'header_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final BookmarkService bookmarkService = BookmarkService(baseUrl: 'http://192.168.1.13:8080');
  final EnrollmentService enrollmentService = EnrollmentService(baseUrl: 'http://192.168.1.13:8080');
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<CourseDTO> _popularCourses = [];

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
      await _fetchEnrolledCourses(token);
      await _fetchPopularCourses(token);
    }
  }

  Future<void> _fetchEnrolledCourses(String token) async {
    enrollmentService.setToken(token);
    courseService.setToken(token);

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
    });
  }

  Future<void> _fetchPopularCourses(String token) async {
    courseService.setToken(token);
    bookmarkService.setToken(token);

    final courses = await courseService.getAllCourses();
    final bookmarks = await bookmarkService.getBookmarkedCourses();

    final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
    for (final course in courses) {
      course.isBookmarked = bookmarkedIds.contains(course.id);
    }

    courses.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
    setState(() {
      _popularCourses = courses;
    });
  }

  void updateEnrollment(EnrollmentDTO updatedEnrollment) {
    final index = _enrolledCourses.indexWhere((data) => data['enrollment'].id == updatedEnrollment.id);
    if (index != -1) {
      setState(() {
        _enrolledCourses[index]['enrollment'] = updatedEnrollment;
      });
    }
  }

  void addEnrollment(EnrollmentDTO newEnrollment, CourseDTO course) {
    setState(() {
      _enrolledCourses.add({
        'enrollment': newEnrollment,
        'course': course,
      });
    });
  }

  void updateBookmarkStatus(int courseId, bool isBookmarked) {
    setState(() {
      final index = _popularCourses.indexWhere((course) => course.id == courseId);
      if (index != -1) {
        _popularCourses[index].isBookmarked = isBookmarked;
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 1: // My Courses
        Navigator.pushNamed(
          context,
          '/my-courses',
          arguments: (int newIndex) {
            setState(() {
              _selectedIndex = newIndex; // Reset to Home (0) when returning
            });
          },
        ).then((_) {
          setState(() {
            _selectedIndex = 0; // Ensure reset to Home on return
          });
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HeaderSection(),
              _buildSearchBar(),
              const CategoriesSection(),
              _buildPopularCourses(),
              _buildContinueLearning(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.textGray),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCourses() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PopularCoursesScreen(),
                    ),
                  );
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: _popularCourses.isEmpty
              ? FutureBuilder<List<CourseDTO>>(
            future: _getCoursesWithToken(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 32, color: AppColors.textGray),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading courses\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_outlined, size: 32, color: AppColors.textGray),
                      const SizedBox(height: 8),
                      Text(
                        'No courses available',
                        style: TextStyle(
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                );
              }

              _popularCourses = snapshot.data!;
              return _buildCourseList();
            },
          )
              : _buildCourseList(),
        ),
      ],
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _popularCourses.length,
      itemBuilder: (context, index) {
        final course = _popularCourses[index];
        return CourseCard(
          course: course,
          courseService: courseService,
          bookmarkService: bookmarkService,
          isBookmarked: course.isBookmarked,
          onTap: () async {
            await Navigator.pushNamed(
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
                  updateEnrollment(updatedEnrollment);
                },
              },
            ).then((result) async {
              if (result != null && result is Map) {
                final enrollment = result['enrollment'] as EnrollmentDTO?;
                final course = result['course'] as CourseDTO?;
                if (enrollment != null && course != null) {
                  addEnrollment(enrollment, course);
                }
              }
              final token = await Provider.of<AuthService>(context, listen: false).getToken();
              if (token != null) {
                await _fetchEnrolledCourses(token);
              }
            });
          },
          onBookmarkChanged: (isBookmarked) {
            updateBookmarkStatus(course.id!, isBookmarked);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isBookmarked ? 'Course added to bookmarks' : 'Course removed from bookmarks',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContinueLearning() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continue Learning',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _enrolledCourses.length,
            itemBuilder: (context, index) {
              final data = _enrolledCourses[index];
              final enrollment = data['enrollment'] as EnrollmentDTO;
              final course = data['course'] as CourseDTO;
              return GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/course-details',
                    arguments: {
                      'courseId': enrollment.courseId,
                      'onEnrollmentChanged': () async {
                        final token = await Provider.of<AuthService>(context, listen: false).getToken();
                        if (token != null) {
                          await _fetchEnrolledCourses(token);
                        }
                      },
                      'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                        updateEnrollment(updatedEnrollment);
                      },
                    },
                  ).then((result) async {
                    if (result != null && result is Map) {
                      final enrollment = result['enrollment'] as EnrollmentDTO?;
                      final course = result['course'] as CourseDTO?;
                      if (enrollment != null && course != null) {
                        addEnrollment(enrollment, course);
                      }
                    }
                    final token = await Provider.of<AuthService>(context, listen: false).getToken();
                    if (token != null) {
                      await _fetchEnrolledCourses(token);
                    }
                  });
                },
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: AppColors.backgroundGray),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              enrollment.courseTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by ${course.instructorName ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: enrollment.progressPercentage / 100,
                              backgroundColor: AppColors.backgroundGray,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${enrollment.progressPercentage}% Complete',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<CourseDTO>> _getCoursesWithToken() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if (token == null) {
      throw Exception('User not authenticated');
    }

    courseService.setToken(token);
    bookmarkService.setToken(token);

    final courses = await courseService.getAllCourses();
    final bookmarks = await bookmarkService.getBookmarkedCourses();

    final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
    for (final course in courses) {
      course.isBookmarked = bookmarkedIds.contains(course.id);
    }

    courses.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
    return courses;
  }
}