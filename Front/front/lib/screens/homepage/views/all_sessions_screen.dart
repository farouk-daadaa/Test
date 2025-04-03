import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:front/constants/colors.dart'; // Adjust path if needed
import 'package:front/services/SessionService.dart';
import 'package:front/screens/instructor/views/LobbyScreen.dart'; // Adjust path if needed
import 'package:provider/provider.dart';
import '../../../../../services/auth_service.dart';
import '../../../services/instructor_service.dart'; // Adjust path if needed

class AllSessionsScreen extends StatefulWidget {
  const AllSessionsScreen({super.key});

  @override
  State<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends State<AllSessionsScreen> {
  late SessionService _sessionService;
  late AuthService _authService;
  List<SessionDTO> _allSessions = [];
  List<SessionDTO> _filteredSessions = [];
  Map<int, String> _instructorNames = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // Default filter

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _searchController.addListener(_filterSessions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _authService = Provider.of<AuthService>(context, listen: false);
    _sessionService = SessionService(baseUrl: 'http://192.168.1.13:8080');
    final token = await _authService.getToken();
    if (token != null) {
      _sessionService.setToken(token);
      await _fetchAllSessions(token);
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchAllSessions(String token) async {
    try {
      final userId = await _authService.getUserIdByUsername(_authService.username ?? '');
      if (userId != null) {
        final sessions = await _sessionService.getAvailableSessions(userId);
        final instructorService = InstructorService()..setToken(token);
        for (var session in sessions) {
          if (session.instructorId != null && !_instructorNames.containsKey(session.instructorId)) {
            final profile = await instructorService.getInstructorProfile(session.instructorId!);
            _instructorNames[session.instructorId!] = profile?.username ?? 'Unknown';
          }
        }
        setState(() {
          _allSessions = sessions;
          _sortAndFilterSessions();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load sessions: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getStatus(SessionDTO session) {
    final now = DateTime.now();
    if (now.isBefore(session.startTime)) return 'UPCOMING';
    if (now.isAfter(session.startTime) && now.isBefore(session.endTime)) return 'LIVE';
    return 'ENDED';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'UPCOMING':
        return Colors.orange;
      case 'LIVE':
        return Colors.red;
      case 'ENDED':
      default:
        return Colors.grey;
    }
  }

  void _sortAndFilterSessions() {
    List<SessionDTO> sortedSessions = List.from(_allSessions);
    // Sort: LIVE first, then UPCOMING, then ENDED
    sortedSessions.sort((a, b) {
      final statusA = _getStatus(a);
      final statusB = _getStatus(b);
      if (statusA == 'LIVE' && statusB != 'LIVE') return -1;
      if (statusB == 'LIVE' && statusA != 'LIVE') return 1;
      if (statusA == 'UPCOMING' && statusB == 'ENDED') return -1;
      if (statusB == 'UPCOMING' && statusA == 'ENDED') return 1;
      return a.startTime.compareTo(b.startTime); // Within same status, sort by start time
    });

    // Apply search filter
    final query = _searchController.text.toLowerCase();
    List<SessionDTO> filtered = query.isEmpty
        ? sortedSessions
        : sortedSessions.where((session) => session.title.toLowerCase().contains(query)).toList();

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((session) => _getStatus(session) == _selectedFilter.toUpperCase()).toList();
    }

    setState(() {
      _filteredSessions = filtered;
    });
  }

  void _filterSessions() {
    _sortAndFilterSessions(); // Reuse the existing method for filtering
  }

  Future<void> _refreshSessions() async {
    setState(() {
      _isLoading = true;
      _searchController.clear(); // Reset search
      _selectedFilter = 'All'; // Reset filter
    });
    final token = await _authService.getToken();
    if (token != null) {
      await _fetchAllSessions(token);
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _joinSession(SessionDTO session) async {
    try {
      final joinDetails = await _sessionService.getSessionJoinDetails(session.id!);
      final hmsSDK = HMSSDK();
      await hmsSDK.build();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            hmsSDK: hmsSDK,
            meetingToken: joinDetails['meetingToken'],
            username: _authService.username ?? 'Student',
            sessionTitle: session.title,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join session: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Sessions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshSessions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Filter
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by session name...',
                    prefixIcon: Icon(Icons.search, color: AppColors.textGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.backgroundGray),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<String>(
                      value: _selectedFilter,
                      items: ['All', 'Live', 'Upcoming', 'Ended']
                          .map((filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                          _sortAndFilterSessions();
                        });
                      },
                      underline: Container(),
                      icon: Icon(Icons.filter_list, color: AppColors.primary),
                      style: TextStyle(color: AppColors.textGray, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Session List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredSessions.isEmpty
                ? Center(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        color: AppColors.textGray.withOpacity(0.7),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No sessions found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              itemCount: _filteredSessions.length,
              itemBuilder: (context, index) {
                final session = _filteredSessions[index];
                final status = _getStatus(session);
                final statusColor = _getStatusColor(status);
                final instructorName = _instructorNames[session.instructorId] ?? 'Unknown';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
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
                                  color: Colors.black87,
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
                                    status == 'UPCOMING'
                                        ? Icons.upcoming
                                        : (status == 'LIVE' ? Icons.live_tv : Icons.event_available),
                                    size: 14,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status,
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
                            if (session.description != null && session.description!.isNotEmpty)
                              Text(
                                session.description!,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (session.description != null && session.description!.isNotEmpty)
                              const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
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
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('h:mm a').format(session.startTime.toLocal())} - '
                                      '${DateFormat('h:mm a').format(session.endTime.toLocal())}',
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
                            if (status == 'LIVE')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _joinSession(session);
                                    },
                                    icon: const Icon(Icons.video_call),
                                    label: const Text('Join Live'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}