import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Global key for ScaffoldMessenger to use across the app
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AuthService with ChangeNotifier {
  static const String baseUrl = 'http://192.168.1.13:8080';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;
  String? _userRole;
  String? _instructorStatus;
  String? _username;

  // Getters
  String? get token => _token;
  String? get userRole => _userRole;
  String? get instructorStatus => _instructorStatus;
  String? get username => _username;

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
    _username = await _secureStorage.read(key: 'user_name');
    print('Loaded token: $_token, userRole: $_userRole, instructorStatus: $_instructorStatus, username: $_username');
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
        return;
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
    // Ensure only one dialog is shown by checking if a dialog is already active
    bool isDialogActive = false;
    if (Navigator.of(context).canPop()) {
      isDialogActive = true;
    }

    if (!isDialogActive) {
      try {
        bool confirmLogout = await showDialog(
          context: context,
          barrierDismissible: false, // Prevent multiple dialogs
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
          print('Clearing authentication state...');
          _token = null;
          _userRole = null;
          _instructorStatus = null;
          _username = null;
          await _secureStorage.delete(key: 'auth_token');
          await _secureStorage.delete(key: 'user_role');
          await _secureStorage.delete(key: 'instructor_status');
          await _secureStorage.delete(key: 'user_name');
          notifyListeners(); // Notify listeners to update the app state
          print('Navigating to login...');
          if (Navigator.of(context).mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
          } else {
            print('Navigator is not mounted, forcing navigation');
            Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
          }
        }
      } catch (e) {
        print('Logout error: $e');
        if (Navigator.of(context).mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
        }
      }
    } else {
      print('Dialog already active, skipping logout prompt');
    }
  }

  Future<dynamic> deleteAccount(String username) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/auth/delete/$username'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return responseData['message'] as String; // Extract the message field
      } else {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      throw Exception('Error deleting account: $e');
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

  Future<int?> getUserIdByUsername(String username) async {
    final token = await getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/user/id/$username'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id'] as int?;
    } else {
      print('Failed to fetch user ID: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  // New method to fetch user details
  Future<Map<String, dynamic>> getUser(String username) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/user/$username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch user: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  // New method to update user details
  Future<Map<String, dynamic>> updateUser(String username, Map<String, dynamic> userData) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/update/$username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        final updatedData = json.decode(response.body);
        // Update local username if it changed
        if (userData.containsKey('username') && userData['username'] != _username) {
          _username = userData['username'].toString();
          await _secureStorage.write(key: 'user_name', value: _username);
          notifyListeners();
        }
        return updatedData;
      } else {
        throw Exception('Failed to update user: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<dynamic> updatePassword(String username, Map<String, String> passwordData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/update-password/$username'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(passwordData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return responseData['message'] as String; // Extract the message field
      } else {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to update password');
      }
    } catch (e) {
      throw Exception('Error updating password: $e');
    }
  }
}