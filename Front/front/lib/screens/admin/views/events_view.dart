import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:front/screens/admin/views/create_edit_event_dialog.dart';
import 'package:front/screens/admin/views/attendance_view.dart';
import 'package:front/screens/admin/views/qr_scanner_view.dart';
import 'package:front/constants/colors.dart';

class EventsView extends StatefulWidget {
  const EventsView({Key? key}) : super(key: key);

  @override
  _EventsViewState createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  Future<List<EventDTO>>? _eventsFuture;

  @override
  void initState() {
    super.initState();
    _initializeEvents();
  }

  Future<void> _initializeEvents() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      _eventService.setToken(token);
      setState(() {
        _eventsFuture = _eventService.getEvents();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCreateEditDialog(context),
        child: Icon(Icons.add),
      ),
      body: _eventsFuture == null
          ? Center(child: CircularProgressIndicator())
          : FutureBuilder<List<EventDTO>>(
        future: _eventsFuture,
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
            return Center(child: Text('No events found'));
          }

          final events = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    event.title,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${event.getFormattedDate()} • ${event.isOnline ? 'Online' : 'In-Person'} • ${event.status}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value, event),
                    itemBuilder: (context) {
                      final items = [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                        PopupMenuItem(value: 'scan', child: Text('Scan QR Code')),
                      ];
                      if (!event.isOnline) {
                        items.insert(2, PopupMenuItem(value: 'attendance', child: Text('View Attendance')));
                      }
                      return items;
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, EventDTO event) {
    switch (action) {
      case 'edit':
        _showCreateEditDialog(context, event: event);
        break;
      case 'delete':
        _confirmDelete(context, event);
        break;
      case 'attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceView(
              eventId: event.id,
              eventTitle: event.title,
              isOnline: event.isOnline,
            ),
          ),
        );
        break;
      case 'scan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRScannerView(eventId: event.id),
          ),
        );
        break;
    }
  }

  void _showCreateEditDialog(BuildContext context, {EventDTO? event}) {
    showDialog(
      context: context,
      builder: (context) => CreateEditEventDialog(
        event: event,
        onSave: (updatedEvent) {
          if (event == null) {
            _eventService.createEvent(updatedEvent).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Event created successfully')),
              );
              setState(() {
                _eventsFuture = _eventService.getEvents();
              });
            }).catchError((e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            });
          } else {
            _eventService.updateEvent(event.id, updatedEvent).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Event updated successfully')),
              );
              setState(() {
                _eventsFuture = _eventService.getEvents();
              });
            }).catchError((e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            });
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, EventDTO event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _eventService.deleteEvent(event.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Event deleted successfully')),
                );
                setState(() {
                  _eventsFuture = _eventService.getEvents();
                });
                Navigator.pop(context);
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              });
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}