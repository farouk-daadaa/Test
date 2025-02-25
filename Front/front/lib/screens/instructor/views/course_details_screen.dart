import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:front/services/course_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import'/screens/instructor/views/lessons_tab_view.dart';

class CourseDetailsScreen extends StatefulWidget {
  const CourseDetailsScreen({Key? key}) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _lessonsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CourseDTO course = ModalRoute.of(context)!.settings.arguments as CourseDTO;
    final courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');

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
                        tag: 'course-${course.id}',
                        child: CachedNetworkImage(
                          imageUrl: courseService.getImageUrl(course.imageUrl),
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
                            if (course.rating != null && course.rating! >= 4.5)
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
                          course.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Course Meta Info
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
                              child: Text(
                                course.instructorName?[0] ?? 'I',
                                style: TextStyle(
                                  color: Color(0xFFDB2777),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              course.instructorName ?? 'Instructor',
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
                        if (course.rating != null)
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < course.rating!.floor()
                                      ? Icons.star
                                      : index < course.rating!
                                      ? Icons.star_half
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                              SizedBox(width: 8),
                              Text(
                                course.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '(${course.totalReviews} reviews)',
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
                    height: 500, // Fixed height for content
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
                                course.description,
                                style: TextStyle(
                                  height: 1.6,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 24),

                              _buildSectionTitle('Course Details'),
                              SizedBox(height: 16),
                              _buildDetailRow('Level', course.level.toString().split('.').last),
                              _buildDetailRow('Language', course.language.toString().split('.').last),
                              _buildDetailRow('Price', course.pricingType == PricingType.FREE
                                  ? 'Free'
                                  : '\$${course.price}'),
                              _buildDetailRow('Total Students', course.totalStudents.toString()),
                              _buildDetailRow('Last Updated', course.lastUpdate?.toString() ?? 'Recently'),


                            ],
                          ),
                        ),

                        LessonsTabView(
                          courseId: course.id!,
                          onLessonsCountChanged: (count) {
                            setState(() {
                              // Update the lessons count in the UI
                              _lessonsCount = count;
                            });
                          },
                        ),

                        // Reviews Tab (Placeholder)
                        Center(child: Text('Reviews coming soon')),
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
}