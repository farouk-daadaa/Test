import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:front/constants/colors.dart';
import 'package:front/services/course_service.dart'; // Add this import
import 'package:front/services/image_service.dart';
import 'package:front/services/instructor_service.dart' as instructorService;
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:decimal/decimal.dart';

// Local definitions for this file only
enum LocalCourseLanguage { ENGLISH, FRENCH, TUNISIAN }
enum LocalCourseLevel { BEGINNER, INTERMEDIATE, EXPERT }
enum LocalPricingType { FREE, PAID }

class LocalCourseDTO {
  final int? id;
  final String title;
  final String description;
  final Decimal price;
  final LocalPricingType pricingType;
  final double? rating;
  final int totalReviews;
  final String imageUrl;
  final LocalCourseLevel level;
  final LocalCourseLanguage language;
  final int totalStudents;
  final DateTime? lastUpdate;
  final int categoryId;
  final String? instructorName;
  bool isBookmarked;

  LocalCourseDTO({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.pricingType,
    this.rating,
    this.totalReviews = 0,
    required this.imageUrl,
    required this.level,
    required this.language,
    this.totalStudents = 0,
    this.lastUpdate,
    required this.categoryId,
    this.instructorName,
    this.isBookmarked = false,
  });

  factory LocalCourseDTO.fromJson(Map<String, dynamic> json) {
    return LocalCourseDTO(
      id: json['id'] != null ? json['id'] as int : 0,
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      price: Decimal.parse(json['price']?.toString() ?? '0.0'),
      pricingType: LocalPricingType.values.firstWhere(
            (e) => e.toString().split('.').last == json['pricingType'],
        orElse: () => LocalPricingType.FREE,
      ),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      totalReviews: json['totalReviews'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
      level: LocalCourseLevel.values.firstWhere(
            (e) => e.toString().split('.').last == json['level'],
        orElse: () => LocalCourseLevel.BEGINNER,
      ),
      language: LocalCourseLanguage.values.firstWhere(
            (e) => e.toString().split('.').last == json['language'],
        orElse: () => LocalCourseLanguage.ENGLISH,
      ),
      totalStudents: json['totalStudents'] ?? 0,
      lastUpdate: json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate']) : null,
      categoryId: json['categoryId'] ?? 0,
      instructorName: json['instructorName'],
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }
}

class InstructorProfileScreen extends StatefulWidget {
  final int instructorId;
  final String instructorName;

  const InstructorProfileScreen({
    Key? key,
    required this.instructorId,
    required this.instructorName,
  }) : super(key: key);

  @override
  _InstructorProfileScreenState createState() => _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  late instructorService.InstructorService _instructorService;
  late ImageService _imageService;
  late CourseService _courseService; // Add CourseService
  instructorService.InstructorProfileDTO? _profile;
  List<LocalCourseDTO> _courses = [];
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _instructorService = instructorService.InstructorService();
    _imageService = ImageService();
    _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080'); // Initialize CourseService
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      if (token == null) throw Exception('No authentication token found');

      _instructorService.setToken(token);
      _imageService.setToken(token);
      _courseService.setToken(token); // Set token for CourseService

      print('Fetching profile for instructorId: ${widget.instructorId}');
      final profile = await _instructorService.getInstructorProfile(widget.instructorId);
      print('Profile fetched: ${profile.username}, isFollowed: ${profile.isFollowed}, '
          'followers: ${profile.followersCount}, avgRating: ${profile.averageRating}, '
          'students: ${profile.totalStudents}');

      final courses = await _instructorService.getInstructorCourses(widget.instructorId);
      print('Courses fetched: ${courses.length} courses');

      final userId = await _instructorService.getUserIdByInstructorId(widget.instructorId);
      Uint8List? imageBytes;
      if (userId != null) {
        print('Fetching image for userId: $userId');
        imageBytes = await _imageService.getUserImage(context, userId);
        print('Image bytes: ${imageBytes?.length ?? 0} bytes');
      }

      setState(() {
        _profile = profile;
        _courses = courses.map((course) => LocalCourseDTO(
          id: course.id,
          title: course.title,
          description: course.description,
          price: course.price,
          pricingType: LocalPricingType.values.firstWhere(
                (e) => e.toString().split('.').last == course.pricingType.toString().split('.').last,
            orElse: () => LocalPricingType.FREE,
          ),
          rating: course.rating,
          totalReviews: course.totalReviews,
          imageUrl: course.imageUrl,
          level: LocalCourseLevel.values.firstWhere(
                (e) => e.toString().split('.').last == course.level.toString().split('.').last,
            orElse: () => LocalCourseLevel.BEGINNER,
          ),
          language: LocalCourseLanguage.values.firstWhere(
                (e) => e.toString().split('.').last == course.language.toString().split('.').last,
            orElse: () => LocalCourseLanguage.ENGLISH,
          ),
          totalStudents: course.totalStudents,
          lastUpdate: course.lastUpdate,
          categoryId: course.categoryId,
          instructorName: course.instructorName,
          isBookmarked: course.isBookmarked,
        )).toList();
        _imageBytes = imageBytes;
        _isLoading = false;
      });
    } catch (e) {
      print('Fetch error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    setState(() => _isLoading = true);
    try {
      if (_profile!.isFollowed) {
        await _instructorService.unfollowInstructor(widget.instructorId);
      } else {
        await _instructorService.followInstructor(widget.instructorId);
      }
      await _fetchData();
    } catch (e) {
      print('Toggle follow error: $e');
      String errorMessage = 'Error: $e';
      if (e.toString().contains('409')) {
        errorMessage = 'You already follow this instructor';
      } else if (e.toString().contains('404')) {
        errorMessage = 'You are not following this instructor';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _profile == null
          ? const Center(child: Text('Profile not found'))
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(''), // Empty title to prevent the title from appearing when scrolling
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Calculate the top padding based on the constraints
                final double topPadding = constraints.biggest.height > 100 ? 40.0 : 0.0;

                return FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  title: constraints.biggest.height <= 80
                      ? Text(
                    '${widget.instructorName}\'s Profile',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                      : const SizedBox.shrink(), // Hide title when expanded
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: topPadding),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (constraints.biggest.height > 100)
                              Text(
                                '${widget.instructorName}\'s Profile',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageBytes != null && _imageBytes!.isNotEmpty
                          ? MemoryImage(_imageBytes!)
                          : null,
                      backgroundColor: Colors.white,
                      child: _imageBytes == null || _imageBytes!.isEmpty
                          ? Text(
                        widget.instructorName[0],
                        style: const TextStyle(fontSize: 50, color: AppColors.primary),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_profile!.firstName} ${_profile!.lastName}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '@${_profile!.username}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  if (authService.token != null)
                    ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _profile!.isFollowed ? Colors.grey[200] : AppColors.primary,
                        foregroundColor: _profile!.isFollowed ? AppColors.primary : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: _profile!.isFollowed
                              ? BorderSide(color: AppColors.primary)
                              : BorderSide.none,
                        ),
                        elevation: _profile!.isFollowed ? 0 : 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _profile!.isFollowed ? Icons.check : Icons.add,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _profile!.isFollowed ? 'Following' : 'Follow',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Courses by ${widget.instructorName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _courses.isEmpty
              ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No courses available yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
              : SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _buildCourseCard(_courses[index]),
              ),
              childCount: _courses.length,
            ),
          ),
          // Add some bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    // Define the stats with icons
    final stats = [
      {
        'icon': Icons.people,
        'value': _profile!.followersCount,
        'label': 'Followers',
        'color': Colors.blue,
      },
      {
        'icon': Icons.book,
        'value': _profile!.coursesCount,
        'label': 'Courses',
        'color': AppColors.primary,
      },
      {
        'icon': Icons.rate_review,
        'value': _profile!.totalReviews,
        'label': 'Reviews',
        'color': Colors.orange,
      },
      {
        'icon': Icons.star,
        'value': _profile!.averageRating.toStringAsFixed(1),
        'label': 'Rating',
        'color': Colors.amber,
      },
      {
        'icon': Icons.school,
        'value': _profile!.totalStudents,
        'label': 'Students',
        'color': Colors.green,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (stat['color'] as Color).withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: (stat['color'] as Color).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                stat['icon'] as IconData,
                color: stat['color'] as Color,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                stat['value'].toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: stat['color'] as Color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(LocalCourseDTO course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (course.id == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Course ID is missing!')),
              );
              return;
            }
            print('Navigating to course details for courseId: ${course.id}');
            await Navigator.pushNamed(
              context,
              '/course-details',
              arguments: {
                'courseId': course.id,
                'onEnrollmentChanged': () async {
                  print('Enrollment changed for courseId: ${course.id}');
                },
                'onLessonCompleted': (dynamic updatedEnrollment) {
                  print('Lesson completed for courseId: ${course.id}');
                },
              },
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: Image.network(
                  _courseService.getImageUrl(course.imageUrl), // Use CourseService.getImageUrl
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    height: 120,
                    color: AppColors.backgroundGray,
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getLevelText(course.level),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: course.pricingType == LocalPricingType.FREE
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              course.pricingType == LocalPricingType.FREE
                                  ? 'Free'
                                  : '\$${course.price}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: course.pricingType == LocalPricingType.FREE
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRatingStars(course.rating),
                          const SizedBox(width: 4),
                          Text(
                            course.rating?.toStringAsFixed(1) ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${course.totalReviews})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${course.totalStudents} students',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLevelText(LocalCourseLevel level) {
    switch (level) {
      case LocalCourseLevel.BEGINNER:
        return 'Beginner';
      case LocalCourseLevel.INTERMEDIATE:
        return 'Intermediate';
      case LocalCourseLevel.EXPERT:
        return 'Expert';
      default:
        return 'All Levels';
    }
  }

  Widget _buildRatingStars(double? rating) {
    if (rating == null) {
      return Row(
        children: List.generate(5, (index) => Icon(Icons.star_border, size: 16, color: Colors.grey[400])),
      );
    }

    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, size: 16, color: Colors.amber);
        } else if (index < rating.ceil() && rating.floor() != rating.ceil()) {
          return const Icon(Icons.star_half, size: 16, color: Colors.amber);
        } else {
          return const Icon(Icons.star_border, size: 16, color: Colors.amber);
        }
      }),
    );
  }
}

