import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

class AdminService {
  static const String baseUrl = 'http://192.168.1.13:8080';
  final _storage = const FlutterSecureStorage();

  // Helper method to get headers with authorization token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch pending instructors
  Future<List<Map<String, dynamic>>> getPendingInstructors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/pending-instructors'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load pending instructors: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Fetch all instructors
  Future<List<Map<String, dynamic>>> getAllInstructors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/instructors'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load instructors: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Fetch all students
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/students'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Approve an instructor
  Future<void> approveInstructor(int id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/approve-instructor/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to approve instructor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Reject an instructor
  Future<void> rejectInstructor(int id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/reject-instructor/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to reject instructor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Add a new category
  Future<Map<String, dynamic>> addCategory(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/categories'),
      headers: await _getHeaders(),
      body: json.encode({'name': name}),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to add category: ${response.body}');
  }

  // Fetch all categories
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: Please check your connection');
    }
  }

  // Delete a category
  Future<void> deleteCategory(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/categories/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  Future<void> updateCategory(int id, String newName) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/categories/$id'),
      headers: await _getHeaders(),
      body: json.encode({'name': newName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Update failed: ${response.body}');
    }
  }
  static String getImageUrl(int userId) {
    return '$baseUrl/image/get/$userId';
  }
  Future<bool> checkImageExists(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/image/get/$userId'),
        headers: await _getHeaders(),
      );
      print('Image check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Image check error: $e');
      return false;
    }
  }
  // In your AdminService class, add this method:
  Future<Uint8List?> getImageBytes(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/image/get/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      print('Image fetch failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error fetching image: $e');
      return null;
    }
  }
}