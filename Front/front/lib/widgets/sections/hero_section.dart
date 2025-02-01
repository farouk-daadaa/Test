import 'package:flutter/material.dart';

class HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Color(0xFFFDF2F8),
      ),
      child: Column(
        children: [
          // Hero Image
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset(
              'assets/images/hero_image.png',
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 32),

          // Hero Text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Color(0xFF1F2937),
                    ),
                    children: [
                      TextSpan(text: 'Improve '),
                      TextSpan(
                        text: 'your skills ',
                        style: TextStyle(color: Color(0xFFDB2777)),
                      ),
                      TextSpan(text: 'on\n'),

                      TextSpan(text: 'your own to prepare for a\n'),

                      TextSpan(
                        text: 'better future',
                        style: TextStyle(color: Color(0xFFDB2777)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Description
                Text(
                  'The Bridge, allows any student, staff or professional to acquire relevant online training to embark on the future employment opportunity with guaranteed follow-up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24),

                // Register Button
                ElevatedButton(
                  onPressed: () {
                    // Add registration logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDB2777),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Register now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}