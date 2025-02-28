import 'package:dio/dio.dart';
import 'dart:io';
import 'package:decimal/decimal.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

enum CourseLanguage { ENGLISH, FRENCH, TUNISIAN }
enum CourseLevel { BEGINNER, INTERMEDIATE, EXPERT }
enum PricingType { FREE, PAID }

class CourseDTO {
  final int? id;
  final String title;
  final String description;
  final Decimal price;
  final PricingType pricingType;
  final double? rating;
  final int totalReviews;
  final String imageUrl;
  final CourseLevel level;
  final CourseLanguage language;
  final int totalStudents;
  final DateTime? lastUpdate;
  final int categoryId;
  final String? instructorName;

  CourseDTO({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.pricingType,
    this.rating,
    this.totalReviews = 0,
    required this.imageUrl,
    required this.level,
    required this.language,
    this.totalStudents = 0,
    this.lastUpdate,
    required this.categoryId,
    this.instructorName,
  });

  factory CourseDTO.fromJson(Map<String, dynamic> json) {
    return CourseDTO(
      id: json['id'] != null ? json['id'] as int : 0,
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      price: Decimal.parse(json['price']?.toString() ?? '0.0'),
      pricingType: PricingType.values.firstWhere(
            (e) => e.toString().split('.').last == json['pricingType'],
        orElse: () => PricingType.FREE,
      ),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      totalReviews: json['totalReviews'] != null ? json['totalReviews'] as int : 0,
      imageUrl: json['imageUrl'] ?? '',
      level: CourseLevel.values.firstWhere(
            (e) => e.toString().split('.').last == json['level'],
        orElse: () => CourseLevel.BEGINNER,
      ),
      language: CourseLanguage.values.firstWhere(
            (e) => e.toString().split('.').last == json['language'],
        orElse: () => CourseLanguage.ENGLISH,
      ),
      totalStudents: json['totalStudents'] != null ? json['totalStudents'] as int : 0,
      lastUpdate: json['lastUpdate'] != null ? DateTime.tryParse(json['lastUpdate']) : null,
      categoryId: json['categoryId'] != null ? json['categoryId'] as int : 0,
      instructorName: json['instructorName'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'price': price.toString(),
    'pricingType': pricingType.toString().split('.').last,
    'imageUrl': imageUrl,
    'level': level.toString().split('.').last,
    'language': language.toString().split('.').last,
    'categoryId': categoryId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CourseDTO &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => title; // For proper display in dropdown
}

class CourseService {
  final Dio _dio;
  final String baseUrl;

  CourseService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
    validateStatus: (status) => status! < 500,
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<List<CourseDTO>> getMyCourses() async {
    try {
      final response = await _dio.get('/api/courses');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => CourseDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to load courses: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again');
      }
      throw Exception('Failed to load courses: ${e.message}');
    }
  }

  Future<CourseDTO> createCourse({required CourseDTO course, File? imageFile}) async {
    try {
      final formData = FormData.fromMap({
        'course': MultipartFile.fromString(
          jsonEncode(course.toJson()),
          contentType: MediaType("application", "json"),
        ),
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
            contentType: MediaType("image", "jpeg"),
          ),
      });

      final response = await _dio.post(
        '/api/courses',
        data: formData,
        queryParameters: {'categoryId': course.categoryId},
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.statusCode == 201) {
        return CourseDTO.fromJson(response.data);
      }
      throw Exception('Failed to create course: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Failed to create course: ${e.message}');
    }
  }

  Future<CourseDTO> updateCourse({
    required CourseDTO course,
    File? imageFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'course': MultipartFile.fromString(
          jsonEncode(course.toJson()),
          contentType: MediaType("application", "json"),
        ),
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
            contentType: MediaType("image", "jpeg"),
          ),
      });

      final response = await _dio.put(
        '/api/courses/${course.id}',
        data: formData,
        queryParameters: {'categoryId': course.categoryId},
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.statusCode == 200) {
        return CourseDTO.fromJson(response.data);
      }
      throw Exception('Failed to update course: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Failed to update course: ${e.message}');
    }
  }

  Future<void> deleteCourse(int courseId) async {
    try {
      final response = await _dio.delete('/api/courses/$courseId');
      if (response.statusCode != 204) {
        throw Exception('Failed to delete course: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Not authorized to delete this course');
      }
      throw Exception('Failed to delete course: ${e.message}');
    }
  }

  Future<CourseDTO> getCourseDetails(int courseId) async {
    try {
      final response = await _dio.get('/api/courses/$courseId');
      if (response.statusCode == 200) {
        return CourseDTO.fromJson(response.data);
      }
      throw Exception('Failed to load course details: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Course not found');
      }
      throw Exception('Failed to load course details: ${e.message}');
    }
  }

  String getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) return imageUrl;

    final String fullUrl = '$baseUrl$imageUrl';
    return '$fullUrl?token=${_dio.options.headers["Authorization"]}';
  }

  Future<List<CourseDTO>> getAllCourses() async {
    try {
      final response = await _dio.get('/api/courses');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => CourseDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to load courses: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Failed to load courses: ${e.message}');
    }
  }

}