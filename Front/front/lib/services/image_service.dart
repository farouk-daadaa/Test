import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ImageService {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Future<Uint8List?> getUserImage(BuildContext context, int idUser) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.13:8080/image/get/$idUser'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Failed to load image: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching image: $e');
      return null;
    }
  }

  Future<bool> uploadUserImage(int idUser, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.13:8080/image/upload/$idUser'),
      );

      request.headers['Authorization'] = 'Bearer $_token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        return true;
      } else {
        print('Failed to upload image: ${response.statusCode}');
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody');
        return false;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return false;
    }
  }

  Future<bool> updateUserImage(int idUser, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://192.168.1.13:8080/image/update/$idUser'),
      );

      request.headers['Authorization'] = 'Bearer $_token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        print('Image updated successfully');
        return true;
      } else {
        print('Failed to update image: ${response.statusCode}');
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody');
        return false;
      }
    } catch (e) {
      print('Error updating image: $e');
      return false;
    }
  }
}