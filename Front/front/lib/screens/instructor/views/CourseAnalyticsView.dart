import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';

class CourseAnalyticsView extends StatefulWidget {
  final VoidCallback? onCreateCoursePressed;

  const CourseAnalyticsView({
    Key? key,
    this.onCreateCoursePressed,
  }) : super(key: key);

  @override
  _CourseAnalyticsViewState createState() => _CourseAnalyticsViewState();
}

class _CourseAnalyticsViewState extends State<CourseAnalyticsView> {
  final CourseService _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
  final AnalyticsService _analyticsService = AnalyticsService(baseUrl: 'http://192.168.1.13:8080');
  List<CourseDTO> _courses = [];
  bool _isLoading = true;
  String? _error;
  CourseDTO? _selectedCourse;
  AnalyticsData? _analyticsData;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      _courseService.setToken(authService.token!);

      final courses = await _courseService.getMyCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnalytics(int courseId) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      _analyticsService.setToken(authService.token!);

      final data = await _analyticsService.getCourseAnalytics(courseId);
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFDB2777)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourses,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
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
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Courses Yet',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first course to see analytics',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onCreateCoursePressed,
              icon: Icon(Icons.add),
              label: Text('Create Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFFDB2777), size: 32),
              const SizedBox(width: 12),
              Text(
                'Course Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDB2777),
                ),
              ),
            ],
          ).animate().fadeIn().slideX(),
          const SizedBox(height: 24),

          // Course Selector
          DropdownButtonFormField<CourseDTO>(
            value: _selectedCourse,
            decoration: InputDecoration(
              labelText: 'Select Course',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              DropdownMenuItem<CourseDTO>(
                value: null,
                child: Text('Overall Analytics'),
              ),
              ..._courses.map((course) {
                return DropdownMenuItem<CourseDTO>(
                  value: course,
                  child: Text(course.title),
                );
              }).toList(),
            ],
            onChanged: (course) {
              setState(() {
                _selectedCourse = course;
                if (course != null) {
                  _loadAnalytics(course.id!);
                } else {
                  _analyticsData = null;
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // Analytics Content
          Expanded(
            child: _selectedCourse == null
                ? _OverallAnalytics(courses: _courses)
                : _CourseDetailAnalytics(
              analyticsData: _analyticsData,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallAnalytics extends StatelessWidget {
  final List<CourseDTO> courses;

  const _OverallAnalytics({required this.courses});

  @override
  Widget build(BuildContext context) {
    final totalStudents = courses.fold<int>(0, (sum, course) => sum + course.totalStudents);
    final totalReviews = courses.fold<int>(0, (sum, course) => sum + course.totalReviews);
    final averageRating = courses.isEmpty
        ? 0.0
        : courses.fold<double>(0, (sum, course) => sum + (course.rating ?? 0)) / courses.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Stats
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _StatCard(
                title: 'Total Courses',
                value: courses.length.toString(),
                icon: Icons.library_books,
              ),
              _StatCard(
                title: 'Total Students',
                value: totalStudents.toString(),
                icon: Icons.people,
              ),
              _StatCard(
                title: 'Average Rating',
                value: averageRating.toStringAsFixed(1),
                icon: Icons.star,
              ),
              _StatCard(
                title: 'Total Reviews',
                value: totalReviews.toString(),
                icon: Icons.rate_review,
              ),
            ],
          ).animate().fadeIn(delay: 200.milliseconds).slideY(),

          const SizedBox(height: 32),

          // Course List
          Text(
            'Course Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDB2777),
            ),
          ),
          const SizedBox(height: 16),

          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(course.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${course.totalStudents} students'),
                          const SizedBox(width: 16),
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${course.rating?.toStringAsFixed(1) ?? "N/A"}'),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.analytics, color: Color(0xFFDB2777)),
                    onPressed: () {
                      // Select this course in the dropdown
                      final state = context.findAncestorStateOfType<_CourseAnalyticsViewState>();
                      if (state != null) {
                        state.setState(() {
                          state._selectedCourse = course;
                          state._loadAnalytics(course.id!); // Load analytics data immediately
                        });
                      }
                    },
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn().slideX();
            },
          ),
        ],
      ),
    );
  }
}

class _CourseDetailAnalytics extends StatelessWidget {
  final AnalyticsData? analyticsData;
  final bool isLoading;

  const _CourseDetailAnalytics({
    required this.analyticsData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFDB2777)),
      );
    }

    if (analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                title: 'Total Students',
                value: analyticsData!.totalStudents.toString(),
                icon: Icons.people,
              ),
              _StatCard(
                title: 'Average Rating',
                value: analyticsData!.averageRating.toStringAsFixed(1),
                icon: Icons.star,
              ),
              _StatCard(
                title: 'Total Reviews',
                value: analyticsData!.reviews.length.toString(),
                icon: Icons.rate_review,
              ),
            ],
          ).animate().fadeIn(delay: 200.milliseconds).slideY(),

          const SizedBox(height: 24),

          // Enrollment Trend Chart
          if (analyticsData!.enrollments.isNotEmpty) ...[
            _SectionTitle(title: 'Enrollment Trend'),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: _EnrollmentChart(
                enrollments: analyticsData!.enrollments,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Recent Reviews
          if (analyticsData!.reviews.isNotEmpty) ...[
            _SectionTitle(title: 'Recent Reviews'),
            const SizedBox(height: 16),
            _ReviewsList(reviews: analyticsData!.reviews),
          ],
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Add this
        children: [
          Flexible( // Add Flexible
            child: Icon(icon,
              color: Color(0xFFDB2777),
              size: 28, // Reduced icon size
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Color(0xFFDB2777),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12, // Reduced font size
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777),
      ),
    );
  }
}

class _EnrollmentChart extends StatelessWidget {
  final List<EnrollmentData> enrollments;

  const _EnrollmentChart({required this.enrollments});

  @override
  Widget build(BuildContext context) {
    final spots = enrollments.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < enrollments.length) {
                  return Text(
                    '${enrollments[value.toInt()].date.day}/${enrollments[value.toInt()].date.month}',
                    style: TextStyle(fontSize: 10),
                  );
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Color(0xFFDB2777),
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFFDB2777).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  final List<ReviewData> reviews;

  const _ReviewsList({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
              child: Text(
                review.studentName[0],
                style: TextStyle(color: Color(0xFFDB2777)),
              ),
            ),
            title: Row(
              children: [
                Text(review.studentName),
                const SizedBox(width: 8),
                // Display fractional stars
                Row(
                  children: List.generate(5, (i) {
                    if (i < review.rating.floor()) {
                      // Full star
                      return Icon(Icons.star, size: 16, color: Colors.amber);
                    } else if (i == review.rating.floor() && review.rating % 1 != 0) {
                      // Half star
                      return Icon(Icons.star_half, size: 16, color: Colors.amber);
                    } else {
                      // Empty star
                      return Icon(Icons.star_border, size: 16, color: Colors.amber);
                    }
                  }),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(review.displayComment),
                const SizedBox(height: 4),
                Text(
                  '${review.date.day}/${review.date.month}/${review.date.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
