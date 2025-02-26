import 'package:dio/dio.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class LessonDTO {
  final int? id;
  final String title;
  final String? videoUrl;

  LessonDTO({
    this.id,
    required this.title,
    this.videoUrl,
  });

  factory LessonDTO.fromJson(Map<String, dynamic> json) {
    return LessonDTO(
      id: json['id'],
      title: json['title'],
      videoUrl: json['videoUrl'],
    );
  }
}

class LessonService {
  final Dio _dio;
  final String baseUrl;

  LessonService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    // Remove default content-type header
    contentType: null,
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<List<LessonDTO>> getLessons(int courseId) async {
    try {
      // Set JSON content type for GET request
      _dio.options.headers['Content-Type'] = 'application/json';

      final response = await _dio.get('/api/courses/$courseId/lessons');
      return (response.data as List)
          .map((json) => LessonDTO.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<LessonDTO> addLesson(int courseId, String title, File? videoFile) async {
    try {
      if (videoFile != null && !_isValidVideoFormat(videoFile.path)) {
        throw Exception('Invalid video format. Allowed formats: MP4, MPEG, MOV, AVI');
      }

      FormData formData = FormData.fromMap({
        'title': title,
        if (videoFile != null)
          'video': await MultipartFile.fromFile(
            videoFile.path,
            filename: videoFile.path.split('/').last,
            contentType: MediaType('video', videoFile.path.split('.').last.toLowerCase()),
          ),
      });

      final response = await _dio.post(
        '/api/courses/$courseId/lessons',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return LessonDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<LessonDTO> updateLesson(int courseId, int lessonId, String title, File? videoFile) async {
    try {
      if (videoFile != null && !_isValidVideoFormat(videoFile.path)) {
        throw Exception('Invalid video format. Allowed formats: MP4, MPEG, MOV, AVI');
      }

      FormData formData = FormData.fromMap({
        'title': title,
        if (videoFile != null)
          'video': await MultipartFile.fromFile(
            videoFile.path,
            filename: videoFile.path.split('.').last.toLowerCase(),
            contentType: MediaType('video', videoFile.path.split('.').last.toLowerCase()),
          ),
      });

      final response = await _dio.put(
        '/api/courses/$courseId/lessons/$lessonId',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return LessonDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteLesson(int courseId, int lessonId) async {
    try {
      // Set JSON content type for DELETE request
      _dio.options.headers['Content-Type'] = 'application/json';

      await _dio.delete('/api/courses/$courseId/lessons/$lessonId');
    } catch (e) {
      throw _handleError(e);
    }
  }
  bool _isValidVideoFormat(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['mp4', 'mpeg', 'mov', 'avi'].contains(extension);
  }

  Exception _handleError(dynamic e) {
    if (e is DioError) {
      print('DioError: ${e.message}'); // Add this for debugging
      print('Response: ${e.response?.data}'); // Add this for debugging

      if (e.response?.statusCode == 401) {
        return Exception('Unauthorized: Please log in again');
      }
      if (e.response?.statusCode == 403) {
        return Exception('You do not have permission to perform this action');
      }
      if (e.response?.statusCode == 413) {
        return Exception('Video file size is too large (max 500MB)');
      }
      return Exception(e.response?.data?['message'] ?? 'An error occurred');
    }
    return Exception('An unexpected error occurred');
  }
}