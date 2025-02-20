import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
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

    if (value.length < 8) {
      requirements.add('At least 8 characters');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      requirements.add('One uppercase letter');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      requirements.add('One number');
    }
    if (!value.contains(RegExp(r'[!@#\$&*~]'))) {
      requirements.add('One special character (!, @, #, \$, &, *, ~)');
    }

    if (requirements.isNotEmpty) {
      return 'Password must meet the following:\n${requirements.map((r) => '• $r').join('\n')}';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isCodeInvalid ? Colors.red : Colors.grey,
                          width: _isCodeInvalid ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isCodeInvalid ? Colors.red : Color(0xFFDB2777),
                          width: 2,
                        ),
                      ),
                      errorText: _codeError,
                      errorStyle: TextStyle(color: Colors.red),
                      prefixIcon: Icon(
                        Icons.lock_reset,
                        color: _isCodeInvalid ? Colors.red : Color(0xFFDB2777),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the reset code';
                      }
                      if (value.length != 6) {
                        return 'Reset code must be 6 digits';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Reset the invalid state when user starts typing again
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : Text(
                        'Validate Code',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDB2777),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (_isCodeValidated) ...[
                    SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _passwordVisibility,
                      builder: (context, isVisible, child) {
                        return TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock, color: Color(0xFFDB2777)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isVisible ? Icons.visibility_off : Icons.visibility,
                                color: Color(0xFFDB2777),
                              ),
                              onPressed: () => _passwordVisibility.value = !isVisible,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: !isVisible,
                          validator: _validatePassword,
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: _confirmPasswordVisibility,
                      builder: (context, isVisible, child) {
                        return TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFDB2777)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isVisible ? Icons.visibility_off : Icons.visibility,
                                color: Color(0xFFDB2777),
                              ),
                              onPressed: () => _confirmPasswordVisibility.value = !isVisible,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: !isVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your new password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _submitForm(authService),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : Text(
                        'Reset Password',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDB2777),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  void _validateCode(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _isCodeInvalid = false;
      });

      try {
        bool isValid = await authService.validateResetCode(_codeController.text);
        if (isValid) {
          setState(() {
            _isCodeValidated = true;
            _codeError = null;
            _isCodeInvalid = false;
            _hasVibratedForCurrentAttempt = false;
          });
        } else {
          setState(() {
            _codeError = 'Invalid reset code. Please try again.';
            _isCodeInvalid = true;
          });

          // Only vibrate if we haven't vibrated for this attempt yet
          if (!_hasVibratedForCurrentAttempt) {
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 100);
              _hasVibratedForCurrentAttempt = true;
            }
          }
        }
      } catch (e) {
        setState(() {
          _codeError = 'Failed to validate code: ${e.toString()}';
          _isCodeInvalid = true;
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _submitForm(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await authService.resetPassword(_codeController.text, _passwordController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset successful. Please login with your new password.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}