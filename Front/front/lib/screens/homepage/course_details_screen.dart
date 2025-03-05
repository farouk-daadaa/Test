import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/course_service.dart';
import '../../services/lesson_service.dart';
import '../../services/review_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/lesson_progress_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/image_service.dart'; // Import ImageService
import '../instructor/views/video_player_screen.dart';
import 'payment_page.dart';
import 'package:collection/collection.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;
  final VoidCallback? onEnrollmentChanged;
  final Function(EnrollmentDTO)? onLessonCompleted;

  const CourseDetailsScreen({
    Key? key,
    required this.courseId,
    this.onEnrollmentChanged,
    this.onLessonCompleted,
  }) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CourseService _courseService;
  late LessonService _lessonService;
  late ReviewService _reviewService;
  late EnrollmentService _enrollmentService;
  late LessonProgressService _lessonProgressService;
  late BookmarkService _bookmarkService;
  late ImageService _imageService; // Add ImageService
  late AuthService _authService; // Add AuthService
  CourseDTO? _course;
  List<LessonDTO> _lessons = [];
  List<ReviewDTO> _reviews = [];
  EnrollmentDTO? _enrollment;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isReviewsLoading = false;
  String? _reviewsErrorMessage;
  bool _isEnrolling = false;
  bool _isEnrolled = false;
  Uint8List? _instructorImage; // Store instructor image
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
    _lessonService = LessonService(baseUrl: 'http://192.168.1.13:8080');
    _reviewService = ReviewService(baseUrl: 'http://192.168.1.13:8080');
    _enrollmentService = EnrollmentService(baseUrl: 'http://192.168.1.13:8080');
    _lessonProgressService = LessonProgressService(baseUrl: 'http://192.168.1.13:8080');
    _bookmarkService = BookmarkService(baseUrl: 'http://192.168.1.13:8080');
    _imageService = ImageService(); // Initialize ImageService
    _authService = authService; // Store AuthService
    _courseService.setToken(token);
    _lessonService.setToken(token);
    _reviewService.setToken(token);
    _enrollmentService.setToken(token);
    _lessonProgressService.setToken(token);
    _bookmarkService.setToken(token);
    _imageService.setToken(token); // Set token for ImageService

    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    try {
      final course = await _courseService.getCourseDetails(widget.courseId);
      final lessons = await _lessonService.getLessons(widget.courseId);
      final enrollments = await _enrollmentService.getEnrolledCourses();
      final bookmarks = await _bookmarkService.getBookmarkedCourses();
      final bookmarkedIds = bookmarks.map((b) => b.id).toSet();
      course.isBookmarked = bookmarkedIds.contains(course.id);

      setState(() {
        _course = course;
        _lessons = lessons;
        _enrollment = enrollments.firstWhereOrNull((e) => e.courseId == widget.courseId);
        _isEnrolled = _enrollment != null;
        _isLoading = false;
      });
      await _fetchInstructorImage(course.instructorName!); // Fetch instructor image
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
      final reviews = await _reviewService.getReviewsByCourse(widget.courseId);
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

  Future<void> _enrollInCourse() async {
    if (_isEnrolled) {
      await _unenrollFromCourse();
    } else {
      if (_course!.pricingType == PricingType.FREE) {
        setState(() {
          _isEnrolling = true;
        });

        try {
          final enrollment = await _enrollmentService.enrollStudent(widget.courseId);
          setState(() {
            _isEnrolled = true;
            _enrollment = enrollment;
            _isEnrolling = false;
          });
          widget.onEnrollmentChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully enrolled in course!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          setState(() {
            _isEnrolling = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Enrollment failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        _navigateToPaymentPage();
      }
    }
  }

  Future<void> _unenrollFromCourse() async {
    setState(() {
      _isEnrolling = true;
    });

    try {
      await _enrollmentService.unenrollStudent(widget.courseId);
      setState(() {
        _isEnrolled = false;
        _enrollment = null;
        _isEnrolling = false;
      });
      widget.onEnrollmentChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully unenrolled from course!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isEnrolling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unenrollment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToPaymentPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(course: _course!),
      ),
    ).then((_) {
      _loadCourseDetails();
    });
  }

  Future<void> _markLessonCompleted(int lessonId) async {
    if (_enrollment == null) return;
    try {
      await _lessonProgressService.markLessonCompleted(_enrollment!.id!, lessonId);
      final progress = await _lessonProgressService.getCourseProgress(_enrollment!.id!);
      final updatedEnrollment = _enrollment!.copyWith(progressPercentage: progress);
      setState(() {
        _enrollment = updatedEnrollment;
      });
      widget.onLessonCompleted?.call(updatedEnrollment);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark lesson: $e')),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    if (_course == null) return;

    final newState = !_course!.isBookmarked;
    final courseId = _course!.id!;

    try {
      if (newState) {
        await _bookmarkService.addBookmark(courseId);
      } else {
        await _bookmarkService.removeBookmark(courseId);
      }

      setState(() {
        _course!.isBookmarked = newState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? 'Course added to bookmarks' : 'Course removed from bookmarks',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newState ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      setState(() {
        _course!.isBookmarked = !newState; // Revert on failure
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update bookmark: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _toggleBookmark(),
          ),
        ),
      );
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
          child: CircularProgressIndicator(color: AppColors.primary),
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

    if (_course == null) {
      return const Scaffold(
        body: Center(child: Text('Course not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabs(),
                _buildTabContent(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDB2777),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDB2777),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.share, color: Colors.white),
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _course!.isBookmarked ? AppColors.primary : const Color(0xFFDB2777).withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              _course!.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _course!.isBookmarked ? Colors.white : AppColors.primary,
            ),
          ),
          onPressed: _toggleBookmark,
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _courseService.getImageUrl(_course!.imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_course!.rating?.toStringAsFixed(1) ?? '0.0'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_course!.totalReviews} reviews)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _course!.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (_course!.instructorName != null)
                Text(
                  'By ${_course!.instructorName!}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'About'),
              Tab(text: 'Lessons'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 600,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildAboutTab(),
          _buildLessonsTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Course',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _course!.description,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 24),
          _buildTutorSection(),
          const SizedBox(height: 24),
          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildTutorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tutor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: _instructorImage != null
                  ? MemoryImage(_instructorImage!)
                  : null,
              backgroundColor: _instructorImage == null
                  ? Colors.grey[200]
                  : null,
              child: _instructorImage == null
                  ? Text(
                _course!.instructorName?[0] ?? 'I',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _course!.instructorName ?? 'Unknown Instructor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Course Instructor',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.message, color: AppColors.primary, size: 20),
              ),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Info',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoItem('Students', '${_course!.totalStudents}', Icons.people),
        _buildInfoItem(
          'Language',
          _course!.language.toString().split('.').last,
          Icons.language,
        ),
        _buildInfoItem(
          'Level',
          _course!.level.toString().split('.').last,
          Icons.bar_chart,
        ),
        _buildInfoItem('Access', 'Mobile, Desktop', Icons.devices),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: lesson.videoUrl != null
                ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoUrl: lesson.videoUrl!,
                    lessonTitle: lesson.title,
                  ),
                ),
              );
              if (_isEnrolled && lesson.id != null) {
                _markLessonCompleted(lesson.id!);
              }
            }
                : null,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: lesson.videoUrl != null
                ? IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoUrl: lesson.videoUrl!,
                      lessonTitle: lesson.title,
                    ),
                  ),
                );
                if (_isEnrolled && lesson.id != null) {
                  _markLessonCompleted(lesson.id!);
                }
              },
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_isReviewsLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
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
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${review.rating}'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.comment),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Price', style: TextStyle(color: Colors.grey)),
              Text(
                _course!.pricingType == PricingType.FREE
                    ? 'Free'
                    : '\$${_course!.price}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_isEnrolled && _enrollment != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Progress: ${_enrollment!.progressPercentage}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isEnrolling ? null : _enrollInCourse,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEnrolled ? Colors.red : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isEnrolling
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                _isEnrolled ? 'Unenroll' : 'Enroll Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add this extension to EnrollmentDTO if not already present
extension EnrollmentDTOCopy on EnrollmentDTO {
  EnrollmentDTO copyWith({int? progressPercentage}) {
    return EnrollmentDTO(
      id: this.id,
      courseId: this.courseId,
      courseTitle: this.courseTitle,
      courseDescription: this.courseDescription,
      status: this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      enrollmentDate: this.enrollmentDate,
      lastAccessedDate: this.lastAccessedDate,
    );
  }
}