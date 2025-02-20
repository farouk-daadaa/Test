import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

enum Gender {
  MALE,
  FEMALE
}

class InstructorSignupScreen extends StatefulWidget {
  const InstructorSignupScreen({Key? key}) : super(key: key);

  @override
  _InstructorSignupScreenState createState() => _InstructorSignupScreenState();
}

class _InstructorSignupScreenState extends State<InstructorSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cvController = TextEditingController();
  final _linkedinLinkController = TextEditingController();
  final _passwordVisibility = ValueNotifier<bool>(false);
  Gender? _selectedGender;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _cvController.dispose();
    _linkedinLinkController.dispose();
    _passwordVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Sign Up'),
        backgroundColor: Color(0xFFDB2777),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Color(0xFFDB2777),
                padding: EdgeInsets.only(bottom: 32.0),
                child: _buildHeader(),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        _buildErrorMessage(),
                      _buildInstructorInfo(),
                      const SizedBox(height: 24),
                      _buildNameFields(),
                      const SizedBox(height: 16),
                      _buildUsernameField(),
                      const SizedBox(height: 16),
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildPhoneField(),
                      const SizedBox(height: 16),
                      _buildGenderSelection(),
                      const SizedBox(height: 16),
                      _buildCVField(),
                      const SizedBox(height: 16),
                      _buildLinkedinField(),
                      const SizedBox(height: 32),
                      _buildSignupButton(authService),
                      const SizedBox(height: 16),
                      _buildLoginOption(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.school,
          size: 64,
          color: Colors.white,
        ),
        SizedBox(height: 16),
        Text(
          'Become an Instructor',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Your application will be reviewed by our admin team\n'
                '• You will receive an email notification about your status\n'
                '• Make sure to provide accurate contact information',
            style: TextStyle(
              color: Colors.blue[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFFDB2777)),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your first name' : null,
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFFDB2777)),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Please enter your last name' : null,
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: 'Username',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.account_circle, color: Color(0xFFDB2777)),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.email, color: Color(0xFFDB2777)),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an email address';
        }
        if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildPasswordField() {
    return ValueListenableBuilder<bool>(
      valueListenable: _passwordVisibility,
      builder: (context, isVisible, child) {
        return TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters long';
            }
            return null;
          },
          onChanged: (_) => setState(() => _errorMessage = null),
        );
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.phone, color: Color(0xFFDB2777)),
        hintText: '+1234567890',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        if (!RegExp(r'^\+?[1-9][0-9]{7,14}$').hasMatch(value)) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildGenderSelection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gender',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: RadioListTile<Gender>(
                  title: Text('Male'),
                  value: Gender.MALE,
                  groupValue: _selectedGender,
                  onChanged: (Gender? value) {
                    setState(() {
                      _selectedGender = value;
                      _errorMessage = null;
                    });
                  },
                  activeColor: Color(0xFFDB2777),
                ),
              ),
              Expanded(
                child: RadioListTile<Gender>(
                  title: Text('Female'),
                  value: Gender.FEMALE,
                  groupValue: _selectedGender,
                  onChanged: (Gender? value) {
                    setState(() {
                      _selectedGender = value;
                      _errorMessage = null;
                    });
                  },
                  activeColor: Color(0xFFDB2777),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCVField() {
    return TextFormField(
      controller: _cvController,
      decoration: InputDecoration(
        labelText: 'CV/Resume Link',
        helperText: 'Provide a link to your CV (Google Drive, Dropbox, etc.)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.description, color: Color(0xFFDB2777)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please provide a link to your CV';
        }
        if (!Uri.parse(value).isAbsolute) {
          return 'Please enter a valid URL';
        }
        return null;
      },
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildLinkedinField() {
    return TextFormField(
      controller: _linkedinLinkController,
      decoration: InputDecoration(
        labelText: 'LinkedIn Profile',
        helperText: 'Example: https://linkedin.com/in/your-profile',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(Icons.link, color: Color(0xFFDB2777)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your LinkedIn profile URL';
        }
        if (!value.toLowerCase().contains('linkedin.com/')) {
          return 'Please enter a valid LinkedIn URL';
        }
        return null;
      },
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildSignupButton(AuthService authService) {
    return ElevatedButton(
      onPressed: _isLoading ? null : () => _submitForm(authService),
      child: _isLoading
          ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      )
          : Text(
        'Submit Application',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFDB2777),
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildLoginOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account?",
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
          child: Text(
            'Sign In',
            style: TextStyle(
              color: Color(0xFFDB2777),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _submitForm(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      // Validate gender selection
      if (_selectedGender == null) {
        setState(() => _errorMessage = 'Please select your gender');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Prepare user data
        final userData = {
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'phone': _phoneController.text,
          'cv': _cvController.text,
          'linkedinLink': _linkedinLinkController.text,
          'gender': _selectedGender.toString().split('.').last,
        };

        // Submit to backend
        await authService.registerInstructor(userData);

        // Check if widget is still mounted
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Application submitted! You will receive an email once reviewed.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Delay navigation to allow seeing the success message
        await Future.delayed(const Duration(seconds: 2));

        // Check mounted again before navigation
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');

      } catch (e) {
        // Handle errors
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _parseErrorMessage(e);
        });

        // Log the error for debugging
        debugPrint('Registration error: ${e.toString()}');
      }
    }
  }

  String _parseErrorMessage(dynamic error) {
    if (error is http.Response) { // Add 'http.' prefix
      try {
        final errorJson = jsonDecode(error.body);
        return errorJson['message'] ?? 'Registration failed';
      } catch (_) {
        return 'Unexpected server response';
      }
    }
    if (error is String) return error;
    return error.toString().replaceAll('Exception: ', '');
  }

// Helper method to build info points in the success dialog
  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Color(0xFFDB2777),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}