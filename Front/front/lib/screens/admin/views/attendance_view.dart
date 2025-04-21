import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:front/constants/colors.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';

class AttendanceView extends StatefulWidget {
  final int eventId;
  final String eventTitle;

  const AttendanceView({Key? key, required this.eventId, required this.eventTitle})
      : super(key: key);

  @override
  _AttendanceViewState createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  Future<List<AttendanceDTO>>? _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _initializeAttendance();
  }

  Future<void> _initializeAttendance() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      _eventService.setToken(token);
      setState(() {
        _attendanceFuture = _eventService.getAttendance(widget.eventId);
      });
    } else {
      // No token, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<void> _exportAttendance(BuildContext context) async {
    try {
      final csvData = await _eventService.exportAttendance(widget.eventId);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/${widget.eventTitle}_attendance.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance exported to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting attendance: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventTitle} Attendance'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _exportAttendance(context),
            tooltip: 'Export as CSV',
          ),
        ],
      ),
      body: _attendanceFuture == null
          ? Center(child: CircularProgressIndicator())
          : FutureBuilder<List<AttendanceDTO>>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Handle 401 Unauthorized specifically
            if (snapshot.error.toString().contains('Unauthorized')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<AuthService>(context, listen: false).logout(context);
                Navigator.of(context).pushReplacementNamed('/login');
              });
              return Center(child: Text('Redirecting to login...'));
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No attendance records found'));
          }

          final attendance = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: attendance.length,
            itemBuilder: (context, index) {
              final record = attendance[index];
              return ListTile(
                title: Text(record.username),
                subtitle: Text('${record.email} • ${record.checkInTime.toString()}'),
              );
            },
          );
        },
      ),
    );
  }
}