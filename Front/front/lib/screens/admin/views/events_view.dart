import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:front/screens/admin/views/create_edit_event_dialog.dart';
import 'package:front/screens/admin/views/attendance_view.dart';
import 'package:front/screens/admin/views/qr_scanner_view.dart';
import 'package:front/screens/admin/views/event_detail_view.dart';
import 'package:front/constants/colors.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';

class EventsView extends StatefulWidget {
  const EventsView({Key? key}) : super(key: key);

  @override
  _EventsViewState createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  final HMSSDK _hmsSDK = HMSSDK(); // Instantiate HMSSDK
  Future<List<EventDTO>>? _eventsFuture;

  @override
  void initState() {
    super.initState();
    _initializeEvents();
    _initializeHMSSDK();
  }

  Future<void> _initializeHMSSDK() async {
    await _hmsSDK.build(); // Build the HMSSDK instance
  }

  @override
  void dispose() {
    _hmsSDK.destroy(); // Clean up HMSSDK when the widget is disposed
    super.dispose();
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

  // Helper method to construct the full image URL
  String _getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';
    // Prepend the baseUrl to the relative path
    return '${_eventService.baseUrl}$relativeUrl';
  }

  // Helper method to check if the event is editable (not ongoing or ended)
  bool _isEventEditable(EventDTO event) {
    final now = DateTime.now();
    // Event is editable if it hasn't started yet (current time is before startDateTime)
    return now.isBefore(event.startDateTime);
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailView(
                            event: event,
                            eventService: _eventService,
                            hmsSDK: _hmsSDK, // Pass HMSSDK to EventDetailView
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // Image Display
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _getFullImageUrl(event.imageUrl), // Construct the full URL
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                              : Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Event Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${event.getFormattedDate()} • ${event.isOnline ? 'Online' : 'In-Person'} • ${event.status ?? 'Unknown'}',
                                style: TextStyle(fontSize: 14),
                              ),
                              if (event.maxParticipants != null)
                                Text(
                                  'Participants: ${event.currentParticipants}/${event.maxParticipants} (${event.capacityLeft ?? 0} left)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        // Popup Menu
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleMenuAction(context, value, event),
                          itemBuilder: (context) {
                            final items = <PopupMenuItem<String>>[];
                            // Only add "Edit" if the event is editable (not ongoing or ended)
                            if (_isEventEditable(event)) {
                              items.add(PopupMenuItem(value: 'edit', child: Text('Edit')));
                            }
                            items.add(PopupMenuItem(value: 'delete', child: Text('Delete')));
                            if (!event.isOnline) {
                              items.add(PopupMenuItem(value: 'attendance', child: Text('View Attendance')));
                              items.add(PopupMenuItem(value: 'scan', child: Text('Scan QR Code')));
                            }
                            return items;
                          },
                        ),
                      ],
                    ),
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
        eventService: _eventService,
        onSave: (updatedEvent) {
          if (event == null) {
            _eventService.createEvent(updatedEvent).then((_) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text('Event created successfully')),
              );
              setState(() {
                _eventsFuture = _eventService.getEvents();
              });
            }).catchError((e) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            });
          } else {
            _eventService.updateEvent(event.id, updatedEvent).then((_) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text('Event updated successfully')),
              );
              setState(() {
                _eventsFuture = _eventService.getEvents();
              });
            }).catchError((e) {
              scaffoldMessengerKey.currentState?.showSnackBar(
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
                scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text('Event deleted successfully')),
                );
                setState(() {
                  _eventsFuture = _eventService.getEvents();
                });
                Navigator.pop(context);
              }).catchError((e) {
                scaffoldMessengerKey.currentState?.showSnackBar(
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