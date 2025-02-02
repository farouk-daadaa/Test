import 'package:flutter/material.dart';
import 'course_card.dart';

class CoursesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Updated header row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Available trainings',
                    style: TextStyle(
                      fontSize: 20, // Smaller font size
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDB2777),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View all',  // Shortened text
                    style: TextStyle(
                      color: Color(0xFFDB2777),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CourseCard(
                  title: 'Create apps for Android',
                  description: 'Android is the most popular operating system on smartphones and tablets. The applications being written in Java, you must know this language',
                  imageUrl: 'https://lh3.googleusercontent.com/LYUDWiiqyTSiwzbPsJnYhfTzA3kUAoYgRy_1mpKTZOuLtpaMTaNdPKm8Xesm5mxA_zUSIGy6RO4PxhUnIDgTgbmroxgVpudnc0XKWW0cByZXppI2WGo',
                  duration: '8',
                  enrollments: 222,
                  backgroundColor: Color(0xFFE5F3F2),
                ),
                SizedBox(width: 16),
                CourseCard(
                  title: 'iOS Development',
                  description: 'Learn to build beautiful and responsive iOS applications using Swift and SwiftUI framework.',
                  imageUrl: 'https://media.licdn.com/dms/image/v2/D4D12AQHg7EszdsV7VA/article-cover_image-shrink_600_2000/article-cover_image-shrink_600_2000/0/1698382937727?e=2147483647&v=beta&t=WvbWbmI9Cd-KlDgfgQSuZp1qx0LaoUXyoJwVaCxLi84',
                  duration: '10',
                  enrollments: 189,
                  backgroundColor: Color(0xFFF3E8FF),
                ),
                SizedBox(width: 16),
                CourseCard(
                  title: 'Python Programming',
                  description: 'Master Python programming from basics to advanced concepts including data science and machine learning.',
                  imageUrl: 'https://devblogs.microsoft.com/python/wp-content/uploads/sites/12/2018/08/pythonfeature.png',
                  duration: '12',
                  enrollments: 345,
                  backgroundColor: Color(0xFFDBEAFE),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}