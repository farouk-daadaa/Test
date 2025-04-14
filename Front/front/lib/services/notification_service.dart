import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:intl/intl.dart';

class NotificationDTO {
  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;
  final String type;

  NotificationDTO({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
  });

  factory NotificationDTO.fromJson(Map<String, dynamic> json) {
    try {
      return NotificationDTO(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? 'Untitled',
        message: json['message'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        isRead: json['read'] as bool? ?? false,
        type: json['type'] as String? ?? 'UNKNOWN',
      );
    } catch (e) {
      print('Error parsing NotificationDTO: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type,
    };
  }

  String getFormattedDate() {
    return DateFormat('MMM dd, yyyy – HH:mm').format(createdAt);
  }

  String getNotificationSubtype() {
    if (title.startsWith('Session Live:')) {
      return 'LIVE';
    } else if (title.startsWith('New Session:')) {
      return 'SCHEDULED';
    } else if (type == 'COURSE') {
      return 'COURSE';
    } else if (type == 'REVIEW') {
      return 'REVIEW';
    }
    return 'UNKNOWN';
  }

  int? getSessionId() {
    final regex = RegExp(r'\[Session ID: (\d+)\]');
    final match = regex.firstMatch(message);
    final sessionIdStr = match?.group(1);
    return sessionIdStr != null ? int.tryParse(sessionIdStr) : null;
  }

  int? getCourseId() {
    final regex = RegExp(r'\[Course ID: (\d+)\]');
    final match = regex.firstMatch(message);
    final courseIdStr = match?.group(1);
    return courseIdStr != null ? int.tryParse(courseIdStr) : null;
  }

  String getFormattedMessage() {
    final subtype = getNotificationSubtype();
    if (subtype == 'LIVE') {
      final sessionTitle = title.replaceFirst('Session Live: ', '');
      return "'$sessionTitle' is now live tap to join";
    } else if (subtype == 'SCHEDULED') {
      final sessionTitle = title.replaceFirst('New Session: ', '');
      final instructorMatch = RegExp(r'Instructor (\w+)').firstMatch(message);
      final instructor = instructorMatch?.group(1) ?? 'Unknown';
      final dateTimeMatch = RegExp(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})').firstMatch(message);
      final dateTimeStr = dateTimeMatch?.group(1);
      final dateTime = dateTimeStr != null ? DateTime.parse(dateTimeStr) : createdAt;
      final visibility = message.contains('Open to all') ? 'Public' : 'Followers Only';
      final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
      final formattedTime = DateFormat('h:mm a').format(dateTime.toLocal());
      return "Instructor $instructor has scheduled '$sessionTitle' on $formattedDate at $formattedTime ($visibility).";
    } else if (subtype == 'COURSE') {
      final courseTitleMatch = RegExp(r"published a new course: '([^']+)'").firstMatch(message);
      final courseTitle = courseTitleMatch?.group(1) ?? 'Unknown Course';
      final instructorMatch = RegExp(r'Instructor (\w+)').firstMatch(message);
      final instructor = instructorMatch?.group(1) ?? 'Unknown';
      return "Instructor $instructor has published a new course: '$courseTitle'. Tap to view.";
    } else if (subtype == 'REVIEW') {
      final courseTitleMatch = RegExp(r"course '([^']+)'").firstMatch(message);
      final courseTitle = courseTitleMatch?.group(1) ?? 'Unknown Course';
      final userMatch = RegExp(r'by (\w+)').firstMatch(message);
      final username = userMatch?.group(1) ?? 'Unknown User';
      if (title == 'New Review') {
        final ratingMatch = RegExp(r'Rating: (\d\.\d)').firstMatch(message);
        final rating = ratingMatch?.group(1) ?? 'N/A';
        return "$username reviewed your course '$courseTitle' with a rating of $rating. Tap to view.";
      } else if (title == 'Review Updated') {
        final ratingMatch = RegExp(r'New Rating: (\d\.\d)').firstMatch(message);
        final rating = ratingMatch?.group(1) ?? 'N/A';
        return "$username updated their review for your course '$courseTitle' with a new rating of $rating. Tap to view.";
      } else if (title == 'Review Deleted') {
        return "$username deleted their review for your course '$courseTitle'. Tap to view.";
      }
    }
    return message;
  }
}

class NotificationService with ChangeNotifier {
  final Dio _dio;
  final String baseUrl;
  StompClient? _stompClient;
  List<NotificationDTO> _notifications = [];
  List<NotificationDTO> _unreadNotifications = [];
  bool _isConnected = false;
  bool _isDisposing = false;

  List<NotificationDTO> get notifications => _notifications;
  List<NotificationDTO> get unreadNotifications => _unreadNotifications;
  int get unreadCount => _unreadNotifications.length;
  bool get isConnected => _isConnected;

  NotificationService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    contentType: 'application/json',
  ));

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearStateAndDisconnect() async {
    print('Clearing NotificationService state and disconnecting WebSocket');
    _notifications.clear();
    _unreadNotifications.clear();
    disconnectWebSocket();
    _isConnected = false;
    resetDisposalState();
    notifyListeners();
  }

  Future<void> initializeWebSocket(String userId, String token) async {
    // Always disconnect existing WebSocket before initializing a new one
    disconnectWebSocket();

    _isDisposing = false;
    print('Reset _isDisposing to false for user $userId');

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://192.168.1.13:8080/ws',
        onConnect: (StompFrame frame) {
          _isConnected = true;
          print('WebSocket connected for user $userId');
          _stompClient!.subscribe(
            destination: '/topic/notifications/$userId',
            callback: (StompFrame frame) {
              try {
                final notificationJson = frame.body ?? '{}';
                print('Received WebSocket message: $notificationJson');

                final notificationData = jsonDecode(notificationJson);
                print('Parsed WebSocket message: $notificationData');

                List<Map<String, dynamic>> notificationList;
                if (notificationData is List) {
                  print('Message is a list of notifications');
                  notificationList = List<Map<String, dynamic>>.from(notificationData);
                } else if (notificationData is Map<String, dynamic>) {
                  print('Message is a single notification');
                  notificationList = [notificationData];
                } else {
                  print('Unexpected WebSocket message format: $notificationData');
                  return;
                }

                for (var data in notificationList) {
                  print('Processing notification: $data');
                  final newNotification = NotificationDTO.fromJson(data);
                  print('Parsed notification: ${newNotification.toJson()}');
                  _notifications.insert(0, newNotification);
                  if (!newNotification.isRead) {
                    _unreadNotifications.insert(0, newNotification);
                  }
                  print('Updated notifications: ${_notifications.length}, unread: ${_unreadNotifications.length}');
                }

                if (!_isDisposing) {
                  print('Notifying listeners of new notifications');
                  notifyListeners();
                } else {
                  print('Skipping notifyListeners because _isDisposing is true');
                }
              } catch (e) {
                print('Error processing WebSocket message: $e');
                print('Frame body: ${frame.body}');
              }
            },
          );
          if (!_isDisposing) {
            print('Notifying listeners of WebSocket connection');
            notifyListeners();
          }
        },
        beforeConnect: () async {
          print('Connecting to WebSocket for user $userId...');
        },
        onWebSocketError: (dynamic error) {
          _isConnected = false;
          print('WebSocket error for user $userId: $error');
          if (!_isDisposing) {
            notifyListeners();
          }
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onDisconnect: (StompFrame frame) {
          _isConnected = false;
          print('WebSocket disconnected for user $userId');
          if (!_isDisposing) {
            notifyListeners();
          }
        },
      ),
    );

    _stompClient!.activate();
  }

  void disconnectWebSocket() {
    _isDisposing = true;
    _stompClient?.deactivate();
    _isConnected = false;
    print('WebSocket disconnected during disposal');
  }

  Future<void> fetchNotifications(int userId) async {
    try {
      final response = await _dio.get('/api/notifications');
      print('Fetched notifications from server: ${response.data}');
      _notifications = (response.data as List)
          .map((json) => NotificationDTO.fromJson(json))
          .toList();
      _unreadNotifications =
          _notifications.where((notification) => !notification.isRead).toList();
      print('Updated notifications: ${_notifications.length}, unread: ${_unreadNotifications.length}');
      if (!_isDisposing) {
        notifyListeners();
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> fetchUnreadNotifications(int userId) async {
    try {
      final response = await _dio.get('/api/notifications?unreadOnly=true');
      print('Fetched unread notifications from server: ${response.data}');
      _unreadNotifications = (response.data as List)
          .map((json) => NotificationDTO.fromJson(json))
          .toList();
      print('Updated unread notifications: ${_unreadNotifications.length}');
      if (!_isDisposing) {
        notifyListeners();
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAllAsRead(int userId) async {
    try {
      final response = await _dio.put('/api/notifications/read-all');
      if (response.statusCode == 204) {
        for (var notification in _notifications) {
          notification.isRead = true;
        }
        _unreadNotifications.clear();
        print('Marked all notifications as read for user $userId');
        if (!_isDisposing) {
          notifyListeners();
        }
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAsRead(int notificationId, int userId) async {
    try {
      final response = await _dio.put('/api/notifications/$notificationId/read');
      if (response.statusCode == 204) {
        final notification = _notifications.firstWhere((n) => n.id == notificationId);
        notification.isRead = true;
        _unreadNotifications.removeWhere((n) => n.id == notificationId);
        print('Marked notification $notificationId as read');
        if (!_isDisposing) {
          notifyListeners();
        }
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteNotification(int notificationId, int userId) async {
    try {
      final response = await _dio.delete('/api/notifications/$notificationId');
      if (response.statusCode == 204) {
        _notifications.removeWhere((n) => n.id == notificationId);
        _unreadNotifications.removeWhere((n) => n.id == notificationId);
        print('Deleted notification $notificationId');
        if (!_isDisposing) {
          notifyListeners();
        }
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
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

  void resetDisposalState() {
    _isDisposing = false;
    print('Reset _isDisposing to false');
  }
}