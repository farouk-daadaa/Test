import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/course_service.dart';
import '../../../services/enrollment_service.dart';
import '../bottom_nav_bar.dart';

class PopularCoursesScreen extends StatefulWidget {
  const PopularCoursesScreen({super.key});

  @override
  State<PopularCoursesScreen> createState() => _PopularCoursesScreenState();
}

class _PopularCoursesScreenState extends State<PopularCoursesScreen> {
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final BookmarkService bookmarkService = BookmarkService(baseUrl: 'http://192.168.1.13:8080');
  List<CourseDTO> _popularCourses = [];
  List<CourseDTO> _filteredCourses = []; // For search results
  bool _isLoading = true;
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
      await _fetchPopularCourses(token);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view popular courses';
      });
    }
  }

  Future<void> _fetchPopularCourses(String token) async {
    try {
      final courses = await courseService.getAllCourses();
      final bookmarks = await bookmarkService.getBookmarkedCourses();

      final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
      for (final course in courses) {
        course.isBookmarked = bookmarkedIds.contains(course.id);
      }

      setState(() {
        _popularCourses = courses;
        _filteredCourses = List.from(_popularCourses); // Initialize filtered list
        _popularCourses.sort((a, b) => (b.totalStudents ?? 0).compareTo(a.totalStudents ?? 0));
        _filteredCourses.sort((a, b) => (b.totalStudents ?? 0).compareTo(a.totalStudents ?? 0));
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
      await _fetchPopularCourses(token);
    } else {
      setState(() {
        _isRefreshing = false;
        _errorMessage = 'Please log in to view popular courses';
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

  void _filterCourses(String query) {
    _filteredCourses = _popularCourses.where((course) {
      final titleLower = course.title.toLowerCase();
      final instructorLower = (course.instructorName ?? '').toLowerCase();
      final searchLower = query.toLowerCase();
      return titleLower.contains(searchLower) || instructorLower.contains(searchLower);
    }).toList();
    _filteredCourses.sort((a, b) => (b.totalStudents ?? 0).compareTo(a.totalStudents ?? 0));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading
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
        'Popular Courses',
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
          onPressed: () async {
            final result = await showSearch(
              context: context,
              delegate: CourseSearchDelegate(_popularCourses, courseService, _fetchPopularCourses),
            );
            if (result != null && result.isNotEmpty) {
              _filterCourses(result);
            }
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
            height: 150, // Adjusted to match card height with image
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
    if (_filteredCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No courses found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
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
        itemCount: _filteredCourses.length,
        itemBuilder: (context, index) {
          final course = _filteredCourses[index];
          return _buildCourseCard(course);
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseDTO course) {
    return Hero(
      tag: 'popular-course-${course.id}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/course-details',
              arguments: {
                'courseId': course.id,
                'onEnrollmentChanged': () async {
                  final token = await Provider.of<AuthService>(context, listen: false).getToken();
                  if (token != null) {
                    await _fetchPopularCourses(token);
                  }
                },
              },
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      courseService.getImageUrl(course.imageUrl),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 50),
                      ),
                    ),
                    // Bookmark button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            course.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: course.isBookmarked ? AppColors.primary : Colors.grey[600],
                          ),
                          onPressed: () => _toggleBookmark(course),
                          constraints: const BoxConstraints(
                            minHeight: 36,
                            minWidth: 36,
                          ),
                          padding: const EdgeInsets.all(8),
                          iconSize: 20,
                        ),
                      ),
                    ),
                    // Student count badge
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${course.totalStudents ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Course details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Instructor
                    Text(
                      'by ${course.instructorName ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rating and reviews
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final rating = course.rating ?? 0.0;
                          if (i < rating.floor()) {
                            return const Icon(Icons.star, color: Colors.amber, size: 18);
                          } else if (i < rating.ceil() && rating.floor() != rating.ceil()) {
                            return const Icon(Icons.star_half, color: Colors.amber, size: 18);
                          } else {
                            return const Icon(Icons.star_border, color: Colors.amber, size: 18);
                          }
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${course.rating?.toStringAsFixed(1) ?? '0.0'} (${course.totalReviews ?? 0})',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Price and level
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Level
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            course.level.toString().split('.').last,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Price
                        Text(
                          course.price == Decimal.fromInt(0)
                              ? 'Free'
                              : '\$${course.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary,
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
      ),
    );
  }
}

// Custom Search Delegate
class CourseSearchDelegate extends SearchDelegate<String> {
  final List<CourseDTO> courses;
  final CourseService courseService;
  final Future<void> Function(String) refreshCourses; // Added refresh callback

  CourseSearchDelegate(this.courses, this.courseService, this.refreshCourses);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, query),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredCourses = courses.where((course) {
      final titleLower = course.title.toLowerCase();
      final instructorLower = (course.instructorName ?? '').toLowerCase();
      final searchLower = query.toLowerCase();
      return titleLower.contains(searchLower) || instructorLower.contains(searchLower);
    }).toList();

    if (filteredCourses.isEmpty && query.isNotEmpty) {
      return Center(
        child: Text(
          'No courses found',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredCourses.length,
      itemBuilder: (context, index) {
        final course = filteredCourses[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              courseService.getImageUrl(course.imageUrl),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 30),
              ),
            ),
          ),
          title: Text(
            course.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            'by ${course.instructorName ?? 'Unknown'}',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          onTap: () {
            close(context, query);
            Navigator.pushNamed(
              context,
              '/course-details',
              arguments: {
                'courseId': course.id,
                'onEnrollmentChanged': () async {
                  await refreshCourses(await Provider.of<AuthService>(context, listen: false).getToken() ?? '');
                },
              },
            );
          },
        );
      },
    );
  }
}