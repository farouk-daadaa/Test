import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class SessionDTO {
  final int? id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool? isFollowerOnly;
  final String? meetingLink;
  final int instructorId;
  final String status;
  final String? meetingToken;

  SessionDTO({
    this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.isFollowerOnly,
    this.meetingLink,
    required this.instructorId,
    required this.status,
    this.meetingToken,
  });

  factory SessionDTO.fromJson(Map<String, dynamic> json) {
    final sessionData = json.containsKey('session') ? json['session'] : json;
    return SessionDTO(
      id: sessionData['id'],
      title: sessionData['title'] ?? 'No Title',
      description: sessionData['description'] ?? 'No Description',
      startTime: DateTime.parse(sessionData['startTime']),
      endTime: DateTime.parse(sessionData['endTime']),
      isFollowerOnly: sessionData['followerOnly'] ?? false,
      meetingLink: sessionData['meetingLink'],
      instructorId: sessionData['instructorId'],
      status: sessionData['status'] ?? 'UPCOMING',
      meetingToken: json['meetingToken'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'isFollowerOnly': isFollowerOnly,
  };
}

class SessionService {
  final Dio _dio;
  final String baseUrl;

  SessionService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    print("🔹 Token Set in Dio: $token");
  }

  Future<List<SessionDTO>> getMySessions() async {
    try {
      final response = await _dio.get('/api/sessions/my-sessions');
      print('API Response: ${response.data}');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => SessionDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to load sessions: ${response.statusCode} - ${response.statusMessage}');
    } on DioException catch (e) {
      print('Dio Error: ${e.response?.data}');
      throw Exception(
          'Failed to load sessions: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<Map<String, dynamic>> getSessionJoinDetails(int sessionId) async {
    try {
      final response = await _dio.get(
        '/api/sessions/join/$sessionId',
        options: Options(
          headers: {
            'Authorization': _dio.options.headers['Authorization'],
          },
        ),
      );
      if (response.statusCode == 200) {
        return response.data; // Returns { "meetingLink": "...", "meetingToken": "..." }
      }
      throw Exception('Failed to fetch session details: ${response.statusCode} - ${response.statusMessage}');
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch session details: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<SessionDTO> createSession(SessionDTO session) async {
    try {
      final response = await _dio.post(
        '/api/sessions/create',
        data: session.toJson(),
      );
      print('Create Session Response: ${response.data}');
      if (response.statusCode == 201) {
        return SessionDTO.fromJson(response.data);
      }
      throw Exception('Failed to create session: ${response.statusCode} - ${response.statusMessage}');
    } on DioException catch (e) {
      throw Exception(
          'Failed to create session: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<SessionDTO> updateSession(int sessionId, SessionDTO session) async {
    try {
      final response = await _dio.put(
        '/api/sessions/$sessionId',
        data: session.toJson(),
      );
      if (response.statusCode == 200) {
        return SessionDTO.fromJson(response.data);
      }
      throw Exception('Failed to update session: ${response.statusCode} - ${response.statusMessage}');
    } on DioException catch (e) {
      throw Exception(
          'Failed to update session: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      final response = await _dio.delete('/api/sessions/$sessionId');
      if (response.statusCode != 204) {
        throw Exception('Failed to delete session: ${response.statusCode} - ${response.statusMessage}');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to delete session: ${e.response?.statusCode} - ${e.response?.data['message'] ?? e.message}');
    }
  }
}