import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../instructor/views/instructor_course_details_screen.dart';

class CourseCard extends StatefulWidget {
  final CourseDTO course;
  final VoidCallback? onTap;
  final Function(bool)? onBookmarkChanged;
  final bool isBookmarked;
  final CourseService courseService;
  final BookmarkService bookmarkService;

  const CourseCard({
    Key? key,
    required this.course,
    required this.courseService,
    required this.bookmarkService,
    this.onTap,
    this.onBookmarkChanged,
    this.isBookmarked = false,
  }) : super(key: key);

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  late bool _isBookmarked;
  bool _isProcessingBookmark = false;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.course.isBookmarked;
  }
  String _getImageUrl() {
    return widget.courseService.getImageUrl(widget.course.imageUrl);
  }

  Future<void> _toggleBookmark() async {
    if (_isProcessingBookmark) return;

    setState(() => _isProcessingBookmark = true);
    final newState = !_isBookmarked;
    final courseId = widget.course.id!;

    try {
      if (newState) {
        await widget.bookmarkService.addBookmark(courseId);
      } else {
        await widget.bookmarkService.removeBookmark(courseId);
      }

      // Update local state only after successful API call
      setState(() => _isBookmarked = newState);
      widget.onBookmarkChanged?.call(newState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update bookmark: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _toggleBookmark,
          ),
        ),
      );
      // Revert UI state if operation failed
      setState(() => _isBookmarked = !newState);
    } finally {
      setState(() => _isProcessingBookmark = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () {
        Navigator.pushNamed(
          context,
          '/course-details',
          arguments: {'courseId': widget.course.id},

        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    _getImageUrl(),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 140,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          widget.course.rating?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _toggleBookmark,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isProcessingBookmark
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                          : Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked ? AppColors.primary : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (widget.course.instructorName != null)
                    Text(
                      widget.course.instructorName!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.course.pricingType == PricingType.FREE
                            ? 'Free'
                            : '\$${widget.course.price}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.course.totalStudents} students',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
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
    );
  }
}