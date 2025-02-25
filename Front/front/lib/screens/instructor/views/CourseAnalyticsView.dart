import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CourseAnalyticsView extends StatelessWidget {
  const CourseAnalyticsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFFDB2777), size: 32),
              const SizedBox(width: 12),
              Text(
                'Course Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDB2777),
                ),
              ),
            ],
          ).animate().fadeIn().slideX(),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analytics Coming Soon',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your course performance and student engagement',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ).animate()
                  .fadeIn(delay: 300.milliseconds)
                  .slideY(begin: 0.2, end: 0),
            ),
          ),
        ],
      ),
    );
  }
}