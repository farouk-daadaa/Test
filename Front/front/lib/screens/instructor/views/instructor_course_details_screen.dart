import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:front/services/course_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:front/services/auth_service.dart';
import '/screens/instructor/views/lessons_tab_view.dart';
import 'package:front/services/review_service.dart';
import 'package:provider/provider.dart';
import 'package:front/services/image_service.dart';

class InstructorCourseDetailsScreen extends StatefulWidget {
  const InstructorCourseDetailsScreen({Key? key}) : super(key: key);

  @override
  State<InstructorCourseDetailsScreen> createState() => _InstructorCourseDetailsScreenState();
}

class _InstructorCourseDetailsScreenState extends State<InstructorCourseDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _lessonsCount = 0;
  late CourseService _courseService;
  late ReviewService _reviewService;
  late ImageService _imageService;
  late AuthService _authService;
  CourseDTO? _course;
  List<ReviewDTO> _reviews = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isReviewsLoading = false;
  String? _reviewsErrorMessage;
  Uint8List? _instructorImage; // Instructor image
  Map<String, Uint8List?> _studentImages = {}; // Map to store student images by username

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if (token == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please log in to view course details';
        _isLoading = false;
      });
      return;
    }

    _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
    _reviewService = ReviewService(baseUrl: 'http://192.168.1.13:8080');
    _imageService = ImageService();
    _authService = authService;
    _courseService.setToken(token);
    _reviewService.setToken(token);
    _imageService.setToken(token);

    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      final course = ModalRoute.of(context)!.settings.arguments as CourseDTO;
      if (course.id == null || course.instructorName == null) {
        throw Exception("Invalid course or instructor name");
      }
      setState(() {
        _course = course;
        _isLoading = false;
      });
      await _fetchInstructorImage(course.instructorName!);
      _loadReviews();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchInstructorImage(String instructorName) async {
    final instructorId = await _authService.getUserIdByUsername(instructorName);
    if (instructorId != null) {
      final imageBytes = await _imageService.getUserImage(context, instructorId);
      if (imageBytes != null) {
        setState(() {
          _instructorImage = imageBytes;
        });
      }
    }
  }

  Future<void> _fetchStudentImage(String username) async {
    if (_studentImages.containsKey(username)) return; // Avoid redundant calls
    final studentId = await _authService.getUserIdByUsername(username);
    if (studentId != null) {
      final imageBytes = await _imageService.getUserImage(context, studentId);
      if (imageBytes != null) {
        setState(() {
          _studentImages[username] = imageBytes;
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isReviewsLoading = true;
      _reviewsErrorMessage = null;
    });

    try {
      final reviews = await _reviewService.getReviewsByCourse(_course!.id!);
      setState(() {
        _reviews = reviews;
        _isReviewsLoading = false;
      });
      // Fetch images for all reviewers
      for (var review in _reviews) {
        await _fetchStudentImage(review.username);
      }
    } catch (e) {
      setState(() {
        _reviewsErrorMessage = e.toString();
        _isReviewsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFDB2777)),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'An error occurred'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCourseDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Course Details'),
        backgroundColor: const Color(0xFFDB2777),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Image Section
                  Stack(
                    children: [
                      Hero(
                        tag: 'course-${_course!.id}',
                        child: CachedNetworkImage(
                          imageUrl: _courseService.getImageUrl(_course!.imageUrl),
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Color(0xFFDB2777)),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error_outline, size: 48),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Course Info Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Badge
                        Row(
                          children: [
                            if (_course!.rating != null && _course!.rating! >= 4.5)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFDB2777).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Best Seller',
                                  style: TextStyle(
                                    color: Color(0xFFDB2777),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ).animate().fadeIn().slideX(),
                            SizedBox(width: 8),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Course Title
                        Text(
                          _course!.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Course Meta Info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: _instructorImage != null
                                  ? MemoryImage(_instructorImage!)
                                  : null,
                              backgroundColor: _instructorImage == null
                                  ? Color(0xFFDB2777).withOpacity(0.1)
                                  : null,
                              child: _instructorImage == null
                                  ? Text(
                                _course!.instructorName?[0] ?? 'I',
                                style: TextStyle(
                                  color: Color(0xFFDB2777),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                                  : null,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _course!.instructorName ?? 'Instructor',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 20),
                            Icon(Icons.book, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '$_lessonsCount Lessons',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Rating Section
                        if (_course!.rating != null)
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < _course!.rating!.floor()
                                      ? Icons.star
                                      : index < _course!.rating!
                                      ? Icons.star_half
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                              SizedBox(width: 8),
                              Text(
                                _course!.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '(${_course!.totalReviews} reviews)',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    labelColor: Color(0xFFDB2777),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFFDB2777),
                    tabs: [
                      Tab(text: 'About'),
                      Tab(text: 'Lessons'),
                      Tab(text: 'Reviews'),
                    ],
                  ),

                  // Tab Content
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // About Tab
                        SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Course Description'),
                              SizedBox(height: 8),
                              Text(
                                _course!.description,
                                style: TextStyle(
                                  height: 1.6,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildSectionTitle('Course Details'),
                              SizedBox(height: 16),
                              _buildDetailRow('Level', _course!.level.toString().split('.').last),
                              _buildDetailRow('Language', _course!.language.toString().split('.').last),
                              _buildDetailRow('Price', _course!.pricingType == PricingType.FREE
                                  ? 'Free'
                                  : '\$${_course!.price}'),
                              _buildDetailRow('Total Students', _course!.totalStudents.toString()),
                              _buildDetailRow('Last Updated', _course!.lastUpdate?.toString() ?? 'Recently'),
                            ],
                          ),
                        ),

                        // Lessons Tab
                        LessonsTabView(
                          courseId: _course!.id!,
                          onLessonsCountChanged: (count) {
                            setState(() {
                              _lessonsCount = count;
                            });
                          },
                        ),

                        // Reviews Tab
                        _buildReviewsTab(),
                      ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPoint(String point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFFDB2777),
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              point,
              style: TextStyle(
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isReviewsLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFDB2777)));
    }

    if (_reviewsErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(_reviewsErrorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReviews,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          'No reviews yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: _studentImages[review.username] != null
                  ? MemoryImage(_studentImages[review.username]!)
                  : null,
              backgroundColor: _studentImages[review.username] == null
                  ? Color(0xFFDB2777).withOpacity(0.1)
                  : null,
              child: _studentImages[review.username] == null
                  ? Text(
                review.username[0].toUpperCase(),
                style: TextStyle(color: Color(0xFFDB2777)),
              )
                  : null,
            ),
            title: Text(review.username),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating.floor()
                          ? Icons.star
                          : index < review.rating
                          ? Icons.star_half
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(review.comment),
                const SizedBox(height: 4),
                Text(
                  review.createdAt.toString().split(' ')[0],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}