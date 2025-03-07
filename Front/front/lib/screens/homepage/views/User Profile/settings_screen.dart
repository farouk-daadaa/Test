import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../constants/colors.dart';
import '../../../../services/auth_service.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String username;
  const SettingsScreen({super.key, required this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AuthService _authService;
  bool _isTwoFactorEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Defer loading 2FA status to after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTwoFactorStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize _authService here to ensure context is valid
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  Future<void> _loadTwoFactorStatus() async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = true);
    try {
      final status = await _authService.isTwoFactorEnabled();
      if (mounted) {
        setState(() => _isTwoFactorEnabled = status);
      }
    } catch (e) {
      print('Error loading 2FA status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading 2FA status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleTwoFactorAuthentication(bool newValue) async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = true);
    try {
      if (newValue) {
        await _authService.enableTwoFactorAuthentication(context); // Pass context
        if (mounted) {
          setState(() => _isTwoFactorEnabled = true);
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
        }
      } else {
        await _authService.disableTwoFactorAuthentication(context); // Pass context
        if (mounted) {
          setState(() => _isTwoFactorEnabled = false);
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
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTwoFactorEnabled = !newValue); // Revert on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling 2FA: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(username: widget.username),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final BuildContext dialogContext = context;

    showDialog(
      context: dialogContext,
      builder: (BuildContext innerContext) {
        return AlertDialog(
          title: const Text(
            'Confirm Account Deletion',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(innerContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(innerContext).pop(); // Close dialog
                try {
                  print('Attempting to delete account for ${widget.username}...');
                  final message = await _authService.deleteAccount(widget.username);
                  if (mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.fixed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    print('Attempting logout after account deletion...');
                    await _authService.logout(dialogContext);
                    if (mounted) {
                      print('Forcing navigation to /login after logout');
                      Navigator.pushReplacementNamed(dialogContext, '/login');
                    }
                  }
                } catch (e) {
                  print('Delete account error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.fixed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color textColor = Colors.black87,
    Widget? trailing,
    bool isSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ),
      trailing: isSwitch
          ? Switch(
        value: switchValue,
        onChanged: _isLoading ? null : onSwitchChanged,
        activeColor: AppColors.primary,
      )
          : trailing ?? const Icon(Icons.chevron_right, color: AppColors.primary, size: 26),
      onTap: isSwitch ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _navigateToChangePassword(),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                endIndent: 24,
                color: Colors.grey,
              ),
              _buildSettingsItem(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage your notification preferences',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification settings coming soon!'),
                      backgroundColor: Colors.grey,
                      behavior: SnackBarBehavior.fixed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
              const Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                endIndent: 24,
                color: Colors.grey,
              ),
              _buildSettingsItem(
                icon: Icons.security,
                title: 'Two-Factor Authentication',
                subtitle: 'Enable or disable 2FA for added security',
                onTap: () {},
                isSwitch: true,
                switchValue: _isTwoFactorEnabled,
                onSwitchChanged: (newValue) => _toggleTwoFactorAuthentication(newValue),
                trailing: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.grey),
                )
                    : null,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                endIndent: 24,
                color: Colors.grey,
              ),
              _buildSettingsItem(
                icon: Icons.delete,
                title: 'Delete Account',
                subtitle: 'Permanently remove your account',
                onTap: () => _deleteAccount(),
                iconColor: Colors.red,
                textColor: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}