import 'package:dio/dio.dart';

class AnalyticsData {
  final int totalStudents;
  final List<EnrollmentData> enrollments;
  final List<ReviewData> reviews;
  final double averageRating;

  AnalyticsData({
    required this.totalStudents,
    required this.enrollments,
    required this.reviews,
    required this.averageRating,
  });
}

class EnrollmentData {
  final DateTime date;
  final int count;

  EnrollmentData({required this.date, required this.count});

  factory EnrollmentData.fromJson(Map<String, dynamic> json) {
    return EnrollmentData(
      date: DateTime.parse(json['enrollmentDate']), // Match your API field name
      count: 1, // Each enrollment represents one student
    );
  }
}

class ReviewData {
  final double rating;
  final String? comment;  // Keep nullable
  final String studentName;
  final DateTime date;

  ReviewData({
    required this.rating,
    this.comment,  // Remove default value to properly handle null
    required this.studentName,
    required this.date,
  });

  factory ReviewData.fromJson(Map<String, dynamic> json) {
    return ReviewData(
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String?,  // Just mark as nullable, don't provide default
      studentName: json['username'] as String? ?? 'Anonymous',
      date: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Add a getter for safe comment display
  String get displayComment => comment ?? 'No comment provided';
}

class AnalyticsService {
  final Dio _dio;
  final String baseUrl;

  AnalyticsService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
    validateStatus: (status) => status! < 500,
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<AnalyticsData> getCourseAnalytics(int courseId) async {
    try {
      print('Fetching analytics for course: $courseId');

      // 1. Fetch course details
      print('Fetching course details...');
      final courseResponse = await _dio.get('/api/courses/$courseId');
      if (courseResponse.statusCode != 200) {
        throw Exception('Failed to fetch course: ${courseResponse.statusCode}');
      }
      final totalStudents = courseResponse.data['totalStudents'] as int;
      print('Course details fetched successfully');

      // 2. Fetch enrollments - Using my-courses endpoint
      print('Fetching enrollments...');
      final enrollmentsResponse = await _dio.get('/api/enrollments/my-courses');
      if (enrollmentsResponse.statusCode != 200) {
        throw Exception('Failed to fetch enrollments: ${enrollmentsResponse.statusCode}');
      }

      // Filter enrollments by course ID
      final allEnrollments = (enrollmentsResponse.data as List)
          .where((enrollment) => enrollment['course']['id'] == courseId) // Filter by course ID
          .map((json) => EnrollmentData.fromJson(json))
          .toList();

      print('Raw enrollment data: ${enrollmentsResponse.data}'); // Debug log
      print('Enrollments fetched: ${allEnrollments.length}');

      // 3. Fetch reviews
      print('Fetching reviews...');
      final reviewsResponse = await _dio.get('/api/reviews/courses/$courseId');
      if (reviewsResponse.statusCode != 200) {
        throw Exception('Failed to fetch reviews: ${reviewsResponse.statusCode}');
      }
      final reviews = (reviewsResponse.data as List)
          .map((json) => ReviewData.fromJson(json))
          .toList();
      print('Reviews fetched: ${reviews.length}');

      // 4. Calculate average rating
      double averageRating = 0;
      if (reviews.isNotEmpty) {
        averageRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            reviews.length;
      }

      return AnalyticsData(
        totalStudents: totalStudents,
        enrollments: allEnrollments,
        reviews: reviews,
        averageRating: averageRating,
      );
    } on DioException catch (e) {
      print('Dio Error:');
      print('URL: ${e.requestOptions.uri}');
      print('Method: ${e.requestOptions.method}');
      print('Headers: ${e.requestOptions.headers}');
      print('Response Status: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      throw Exception('Analytics request failed: ${e.message}');
    } catch (e) {
      print('General Error: $e');
      throw Exception('Failed to load analytics: $e');
    }
  }
}