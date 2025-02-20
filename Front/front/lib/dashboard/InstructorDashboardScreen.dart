import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class InstructorDashboardScreen extends StatelessWidget {
  const InstructorDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('instructor Dashboard'),
        backgroundColor: Color(0xFFDB2777),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.logout(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'This is the instructor Dashboard Screen',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
    );
  }
}