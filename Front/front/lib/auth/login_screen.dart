import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordVisibility = ValueNotifier<bool>(false);
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  if (_errorMessage != null)
                    _buildErrorMessage(),
                  _buildUsernameField(),
                  const SizedBox(height: 24),
                  _buildPasswordField(),
                  const SizedBox(height: 24),
                  _buildForgotPasswordButton(),
                  const SizedBox(height: 32),
                  _buildLoginButton(authService),
                  const SizedBox(height: 24),
                  _buildSignupOption(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.school, size: 64, color: Color(0xFFDB2777)),
        SizedBox(height: 16),
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sign in to continue learning',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
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

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: 'Username',
        prefixIcon: Icon(Icons.person, color: Color(0xFFDB2777)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFDB2777)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      validator: (value) =>
      value == null || value.isEmpty
          ? 'Please enter your username'
          : null,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFDB2777)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          obscureText: !isVisible,
          validator: (value) =>
          value == null || value.isEmpty
              ? 'Please enter your password'
              : null,
          onChanged: (_) => setState(() => _errorMessage = null),
        );
      },
    );
  }

  Widget _buildLoginButton(AuthService authService) {
    return ElevatedButton(
      onPressed: _isLoading ? null : () => _submitForm(authService),
      child: _isLoading
          ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      )
          : Text(
        'Sign In',
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

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, '/forgot-password');
        },
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: Color(0xFFDB2777),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSignupOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/signup');
          },
          child: Text(
            'Sign up',
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
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final response = await authService.login(
          _usernameController.text,
          _passwordController.text,
        );

        if (response.containsKey('accessToken')) {
          final userRole = authService.userRole;
          final instructorStatus = authService.instructorStatus;

          if (userRole == 'ADMIN') {
            Navigator.of(context).pushReplacementNamed('/admin-dashboard');
          } else if (userRole == 'INSTRUCTOR') {
            if (instructorStatus == 'APPROVED') {
              Navigator.of(context).pushReplacementNamed(
                  '/instructor-dashboard');
            } else {
              Navigator.of(context).pushReplacementNamed('/pending-approval');
            }
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          setState(() => _errorMessage = 'Invalid response format from server');
        }
      } catch (e) {
        if (e.toString().contains('403')) {
          setState(() => _errorMessage = 'Your account is not approved yet.');
        } else {
          setState(() {
            _errorMessage = e is Exception
                ? e.toString().split(': ')[1]
                : 'An unexpected error occurred';
          });
        }
      }
    }
  }
}