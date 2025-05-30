import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front/screens/homepage/views/User%20Profile/profile_screen.dart';
import 'package:front/screens/homepage/views/all_instructors_screen.dart';
import 'package:front/screens/homepage/views/all_sessions_screen.dart';
import 'package:front/screens/homepage/views/bookmarks_screen.dart';
import 'package:front/screens/homepage/views/instructor_profile_screen.dart';
import 'package:front/screens/homepage/views/my_courses_screen.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/event_service.dart';
import '../../services/image_service.dart';
import '../../services/admin_service.dart';
import '../../services/instructor_service.dart';
import '../../services/notification_service.dart';
import '../../services/SessionService.dart';
import '../admin/views/event_detail_view.dart';
import '../instructor/views/LobbyScreen.dart';
import 'bottom_nav_bar.dart';
import 'categories_section.dart';
import 'chatbot_screen.dart';
import 'course_card.dart';
import 'header_section.dart';
import 'views/ongoing_courses_screen.dart';
import 'views/popular_courses_screen.dart';
import 'filter_screen.dart';
import 'package:collection/collection.dart';

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
                    // Refresh will handle this now
                  },
                  'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                    // Refresh will handle this now
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
  final SessionService sessionService = SessionService(baseUrl: 'http://192.168.1.13:8080');
  final EventService eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  late AuthService _authService;
  late NotificationService _notificationService;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<CourseDTO> _popularCourses = [];
  List<CourseDTO> _featuredCourses = [];
  List<Map<String, dynamic>> _topInstructors = [];
  Map<String, Uint8List?> _instructorImages = {};
  List<Map<String, dynamic>> _categories = [];
  List<SessionDTO> _availableSessions = [];
  List<EventDTO> _upcomingEvents = [];
  Map<int, String> _instructorNames = {};
  final HMSSDK _hmsSDK = HMSSDK();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  final GlobalKey _searchContainerKey = GlobalKey();

  static final List<Widget> _screens = [
    Container(),
    const MyCoursesScreen(),
    const BookmarksScreen(),
    const ChatBotScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _notificationService = Provider.of<NotificationService>(context, listen: false);
    _initializeServices();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(_onSearchTextChanged);
    _initializeHMSSDK();
  }

  Future<void> _initializeHMSSDK() async {
    await _hmsSDK.build();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeOverlay();
    _notificationService.disconnectWebSocket();
    _hmsSDK.destroy();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
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
      sessionService.setToken(token);
      eventService.setToken(token);
      _authService = authService;
      _notificationService.setToken(token);
      _notificationService.resetDisposalState();
      final username = authService.username;
      if (username != null) {
        final userId = await authService.getUserIdByUsername(username);
        if (userId != null) {
          try {
            await _notificationService.fetchNotifications(userId);
            await _notificationService.fetchUnreadNotifications(userId);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load notifications: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          try {
            await _notificationService.initializeWebSocket(userId.toString(), token);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to connect to notifications: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      await _refreshAllData(token);
    }
  }

  Future<void> _refreshAllData(String? token) async {
    token ??= await _authService.getToken();
    if (token == null) return;
    await Future.wait([
      _fetchEnrolledCourses(token),
      _fetchPopularCourses(token),
      _fetchFeaturedCourses(token),
      _fetchTopInstructors(token, context),
      _fetchCategories(token),
      _fetchAvailableSessions(token),
      _fetchUpcomingEvents(token),
    ]);
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
    final instructorIds = <String, int>{};
    final instructorService = InstructorService();
    instructorService.setToken(token);

    for (var course in allCourses) {
      if (course.instructorName != null && course.rating != null) {
        instructorRatings.putIfAbsent(course.instructorName!, () => []).add(course.rating!);
        if (!instructorIds.containsKey(course.instructorName)) {
          final id = await instructorService.getInstructorIdByUsername(course.instructorName!);
          if (id != null) {
            instructorIds[course.instructorName!] = id;
          }
        }
      }
    }

    final topInstructors = instructorRatings.entries
        .map((entry) => MapEntry(entry.key, entry.value.reduce((a, b) => a + b) / entry.value.length))
        .where((entry) => entry.value > 0 && instructorIds.containsKey(entry.key))
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((entry) => {'name': entry.key, 'id': instructorIds[entry.key]})
        .toList();

    setState(() {
      _topInstructors = topInstructors;
    });

    for (var instructor in topInstructors) {
      await _fetchInstructorImage(instructor['name'] as String, instructor['id'] as int, token);
    }
  }

  Future<void> _fetchInstructorImage(String instructorName, int instructorId, String token) async {
    if (_instructorImages.containsKey(instructorName)) return;

    final instructorService = InstructorService();
    instructorService.setToken(token);
    final imageService = ImageService();
    imageService.setToken(token);

    try {
      final userId = await instructorService.getUserIdByInstructorId(instructorId);
      if (userId == null) {
        print('No userId found for instructor: $instructorName (instructorId: $instructorId)');
        return;
      }

      print('Fetching image for instructor: $instructorName, userId: $userId');
      final imageBytes = await imageService.getUserImage(context, userId);
      if (imageBytes != null && imageBytes.isNotEmpty) {
        setState(() {
          _instructorImages[instructorName] = imageBytes;
          print('Image loaded for $instructorName: ${imageBytes.length} bytes');
        });
      } else {
        print('No image data returned for instructor: $instructorName (userId: $userId)');
      }
    } catch (e) {
      print('Error fetching image for instructor $instructorName (instructorId: $instructorId): $e');
    }
  }

  Future<void> _fetchCategories(String token) async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final categories = await adminService.getAllCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _fetchAvailableSessions(String token) async {
    sessionService.setToken(token);
    final instructorService = InstructorService()..setToken(token);
    try {
      final userId = await _authService.getUserIdByUsername(_authService.username ?? '');
      if (userId != null) {
        final sessions = await sessionService.getAvailableSessions(userId);
        final liveSessions = sessions.where((session) => session.status == 'LIVE').toList();

        for (var session in liveSessions) {
          if (session.instructorId != null && !_instructorNames.containsKey(session.instructorId)) {
            final profile = await instructorService.getInstructorProfile(session.instructorId!);
            _instructorNames[session.instructorId!] = profile?.username ?? 'Unknown';
          }
        }

        setState(() {
          _availableSessions = liveSessions;
        });
      }
    } catch (e) {
      print('Error fetching live sessions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load live sessions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchUpcomingEvents(String token) async {
    eventService.setToken(token);
    try {
      final response = await eventService.getEvents(status: 'UPCOMING');
      final events = response['events'] as List<EventDTO>;
      setState(() {
        _upcomingEvents = events;
      });
      print('Fetched ${events.length} upcoming events');
    } catch (e) {
      print('Error fetching upcoming events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load upcoming events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        _suggestions = uniqueSuggestions.where((suggestion) => suggestion.length <= 50).take(5).toList();
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
    if (renderBox == null) return;
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HeaderSection(),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _refreshAllData(null);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          CategoriesSection(
                            allCourses: _popularCourses,
                            onCategorySelected: _openCategoryScreen,
                          ),
                          _buildPopularCourses(),
                          _buildTopInstructors(),
                          if (_enrolledCourses.any((data) =>
                          (data['enrollment'] as EnrollmentDTO).progressPercentage < 100))
                            Column(
                              children: [
                                _buildContinueLearning(),
                                const SizedBox(height: 20),
                                _buildLiveSessions(),
                                const SizedBox(height: 20),
                                _buildUpcomingEvents(),
                                const SizedBox(height: 80),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _screens[1],
          _screens[2],
          _screens[3],
          _screens[4],
        ],
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
              ? Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
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
                  // No need to fetch here; refresh will handle it
                },
                'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                  updateEnrollment(updatedEnrollment);
                },
              },
            );
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

  String _getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';
    return '${eventService.baseUrl}$relativeUrl';
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.event,
          size: 64,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildEventCard(EventDTO event) {
    final now = DateTime.now();
    final isUpcoming = now.isBefore(event.startDateTime);
    final isOngoing = now.isAfter(event.startDateTime) && now.isBefore(event.endDateTime);
    final isPast = now.isAfter(event.endDateTime);

    Color statusColor;
    String statusText;

    if (isUpcoming) {
      statusColor = Colors.blue;
      statusText = 'Upcoming';
    } else if (isOngoing) {
      statusColor = Colors.green;
      statusText = 'Ongoing';
    } else {
      statusColor = Colors.grey;
      statusText = 'Ended';
    }

    String timeInfo = '';
    if (isUpcoming) {
      final difference = event.startDateTime.difference(now);
      if (difference.inDays > 0) {
        timeInfo = 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        timeInfo = 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        timeInfo = 'In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      }
    }

    return Container(
      margin: EdgeInsets.only(right: 16),
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailView(
                    event: event,
                    eventService: eventService,
                    hmsSDK: _hmsSDK,
                  ),
                ),
              );
              final token = await _authService.getToken();
              if (token != null) {
                await _fetchUpcomingEvents(token);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                          ? Image.network(
                        _getFullImageUrl(event.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                      )
                          : _buildPlaceholderImage(),
                    ),
                    if (timeInfo.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            timeInfo,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy').format(event.startDateTime),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${DateFormat('h:mm a').format(event.startDateTime)} - ${DateFormat('h:mm a').format(event.endDateTime)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (event.isOnline ? Colors.indigo : Colors.amber).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              event.isOnline ? Icons.videocam : Icons.location_on,
                              size: 14,
                              color: event.isOnline ? Colors.indigo : Colors.amber.shade700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.isOnline
                                  ? 'Online Event'
                                  : (event.location ?? 'No location specified'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All Events screen not implemented yet'),
                      duration: Duration(seconds: 2),
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
          height: 260,
          child: _upcomingEvents.isEmpty
              ? Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    color: AppColors.textGray.withOpacity(0.7),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No upcoming events',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
              : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _upcomingEvents.map((event) {
                return _buildEventCard(event);
              }).toList(),
            ),
          ),
        ),
      ],
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
                        // No need to fetch here; refresh will handle it
                      },
                      'onLessonCompleted': (EnrollmentDTO updatedEnrollment) {
                        updateEnrollment(updatedEnrollment);
                      },
                    },
                  );
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

  Widget _buildLiveSessions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Live Sessions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AllSessionsScreen()),
                  );
                },
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _availableSessions.isEmpty
              ? Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    color: AppColors.textGray.withOpacity(0.7),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No live sessions',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
              : _availableSessions.length == 1
              ? _buildSingleSessionCard(_availableSessions[0])
              : SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableSessions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final session = _availableSessions[index];
                final instructorName = _instructorNames[session.instructorId] ?? 'Unknown';
                if (session.status != 'LIVE') return const SizedBox.shrink();
                return SizedBox(
                  width: 260,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  session.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.live_tv,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (session.description != null && session.description!.isNotEmpty)
                                Text(
                                  session.description!,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (session.description != null && session.description!.isNotEmpty)
                                const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(session.startTime),
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${DateFormat('h:mm a').format(session.startTime.toLocal())} - '
                                        '${DateFormat('h:mm a').format(session.endTime.toLocal())}',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    session.isFollowerOnly == true ? Icons.people : Icons.public,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    session.isFollowerOnly == true ? 'Followers Only' : 'Public Session',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await _joinSession(session);
                                  },
                                  icon: const Icon(Icons.video_call, size: 16),
                                  label: const Text('Join Live'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green,
                                    side: const BorderSide(color: Colors.green),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
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
      ),
    );
  }

  Widget _buildSingleSessionCard(SessionDTO session) {
    final instructorName = _instructorNames[session.instructorId] ?? 'Unknown';
    if (session.status != 'LIVE') return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.live_tv,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.description != null && session.description!.isNotEmpty)
                  Text(
                    session.description!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (session.description != null && session.description!.isNotEmpty) const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(session.startTime),
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('h:mm a').format(session.startTime.toLocal())} - '
                          '${DateFormat('h:mm a').format(session.endTime.toLocal())}',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      session.isFollowerOnly == true ? Icons.people : Icons.public,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.isFollowerOnly == true ? 'Followers Only' : 'Public Session',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _joinSession(session);
                      },
                      icon: const Icon(Icons.video_call, size: 18),
                      label: const Text('Join Live'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinSession(SessionDTO session) async {
    try {
      final joinDetails = await sessionService.getSessionJoinDetails(session.id!);
      final hmsSDK = HMSSDK();
      await hmsSDK.build();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            hmsSDK: hmsSDK,
            meetingToken: joinDetails['meetingToken'],
            username: _authService.username ?? 'Student',
            sessionTitle: session.title,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<CourseDTO>> _getCoursesWithToken() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token == null) throw Exception('User not authenticated');
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
                      builder: (context) => const AllInstructorsScreen(),
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
              final instructor = _topInstructors[index];
              final instructorName = instructor['name'] as String;
              final instructorId = instructor['id'] as int;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InstructorProfileScreen(
                        instructorId: instructorId,
                        instructorName: instructorName,
                      ),
                    ),
                  );
                },
                child: Padding(
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