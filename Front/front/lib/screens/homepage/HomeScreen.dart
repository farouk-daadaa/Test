import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart'; // Add this import
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
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
              _buildUpcomingSessions(),
              _buildUpcomingEvents(),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: FutureBuilder<List<CourseDTO>>(
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
                      const Icon(Icons.error_outline, size: 32),
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
                      const Icon(Icons.school_outlined, size: 32),
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

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final course = snapshot.data![index];
                  return CourseCard(
                    course: course,
                    courseService: courseService,
                    bookmarkService: bookmarkService,
                    isBookmarked: course.isBookmarked,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/course-details',
                        arguments: course.id,
                      );
                    },
                    onBookmarkChanged: (isBookmarked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isBookmarked
                                ? 'Course added to bookmarks'
                                : 'Course removed from bookmarks',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLearning() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continue Learning',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getEnrolledCoursesWithToken(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 32, color: AppColors.textGray),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    ],
                  ),
                );
              }
              final enrollmentData = snapshot.data ?? [];
              if (enrollmentData.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_outlined, size: 32, color: AppColors.textGray),
                      const SizedBox(height: 8),
                      Text(
                        'No enrolled courses yet',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: enrollmentData.length,
                itemBuilder: (context, index) {
                  final data = enrollmentData[index];
                  final enrollment = data['enrollment'] as EnrollmentDTO;
                  final course = data['course'] as CourseDTO;
                  return Container(
                    width: 300,
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.backgroundGray),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            courseService.getImageUrl(course.imageUrl), // Use course.imageUrl
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
                        const SizedBox(width: 16),
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
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: enrollment.progressPercentage / 100,
                                backgroundColor: AppColors.backgroundGray,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${enrollment.progressPercentage}% Complete',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/course-details',
                                        arguments: enrollment.courseId,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text('Resume'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingSessions() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Live Sessions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.backgroundGray),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advanced Flutter Concepts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: AppColors.textGray),
                        const SizedBox(width: 4),
                        Text(
                          'Today, 3:00 PM',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingEvents() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.backgroundGray),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flutter Developer Meetup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AppColors.textGray),
                        const SizedBox(width: 4),
                        Text(
                          'March 15, 2024',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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

  Future<List<Map<String, dynamic>>> _getEnrolledCoursesWithToken() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token == null) throw Exception('User not authenticated');

    enrollmentService.setToken(token);
    courseService.setToken(token); // Ensure token is set for courseService

    final enrollments = await enrollmentService.getEnrolledCourses();
    final courses = await courseService.getAllCourses();

    // Map enrollments to their corresponding courses
    return enrollments.map((enrollment) {
      final course = courses.firstWhere(
            (c) => c.id == enrollment.courseId,
        orElse: () => CourseDTO(
          id: enrollment.courseId,
          title: enrollment.courseTitle,
          description: enrollment.courseDescription,
          price: Decimal.zero,
          pricingType: PricingType.FREE,
          imageUrl: '', // Default empty image URL
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
  }
}