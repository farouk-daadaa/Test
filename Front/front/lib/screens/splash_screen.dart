import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _transform;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _handleStartup();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Reduced from 2500
    );

    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _transform = Tween<double>(
      begin: 30,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  Future<void> _handleStartup() async {
    try {
      // Reduced minimum splash screen duration
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loadToken();

      if (!mounted) return;

      final isLoggedIn = await authService.isLoggedIn();
      if (!mounted) return;

      // Start exit animation
      await _controller.reverse();

      if (!mounted) return;

      // Navigate based on auth state
      if (isLoggedIn) {
        final userRole = authService.userRole;
        switch (userRole) {
          case 'ADMIN':
            Navigator.pushReplacementNamed(context, '/admin-dashboard');
            break;
          case 'INSTRUCTOR':
            Navigator.pushReplacementNamed(context, '/instructor-dashboard');
            break;
          default:
            Navigator.pushReplacementNamed(context, '/home');
            break;
        }
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during startup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildAnimatedWave(isTop: true),
          _buildAnimatedWave(isTop: false),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _transform.value),
                child: Opacity(
                  opacity: _opacity.value,
                  child: Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.school_outlined,
                                size: 80,
                                color: AppColors.primary,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWave({required bool isTop}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: isTop ? 0 : null,
          bottom: isTop ? null : 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, isTop ? -_transform.value : _transform.value),
            child: Opacity(
              opacity: _opacity.value,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: WavePainter(
                  color: isTop ? AppColors.primary : AppColors.secondary,
                  isBottom: !isTop,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final bool isBottom;

  WavePainter({
    required this.color,
    this.isBottom = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8) // Increased from 0.4
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isBottom) {
      path.moveTo(0, size.height * 0.3);
      path.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.1,
        size.width * 0.5,
        size.height * 0.3,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.5,
        size.width,
        size.height * 0.3,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, size.height * 0.7);
      path.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.7,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.5,
        size.width,
        size.height * 0.7,
      );
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}