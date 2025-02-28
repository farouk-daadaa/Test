import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AuthService with ChangeNotifier {
  static const String baseUrl = 'http://192.168.1.13:8080';
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String? _token;
  String? _userRole;
  String? _instructorStatus;
  String? _username; // Added username property

  // Getters
  String? get token => _token;
  String? get userRole => _userRole;
  String? get instructorStatus => _instructorStatus;
  String? get username => _username; // Added username getter

  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _handleNetworkError(dynamic error) async {
    if (!await _checkInternetConnection()) {
      throw Exception('No internet connection. Please try again later.');
    } else if (error is http.ClientException) {
      throw Exception('Network error: Unable to connect to the server.');
    } else {
      throw Exception('An unexpected error occurred: ${error.toString()}');
    }
  }

  Future<void> loadToken() async {
    _token = await _secureStorage.read(key: 'auth_token');
    _userRole = await _secureStorage.read(key: 'user_role');
    _instructorStatus = await _secureStorage.read(key: 'instructor_status');
    _username = await _secureStorage.read(key: 'user_name'); // Load username
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('accessToken')) {
          _token = responseData['accessToken'];
          await _secureStorage.write(key: 'auth_token', value: _token);

          if (responseData.containsKey('user')) {
            final userData = responseData['user'];
            if (userData.containsKey('role')) {
              _userRole = userData['role'].toString();
              await _secureStorage.write(key: 'user_role', value: _userRole);

              if (_userRole == 'INSTRUCTOR' && userData.containsKey('instructor')) {
                _instructorStatus = userData['instructor']['status'];
                await _secureStorage.write(key: 'instructor_status', value: _instructorStatus);
              }

              // Store username if available
              if (userData.containsKey('username')) {
                _username = userData['username'].toString();
                await _secureStorage.write(key: 'user_name', value: _username);
              }
            }
          }

          notifyListeners();
          return responseData;
        } else {
          throw Exception('Invalid response format: missing access token');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, String> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<void> registerInstructor(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register/instructor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return; // Success
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Registration failed');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to send reset code');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<bool> validateResetCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/validate-reset-code?code=$code'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<void> resetPassword(String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Future<void> logout(BuildContext context) async {
    bool confirmLogout = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirmLogout) {
      _token = null;
      _userRole = null;
      _instructorStatus = null;
      _username = null; // Clear username
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'user_role');
      await _secureStorage.delete(key: 'instructor_status');
      await _secureStorage.delete(key: 'user_name'); // Delete stored username
      notifyListeners();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }

  Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/validate-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}