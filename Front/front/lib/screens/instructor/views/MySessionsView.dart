import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:front/constants/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import '../../../services/SessionService.dart';
import 'LobbyScreen.dart';

class MySessionsView extends StatefulWidget {
  const MySessionsView({Key? key}) : super(key: key);

  @override
  _MySessionsViewState createState() => _MySessionsViewState();
}

class _MySessionsViewState extends State<MySessionsView> implements HMSUpdateListener {
  late SessionService _sessionService;
  List<SessionDTO> _sessions = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isFollowerOnly = false;
  SessionDTO? _editingSession;
  final Color primaryColor = AppColors.primary;

  // 100ms SDK instance
  HMSSDK? _hmsSDK;

  @override
  void initState() {
    super.initState();
    // Initialize 100ms SDK
    _initializeHMSSDK();

    // Auto-refresh every 30 seconds to update UI
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to recompute statuses
      }
    });
  }

  void _initializeHMSSDK() {
    _hmsSDK = HMSSDK();
    _hmsSDK!.build();
    _hmsSDK!.addUpdateListener(listener: this);
  }

  @override
  void dispose() {
    // Remove the update listener when the widget is disposed
    _hmsSDK?.removeUpdateListener(listener: this);
    // Leave the meeting if still in it
    _hmsSDK?.leave();
    _hmsSDK = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    _sessionService = SessionService(baseUrl: AuthService.baseUrl);
    _sessionService.setToken(authService.token ?? '');
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    try {
      _sessions = await _sessionService.getMySessions();
      if (_sessions.isEmpty) {
        print('No sessions returned from API.');
      } else {
        print('Sessions fetched: ${_sessions.length}');
      }
    } catch (e) {
      print('Error fetching sessions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _navigateToLobby(String meetingToken, String username, String sessionTitle) async {
    try {
      // Request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.bluetoothConnect, // Optional
      ].request();

      // Only camera and microphone are mandatory
      if (statuses[Permission.camera]!.isDenied || statuses[Permission.microphone]!.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and microphone permissions are required.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Bluetooth is optional, just log if denied
      if (statuses[Permission.bluetoothConnect]?.isDenied ?? false) {
        print('Bluetooth permission denied, proceeding without it.');
      }

      // Reinitialize HMSSDK to ensure a fresh state
      _hmsSDK?.removeUpdateListener(listener: this);
      _hmsSDK?.leave();
      _initializeHMSSDK();

      // Navigate to LobbyScreen with the session title
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            hmsSDK: _hmsSDK!,
            meetingToken: meetingToken,
            username: username,
            sessionTitle: sessionTitle, // Pass the session title
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to proceed to lobby: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // HMSUpdateListener methods
  @override
  void onJoin({required HMSRoom room}) {
    print('Joined room: ${room.id}');
    // Navigation to MeetingScreen is handled in LobbyScreen
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    print('Peer update: ${peer.name}, update: $update');
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    print('Track update: ${track.kind}, update: $trackUpdate, peer: ${peer.name}');
  }

  @override
  void onError({required HMSException error}) {
    print('HMS Error: ${error.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meeting error: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void onMessage({required HMSMessage message}) {
    print('Received message: ${message.message}');
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {
    print('Role change request received');
  }

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {
    print('Speakers updated: ${updateSpeakers.map((s) => s.peer.name).toList()}');
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    print('Room update: $update');
  }

  @override
  void onReconnecting() {
    print('Reconnecting...');
  }

  @override
  void onReconnected() {
    print('Reconnected');
  }

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {
    print('Audio device changed: $currentAudioDevice');
  }

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {
    print('Track state change requested: ${hmsTrackChangeRequest.track}');
  }

  @override
  void onHMSError({required HMSException error}) {
    print('HMS Error occurred: ${error.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('HMS Error: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    print('Peer list updated: added ${addedPeers.length}, removed ${removedPeers.length}');
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    print('Removed from room: ${hmsPeerRemovedFromPeer.reason}');
    Navigator.pop(context); // Navigate back when removed from the room
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    print('Session store available: ${hmsSessionStore != null ? "Initialized" : "Not initialized"}');
  }
  // Helper method to validate the session title
  bool _isValidSessionTitle(String title) {
    final RegExp regex = RegExp(r'^[a-zA-Z0-9.:_-]+$');
    return regex.hasMatch(title);
  }

// Helper method to sanitize the session title
  String _sanitizeSessionTitle(String title) {
    if (title.isEmpty) {
      return 'session-${DateTime.now().millisecondsSinceEpoch}';
    }
    // Replace invalid characters with underscores
    String sanitized = title.replaceAll(RegExp(r'[^a-zA-Z0-9.:_-]'), '_');
    // Ensure the title is not empty after sanitization
    if (sanitized.isEmpty) {
      return 'session-${DateTime.now().millisecondsSinceEpoch}';
    }
    return sanitized;
  }

  void _showSessionForm({SessionDTO? session}) {
    _editingSession = session;
    _title = session?.title ?? '';
    _description = session?.description ?? '';
    _startTime = session?.startTime;
    _endTime = session?.endTime;
    bool isFollowerOnlyLocal = session?.isFollowerOnly ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          session == null ? 'Create Session' : 'Edit Session',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: _title,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.title, color: Color(0xFFDB2777)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Title is required';
                        }
                        if (!_isValidSessionTitle(value)) {
                          return 'Only letters, numbers, and . - : _ are allowed';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setDialogState(() {
                          _title = value;
                        });
                      },
                      onSaved: (value) => _title = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _description,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.description, color: Color(0xFFDB2777)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      validator: (value) => value!.isEmpty ? 'Description is required' : null,
                      onSaved: (value) => _description = value!,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.access_time, color: Color(0xFFDB2777)),
                        title: Text(
                          _startTime == null
                              ? 'Select Start Time'
                              : 'Start: ${DateFormat('yyyy-MM-dd HH:mm').format(_startTime!)}',
                          style: TextStyle(
                            color: _startTime == null ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2026),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: primaryColor,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setDialogState(() {
                                _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled, color: Color(0xFFDB2777)),
                        title: Text(
                          _endTime == null
                              ? 'Select End Time'
                              : 'End: ${DateFormat('yyyy-MM-dd HH:mm').format(_endTime!)}',
                          style: TextStyle(
                            color: _endTime == null ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startTime ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2026),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: primaryColor,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: primaryColor,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setDialogState(() {
                                _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Follower Only',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Only your followers can join this session',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: isFollowerOnlyLocal,
                        activeColor: primaryColor,
                        secondary: Icon(
                          isFollowerOnlyLocal ? Icons.people : Icons.public,
                          color: primaryColor,
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            isFollowerOnlyLocal = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              _isFollowerOnly = isFollowerOnlyLocal;
              await _submitForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(session == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _startTime != null && _endTime != null) {
      if (_endTime!.isBefore(_startTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('End time must be after start time'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      _formKey.currentState!.save();

      // Sanitize the title before sending to the backend
      final sanitizedTitle = _sanitizeSessionTitle(_title);

      final session = SessionDTO(
        id: _editingSession?.id,
        title: sanitizedTitle, // Use the sanitized title
        description: _description,
        startTime: _startTime!,
        endTime: _endTime!,
        isFollowerOnly: _isFollowerOnly,
        meetingLink: '',
        instructorId: 0,
        status: 'UPCOMING',
      );

      try {
        if (_editingSession == null) {
          await _sessionService.createSession(session);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          await _sessionService.updateSession(_editingSession!.id!, session);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Session updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        _fetchSessions();
        Navigator.pop(context);
      } catch (e) {
        // Improved error handling to display specific backend error messages
        String errorMessage = 'Error: $e';
        if (e.toString().contains('Invalid body param')) {
          errorMessage = 'Failed to create session: Invalid title. Only letters, numbers, and . - : _ are allowed.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select both start and end times'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      await _sessionService.deleteSession(sessionId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Session deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _fetchSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showDeleteConfirmation(int sessionId, String sessionTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          'Are you sure you want to delete "$sessionTitle"? This action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSession(sessionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
        return '#3B82F6'; // Blue
      case 'LIVE':
        return '#10B981'; // Green
      case 'COMPLETED':
        return '#6B7280'; // Gray
      case 'ENDED':
        return '#6B7280'; // Gray
      case 'CANCELLED':
        return '#EF4444'; // Red
      default:
        return '#6B7280'; // Default Gray
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSessionForm(),
        backgroundColor: const Color(0xFFDB2777), // Match My Courses
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Session',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Match My Courses padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(), // Custom header to match My Courses
            const SizedBox(height: 16), // Match My Courses spacing
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)), // Match My Courses
                ),
              )
                  : _sessions.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _fetchSessions,
                color: const Color(0xFFDB2777), // Match My Courses
                child: ListView.builder(
                  padding: const EdgeInsets.all(0), // Remove extra padding since parent already has it
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.event, color: Color(0xFFDB2777), size: 32), // Icon for sessions, matching My Courses style
        const SizedBox(width: 12), // Match My Courses spacing
        const Text(
          'My Sessions',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777), // Match My Courses color
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFFDB2777)), // Match My Courses color
          tooltip: 'Refresh sessions',
          onPressed: _fetchSessions,
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: const Duration(seconds: 2),
          color: const Color(0xFFDB2777).withOpacity(0.2), // Match My Courses shimmer
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Sessions Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first session to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showSessionForm(),
            icon: const Icon(Icons.add),
            label: const Text('Create Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(SessionDTO session) {
    final now = DateTime.now();
    String computedStatus;

    if (now.isBefore(session.startTime)) {
      computedStatus = 'UPCOMING';
    } else if (now.isAfter(session.startTime) && now.isBefore(session.endTime)) {
      computedStatus = 'LIVE';
    } else {
      computedStatus = 'ENDED';
    }

    final status = computedStatus.toUpperCase();
    final isUpcoming = status == 'UPCOMING';
    final isLive = status == 'LIVE';

    final statusColor = Color(int.parse(_getStatusColor(computedStatus).replaceAll('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUpcoming ? Icons.upcoming : (isLive ? Icons.live_tv : Icons.event_available),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.isEmpty ? 'UNKNOWN' : status,
                        style: TextStyle(
                          color: statusColor,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 150,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(session.startTime),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('h:mm a').format(session.startTime.toLocal())} - ${DateFormat('h:mm a').format(session.endTime.toLocal())}',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            session.isFollowerOnly == true ? Icons.people : Icons.public,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.isFollowerOnly == true ? 'Followers Only' : 'Public Session',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isLive)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final authService = Provider.of<AuthService>(context, listen: false);
                                await authService.loadToken();
                                final token = authService.token;

                                if (token == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('You need to log in first.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final sessionDetails = await _sessionService.getSessionJoinDetails(session.id!);
                                  print('Session Join Details: $sessionDetails');
                                  final meetingToken = sessionDetails["meetingToken"] as String?;
                                  final sessionTitle = sessionDetails["title"] as String? ?? session.title;

                                  if (meetingToken == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Meeting token is missing.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Navigate to LobbyScreen
                                  await _navigateToLobby(meetingToken, authService.username ?? 'Instructor',sessionTitle);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to join meeting: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.video_call),
                              label: const Text('Join Live'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: (isLive || status == 'ENDED' || status == 'CANCELLED')
                                ? null
                                : () => _showSessionForm(session: session),
                            tooltip: 'Edit',
                            color: Colors.blue,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _showDeleteConfirmation(session.id!, session.title),
                            tooltip: 'Delete',
                            color: Colors.red,
                          ),
                        ],
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
}