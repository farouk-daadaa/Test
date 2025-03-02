import 'package:dio/dio.dart';

class ReviewDTO {
  final int? id;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final int courseId;
  final int userId;
  final String username;

  ReviewDTO({
    this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.courseId,
    required this.userId,
    required this.username,
  });

  factory ReviewDTO.fromJson(Map<String, dynamic> json) {
    return ReviewDTO(
      id: json['id'],
      rating: json['rating'].toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
      courseId: json['courseId'],
      userId: json['userId'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'courseId': courseId,
      'userId': userId,
      'username': username,
    };
  }
}

class ReviewService {
  final Dio _dio;
  final String baseUrl;

  ReviewService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<ReviewDTO> createReview(int courseId, int userId, double rating, String comment) async {
    try {
      final response = await _dio.post(
        '/api/courses/$courseId/reviews',
        data: {
          'rating': rating,
          'comment': comment,
          'userId': userId,
        },
      );
      return ReviewDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<ReviewDTO> updateReview(int reviewId, int userId, double rating, String comment) async {
    try {
      final response = await _dio.put(
        '/api/reviews/$reviewId',
        data: {
          'rating': rating,
          'comment': comment,
          'userId': userId,
        },
      );
      return ReviewDTO.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteReview(int reviewId, int userId) async {
    try {
      await _dio.delete(
        '/api/reviews/$reviewId',
        data: {
          'userId': userId,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<ReviewDTO>> getReviewsByCourse(int courseId, {String? sortBy}) async {
    try {
      final response = await _dio.get(
        '/api/reviews/courses/$courseId',
        queryParameters: {
          if (sortBy != null) 'sortBy': sortBy,
        },
      );
      return (response.data as List)
          .map((json) => ReviewDTO.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioError) {
      print('DioError: ${e.message}');
      print('Response: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        return Exception('Unauthorized: Please log in again');
      }
      if (e.response?.statusCode == 403) {
        return Exception('You do not have permission to perform this action');
      }
      if (e.response?.statusCode == 400) {
        return Exception('Invalid request: ${e.response?.data?['message']}');
      }
      if (e.response?.statusCode == 404) {
        return Exception('Resource not found');
      }
      return Exception(e.response?.data?['message'] ?? 'An error occurred');
    }
    return Exception('An unexpected error occurred');
  }
}