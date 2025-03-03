import 'package:dio/dio.dart';

enum EnrollmentStatus {
  ONGOING,
  COMPLETED
}

class EnrollmentDTO {
  final int? id;
  final int courseId;
  final String courseTitle;
  final String courseDescription;
  final EnrollmentStatus status;
  final int progressPercentage;
  final DateTime enrollmentDate;
  final DateTime lastAccessedDate;

  EnrollmentDTO({
    this.id,
    required this.courseId,
    required this.courseTitle,
    required this.courseDescription,
    required this.status,
    required this.progressPercentage,
    required this.enrollmentDate,
    required this.lastAccessedDate,
  });

  factory EnrollmentDTO.fromJson(Map<String, dynamic> json) {
    return EnrollmentDTO(
      id: json['id'],
      courseId: json['courseId'],
      courseTitle: json['courseTitle'],
      courseDescription: json['courseDescription'] ?? '',
      status: EnrollmentStatus.values.firstWhere(
            (e) => e.toString() == 'EnrollmentStatus.${json['status']}',
        orElse: () => EnrollmentStatus.ONGOING,
      ),
      progressPercentage: json['progressPercentage'],
      enrollmentDate: DateTime.parse(json['enrollmentDate']),
      lastAccessedDate: DateTime.parse(json['lastAccessedDate']),
    );
  }
}

class EnrollmentService {
  final Dio _dio;
  final String baseUrl;

  EnrollmentService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<EnrollmentDTO> enrollStudent(int courseId) async {
    try {
      final response = await _dio.post(
        '/api/enrollments/enroll/$courseId',
      );
      return EnrollmentDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unenrollStudent(int courseId) async {
    try {
      await _dio.delete(
        '/api/enrollments/unenroll/$courseId',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<EnrollmentDTO>> getEnrolledCourses() async {
    try {
      final response = await _dio.get('/api/enrollments/my-courses');
      return (response.data as List)
          .map((json) => EnrollmentDTO.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateProgress(int enrollmentId, int progressPercentage) async {
    try {
      await _dio.put(
        '/api/enrollments/$enrollmentId/progress',
        queryParameters: {'progressPercentage': progressPercentage},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioError) {
      print('DioError: ${e.message}');
      print('Response: ${e.response?.data}');

      switch (e.response?.statusCode) {
        case 401:
          return Exception('Unauthorized: Please log in again');
        case 403:
          return Exception('You do not have permission for this action');
        case 404:
          return Exception('Enrollment not found');
        case 409:
          return Exception('Already enrolled in this course');
        default:
          return Exception(e.response?.data?['message'] ?? 'An error occurred');
      }
    }
    return Exception('An unexpected error occurred');
  }
}