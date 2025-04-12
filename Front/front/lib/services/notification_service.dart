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
        isRead: json['isRead'] as bool? ?? false,
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
}

class NotificationService with ChangeNotifier {
  final Dio _dio;
  final String baseUrl;
  StompClient? _stompClient;
  List<NotificationDTO> _notifications = [];
  List<NotificationDTO> _unreadNotifications = [];
  bool _isConnected = false;
  bool _isDisposing = false; // Add flag to track disposal state

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

  // Initialize WebSocket connection
  Future<void> initializeWebSocket(String userId, String token) async {
    if (_stompClient != null && _stompClient!.connected) {
      return; // Already connected
    }

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
                final notificationJson = frame.body != null ? frame.body! : '{}';
                print('Raw WebSocket message: $notificationJson');
                final notificationData = jsonDecode(notificationJson);

                List<Map<String, dynamic>> notificationList;
                if (notificationData is List) {
                  notificationList = List<Map<String, dynamic>>.from(notificationData);
                } else if (notificationData is Map<String, dynamic>) {
                  notificationList = [notificationData];
                } else {
                  print('Unexpected WebSocket message format: $notificationData');
                  return;
                }

                for (var data in notificationList) {
                  final newNotification = NotificationDTO.fromJson(data);
                  _notifications.insert(0, newNotification);
                  if (!newNotification.isRead) {
                    _unreadNotifications.insert(0, newNotification);
                  }
                  print('Processed WebSocket notification: ${newNotification.toJson()}');
                }
                if (!_isDisposing) {
                  notifyListeners();
                }
              } catch (e) {
                print('Error processing WebSocket message: $e');
              }
            },
          );
          if (!_isDisposing) {
            notifyListeners();
          }
        },
        beforeConnect: () async {
          print('Connecting to WebSocket...');
        },
        onWebSocketError: (dynamic error) {
          _isConnected = false;
          print('WebSocket error: $error');
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
          print('WebSocket disconnected');
          if (!_isDisposing) {
            notifyListeners();
          }
        },
      ),
    );

    _stompClient!.activate();
  }

  void disconnectWebSocket() {
    _isDisposing = true; // Set flag to indicate disposal
    _stompClient?.deactivate();
    _isConnected = false;
    // Do not call notifyListeners() here, as the widget is being disposed
    print('WebSocket disconnected during disposal');
  }

  Future<void> fetchNotifications(int userId) async {
    try {
      final response = await _dio.get('/api/notifications');
      _notifications = (response.data as List)
          .map((json) => NotificationDTO.fromJson(json))
          .toList();
      _unreadNotifications =
          _notifications.where((notification) => !notification.isRead).toList();
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
      _unreadNotifications = (response.data as List)
          .map((json) => NotificationDTO.fromJson(json))
          .toList();
      if (!_isDisposing) {
        notifyListeners();
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

  // Optional: Reset the disposal flag if the service is reused
  void resetDisposalState() {
    _isDisposing = false;
  }
}