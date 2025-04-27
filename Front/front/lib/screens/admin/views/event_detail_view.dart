import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:front/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:front/screens/instructor/views/LobbyScreen.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventDetailView extends StatefulWidget {
  final EventDTO event;
  final EventService eventService;
  final HMSSDK hmsSDK;

  const EventDetailView({
    Key? key,
    required this.event,
    required this.eventService,
    required this.hmsSDK,
  }) : super(key: key);

  @override
  _EventDetailViewState createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView> {
  late EventDTO _event;
  late Timer _timer;
  Duration _timeUntilEvent = Duration.zero;
  bool _isDuringEvent = false;
  String? _userRole;
  String? _username;
  bool _isLoadingUserDetails = true;
  LatLng? _eventLocation; // To store the geocoded location coordinates
  bool _isLoadingLocation = false;

  static const String _googleApiKey = 'AIzaSyCjUgGySYoos2UeHYmd6-MpIDLno2Sy2Ps';

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _updateCountdown();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
    _loadUserDetails();
    if (!_event.isOnline && _event.location != null && _event.location!.isNotEmpty) {
      _geocodeLocation(_event.location!);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.loadToken();
    setState(() {
      _userRole = authService.userRole;
      _username = authService.username;
      _isLoadingUserDetails = false;
      debugPrint('User role loaded: $_userRole');
      debugPrint('Username loaded: $_username');
      debugPrint('Event isRegistered: ${_event.isRegistered}');
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    setState(() {
      _timeUntilEvent = _event.startDateTime.difference(now);
      _isDuringEvent = now.isAfter(_event.startDateTime) && now.isBefore(_event.endDateTime);
      debugPrint('Current time: $now');
      debugPrint('Event start: ${_event.startDateTime}, end: ${_event.endDateTime}');
      debugPrint('Time until event: $_timeUntilEvent, isDuringEvent: $_isDuringEvent');
    });
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return _event.isOnline ? "Live now" : "Happening now";
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return "Starts in $days day${days == 1 ? '' : 's'}";
    } else if (hours > 0) {
      return "Starts in $hours hour${hours == 1 ? '' : 's'}";
    } else if (minutes > 0) {
      return "Starts in $minutes minute${minutes == 1 ? '' : 's'}";
    } else {
      return "Starts in less than a minute";
    }
  }

  Future<void> _geocodeLocation(String address) async {
    setState(() {
      _isLoadingLocation = true;
    });

    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          setState(() {
            _eventLocation = LatLng(location['lat'], location['lng']);
            _isLoadingLocation = false;
          });
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to geocode location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error geocoding location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load event location on map')),
      );
    }
  }

  Future<void> _handleRegister() async {
    try {
      await widget.eventService.registerForEvent(_event.id);
      setState(() {
        _event.isRegistered = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully registered for the event')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register: $e')),
      );
    }
  }

  Future<void> _handleJoin() async {
    if (_username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Username not available. Please log in again.')),
      );
      return;
    }

    try {
      final meetingDetails = await widget.eventService.joinOnlineEvent(_event.id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', _userRole!);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            hmsSDK: widget.hmsSDK,
            meetingToken: meetingDetails.meetingToken,
            username: _username!,
            sessionTitle: meetingDetails.title,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _event.imageUrl != null && _event.imageUrl!.isNotEmpty
                      ? Image.network(
                    '${widget.eventService.baseUrl}${_event.imageUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildGradientBackground(),
                  )
                      : _buildGradientBackground(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Text(
                      _event.title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_event.isOnline) _buildOnlineEventDetails() else _buildInPersonEventDetails(),
                  SizedBox(height: 24),
                  Text(
                    "About This Event",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _event.description ?? 'No description available.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "ONLINE EVENT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _event.getFormattedDate(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.people, color: Colors.grey[600], size: 20),
            SizedBox(width: 8),
            Text(
              '${_event.currentParticipants} / ${_event.maxParticipants ?? '∞'} attendees',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          _formatCountdown(_timeUntilEvent),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _timeUntilEvent.isNegative ? Colors.green : Colors.black87,
          ),
        ),
        if (!_isLoadingUserDetails && _userRole != null) ...[
          SizedBox(height: 20),
          Center(child: _buildActionButton()),
        ],
      ],
    );
  }

  Widget _buildInPersonEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "IN-PERSON EVENT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _event.getFormattedDate(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.people, color: Colors.grey[600], size: 20),
            SizedBox(width: 8),
            Text(
              '${_event.currentParticipants} / ${_event.maxParticipants ?? '∞'} attendees',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          _formatCountdown(_timeUntilEvent),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _timeUntilEvent.isNegative ? Colors.green : Colors.black87,
          ),
        ),
        if (_event.location != null && _event.location!.isNotEmpty) ...[
          SizedBox(height: 20),
          Text(
            "Location",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.redAccent, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _event.location!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (_isLoadingLocation)
                  Center(child: CircularProgressIndicator())
                else if (_eventLocation != null)
                  SizedBox(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _eventLocation!,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('event_location'),
                          position: _eventLocation!,
                          infoWindow: InfoWindow(title: _event.title),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                    ),
                  )
                else
                  Text(
                    'Unable to load map for this location.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (!_isLoadingUserDetails && _userRole != null) ...[
          SizedBox(height: 20),
          Center(child: _buildActionButton()),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    if (_userRole == 'ADMIN' && _isDuringEvent) {
      return ElevatedButton(
        onPressed: _event.isOnline ? _handleJoin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _event.isOnline ? Colors.blueAccent : Colors.grey,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: Text(
          "Join",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_userRole != 'ADMIN') {
      return ElevatedButton(
        onPressed: _event.isRegistered
            ? (_isDuringEvent && _event.isOnline ? _handleJoin : null)
            : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _event.isRegistered && (!_isDuringEvent || !_event.isOnline)
              ? Colors.grey
              : Colors.blueAccent,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: Text(
          _event.isRegistered ? (_event.isOnline ? "Join" : "Registered") : "Register",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container();
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent,
            Colors.purpleAccent,
          ],
        ),
      ),
    );
  }
}