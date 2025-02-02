import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sections/footer_section.dart';
import '../services/auth_service.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  String _username = '';
  String _password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 48),
                    _buildHeader(),
                    SizedBox(height: 32),
                    _buildUsernameField(),
                    SizedBox(height: 16),
                    _buildPasswordField(),
                    SizedBox(height: 24),
                    _buildLoginButton(),
                    SizedBox(height: 16),
                    _buildForgotPasswordButton(),
                    SizedBox(height: 24),
                    _buildSignupOption(),
                  ],
                ),
              ),
            ),
            FooterSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.school, size: 64, color: AppTheme.primaryColor),
        SizedBox(height: 16),
        Text(
          'Welcome back',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        SizedBox(height: 8),
        Text(
          'Sign in to continue learning',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Username',
        prefixIcon: Icon(Icons.person),
      ),
      keyboardType: TextInputType.text,
      validator: (value) => value == null || value.isEmpty ? 'Please enter your username' : null,
      onSaved: (value) => _username = value!,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.primaryColor,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
      onSaved: (value) => _password = value!,
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
      child: _isLoading
          ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      )
          : Text('Sign In'),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ForgotPasswordPage()));
        },
        child: Text('Forgot Password?'),
      ),
    );
  }

  Widget _buildSignupOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?"),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/signup');
          },
          child: Text('Sign Up'),
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await _authService.login(_username, _password);

        if (response.containsKey('accessToken')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login successful!')));
          Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
        } else {
          throw Exception('Invalid credentials or unexpected response format');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
