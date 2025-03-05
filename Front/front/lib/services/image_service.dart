import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:front/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
}