import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:front/screens/homepage/views/User%20Profile/profile_screen.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/image_service.dart';
import '../../services/admin_service.dart';
import 'bottom_nav_bar.dart';
import 'categories_section.dart'; // Use the standalone CategoriesSection
import 'course_card.dart';
import 'header_section.dart';
import 'views/ongoing_courses_screen.dart';
import 'views/popular_courses_screen.dart';
import 'filter_screen.dart';
import 'package:collection/collection.dart';

// SearchResultsScreen class (kept inside HomeScreen file as per your setup)
class SearchResultsScreen extends StatelessWidget {
  final List<CourseDTO> searchResults;
  final CourseService courseService;
  final BookmarkService bookmarkService;
  final Function(int, bool) onBookmarkChanged;

  const SearchResultsScreen({
    super.key,
    required this.searchResults,
    required this.courseService,
    required this.bookmarkService,
    required this.onBookmarkChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: searchResults.isEmpty
          ? const Center(
        child: Text(
          'No courses found',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.textGray,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final course = searchResults[index];
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
                      // Assuming there's a way to refresh enrolled courses in the parent
                    }
                  },
                  'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                    // Assuming there's a way to update enrollment in the parent
                  },
                },
              );
            },
            onBookmarkChanged: (isBookmarked) {
              onBookmarkChanged(course.id!, isBookmarked);
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
      ),
    );
  }
}

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
  final ImageService imageService = ImageService();
  late AuthService _authService;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<CourseDTO> _popularCourses = [];
  List<CourseDTO> _featuredCourses = [];
  List<String> _topInstructors = [];
  Map<String, Uint8List?> _instructorImages = {};
  List<Map<String, dynamic>> _categories = []; // Added to store categories

  // Search-related variables
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  final GlobalKey _searchContainerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      courseService.setToken(token);
      bookmarkService.setToken(token);
      enrollmentService.setToken(token);
      imageService.setToken(token);
      _authService = authService;
      await _fetchEnrolledCourses(token);
      await _fetchPopularCourses(token);
      await _fetchFeaturedCourses(token);
      await _fetchTopInstructors(token, context);
      await _fetchCategories(token); // Fetch categories
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

  Future<void> _fetchFeaturedCourses(String token) async {
    final allCourses = await courseService.getAllCourses();
    setState(() {
      _featuredCourses = allCourses.where((course) => (course.rating ?? 0) > 4.0).take(5).toList();
    });
  }

  Future<void> _fetchTopInstructors(String token, BuildContext context) async {
    final allCourses = await courseService.getAllCourses();
    final instructorRatings = <String, List<double>>{};
    for (var course in allCourses) {
      if (course.instructorName != null && course.rating != null) {
        instructorRatings.putIfAbsent(course.instructorName!, () => []).add(course.rating!);
      }
    }
    final topInstructors = instructorRatings.entries
        .map((entry) => MapEntry(entry.key, entry.value.reduce((a, b) => a + b) / entry.value.length))
        .where((entry) => entry.value > 0)
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((entry) => entry.key)
        .toList();
    setState(() {
      _topInstructors = topInstructors;
    });
    for (var instructorName in _topInstructors) {
      await _fetchInstructorImage(instructorName, context, token);
    }
  }

  Future<void> _fetchInstructorImage(String instructorName, BuildContext context, String token) async {
    if (_instructorImages.containsKey(instructorName)) return;
    final instructorId = await _authService.getUserIdByUsername(instructorName);
    if (instructorId != null) {
      print('Fetching image for $instructorName with ID: $instructorId');
      final imageBytes = await imageService.getUserImage(context, instructorId);
      if (imageBytes != null) {
        print('Image fetched for $instructorName: ${imageBytes.length} bytes');
        setState(() {
          _instructorImages[instructorName] = imageBytes;
        });
      } else {
        print('No image bytes returned for $instructorName');
      }
    } else {
      print('No ID found for instructor: $instructorName');
    }
  }

  Future<void> _fetchCategories(String token) async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final categories = await adminService.getAllCategories();
    setState(() {
      _categories = categories;
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
      case 1:
        Navigator.pushNamed(
          context,
          '/my-courses',
          arguments: (int newIndex) {
            setState(() {
              _selectedIndex = newIndex;
            });
          },
        ).then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
      case 2:
        Navigator.pushNamed(context, '/bookmarks').then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
      case 3:
        Navigator.pushNamed(context, '/chat').then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
    } else {
      final uniqueSuggestions = <String>{};
      for (final course in _popularCourses) {
        if (course.title.toLowerCase().contains(query)) {
          uniqueSuggestions.add(course.title);
        }
      }
      setState(() {
        _suggestions = uniqueSuggestions
            .where((suggestion) => suggestion.length <= 50)
            .take(5)
            .toList();
      });
    }
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final query = _searchController.text;
    final suggestionsToShow = query.isEmpty ? _recentSearches : _suggestions;
    if (suggestionsToShow.isEmpty && query.isEmpty && _recentSearches.isEmpty) return;
    final RenderBox? renderBox = _searchContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      print('Search bar render box not found');
      return;
    }
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    const double listTileHeight = 56.0;
    const double headerHeight = 32.0;
    final int suggestionCount = suggestionsToShow.length;
    final double dynamicHeight = query.isEmpty && _recentSearches.isNotEmpty
        ? headerHeight + (suggestionCount * listTileHeight)
        : suggestionCount * listTileHeight;
    const double minHeight = listTileHeight;
    const double maxHeight = 200.0;
    final double finalHeight = dynamicHeight.clamp(minHeight, maxHeight);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 16,
        top: offset.dy + size.height,
        width: size.width - 24,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: finalHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.backgroundGray),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (query.isEmpty && _recentSearches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Searches',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...suggestionsToShow.asMap().entries.map((entry) {
                    final index = entry.key;
                    final suggestion = entry.value;
                    return ListTile(
                      title: Text(
                        suggestion.length > 50 ? '${suggestion.substring(0, 47)}...' : suggestion,
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: query.isEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textGray),
                        onPressed: () {
                          setState(() {
                            _recentSearches.removeAt(index);
                          });
                          _showOverlay();
                        },
                      )
                          : null,
                      onTap: () {
                        _searchController.text = suggestion;
                        _removeOverlay();
                        _performSearch(suggestion);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a search query'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 5) {
        _recentSearches = _recentSearches.take(5).toList();
      }
    });
    final searchResults = _popularCourses.where((course) {
      final queryLower = query.toLowerCase();
      return course.title.toLowerCase().contains(queryLower);
    }).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          searchResults: searchResults,
          courseService: courseService,
          bookmarkService: bookmarkService,
          onBookmarkChanged: updateBookmarkStatus,
        ),
      ),
    );
    _removeOverlay();
  }

  void _openFilterScreen() {
    if (_popularCourses.isEmpty) {
      print('Warning: _popularCourses is empty, filtering may not work');
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          allCourses: _popularCourses,
          onApply: (filteredCourses) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchResultsScreen(
                  searchResults: filteredCourses,
                  courseService: courseService,
                  bookmarkService: bookmarkService,
                  onBookmarkChanged: updateBookmarkStatus,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openCategoryScreen(String categoryId, String categoryName) {
    if (_popularCourses.isEmpty) {
      print('Warning: _popularCourses is empty, filtering may not work');
    }
    final filteredCourses = _popularCourses.where((course) {
      return course.categoryId.toString() == categoryId;
    }).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          searchResults: filteredCourses,
          courseService: courseService,
          bookmarkService: bookmarkService,
          onBookmarkChanged: updateBookmarkStatus,
        ),
      ),
    );
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
              CategoriesSection(
                allCourses: _popularCourses, // Pass _popularCourses
                onCategorySelected: _openCategoryScreen, // Pass the callback
              ),
              _buildPopularCourses(),
              _buildTopInstructors(),
              if (_enrolledCourses.any((data) => (data['enrollment'] as EnrollmentDTO).progressPercentage < 100))
                Column(
                  children: [
                    _buildContinueLearning(),
                    const SizedBox(height: 80),
                  ],
                ),
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
              key: _searchContainerKey,
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
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Search courses...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.textGray),
                ),
                onSubmitted: (value) {
                  _performSearch(value);
                },
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
            child: GestureDetector(
              onTap: () {
                _performSearch(_searchController.text);
              },
              child: const Icon(Icons.search, color: Colors.white),
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
            child: GestureDetector(
              onTap: _openFilterScreen,
              child: const Icon(Icons.tune, color: Colors.white),
            ),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OngoingCoursesScreen(),
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
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _enrolledCourses.length,
            itemBuilder: (context, index) {
              final data = _enrolledCourses[index];
              final enrollment = data['enrollment'] as EnrollmentDTO;
              if (enrollment.progressPercentage == 100) return const SizedBox.shrink();
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

  Widget _buildTopInstructors() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Instructors',
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
          height: 150,
          child: _topInstructors.isEmpty
              ? const Center(child: Text('No top instructors available'))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _topInstructors.length,
            itemBuilder: (context, index) {
              final instructorName = _topInstructors[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _instructorImages[instructorName] != null
                          ? MemoryImage(_instructorImages[instructorName]!)
                          : null,
                      backgroundColor: _instructorImages[instructorName] == null
                          ? AppColors.primary.withOpacity(0.1)
                          : null,
                      child: _instructorImages[instructorName] == null
                          ? Text(
                        instructorName[0],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      instructorName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    return Icons.category;
  }
}