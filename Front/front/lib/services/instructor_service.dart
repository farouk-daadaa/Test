// lib/services/instructor_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:front/services/course_service.dart' as courseService; // Alias for CourseDTO

class InstructorProfileDTO {
  final String username;
  final String firstName;
  final String lastName;
  int followersCount;
  final int coursesCount;
  final int totalReviews;
  bool isFollowed;
  final double averageRating;
  final int totalStudents;
  final String imageBytes;

  InstructorProfileDTO({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.followersCount,
    required this.coursesCount,
    required this.totalReviews,
    required this.isFollowed,
    required this.averageRating,
    required this.totalStudents,
    required this.imageBytes,
  });

  factory InstructorProfileDTO.fromJson(Map<String, dynamic> json) {
    return InstructorProfileDTO(
      username: json['username'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      followersCount: json['followersCount'] ?? 0,
      coursesCount: json['coursesCount'] ?? 0,
      totalReviews: json['totalReviews'] ?? 0,
      isFollowed: json['isFollowed'] ?? false,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalStudents: json['totalStudents'] ?? 0,
      imageBytes: json['imageBytes'] ?? '',
    );
  }
}

class InstructorService {
  static const String baseUrl = 'http://192.168.1.13:8080';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  void setToken(String token) {
    _token = token;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) throw Exception('No authentication token found');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<InstructorProfileDTO> getInstructorProfile(int instructorId) async {
    try {
      final url = Uri.parse('$baseUrl/api/instructors/$instructorId/profile');
      final headers = await _getHeaders();
      print('Fetching profile for instructorId: $instructorId');
      final response = await http.get(url, headers: headers);
      print('Profile response: ${response.body}');
      if (response.statusCode == 200) {
        return InstructorProfileDTO.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  Future<List<courseService.CourseDTO>> getInstructorCourses(int instructorId) async {
    try {
      final url = Uri.parse('$baseUrl/api/instructors/$instructorId/courses');
      final headers = await _getHeaders();
      print('Fetching courses for instructorId: $instructorId');
      final response = await http.get(url, headers: headers);
      print('Courses response: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => courseService.CourseDTO.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching courses: $e');
    }
  }

  Future<void> followInstructor(int instructorId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/follow/instructor/$instructorId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to follow: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error following instructor: $e');
    }
  }

  Future<void> unfollowInstructor(int instructorId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/follow/instructor/$instructorId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to unfollow: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error unfollowing instructor: $e');
    }
  }

  Future<int?> getInstructorIdByUsername(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/instructors/username/$username/id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return int.parse(response.body);
      } else {
        print('Failed to fetch instructor ID for $username: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching instructor ID: $e');
      return null;
    }
  }

  Future<int?> getUserIdByInstructorId(int instructorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/instructors/$instructorId/user-id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return int.parse(response.body);
      } else {
        print('Failed to fetch user ID for instructorId $instructorId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user ID: $e');
      return null;
    }
  }
}