import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:front/constants/colors.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceView extends StatefulWidget {
  final int eventId;
  final String eventTitle;
  final bool isOnline;

  const AttendanceView({
    Key? key,
    required this.eventId,
    required this.eventTitle,
    required this.isOnline,
  }) : super(key: key);

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<void> _exportAttendance(BuildContext context) async {
    if (widget.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export is only available for in-person events')),
      );
      return;
    }
    try {
      final csvData = await _eventService.exportAttendance(widget.eventId);
      final directory = await getTemporaryDirectory();
      final safeEventTitle = widget.eventTitle.replaceAll(RegExp(r'[^\w\s-]'), '_'); // Sanitize filename
      final path = '${directory.path}/${safeEventTitle}_attendance.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      // Share the file using share_plus
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        text: 'Attendance for ${widget.eventTitle}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance exported and ready to share')),
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
            onPressed: widget.isOnline ? null : () => _exportAttendance(context),
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
                title: Text(record.username.isEmpty ? 'Unknown' : record.username),
                subtitle: Text(
                  record.checkedIn ? 'Checked in' : 'Not checked in',
                ),
              );
            },
          );
        },
      ),
    );
  }
}