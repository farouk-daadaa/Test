import 'package:dio/dio.dart';

enum LessonStatus {
  PENDING,
  COMPLETED
}

class LessonProgressDTO {
  final int? id;
  final int enrollmentId;
  final int lessonId;
  final LessonStatus status;
  final DateTime? completedAt;

  LessonProgressDTO({
    this.id,
    required this.enrollmentId,
    required this.lessonId,
    required this.status,
    this.completedAt,
  });

  factory LessonProgressDTO.fromJson(Map<String, dynamic> json) {
    return LessonProgressDTO(
      id: json['id'],
      enrollmentId: json['enrollmentId'],
      lessonId: json['lessonId'],
      status: LessonStatus.values.firstWhere(
            (e) => e.toString() == 'LessonStatus.${json['status']}',
        orElse: () => LessonStatus.PENDING,
      ),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'enrollmentId': enrollmentId,
    'lessonId': lessonId,
    'status': status.toString().split('.').last,
    'completedAt': completedAt?.toIso8601String(),
  };
}

class LessonProgressService {
  final Dio _dio;
  final String baseUrl;

  LessonProgressService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<LessonProgressDTO> markLessonCompleted(int enrollmentId, int lessonId) async {
    try {
      final response = await _dio.post(
        '/api/lesson-progress/$enrollmentId/complete/$lessonId',
      );
      return LessonProgressDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<int> getCourseProgress(int enrollmentId) async {
    try {
      final response = await _dio.get(
        '/api/lesson-progress/$enrollmentId/progress',
      );
      return response.data as int;
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
          return Exception('Lesson or enrollment not found');
        case 409:
          return Exception('Lesson is already completed');
        case 400:
          return Exception('Invalid request: ${e.response?.data?['message']}');
        default:
          return Exception(e.response?.data?['message'] ?? 'An error occurred');
      }
    }
    return Exception('An unexpected error occurred');
  }
}