import 'package:dio/dio.dart';

class LessonDTO {
  final int? id;
  final String title;
  final int duration;
  final String? videoUrl;

  LessonDTO({
    this.id,
    required this.title,
    required this.duration,
    this.videoUrl,
  });

  factory LessonDTO.fromJson(Map<String, dynamic> json) {
    return LessonDTO(
      id: json['id'],
      title: json['title'],
      duration: json['duration'],
      videoUrl: json['videoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'duration': duration,
    if (videoUrl != null) 'videoUrl': videoUrl,
  };
}

class LessonService {
  final Dio _dio;
  final String baseUrl;

  LessonService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<List<LessonDTO>> getLessons(int courseId) async {
    try {
      final response = await _dio.get('/api/courses/$courseId/lessons');
      return (response.data as List)
          .map((json) => LessonDTO.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<LessonDTO> addLesson(int courseId, LessonDTO lesson) async {
    try {
      final response = await _dio.post(
        '/api/courses/$courseId/lessons',
        data: lesson.toJson(),
      );
      return LessonDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<LessonDTO> updateLesson(int courseId, int lessonId, LessonDTO lesson) async {
    try {
      final response = await _dio.put(
        '/api/courses/$courseId/lessons/$lessonId',
        data: lesson.toJson(),
      );
      return LessonDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteLesson(int courseId, int lessonId) async {
    try {
      await _dio.delete('/api/courses/$courseId/lessons/$lessonId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioError) {
      if (e.response?.statusCode == 401) {
        return Exception('Unauthorized: Please log in again');
      }
      if (e.response?.statusCode == 403) {
        return Exception('You do not have permission to perform this action');
      }
      return Exception(e.response?.data?['message'] ?? 'An error occurred');
    }
    return Exception('An unexpected error occurred');
  }
}