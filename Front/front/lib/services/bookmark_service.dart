import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../services/course_service.dart';

class BookmarkService {
  final Dio _dio;
  final String baseUrl;

  BookmarkService({required this.baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> addBookmark(int courseId) async {
    try {
      final response = await _dio.post('/api/bookmarks/$courseId');
      if (response.statusCode != 201) {
        throw Exception('Failed to add bookmark: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Course is already bookmarked');
      }
      throw Exception('Failed to add bookmark: ${e.message}');
    }
  }

  Future<void> removeBookmark(int courseId) async {
    try {
      final response = await _dio.delete('/api/bookmarks/$courseId');
      if (response.statusCode != 204) {
        throw Exception('Failed to remove bookmark: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Bookmark not found');
      }
      throw Exception('Failed to remove bookmark: ${e.message}');
    }
  }

  Future<List<CourseDTO>> getBookmarkedCourses() async {
    try {
      final response = await _dio.get('/api/bookmarks');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => CourseDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to fetch bookmarks: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again');
      }
      throw Exception('Failed to fetch bookmarks: ${e.message}');
    }
  }

  Future<bool> isCourseBookmarked(int courseId) async {
    try {
      final bookmarks = await getBookmarkedCourses();
      return bookmarks.any((course) => course.id == courseId);
    } catch (e) {
      throw Exception('Failed to check bookmark status: $e');
    }
  }
}