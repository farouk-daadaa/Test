import 'package:flutter/material.dart';
import '../../services/course_service.dart';

class PaymentPage extends StatelessWidget {
  final CourseDTO course;

  const PaymentPage({Key? key, required this.course}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Price: \$${course.price}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Handle payment logic here
                // After successful payment, enroll the user
                _completePayment(context);
              },
              child: const Text('Complete Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _completePayment(BuildContext context) async {
    // Simulate a payment process
    await Future.delayed(const Duration(seconds: 2));

    // After successful payment, enroll the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful! You are now enrolled.'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back to the course details page
    Navigator.pop(context);
  }
}