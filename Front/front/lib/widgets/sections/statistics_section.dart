import 'package:flutter/material.dart';

class StatisticsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Images Column
          Column(
            children: [
              _buildImage('assets/images/teacher.png'),
              SizedBox(height: 16),
              _buildImage('assets/images/student.png'),
            ],
          ),

          SizedBox(height: 32),

          // Heading and Description
          Text(
            'We are here to help',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDB2777),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Become who you want to be with The Bridge.\nChoose your own career path and earn an online degree with hands-on projects and weekly one-on-one mentoring sessions with a dedicated professional in your field.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),

          // Statistics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatisticCard(
                    'Enrolled Students',
                    '3,800+',
                    Icons.people_outline,
                    constraints.maxWidth > 600 ? (constraints.maxWidth - 48) / 3 : (constraints.maxWidth - 32) / 2,
                  ),
                  _buildStatisticCard(
                    'Online Courses',
                    '500+',
                    Icons.school_outlined,
                    constraints.maxWidth > 600 ? (constraints.maxWidth - 48) / 3 : (constraints.maxWidth - 32) / 2,
                  ),
                  _buildStatisticCard(
                    'Trainers',
                    '187+',
                    Icons.person_outline,
                    constraints.maxWidth > 600 ? (constraints.maxWidth - 48) / 3 : (constraints.maxWidth - 32) / 2,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFCA311),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // 16-2 to account for border
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildStatisticCard(String label, String number, IconData icon, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFDB2777).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFFDB2777),
              size: 24,
            ),
          ),
          SizedBox(height: 12),
          Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFDB2777),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}