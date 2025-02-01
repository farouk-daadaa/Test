import 'package:flutter/material.dart';

class FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 300,
                height: 300,
                child: Image.asset(
                  'assets/images/coach.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You need more than just studying',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDB2777),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Get greater support from a professional coach with a membership service that really helps you build your potential and career with some access and more premium features that you shouldn\'t pass.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 32),
                _buildFeatureItem(
                  icon: Icons.code_rounded,
                  text: 'Gain practical experience with our projects supported in Python & JavaScript applications development using your favorite browser.',
                ),
                _buildFeatureItem(
                  icon: Icons.school_rounded,
                  text: 'If you are looking to start a new career, The Bridge Professional Certificate helps you get up and running.',
                ),
                _buildFeatureItem(
                  icon: Icons.play_circle_rounded,
                  text: 'Our courses include recorded course videos, homework assignments and community discussions.',
                ),
                _buildFeatureItem(
                  icon: Icons.verified_user_rounded,
                  text: 'Register for our Specializations to master a specific professional skill.',
                ),
                SizedBox(height: 40),
                // Buttons Section
                Row(
                  mainAxisSize: MainAxisSize.min, // Ensure buttons take only needed space
                  children: [
                    _buildButton(
                      text: 'Learn more',
                      isPrimary: false,
                      onPressed: () {},
                    ),
                    SizedBox(width: 16),
                    _buildButton(
                      text: 'Ask for a coach',
                      isPrimary: true,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFCA311).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Color(0xFFFCA311),
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return IntrinsicWidth( // Ensure button width adapts to content
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: isPrimary ? Colors.white : Color(0xFFDB2777),
          backgroundColor: isPrimary ? Color(0xFFDB2777) : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Adjust padding for full text visibility
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Color(0xFFDB2777),
              width: isPrimary ? 0 : 1,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
