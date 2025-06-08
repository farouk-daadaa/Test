import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordVisibility = ValueNotifier<bool>(false);
  final _confirmPasswordVisibility = ValueNotifier<bool>(false);
  bool _isLoading = false;
  bool _isCodeValidated = false;
  bool _isCodeInvalid = false;
  String? _codeError;
  bool _hasVibratedForCurrentAttempt = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordVisibility.dispose();
    _confirmPasswordVisibility.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }

    List<String> requirements = [];
    if (value.length < 8) requirements.add('At least 8 characters');
    if (!value.contains(RegExp(r'[A-Z]'))) requirements.add('One uppercase letter');
    if (!value.contains(RegExp(r'[0-9]'))) requirements.add('One number');
    if (!value.contains(RegExp(r'[!@#\$&*~]'))) {
      requirements.add('One special character (!, @, #, \$, &, *, ~)');
    }

    return requirements.isNotEmpty
        ? 'Password must contain:\n${requirements.map((r) => '• $r').join('\n')}'
        : null;
  }
  @override
  void initState() {
    super.initState();
    _isCodeValidated = false;
    _isCodeInvalid = false;
    _codeError = null;
    _hasVibratedForCurrentAttempt = false;
    _codeController.clear();
    print('Initialized ResetPasswordScreen state');
  }

  @override
  Widget build(BuildContext context) {
    print('Building ResetPasswordScreen, _isCodeValidated: $_isCodeValidated, _isCodeInvalid: $_isCodeInvalid');
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
        backgroundColor: Color(0xFFDB2777),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the 6-digit reset code sent to your email.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Reset Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isCodeInvalid ? Colors.red : Colors.grey,
                          width: _isCodeInvalid ? 2 : 1,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.lock_reset,
                        color: _isCodeInvalid ? Colors.red : Color(0xFFDB2777),
                      ),
                      errorText: _codeError,
                      errorStyle: TextStyle(color: Colors.red),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter reset code';
                      if (value.length != 6) return 'Must be 6 digits';
                      return null;
                    },
                    onChanged: (value) {
                      if (_isCodeInvalid) {
                        setState(() {
                          _isCodeInvalid = false;
                          _codeError = null;
                          _hasVibratedForCurrentAttempt = false;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  if (!_isCodeValidated)
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _validateCode(authService),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2),
                      )
                          : Text('Validate Code', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDB2777),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  if (_isCodeValidated) ...[
                    SizedBox(height: 24),
                    ValueListenableBuilder<bool>(
                      valueListenable: _passwordVisibility,
                      builder: (context, isVisible, _) => TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock, color: Color(0xFFDB2777)),
                          suffixIcon: IconButton(
                            icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => _passwordVisibility.value = !isVisible,
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        obscureText: !isVisible,
                        validator: _validatePassword,
                      ),
                    ),
                    SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _confirmPasswordVisibility,
                      builder: (context, isVisible, _) => TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFDB2777)),
                          suffixIcon: IconButton(
                            icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => _confirmPasswordVisibility.value = !isVisible,
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        obscureText: !isVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Confirm your password';
                          if (value != _passwordController.text) return 'Passwords don\'t match';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _submitForm(authService),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2),
                      )
                          : Text('Reset Password', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDB2777),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _validateCode(AuthService authService) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isCodeValidated = false; // Reset state
      _isCodeInvalid = false;
      _codeError = null;
      _hasVibratedForCurrentAttempt = false; // Reset vibration flag
    });

    try {
      final isValid = await authService.validateResetCode(_codeController.text);
      print('Code validation result for ${_codeController.text}: $isValid');

      if (isValid) {
        setState(() {
          _isCodeValidated = true;
          _isCodeInvalid = false;
          _codeError = null;
        });
      } else {
        setState(() {
          _isCodeInvalid = true;
          _codeError = 'Invalid or expired reset code. Please request a new one.';
        });

        if (!(_hasVibratedForCurrentAttempt) && (await Vibration.hasVibrator() ?? false)) {
          Vibration.vibrate(duration: 500);
          _hasVibratedForCurrentAttempt = true;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid reset code. Please request a new one.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            print('Navigating to /forgot-password due to invalid code');
            _codeController.clear();
            Navigator.pushReplacementNamed(context, '/forgot-password');
          }
        });
      }
    } catch (e) {
      print('Error in validateCode: $e');
      setState(() {
        _isCodeInvalid = true;
        _codeError = 'Error validating reset code: ${e.toString()}';
      });

      if (!(_hasVibratedForCurrentAttempt) && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 500);
        _hasVibratedForCurrentAttempt = true;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error validating code. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          print('Navigating to /forgot-password due to error');
          _codeController.clear();
          Navigator.pushReplacementNamed(context, '/forgot-password');
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _submitForm(AuthService authService) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await authService.resetPassword(
        _codeController.text,
        _passwordController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_parseError(e)),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _parseError(dynamic error) {
    if (error is http.Response) {
      try {
        final errorJson = jsonDecode(error.body);
        return errorJson['message'] ?? 'Unknown error occurred';
      } catch (_) {
        return 'Server error: ${error.statusCode}';
      }
    }
    return error.toString().replaceAll('Exception: ', '');
  }
}