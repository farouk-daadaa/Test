import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import for ChangeNotifier
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

class AdminService with ChangeNotifier { // Add `with ChangeNotifier`
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

  Future<Map<String, String>> getImageHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Authorization': 'Bearer $token',  // No Content-Type for images
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

  Future<Map<String, dynamic>> addCategory(String name, File? image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/categories'),
    );
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields['name'] = name;

    if (image != null) {
      final fileStream = http.ByteStream(image.openRead());
      final length = await image.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        length,
        filename: image.path.split('/').last,
      );
      request.files.add(multipartFile);
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to add category: $responseBody');
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

  Future<Map<String, dynamic>> updateCategoryWithImage(int id, String newName, File? image) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/categories/$id'),
    );
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    request.headers.addAll(headers);
    request.fields['name'] = newName;

    if (image != null) {
      final fileStream = http.ByteStream(image.openRead());
      final length = await image.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        length,
        filename: image.path.split('/').last,
      );
      request.files.add(multipartFile);
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to update category: $responseBody');
    }
  }

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
  static String getCategoryImageUrl(String imagePath) {
    return '$baseUrl$imagePath';
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