import 'package:flutter/material.dart';
import 'package:front/services/event_service.dart';
import 'package:front/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:front/screens/instructor/views/LobbyScreen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:front/constants/colors.dart' as app_colors;
import 'package:qr_flutter/qr_flutter.dart';
import 'RouteView.dart';

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

class _EventDetailViewState extends State<EventDetailView>
    with SingleTickerProviderStateMixin {
  late EventDTO _event;
  late Timer _timer;
  Duration _timeUntilEvent = Duration.zero;
  bool _isDuringEvent = false;
  bool _isEventEnded = false;
  bool _isUpcoming = false;
  String? _userRole;
  String? _username;
  bool _isLoadingUserDetails = true;
  LatLng? _eventLocation;
  bool _isLoadingLocation = false;
  GoogleMapController? _mapController;
  bool _isRegistering = false;
  bool _isJoining = false;
  bool _isCanceling = false;
  late TabController _tabController;

  String? _qrCodeData; // Store the Base64 QR code data

  // Theme colors for consistent design
  final Color primaryColor = app_colors.AppColors.primary;
  final Color secondaryColor =
      app_colors.AppColors.secondary ?? Colors.purple.shade600;
  final Color accentColor = Colors.teal.shade600;

  // Google Maps API Key
  static const String _googleApiKey = 'AIzaSyCjUgGySYoos2UeHYmd6-MpIDLno2Sy2Ps';

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _initializeState();
  }

  void _initializeState() {
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
    _loadUserDetails();
    if (!_event.isOnline && _event.location != null && _event.location!.isNotEmpty) {
      _geocodeLocation(_event.location!);
    }
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _timer.cancel();
    _mapController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.loadToken();
      setState(() {
        _userRole = authService.userRole;
        _username = authService.username;
        _isLoadingUserDetails = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load user details: $e');
      setState(() {
        _isLoadingUserDetails = false;
      });
    }
  }

  void _updateCountdown() {
    final now = DateTime.now();
    setState(() {
      _timeUntilEvent = _event.startDateTime.difference(now);
      _isDuringEvent =
          now.isAfter(_event.startDateTime) && now.isBefore(_event.endDateTime);
      _isEventEnded = now.isAfter(_event.endDateTime);
      _isUpcoming = now.isBefore(_event.startDateTime);
    });
  }



  Widget _buildEventStatusBadge() {
    if (_isEventEnded) {
      return _buildStatusBadge("Event Ended", Colors.red.shade600, Icons.event_busy);
    } else if (_isDuringEvent) {
      return _buildStatusBadge(
        _event.isOnline ? "Live Now" : "Happening Now",
        Colors.green.shade600,
        _event.isOnline ? Icons.live_tv : Icons.event_available,
      );
    } else {
      return _buildStatusBadge(
        "Upcoming",
        Colors.amber.shade700,
        Icons.upcoming,
      );
    }
  }

  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer(Duration duration) {
    if (!_isUpcoming) return const SizedBox.shrink();

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Starting in",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeBox(days, "Days"),
            _buildTimeSeparator(),
            _buildTimeBox(hours, "Hours"),
            _buildTimeSeparator(),
            _buildTimeBox(minutes, "Mins"),
            _buildTimeSeparator(),
            _buildTimeBox(seconds, "Secs"),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ":",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildTimeBox(int value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _geocodeLocation(String address) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to geocode location: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') {
        throw Exception('Geocoding failed: ${data['status']}');
      }

      final location = data['results'][0]['geometry']['location'];
      setState(() {
        _eventLocation = LatLng(location['lat'], location['lng']);
        _isLoadingLocation = false;
      });
    } catch (e) {
      _showErrorSnackBar('Could not load event location on map: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<LatLng?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar(
          'Location services are disabled. Please enable them.',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _navigateToRoutePage,
            textColor: Colors.white,
          ),
        );
        return null;
      }

      PermissionStatus permission = await Permission.locationWhenInUse.request();
      if (permission.isDenied) {
        _showErrorSnackBar(
          'Location permissions are denied.',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _navigateToRoutePage,
            textColor: Colors.white,
          ),
        );
        return null;
      }

      if (permission.isPermanentlyDenied) {
        _showErrorSnackBar(
          'Location permissions are permanently denied. Please enable them in settings.',
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () async {
              await openAppSettings();
            },
            textColor: Colors.white,
          ),
        );
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Timed out while getting location');
      });

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      _showErrorSnackBar(
        'Could not get your current location: $e',
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _navigateToRoutePage,
          textColor: Colors.white,
        ),
      );
      return null;
    }
  }

  Future<void> _navigateToRoutePage() async {
    if (_eventLocation == null) {
      _showErrorSnackBar('Event location not available.');
      return;
    }

    final currentLocation = await _getUserLocation();
    if (currentLocation == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteView(
          eventLocation: _eventLocation!,
          userLocation: currentLocation,
          googleApiKey: _googleApiKey,
          isEventEnded: _isEventEnded,
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_isRegistering) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      final qrCodeBase64 = await widget.eventService.registerForEvent(_event.id);
      setState(() {
        _event.isRegistered = true;
        _qrCodeData = qrCodeBase64; // Store the Base64 QR code data
      });
      _showSuccessSnackBar('Successfully registered for the event');
    } catch (e) {
      _showErrorSnackBar('Failed to register: $e');
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  Future<void> _handleCancel() async {
    if (_isCanceling) return;

    setState(() {
      _isCanceling = true;
    });

    try {
      await widget.eventService.cancelRegistration(_event.id);
      setState(() {
        _event.isRegistered = false;
        _qrCodeData = null; // Clear the QR code data
      });
      _showSuccessSnackBar('Registration canceled successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to cancel registration: $e');
    } finally {
      setState(() {
        _isCanceling = false;
      });
    }
  }

  Future<void> _handleJoin() async {
    if (_isJoining) return;

    if (_username == null) {
      _showErrorSnackBar('Username not available. Please log in again.');
      return;
    }

    setState(() {
      _isJoining = true;
    });

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
      _showErrorSnackBar('Failed to join: $e');
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }



  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showErrorSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        action: action,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildEventDetails()),
        ],
      ),
      bottomNavigationBar: _isLoadingUserDetails || _userRole == null
          ? null
          : _buildBottomActionBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      backgroundColor: primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'event_image_${_event.id}',
              child: _event.imageUrl != null && _event.imageUrl!.isNotEmpty
                  ? Image.network(
                '${widget.eventService.baseUrl}${_event.imageUrl}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGradientBackground(),
              )
                  : _buildGradientBackground(),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Row(
                children: [
                  _buildEventStatusBadge(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _event.isOnline
                          ? Colors.blue.shade600
                          : Colors.green.shade600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _event.isOnline ? Icons.videocam : Icons.location_on,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _event.isOnline ? "ONLINE" : "IN-PERSON",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _event.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white.withOpacity(0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatEventDate(_event.startDateTime, _event.endDateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (_event.isRegistered && !_isEventEnded) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "REGISTERED",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusSection(),
        _buildTabSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isUpcoming) ...[
            _buildCountdownTimer(_timeUntilEvent),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Attendees",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_event.currentParticipants}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            ' / ${_event.maxParticipants ?? '∞'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'registered',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_event.isRegistered && !_isEventEnded) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Registered",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: primaryColor,
            indicatorWeight: 3,
            tabs: [
              const Tab(
                icon: Icon(Icons.info_outline),
                text: "Details",
              ),
              Tab(
                icon: Icon(_event.isOnline ? Icons.videocam : Icons.location_on),
                text: _event.isOnline ? "Online" : "Location",
              ),
            ],
          ),
        ),
        Container(
          height: _event.isOnline ? 400 : 500,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(),
              _event.isOnline ? _buildOnlineTab() : _buildLocationTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("About This Event", Icons.info_outline),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _event.description ?? 'No description available.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Event Details", Icons.event_note),
          const SizedBox(height: 16),
          _buildDetailCard(
            icon: Icons.calendar_today,
            title: "Date",
            value: DateFormat('EEEE, MMMM d, yyyy').format(_event.startDateTime),
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.access_time,
            title: "Time",
            value:
            "${DateFormat('h:mm a').format(_event.startDateTime)} - ${DateFormat('h:mm a').format(_event.endDateTime)}",
          ),
          const SizedBox(height: 12),
          _buildDetailCard(
            icon: Icons.people,
            title: "Capacity",
            value:
            "${_event.currentParticipants} registered${_event.maxParticipants != null ? ' (max ${_event.maxParticipants})' : ''}",
          ),
          if (_event.isOnline) ...[
            const SizedBox(height: 12),
            _buildDetailCard(
              icon: Icons.videocam,
              title: "Platform",
              value: "Online Meeting",
            ),
          ],
          if (!_event.isOnline &&
              _userRole != "ADMIN" &&
              _event.isRegistered &&
              !_isEventEnded &&
              _qrCodeData != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("Your QR Code", Icons.qr_code),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    QrImageView(
                      data: _qrCodeData!,
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Present this QR code at the event for check-in.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Online Event", Icons.videocam),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "How to Join",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isDuringEvent
                      ? "This event is happening now. Click the 'Join' button below to participate."
                      : _isEventEnded
                      ? "This event has ended."
                      : "This is an online event. Once registered, you'll be able to join when the event starts.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isDuringEvent && _event.isRegistered) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.videocam,
                      size: 40,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Event is live now!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Click the button below to join",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isEventEnded) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_busy,
                      size: 40,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Event has ended",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.upcoming,
                      size: 40,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Event starts in",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${_timeUntilEvent.inDays}d ${_timeUntilEvent.inHours % 24}h ${_timeUntilEvent.inMinutes % 60}m",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Event Location", Icons.location_on),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _event.location ?? 'No location specified',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingLocation)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Loading map...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_eventLocation != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _eventLocation!,
                              zoom: 15,
                            ),
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            markers: {
                              Marker(
                                markerId: const MarkerId('event_location'),
                                position: _eventLocation!,
                                infoWindow: InfoWindow(title: _event.title),
                              ),
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isEventEnded ? null : _navigateToRoutePage,
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text("Get Directions"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _isEventEnded ? Colors.grey.shade400 : primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load map for this location.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 22,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_isEventEnded && !(_event.isRegistered && _userRole != 'ADMIN')) {
      return const SizedBox.shrink();
    }

    if (_userRole == 'ADMIN') {
      if (_event.isOnline && _isDuringEvent) {
        return _buildActionButton(
          onPressed: _isJoining ? null : _handleJoin,
          isLoading: _isJoining,
          label: "Join Live Session",
          icon: Icons.videocam,
          loadingLabel: "Joining...",
        );
      }
      return const SizedBox.shrink();
    }

    if (_isDuringEvent && !_event.isRegistered) {
      return const SizedBox.shrink();
    }

    return _buildActionButton(
      onPressed: _event.isRegistered
          ? (_isCanceling ? null : _handleCancel)
          : (_isRegistering ? null : _handleRegister),
      isLoading: _isRegistering || _isJoining || _isCanceling,
      label: _event.isRegistered
          ? "Cancel Registration"
          : "Register for Event",
      icon: _event.isRegistered
          ? Icons.cancel
          : Icons.event_available,
      loadingLabel: _isRegistering
          ? "Registering..."
          : _isCanceling
          ? "Canceling..."
          : "Joining...",
      disabled: false,
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    required IconData icon,
    required String loadingLabel,
    bool disabled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey.shade400 : primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              loadingLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
      ),
    );
  }

  String _formatEventDate(DateTime start, DateTime end) {
    final bool sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (sameDay) {
      return DateFormat('EEEE, MMMM d, yyyy').format(start);
    } else {
      return "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}";
    }
  }
}