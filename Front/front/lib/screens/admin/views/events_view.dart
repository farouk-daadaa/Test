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
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

class EventsView extends StatefulWidget {
  const EventsView({Key? key}) : super(key: key);

  @override
  _EventsViewState createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  final HMSSDK _hmsSDK = HMSSDK();
  Future<List<EventDTO>>? _eventsFuture;
  bool _isLoading = false;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeEvents();
    _initializeHMSSDK();
  }

  Future<void> _initializeHMSSDK() async {
    await _hmsSDK.build();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hmsSDK.destroy();
    super.dispose();
  }

  Future<void> _initializeEvents() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      _eventService.setToken(token);
      setState(() {
        _eventsFuture = _eventService.getEvents();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _isLoading = true;
      _eventsFuture = _eventService.getEvents();
    });
    await _eventsFuture;
    setState(() {
      _isLoading = false;
    });
  }

  String _getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';
    return '${_eventService.baseUrl}$relativeUrl';
  }

  bool _isEventEditable(EventDTO event) {
    final now = DateTime.now();
    return now.isBefore(event.startDateTime);
  }

  List<EventDTO> _filterEventsByTab(List<EventDTO> events, int tabIndex) {
    final now = DateTime.now();
    switch (tabIndex) {
      case 0: // Upcoming
        return events.where((event) => now.isBefore(event.startDateTime)).toList();
      case 1: // Ongoing
        return events.where((event) =>
        now.isAfter(event.startDateTime) && now.isBefore(event.endDateTime)
        ).toList();
      case 2: // Past
        return events.where((event) => now.isAfter(event.endDateTime)).toList();
      default:
        return events;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Events',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Search functionality coming soon'))
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refreshEvents,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: 'UPCOMING'),
                Tab(text: 'ONGOING'),
                Tab(text: 'PAST'),
              ],
              onTap: (index) {
                setState(() {});
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEditDialog(context),
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add),
        elevation: 4,
      ),
      body: _buildEventsList(),
    );
  }

  Widget _buildEventsList() {
    return _eventsFuture == null
        ? _buildEmptyState()
        : FutureBuilder<List<EventDTO>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return _buildLoadingState();
        } else if (snapshot.hasError) {
          if (snapshot.error.toString().contains('Unauthorized')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<AuthService>(context, listen: false).logout(context);
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return Center(child: Text('Redirecting to login...'));
          }
          return _buildErrorState(snapshot.error.toString());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoEventsState();
        }

        final filteredEvents = _filterEventsByTab(
            snapshot.data!,
            _tabController.index
        );

        if (filteredEvents.isEmpty) {
          return _buildEmptyTabState(_tabController.index);
        }

        return RefreshIndicator(
          onRefresh: _refreshEvents,
          color: AppColors.primary,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: filteredEvents.length,
            itemBuilder: (context, index) {
              return _buildEventCard(filteredEvents[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading events...',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Unable to load events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshEvents,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Events',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create your first event to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCreateEditDialog(context),
            icon: Icon(Icons.add),
            label: Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Events Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create your first event to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showCreateEditDialog(context),
            icon: Icon(Icons.add),
            label: Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(int tabIndex) {
    String message;
    IconData icon;

    switch (tabIndex) {
      case 0:
        message = 'No upcoming events';
        icon = Icons.event_available;
        break;
      case 1:
        message = 'No ongoing events';
        icon = Icons.event_busy;
        break;
      case 2:
        message = 'No past events';
        icon = Icons.history;
        break;
      default:
        message = 'No events found';
        icon = Icons.event_note;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            tabIndex == 0 ? 'Create a new event to get started' : 'Check back later',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          if (tabIndex == 0) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateEditDialog(context),
              icon: Icon(Icons.add),
              label: Text('Create Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(EventDTO event) {
    final now = DateTime.now();
    final isUpcoming = now.isBefore(event.startDateTime);
    final isOngoing = now.isAfter(event.startDateTime) && now.isBefore(event.endDateTime);
    final isPast = now.isAfter(event.endDateTime);

    Color statusColor;
    String statusText;

    if (isUpcoming) {
      statusColor = Colors.blue;
      statusText = 'Upcoming';
    } else if (isOngoing) {
      statusColor = Colors.green;
      statusText = 'Ongoing';
    } else {
      statusColor = Colors.grey;
      statusText = 'Ended';
    }

    // Calculate time difference for upcoming events
    String timeInfo = '';
    if (isUpcoming) {
      final difference = event.startDateTime.difference(now);
      if (difference.inDays > 0) {
        timeInfo = 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        timeInfo = 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        timeInfo = 'In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailView(
                    event: event,
                    eventService: _eventService,
                    hmsSDK: _hmsSDK,
                  ),
                ),
              ).then((_) => _refreshEvents());
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Image with Overlay
                Stack(
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                          ? Image.network(
                        _getFullImageUrl(event.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                      )
                          : _buildPlaceholderImage(),
                    ),
                    // Status badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUpcoming ? Icons.event_available :
                              isOngoing ? Icons.event_note : Icons.event_busy,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Time info for upcoming events
                    if (timeInfo.isNotEmpty)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            timeInfo,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    // Online/In-person badge
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: event.isOnline ?
                          Colors.indigo.withOpacity(0.8) :
                          Colors.amber.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              event.isOnline ? Icons.videocam : Icons.location_on,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              event.isOnline ? 'Online' : 'In-Person',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Event Details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 12),

                      // Date and Time
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(event.startDateTime),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${DateFormat('h:mm a').format(event.startDateTime)} - ${DateFormat('h:mm a').format(event.endDateTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Location or Meeting Link
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (event.isOnline ? Colors.indigo : Colors.amber).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              event.isOnline ? Icons.videocam : Icons.location_on,
                              size: 18,
                              color: event.isOnline ? Colors.indigo : Colors.amber.shade700,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              event.isOnline
                                  ? (event.meetingLink ?? 'Online Meeting')
                                  : (event.location ?? 'No location specified'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Participants info
                      if (event.maxParticipants != null) ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.people,
                                size: 18,
                                color: Colors.teal,
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Participants: ${event.currentParticipants}/${event.maxParticipants}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  width: 200,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: Colors.grey.shade200,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: event.maxParticipants! > 0
                                        ? event.currentParticipants / event.maxParticipants!
                                        : 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: event.currentParticipants >= event.maxParticipants!
                                            ? Colors.red.shade400
                                            : Colors.teal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: event.capacityLeft! > 0
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: event.capacityLeft! > 0
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                event.capacityLeft! > 0
                                    ? '${event.capacityLeft} spots left'
                                    : 'Full',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: event.capacityLeft! > 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Action buttons
                      SizedBox(height: 20),
                      Row(
                        children: [
                          if (!event.isOnline && !isPast) ...[
                            _buildActionButton(
                              icon: Icons.qr_code_scanner,
                              label: 'Scan QR',
                              color: Colors.indigo,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QRScannerView(eventId: event.id),
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 8),
                          ],
                          if (!event.isOnline) ...[
                            _buildActionButton(
                              icon: Icons.people,
                              label: 'Attendance',
                              color: Colors.teal,
                              onPressed: () {
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
                              },
                            ),
                          ],
                          Spacer(),
                          if (_isEventEditable(event)) ...[
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              color: Colors.amber.shade700,
                              onPressed: () => _showCreateEditDialog(context, event: event),
                            ),
                            SizedBox(width: 8),
                          ],
                          _buildActionButton(
                            icon: Icons.delete,
                            label: 'Delete',
                            color: Colors.red.shade400,
                            onPressed: () => _confirmDelete(context, event),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.event,
          size: 64,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showCreateEditDialog(BuildContext context, {EventDTO? event}) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateEditEventDialog(
        event: event,
        eventService: _eventService,
        onSave: (updatedEvent) async {
          try {
            if (event == null) {
              // Create new event
              await _eventService.createEvent(updatedEvent);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Event created successfully'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else {
              // Update existing event
              await _eventService.updateEvent(event.id, updatedEvent);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Event updated successfully'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
            // Refresh events after successful operation
            await _refreshEvents();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, EventDTO event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            SizedBox(width: 8),
            Text('Delete Event'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this event?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.event, color: AppColors.primary),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(event.startDateTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _eventService.deleteEvent(event.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Event deleted successfully'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                _refreshEvents();
                Navigator.pop(context);
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            },
            icon: Icon(Icons.delete),
            label: Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
