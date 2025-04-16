import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:typed_data'; // Import for Uint8List
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/course_service.dart';
import '../../../services/image_service.dart'; // Import ImageService
import '../bottom_nav_bar.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final CourseService courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final BookmarkService bookmarkService = BookmarkService(baseUrl: 'http://192.168.1.13:8080');
  final ImageService imageService = ImageService(); // Initialize ImageService
  late AuthService _authService; // Declare _authService as late
  List<CourseDTO> _bookmarkedCourses = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<CourseDTO> _filteredCourses = [];
  Map<String, Uint8List?> _instructorImages = {}; // Map to store instructor images by name

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
      imageService.setToken(token); // Set token for ImageService
      _authService = authService; // Initialize _authService
      await _fetchBookmarkedCourses(token);
      await _fetchInstructorImages(token); // Fetch images after courses are loaded
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view bookmarks';
      });
    }
  }

  Future<void> _fetchBookmarkedCourses(String token) async {
    try {
      final bookmarks = await bookmarkService.getBookmarkedCourses();
      final allCourses = await courseService.getAllCourses();

      final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
      final courses = allCourses.where((course) => bookmarkedIds.contains(course.id)).toList();

      setState(() {
        _bookmarkedCourses = courses;
        _filteredCourses = courses;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Failed to load bookmarks: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchInstructorImages(String token) async {
    for (var course in _bookmarkedCourses) {
      if (course.instructorName != null && !_instructorImages.containsKey(course.instructorName!)) {
        final instructorId = await _authService.getUserIdByUsername(course.instructorName!); // Use class-level _authService
        if (instructorId != null) {
          print('Fetching image for ${course.instructorName} with ID: $instructorId'); // Debug log
          final imageBytes = await imageService.getUserImage(context, instructorId);
          if (imageBytes != null) {
            print('Image fetched for ${course.instructorName}: ${imageBytes.length} bytes'); // Debug log
            setState(() {
              _instructorImages[course.instructorName!] = imageBytes;
            });
          } else {
            print('No image bytes returned for ${course.instructorName}');
          }
        } else {
          print('No ID found for instructor: ${course.instructorName}');
        }
      }
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
      await _fetchBookmarkedCourses(token);
      await _fetchInstructorImages(token); // Refresh images too
    } else {
      setState(() {
        _isRefreshing = false;
        _errorMessage = 'Please log in to view bookmarks';
      });
    }
  }

  void _filterCourses(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCourses = _bookmarkedCourses;
      } else {
        _filteredCourses = _bookmarkedCourses
            .where((course) =>
        course.title.toLowerCase().contains(query.toLowerCase()) ||
            (course.instructorName?.toLowerCase().contains(query.toLowerCase()) ?? false))
            .toList();
      }
    });
  }

  Future<void> _removeBookmark(CourseDTO course) async {
    try {
      await bookmarkService.removeBookmark(course.id!);
      setState(() {
        _bookmarkedCourses.removeWhere((c) => c.id == course.id);
        _filteredCourses = _searchQuery.isEmpty
            ? _bookmarkedCourses
            : _bookmarkedCourses
            .where((c) =>
        c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Course removed from bookmarks'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary.withOpacity(0.9),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await bookmarkService.addBookmark(course.id!);
                  setState(() {
                    _bookmarkedCourses.add(course);
                    _filteredCourses = _searchQuery.isEmpty
                        ? _bookmarkedCourses
                        : _bookmarkedCourses
                        .where((c) =>
                    c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                        .toList();
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to restore bookmark'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove bookmark'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          : Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildCourseList()),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2, // Set to Bookmarks index
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/my-courses');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/chatbot');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: TextField(
        onChanged: _filterCourses,
        decoration: InputDecoration(
          hintText: 'Search bookmarks...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _filterCourses('');
              FocusScope.of(context).unfocus();
            },
          )
              : null,
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context), // Simple back navigation
      ),
      title: const Text(
        'Bookmarks',
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
        if (_bookmarkedCourses.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.black),
            onPressed: () => _showSortOptions(),
            tooltip: 'Sort bookmarks',
          ),
      ],
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort Bookmarks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Sort by Title (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _bookmarkedCourses.sort((a, b) => a.title.compareTo(b.title));
                    _filteredCourses = _searchQuery.isEmpty
                        ? List.from(_bookmarkedCourses)
                        : _bookmarkedCourses
                        .where((c) =>
                    c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                        .toList();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_outlined),
                title: const Text('Sort by Title (Z-A)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _bookmarkedCourses.sort((a, b) => b.title.compareTo(a.title));
                    _filteredCourses = _searchQuery.isEmpty
                        ? List.from(_bookmarkedCourses)
                        : _bookmarkedCourses
                        .where((c) =>
                    c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                        .toList();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Sort by Price (Low to High)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _bookmarkedCourses.sort((a, b) => a.price.compareTo(b.price));
                    _filteredCourses = _searchQuery.isEmpty
                        ? List.from(_bookmarkedCourses)
                        : _bookmarkedCourses
                        .where((c) =>
                    c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                        .toList();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money_outlined),
                title: const Text('Sort by Price (High to Low)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _bookmarkedCourses.sort((a, b) => b.price.compareTo(a.price));
                    _filteredCourses = _searchQuery.isEmpty
                        ? List.from(_bookmarkedCourses)
                        : _bookmarkedCourses
                        .where((c) =>
                    c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (c.instructorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                        .toList();
                  });
                },
              ),
            ],
          ),
        );
      },
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
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 80,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorMessage ?? 'Failed to load bookmarks',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _refreshCourses,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
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
    if (_bookmarkedCourses.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshCourses,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bookmark_outline,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No bookmarked courses yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Save your favorite courses to access them quickly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/popular-courses');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'Browse Courses',
                        style: TextStyle(
                          fontSize: 16,
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

    if (_filteredCourses.isEmpty && _searchQuery.isNotEmpty) {
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
              'No results found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
    return Dismissible(
      key: Key('bookmark-${course.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        _removeBookmark(course);
      },
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Remove Bookmark'),
              content: const Text('Are you sure you want to remove this course from your bookmarks?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                      await _fetchBookmarkedCourses(token);
                    }
                  },
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'bookmark-image-${course.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        courseService.getImageUrl(course.imageUrl),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                course.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.bookmark,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _removeBookmark(course),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: _instructorImages[course.instructorName] != null
                                  ? MemoryImage(_instructorImages[course.instructorName]!)
                                  : null,
                              backgroundColor: _instructorImages[course.instructorName] == null
                                  ? AppColors.primary.withOpacity(0.1)
                                  : null,
                              child: _instructorImages[course.instructorName] == null
                                  ? Text(
                                course.instructorName?[0] ?? 'I',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'by ${course.instructorName ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber[700],
                                ),
                                const SizedBox(width: 4),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                course.price == Decimal.fromInt(0) ? 'Free' : '\$${course.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildCourseTag(course.level.toString().split('.').last),
                            const SizedBox(width: 8),
                            _buildCourseTag(course.language.toString().split('.').last),
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
      ),
    );
  }

  Widget _buildCourseTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}