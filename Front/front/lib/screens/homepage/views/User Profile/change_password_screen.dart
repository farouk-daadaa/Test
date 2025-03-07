import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../constants/colors.dart';
import '../../../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String username;
  const ChangePasswordScreen({super.key, required this.username});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late AuthService _authService;
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final passwordData = {
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        };

        final response = await _authService.updatePassword(widget.username, passwordData);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.toString()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update password: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 32),
                  _buildPasswordFields(),
                  const SizedBox(height: 40),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outlined,
          size: 48,
          color: AppColors.primary,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),
        const SizedBox(height: 16),
        Text(
          'Create a new password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'Your new password must be different from previous passwords and at least 8 characters long.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        _buildPasswordField(
          controller: _currentPasswordController,
          label: 'Current Password',
          hint: 'Enter your current password',
          obscureText: _obscureCurrentPassword,
          onToggleVisibility: () {
            setState(() {
              _obscureCurrentPassword = !_obscureCurrentPassword;
            });
          },
          validator: (value) => value?.isEmpty ?? true ? 'Enter current password' : null,
        ),
        const SizedBox(height: 20),
        _buildPasswordField(
          controller: _newPasswordController,
          label: 'New Password',
          hint: 'Enter your new password',
          obscureText: _obscureNewPassword,
          onToggleVisibility: () {
            setState(() {
              _obscureNewPassword = !_obscureNewPassword;
            });
          },
          validator: (value) => (value?.length ?? 0) < 8 ? 'Password must be at least 8 characters' : null,
        ),
        const SizedBox(height: 20),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          hint: 'Confirm your new password',
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
          validator: (value) => value != _newPasswordController.text ? 'Passwords do not match' : null,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: onToggleVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            obscureText: obscureText,
            validator: validator,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _savePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          'Update Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}