import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/course_service.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';

class CourseReviewScreen extends StatefulWidget {
  final int courseId;
  final String courseImageUrl;
  final String title;
  final String instructorName;
  final int lessonCount;
  final Decimal? rating;
  final ReviewDTO? initialReview; // New parameter for editing

  const CourseReviewScreen({
    Key? key,
    required this.courseId,
    required this.courseImageUrl,
    required this.title,
    required this.instructorName,
    required this.lessonCount,
    required this.rating,
    this.initialReview,
  }) : super(key: key);

  @override
  State<CourseReviewScreen> createState() => _CourseReviewScreenState();
}

class _CourseReviewScreenState extends State<CourseReviewScreen> {
  int _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  final CourseService _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  late ReviewService _reviewService;
  late AuthService _authService;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill fields if editing an existing review
    if (widget.initialReview != null) {
      _userRating = widget.initialReview!.rating.round();
      _reviewController.text = widget.initialReview!.comment;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reviewService = Provider.of<ReviewService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _reviewService.setToken(_authService.token ?? '');
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_userRating == 0 || _reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rating and review.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = await _authService.getUserIdByUsername(_authService.username ?? '');
      if (userId == null) {
        throw Exception('Unable to retrieve user ID. Please ensure you are logged in.');
      }

      if (widget.initialReview == null) {
        // Create new review
        await _reviewService.createReview(
          widget.courseId,
          userId,
          _userRating.toDouble(),
          _reviewController.text,
        );
      } else {
        // Update existing review
        await _reviewService.updateReview(
          widget.initialReview!.id!,
          userId,
          _userRating.toDouble(),
          _reviewController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Image.network(
                      _courseService.getImageUrl(widget.courseImageUrl),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.black87),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.instructorName,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.menu_book, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.lessonCount} Lessons',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.rating?.toStringAsFixed(1) ?? '0.0'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your overall rating for this course',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _userRating = index + 1;
                            });
                          },
                          child: Icon(
                            index < _userRating ? Icons.star : Icons.star_border,
                            size: 40,
                            color: Colors.amber,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Add detailed review',
                        hintText: 'Enter here',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}