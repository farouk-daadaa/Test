import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../auth/two_factor_dialog.dart';
import '../services/notification_service.dart'; // Import NotificationService

// Global key for ScaffoldMessenger to use across the app
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AuthService with ChangeNotifier {
  static const String baseUrl = 'http://192.168.1.13:8080';
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final NotificationService _notificationService; // Add NotificationService dependency
  String? _token;
  String? _userRole;
  String? _instructorStatus;
  String? _username;
  String? _email;
  DateTime? _lastCodeSentTime;
  int? _remainingCodeResendTime;
  static const int _codeResendCooldown = 300;

  // Constructor updated to accept NotificationService
  AuthService({required NotificationService notificationService})
      : _notificationService = notificationService;

  // Getters
  String? get token => _token;
  String? get userRole => _userRole;
  String? get instructorStatus => _instructorStatus;
  String? get username => _username;
  String? get email => _email;
  int? get remainingCodeResendTime => _remainingCodeResendTime;

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
    _email = await _secureStorage.read(key: 'user_email');
    String? lastSent = await _secureStorage.read(key: 'last_2fa_code_sent');
    if (lastSent != null) {
      _lastCodeSentTime = DateTime.parse(lastSent);
      final now = DateTime.now();
      final elapsedSeconds = now.difference(_lastCodeSentTime!).inSeconds;
      _remainingCodeResendTime = _codeResendCooldown - elapsedSeconds;
      if (_remainingCodeResendTime! < 0) {
        _remainingCodeResendTime = 0;
        _lastCodeSentTime = null;
        await _secureStorage.delete(key: 'last_2fa_code_sent');
        await _secureStorage.delete(key: 'remaining_2fa_code_time');
      }
    }
    String? remainingTime = await _secureStorage.read(key: 'remaining_2fa_code_time');
    if (remainingTime != null && _remainingCodeResendTime == null) {
      _remainingCodeResendTime = int.tryParse(remainingTime);
    }
    print('Loaded token: $_token, userRole: $_userRole, instructorStatus: $_instructorStatus, username: $_username, email: $_email, lastCodeSent: $_lastCodeSentTime, remainingCodeResendTime: $_remainingCodeResendTime');
    notifyListeners();
  }

  Future<void> loadUserDetails() async {
    if (_username != null) {
      try {
        final userData = await getUser(_username!);
        _email = userData['email'] as String?;
        await _secureStorage.write(key: 'user_email', value: _email);
        notifyListeners();
      } catch (e) {
        print('Error loading user details: $e');
      }
    }
  }

  Future<Map<String, dynamic>> login(String username, String password, BuildContext context) async {
    try {
      _username = username;
      print('Attempting login with username: $_username');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('Login response: $responseData');
        if (responseData.containsKey('accessToken')) {
          _token = responseData['accessToken'];
          await _secureStorage.write(key: 'auth_token', value: _token);
          print('Token set: $_token');

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

              if (userData.containsKey('email')) {
                _email = userData['email'].toString();
                await _secureStorage.write(key: 'user_email', value: _email);
              }

              if (userData['twoFactorEnabled'] == true) {
                print('2FA enabled, username: $_username, token: $_token');
                if (_shouldSendNewCode()) {
                  await sendTwoFactorCode(context);
                }
                String? code = await showTwoFactorCodeDialog(context, this);
                if (code != null) {
                  notifyListeners();
                  return responseData;
                } else {
                  throw Exception('2FA verification canceled');
                }
              }
            }
          }

          notifyListeners();
          await loadUserDetails();
          return responseData;
        } else {
          throw Exception('Invalid response format: missing access token');
        }
      } else if (response.statusCode == 401) {
        final errorBody = json.decode(response.body);
        print('401 Error: $errorBody');
        if (errorBody['message'] == '2FA required') {
          print('2FA required, attempting to send code for $_username');
          if (json.decode(response.body).containsKey('accessToken')) {
            _token = json.decode(response.body)['accessToken'];
            await _secureStorage.write(key: 'auth_token', value: _token);
          }
          if (_shouldSendNewCode()) {
            await sendTwoFactorCode(context);
          }
          String? code = await showTwoFactorCodeDialog(context, this);
          if (code != null) {
            return await login(username, password, context);
          } else {
            throw Exception('2FA verification canceled');
          }
        }
        throw Exception(errorBody['message'] ?? 'Invalid username or password');
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      print('Login error: $e');
      rethrow;
    }
  }

  bool _shouldSendNewCode() {
    if (_lastCodeSentTime == null) {
      return true;
    }
    final now = DateTime.now();
    final difference = now.difference(_lastCodeSentTime!).inSeconds;
    return difference >= _codeResendCooldown;
  }

  Future<void> updateRemainingCodeResendTime(int remainingSeconds) async {
    _remainingCodeResendTime = remainingSeconds;
    await _secureStorage.write(
      key: 'remaining_2fa_code_time',
      value: _remainingCodeResendTime.toString(),
    );
    notifyListeners();
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

      print('Validate reset code response for code $code: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        bool isValid = response.body.toLowerCase() == 'true';
        print('Parsed isValid for code $code: $isValid');
        return isValid;
      } else {
        throw Exception('Failed to validate reset code: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('Error validating reset code $code: $e');
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

  Future<void> logout(BuildContext context, {bool skipConfirmation = false}) async {
    bool isDialogActive = false;
    if (Navigator.of(context).canPop()) {
      isDialogActive = true;
    }

    bool confirmLogout = skipConfirmation;

    if (!skipConfirmation && !isDialogActive) {
      confirmLogout = await showDialog(
        context: context,
        barrierDismissible: false,
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
    }

    if (confirmLogout) {
      try {
        print('Clearing authentication state...');
        // Clear NotificationService state and disconnect WebSocket
        await _notificationService.clearStateAndDisconnect();
        _token = null;
        _userRole = null;
        _instructorStatus = null;
        _username = null;
        _email = null;
        _lastCodeSentTime = null;
        _remainingCodeResendTime = null;
        await _secureStorage.delete(key: 'auth_token');
        await _secureStorage.delete(key: 'user_role');
        await _secureStorage.delete(key: 'instructor_status');
        await _secureStorage.delete(key: 'user_name');
        await _secureStorage.delete(key: 'user_email');
        await _secureStorage.delete(key: 'last_2fa_code_sent');
        await _secureStorage.delete(key: 'remaining_2fa_code_time');
        notifyListeners();
        print('Navigating to login...');
        if (Navigator.of(context).mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
        } else {
          print('Navigator is not mounted, forcing navigation');
          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
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
      print('Dialog already active or logout canceled');
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
        return responseData['message'] as String;
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
        if (userData.containsKey('username') && userData['username'] != _username) {
          _username = userData['username'].toString();
          await _secureStorage.write(key: 'user_name', value: _username);
          notifyListeners();
        }
        if (userData.containsKey('email') && userData['email'] != _email) {
          _email = userData['email'].toString();
          await _secureStorage.write(key: 'user_email', value: _email);
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
        return responseData['message'] as String;
      } else {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to update password');
      }
    } catch (e) {
      throw Exception('Error updating password: $e');
    }
  }

  Future<void> enableTwoFactorAuthentication(BuildContext context) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/enable-2fa?username=$_username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Two-Factor Authentication enabled'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          if (_shouldSendNewCode()) {
            await sendTwoFactorCode(context);
          }
        } else {
          throw Exception(responseData['message'] ?? 'Failed to enable 2FA');
        }
      } else {
        throw Exception('Failed to enable 2FA: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling 2FA: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      rethrow;
    }
  }

  Future<void> disableTwoFactorAuthentication(BuildContext context) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/disable-2fa?username=$_username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Two-Factor Authentication disabled'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          throw Exception(responseData['message'] ?? 'Failed to disable 2FA');
        }
      } else {
        throw Exception('Failed to disable 2FA: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error disabling 2FA: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      rethrow;
    }
  }

  Future<String> sendTwoFactorCode(BuildContext context) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      print('Sending 2FA code request for user: $_username');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/send-2fa-code?username=$_username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _lastCodeSentTime = DateTime.now();
          _remainingCodeResendTime = _codeResendCooldown;
          await _secureStorage.write(key: 'last_2fa_code_sent', value: _lastCodeSentTime!.toIso8601String());
          await _secureStorage.write(key: 'remaining_2fa_code_time', value: _remainingCodeResendTime.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Two-Factor code sent to your email'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return 'Code sent';
        } else {
          throw Exception(responseData['message'] ?? 'Failed to send 2FA code');
        }
      } else {
        throw Exception('Failed to send 2FA code: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending 2FA code: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      rethrow;
    }
  }

  Future<bool> verifyTwoFactorCode(String code, BuildContext context) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token found');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-2fa-code?username=$_username&code=$code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _lastCodeSentTime = null;
          _remainingCodeResendTime = null;
          await _secureStorage.delete(key: 'last_2fa_code_sent');
          await _secureStorage.delete(key: 'remaining_2fa_code_time');
          return true;
        } else {
          throw Exception(responseData['message'] ?? 'Invalid or expired code');
        }
      } else {
        throw Exception('Failed to verify 2FA code: ${response.statusCode}');
      }
    } catch (e) {
      await _handleNetworkError(e);
      rethrow;
    }
  }

  Future<bool> isTwoFactorEnabled() async {
    try {
      final userData = await getUser(_username ?? '');
      return userData['twoFactorEnabled'] == true;
    } catch (e) {
      print('Error checking 2FA status: $e');
      return false;
    }
  }
}