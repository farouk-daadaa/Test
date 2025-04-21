import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class EventDTO {
  final int id;
  final String title;
  final String description;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isOnline;
  final String? location;
  final String? meetingLink;
  final String? imageUrl;
  final int? maxParticipants;
  final int currentParticipants;
  final int capacityLeft;
  final String status;

  EventDTO({
    required this.id,
    required this.title,
    required this.description,
    required this.startDateTime,
    required this.endDateTime,
    required this.isOnline,
    this.location,
    this.meetingLink,
    this.imageUrl,
    this.maxParticipants,
    required this.currentParticipants,
    required this.capacityLeft,
    required this.status,
  });

  factory EventDTO.fromJson(Map<String, dynamic> json) {
    return EventDTO(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startDateTime: DateTime.parse(json['startDateTime']),
      endDateTime: DateTime.parse(json['endDateTime']),
      isOnline: json['online'] ?? false,
      location: json['location'],
      meetingLink: json['meetingLink'],
      imageUrl: json['imageUrl'],
      maxParticipants: json['maxParticipants'],
      currentParticipants: json['currentParticipants'],
      capacityLeft: json['capacityLeft'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'online': isOnline,
      'location': location,
      'maxParticipants': maxParticipants,
    };
  }

  String getFormattedDate() {
    return DateFormat('MMM dd, yyyy – HH:mm').format(startDateTime);
  }
}

class JoinEventResponse {
  final String meetingLink;
  final String meetingToken;
  final String roomId;
  final String title;

  JoinEventResponse({
    required this.meetingLink,
    required this.meetingToken,
    required this.roomId,
    required this.title,
  });

  factory JoinEventResponse.fromJson(Map<String, dynamic> json) {
    return JoinEventResponse(
      meetingLink: json['meetingLink'],
      meetingToken: json['meetingToken'],
      roomId: json['roomId'],
      title: json['title'],
    );
  }
}

class AttendanceDTO {
  final int? studentId;
  final String username;
  final String? email; // Nullable to handle missing email
  final DateTime? checkInTime; // Nullable to handle no check-in
  final bool checkedIn;

  AttendanceDTO({
    this.studentId,
    required this.username,
    this.email,
    this.checkInTime,
    required this.checkedIn,
  });

  factory AttendanceDTO.fromJson(Map<String, dynamic> json) {
    return AttendanceDTO(
      studentId: json['studentId'],
      username: json['username'] ?? '',
      email: json['email'],
      checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime']) : null,
      checkedIn: json['checkedIn'] ?? false,
    );
  }
}

class EventService {
  final Dio _dio;
  final String baseUrl;

  EventService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    debugPrint('EventService: Set token: $token');
  }

  Future<List<EventDTO>> getEvents({int page = 0, int size = 10, String? status}) async {
    try {
      debugPrint('EventService: Fetching events with headers: ${_dio.options.headers}');
      final response = await _dio.get(
        '/api/events',
        queryParameters: {
          'page': page,
          'size': size,
          if (status != null) 'status': status,
        },
      );
      debugPrint('EventService: Response status: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        return (response.data['content'] as List)
            .map((json) => EventDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to load events: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error fetching events: $e');
      throw _handleError(e);
    }
  }

  Future<EventDTO> createEvent(EventDTO event) async {
    try {
      debugPrint('EventService: Creating event with data: ${event.toJson()}');
      final response = await _dio.post(
        '/api/events',
        data: event.toJson(),
      );
      debugPrint('EventService: Create event response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 201) {
        return EventDTO.fromJson(response.data);
      }
      throw Exception('Failed to create event: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error creating event: $e');
      throw _handleError(e);
    }
  }

  Future<EventDTO> updateEvent(int eventId, EventDTO event) async {
    try {
      debugPrint('EventService: Updating event $eventId with data: ${event.toJson()}');
      final response = await _dio.put(
        '/api/events/$eventId',
        data: event.toJson(),
      );
      debugPrint('EventService: Update event response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        return EventDTO.fromJson(response.data);
      }
      throw Exception('Failed to update event: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error updating event: $e');
      throw _handleError(e);
    }
  }

  Future<void> deleteEvent(int eventId) async {
    try {
      debugPrint('EventService: Deleting event $eventId');
      final response = await _dio.delete('/api/events/$eventId');
      debugPrint('EventService: Delete event response: ${response.statusCode}');
      if (response.statusCode != 204) {
        throw Exception('Failed to delete event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('EventService: Error deleting event: $e');
      throw _handleError(e);
    }
  }

  Future<List<AttendanceDTO>> getAttendance(int eventId) async {
    try {
      debugPrint('EventService: Fetching attendance for event $eventId');
      final response = await _dio.get('/api/events/$eventId/attendance');
      debugPrint('EventService: Attendance response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => AttendanceDTO.fromJson(json))
            .toList();
      }
      throw Exception('Failed to load attendance: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error fetching attendance: $e');
      throw _handleError(e);
    }
  }

  Future<String> exportAttendance(int eventId) async {
    try {
      debugPrint('EventService: Exporting attendance for event $eventId');
      final response = await _dio.get(
        '/api/events/$eventId/attendance/csv', // Updated endpoint
        options: Options(
          responseType: ResponseType.plain, // Expect plain text (Base64)
        ),
      );
      debugPrint('EventService: Export attendance response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        // Decode Base64 data
        final decodedData = utf8.decode(base64Decode(response.data));
        return decodedData;
      }
      throw Exception('Failed to export attendance: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error exporting attendance: $e');
      throw _handleError(e);
    }
  }

  Future<bool> checkIn(int eventId, String qrData) async {
    try {
      debugPrint('EventService: Checking in for event $eventId with QR: $qrData');
      final response = await _dio.post(
        '/api/events/$eventId/check-in',
        data: {'qrData': qrData},
      );
      debugPrint('EventService: Check-in response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      throw Exception('Failed to check in: ${response.statusCode}');
    } catch (e) {
      debugPrint('EventService: Error checking in: $e');
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
      debugPrint('EventService: DioException: ${e.response?.statusCode}, ${e.response?.data}');
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
        return Exception('Event not found');
      }
      if (e.response?.statusCode == 406) {
        return Exception('Invalid request format for CSV export');
      }
      if (e.response?.statusCode == 500 && e.response?.data['message']?.contains('Attendance export is only available for in-person events') == true) {
        return Exception('Attendance not available for online events');
      }
      return Exception(e.response?.data?['message'] ?? 'An error occurred');
    }
    return Exception('An unexpected error occurred');
  }
}