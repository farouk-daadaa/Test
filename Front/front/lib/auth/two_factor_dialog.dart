import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

Future<String?> showTwoFactorCodeDialog(BuildContext context, AuthService authService) async {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCountdown = authService.remainingCodeResendTime ?? 0; // Initialize with remaining time
  Timer? _countdownTimer;
  String? _errorMessage;

  return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Start the countdown timer if not already running
            void startCountdownTimer() {
              _countdownTimer?.cancel();
              _countdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                    setState(() {
                      if (_resendCountdown > 0) {
                        _resendCountdown--;
                        authService.updateRemainingCodeResendTime(
                            _resendCountdown); // Update AuthService
                      } else {
                        timer.cancel();
                      }
                    });
                  });
            }

            // Format the countdown time as mm:ss
            String formatCountdown() {
              int minutes = _resendCountdown ~/ 60;
              int seconds = _resendCountdown % 60;
              return '${minutes.toString().padLeft(2, '0')}:${seconds.toString()
                  .padLeft(2, '0')}';
            }

            // Handle resend code
            Future<void> handleResendCode() async {
              if (_resendCountdown > 0) return;

              setState(() {
                _isResending = true;
                _errorMessage = null;
              });
              try {
                await authService.sendTwoFactorCode(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'New code sent. Please check your email.'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  setState(() {
                    _resendCountdown = 300; // Reset to 5 minutes after resend
                    startCountdownTimer();
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Error resending code: $e'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } finally {
                setState(() => _isResending = false);
              }
            }

            // Handle verification
            Future<void> handleVerify() async {
              if (_codeController.text.length != 6) {
                setState(() {
                  _errorMessage = 'Please enter a 6-digit code';
                });
                return;
              }

              setState(() {
                _isVerifying = true;
                _errorMessage = null;
              });

              try {
                bool isValid = await authService.verifyTwoFactorCode(
                    _codeController.text, context);
                if (isValid) {
                  Navigator.of(context).pop(_codeController.text);
                } else {
                  setState(() {
                    _errorMessage = 'Invalid or expired code';
                    _codeController.clear();
                  });
                }
              } catch (e) {
                setState(() {
                  _errorMessage = e.toString().replaceFirst('Exception: ', '');
                  _codeController.clear();
                });
              } finally {
                setState(() => _isVerifying = false);
              }
            }

            // Initialize the countdown timer on first build if there's remaining time
            if (_countdownTimer == null && _resendCountdown > 0) {
              startCountdownTimer();
            }

            // Clean up the timer when the dialog is closed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                _countdownTimer?.cancel();
              }
            });

            // Define the Pinput default theme
            final defaultPinTheme = PinTheme(
              width: 45,
              height: 55,
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildInfoBox(),
                      const SizedBox(height: 24),
                      _buildOtpInput(
                          _codeController, defaultPinTheme, _errorMessage),
                      const SizedBox(height: 16),
                      _buildResendSection(
                          _resendCountdown, formatCountdown(), _isResending,
                          handleResendCode),
                      const SizedBox(height: 24),
                      _buildActions(_isVerifying, handleVerify, context),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      });

      }

      Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.security_rounded,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Two-Factor Authentication',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 4),
              Text(
                'Verify your identity',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'A 2FA code has been sent to your registered email. Please enter it below.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildOtpInput(TextEditingController controller, PinTheme defaultPinTheme, String? errorMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
        const SizedBox(height: 16),
        Pinput(
          controller: controller,
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
          submittedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary),
            ),
          ),
          errorPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: Colors.red),
            ),
          ),
          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
          showCursor: true,
          cursor: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                width: 22,
                height: 2,
                color: AppColors.primary,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResendSection(int countdown, String formattedTime, bool isResending, VoidCallback onResend) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          countdown > 0
              ? 'Resend code in $formattedTime'
              : 'Didn\'t receive the code?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        TextButton.icon(
          onPressed: countdown > 0 || isResending ? null : onResend,
          icon: isResending
              ? SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
              : Icon(
            Icons.refresh,
            size: 16,
            color: countdown > 0 ? Colors.grey : AppColors.primary,
          ),
          label: Text(
            'Resend',
            style: TextStyle(
              color: countdown > 0 ? Colors.grey : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: countdown > 0 ? Colors.grey[100] : AppColors.primary.withOpacity(0.1),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 300.ms);
  }

  Widget _buildActions(bool isVerifying, VoidCallback onVerify, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isVerifying ? null : onVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isVerifying
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Verify',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 300.ms),
      ],
    );
  }