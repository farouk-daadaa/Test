import 'package:flutter/material.dart';

class CourseCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String duration;
  final int enrollments;
  final Color backgroundColor;

  const CourseCard({
    Key? key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.duration,
    required this.enrollments,
    this.backgroundColor = const Color(0xFFE5F3F2),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Image Container
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    imageUrl,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                if (enrollments > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '($enrollments)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Course Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                // Course Features
                _buildFeatureRow(Icons.assignment_outlined, 'Training & Assessment'),
                SizedBox(height: 8),
                _buildFeatureRow(Icons.card_membership_outlined, 'Achievement Certificate'),
                SizedBox(height: 8),
                _buildFeatureRow(Icons.calendar_today_outlined, '$duration weeks'),
                SizedBox(height: 16),
                // Yellow Line
                Container(
                  height: 1,
                  color: Color(0xFFFCA311), // Yellow brand color
                ),
                SizedBox(height: 16),
                // Add Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFDB2777),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward, color: Colors.white), // Change icon here
                      onPressed: () {
                        // Add your onPressed logic here
                      },
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

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Color(0xFFDB2777), // Pink accent color
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}