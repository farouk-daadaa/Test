import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';
import 'CreateCourseView.dart'; // Add this import

class MyCoursesView extends StatefulWidget {
  final VoidCallback? onCreateCoursePressed;

  const MyCoursesView({Key? key, this.onCreateCoursePressed}) : super(key: key);

  @override
  _MyCoursesViewState createState() => _MyCoursesViewState();
}

class _MyCoursesViewState extends State<MyCoursesView> {
  final CourseService _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  List<CourseDTO> _courses = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setTokenAndLoadCourses();
  }

  Future<void> _setTokenAndLoadCourses() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token != null) {
      _courseService.setToken(token);
      await _loadCourses();
    } else {
      setState(() => _error = 'Unauthorized: Please log in');
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final courses = await _courseService.getMyCourses();
      setState(() {
        _courses = courses;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourse(int? courseId) async {
    if (courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete course: Invalid ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _courseService.deleteCourse(courseId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadCourses();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateCourseView()),
          );
        },
        backgroundColor: Color(0xFFDB2777),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildCoursesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.library_books, color: Color(0xFFDB2777), size: 32),
        const SizedBox(width: 12),
        Text(
          'My Courses',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.refresh, color: Color(0xFFDB2777)),
          tooltip: 'Refresh courses',
          onPressed: _loadCourses,
        ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2.seconds, color: Color(0xFFDB2777).withOpacity(0.2)),
      ],
    );
  }

  Widget _buildCoursesList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCourses,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No courses yet',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateCourseView()),
                );
              },
              icon: Icon(Icons.add),
              label: Text('Create your first course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return _buildCourseCard(course, index);
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseDTO course, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/instructor-course-details',
            arguments: course,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.imageUrl.isNotEmpty)
              Image.network(
                _courseService.getImageUrl(course.imageUrl),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Color(0xFFDB2777)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.pushNamed(
                              context,
                              '/edit-course',
                              arguments: course,
                            ).then((_) => _loadCourses());
                          } else if (value == 'delete') {
                            if (course.id == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot delete course: ID is missing'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Course'),
                                content: Text('Are you sure you want to delete this course?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (course.id != null) {
                                        _deleteCourse(course.id!);
                                      }
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFFDB2777)),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.attach_money,
                        course.pricingType == PricingType.FREE ? 'Free' : course.price.toString(),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.school,
                        course.level.toString().split('.').last.capitalize(),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.language,
                        course.language.toString().split('.').last.capitalize(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (course.rating != null) ...[
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          course.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${course.totalReviews})',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${course.totalStudents} students',
                        style: TextStyle(
                          color: Colors.grey[600],
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
    ).animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn()
        .slideX();
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFFDB2777).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Color(0xFFDB2777)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFDB2777),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}