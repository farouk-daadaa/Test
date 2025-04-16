import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class ChatBotService {
  final Dio _dio;
  final String baseUrl;

  ChatBotService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String> askQuestion(String question, BuildContext context) async {
    // Declare authService outside the try block
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      // Ensure token is set before making the request
      final token = await authService.getToken();
      if (token == null) {
        throw Exception('No authentication token found. Please log in again.');
      }
      setToken(token);

      final response = await _dio.post(
        '/api/chatbot/ask',
        data: {'question': question},
      );

      if (response.statusCode == 200) {
        return response.data as String;
      }
      throw Exception('Failed to get response: ${response.statusCode} - ${response.data}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Handle token expiration or invalid token
        await authService.logout(context); // Now authService is accessible
        throw Exception('Session expired. Please log in again.');
      }
      if (e.response?.statusCode == 429) {
        throw Exception('Too many requests. Please try again later.');
      }
      throw Exception(
          'Error: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}