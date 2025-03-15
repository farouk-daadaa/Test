import 'package:flutter/material.dart';

class MySessionsView extends StatelessWidget {
  const MySessionsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event,
              size: 64,
              color: Color(0xFFDB2777),
            ),
            const SizedBox(height: 16),
            Text(
              'My Sessions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDB2777),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is a placeholder for the My Sessions view.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}