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
  List<EventDTO> _allEvents = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalPages = 1;
  late ScrollController _scrollController;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  String _searchQuery = '';
  bool? _filterOnline;
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _initializeEvents();
    _initializeHMSSDK();
  }

  Future<void> _initializeHMSSDK() async {
    await _hmsSDK.build();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _currentPage < _totalPages - 1) {
      _fetchMoreEvents();
    }
  }

  Future<void> _initializeEvents() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    if (token != null) {
      _eventService.setToken(token);
      await _fetchEvents();
    } else {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<void> _fetchEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _allEvents.clear();
      });
      final result = await _eventService.getEvents(page: _currentPage, size: 50);
      setState(() {
        _allEvents = result['events'] as List<EventDTO>;
        _allEvents.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
        _totalPages = result['totalPages'] as int;
        debugPrint('Fetched initial page: ${_allEvents.length} events, totalPages: $_totalPages');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching events: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreEvents() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final nextPage = _currentPage + 1;
      final result = await _eventService.getEvents(page: nextPage, size: 50);
      setState(() {
        final newEvents = result['events'] as List<EventDTO>;
        _allEvents.addAll(newEvents);
        _allEvents.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
        _currentPage = nextPage;
        _totalPages = result['totalPages'] as int;
        debugPrint('Fetched page $_currentPage: Added ${newEvents.length} events, total: ${_allEvents.length}');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading more events: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshEvents() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshing events...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      await _fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing events: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterOnline = null;
      _startDateFilter = null;
      _endDateFilter = null;
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

  List<EventDTO> _filterEvents(List<EventDTO> events) {
    final now = DateTime.now();
    debugPrint('Filtering events at: $now');
    List<EventDTO> filteredEvents = [];

    switch (_tabController.index) {
      case 0: // ALL
        filteredEvents = events;
        break;
      case 1: // Upcoming
        filteredEvents = events.where((event) {
          final isUpcoming = now.isBefore(event.startDateTime);
          debugPrint('Event ${event.title}: Start=${event.startDateTime}, IsUpcoming=$isUpcoming');
          return isUpcoming;
        }).toList();
        break;
      case 2: // Ongoing
        filteredEvents = events.where((event) {
          final isOngoing = now.isAfter(event.startDateTime) && now.isBefore(event.endDateTime);
          debugPrint('Event ${event.title}: Start=${event.startDateTime}, End=${event.endDateTime}, IsOngoing=$isOngoing');
          return isOngoing;
        }).toList();
        break;
      case 3: // Past
        filteredEvents = events.where((event) {
          final isPast = now.isAfter(event.endDateTime);
          debugPrint('Event ${event.title}: End=${event.endDateTime}, IsPast=$isPast');
          return isPast;
        }).toList();
        break;
      default:
        filteredEvents = events;
    }

    if (_searchQuery.isNotEmpty) {
      debugPrint('Applying search query: $_searchQuery');
      filteredEvents = filteredEvents.where((event) {
        final matchesSearch = event.title.toLowerCase().contains(_searchQuery.toLowerCase());
        debugPrint('Event ${event.title}: MatchesSearch=$matchesSearch');
        return matchesSearch;
      }).toList();
    }

    if (_filterOnline != null) {
      debugPrint('Applying online filter: $_filterOnline');
      filteredEvents = filteredEvents.where((event) => event.isOnline == _filterOnline).toList();
    }

    if (_startDateFilter != null) {
      debugPrint('Applying start date filter: $_startDateFilter');
      filteredEvents = filteredEvents.where((event) =>
      event.startDateTime.isAfter(_startDateFilter!) ||
          event.startDateTime.isAtSameMomentAs(_startDateFilter!)).toList();
    }

    if (_endDateFilter != null) {
      debugPrint('Applying end date filter: $_endDateFilter');
      filteredEvents = filteredEvents.where((event) =>
      event.startDateTime.isBefore(_endDateFilter!) ||
          event.startDateTime.isAtSameMomentAs(_endDateFilter!)).toList();
    }

    return filteredEvents;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _hmsSDK.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isAdmin = authService.userRole == "ADMIN";

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _showSearchBar
            ? TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search events...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          style: TextStyle(color: Colors.black87, fontSize: 16),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          autofocus: true,
        )
            : Text(
          'Events',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        leading: _showSearchBar
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            setState(() {
              _showSearchBar = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.clear : Icons.search, color: Colors.black87),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.black87),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refreshEvents,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 144 : 48),
          child: Column(
            children: [
              if (_showFilters) _buildFilterOptions(),
              Container(
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
                    Tab(text: 'ALL'),
                    Tab(text: 'UPCOMING'),
                    Tab(text: 'ONGOING'),
                    Tab(text: 'PAST'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        onPressed: () => _showCreateEditDialog(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
      )
          : null, // No FAB for students
      body: _buildEventsList(),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () {
                  _resetFilters();
                },
                child: Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size(0, 30),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDateRangePicker(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 16, color: Colors.grey.shade600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDateRangeText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _startDateFilter != null || _endDateFilter != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildEventTypeFilterButton(true, 'Online'),
                    _buildEventTypeFilterButton(false, 'In-Person'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventTypeFilterButton(bool isOnline, String label) {
    final isSelected = _filterOnline == isOnline;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_filterOnline == isOnline) {
            _filterOnline = null;
          } else {
            _filterOnline = isOnline;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 1 : 0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.videocam : Icons.location_on,
              size: 16,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateRangeText() {
    if (_startDateFilter != null && _endDateFilter != null) {
      return '${DateFormat('MMM d').format(_startDateFilter!)} - ${DateFormat('MMM d').format(_endDateFilter!)}';
    } else if (_startDateFilter != null) {
      return 'From ${DateFormat('MMM d').format(_startDateFilter!)}';
    } else if (_endDateFilter != null) {
      return 'Until ${DateFormat('MMM d').format(_endDateFilter!)}';
    } else {
      return 'Select date range';
    }
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDateFilter != null && _endDateFilter != null
          ? DateTimeRange(start: _startDateFilter!, end: _endDateFilter!)
          : null,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDateFilter = picked.start;
        _endDateFilter = picked.end;
      });
    }
  }

  Widget _buildEventsList() {
    if (_isLoading && _allEvents.isEmpty) {
      return _buildLoadingState();
    }

    if (_allEvents.isEmpty) {
      return _buildEmptyState();
    }

    final filteredEvents = _filterEvents(_allEvents);

    debugPrint('Filtered events: ${filteredEvents.length}');
    filteredEvents.forEach((event) {
      debugPrint('Filtered Event: ${event.title}, Start: ${event.startDateTime}, Status: ${event.status}');
    });

    if (filteredEvents.isEmpty) {
      return _buildNoMatchingEventsState();
    }

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: filteredEvents.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredEvents.length && _isLoadingMore) {
            return Center(child: CircularProgressIndicator());
          }
          return _buildEventCard(filteredEvents[index]);
        },
      ),
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

  Widget _buildEmptyState() {
    final authService = Provider.of<AuthService>(context);
    final bool isAdmin = authService.userRole == "ADMIN";

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
              isAdmin
                  ? 'Create your first event to get started'
                  : 'No events available at the moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ),
          if (isAdmin) ...[
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateEditDialog(context),
              icon: Icon(
                Icons.add,
                color: Colors.white,
              ),
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
        ],
      ),
    );
  }

  Widget _buildNoMatchingEventsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No matching events found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _resetFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Reset Filters',
              style: TextStyle(color: Colors.white),
            ),
          ),
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
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  ? 'Online Event'
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
                      SizedBox(height: 20),
                      _buildActionButtonsRow(event, isPast, isOngoing),
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

  Widget _buildActionButtonsRow(EventDTO event, bool isPast, bool isOngoing) {
    final authService = Provider.of<AuthService>(context);
    final bool isAdmin = authService.userRole == "ADMIN";

    if (isAdmin) {
      return _buildAdminActionButtonsRow(event, isPast);
    } else {
      return _buildStudentActionButtonsRow(event, isPast, isOngoing);
    }
  }

  Widget _buildAdminActionButtonsRow(EventDTO event, bool isPast) {
    if (!event.isOnline && !isPast && _isEventEditable(event)) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
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
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
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
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  color: Colors.amber.shade700,
                  onPressed: () => _showCreateEditDialog(context, event: event),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red.shade400,
                  onPressed: () => _confirmDelete(context, event),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (!event.isOnline && isPast) {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
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
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              icon: Icons.delete,
              label: 'Delete',
              color: Colors.red.shade400,
              onPressed: () => _confirmDelete(context, event),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          if (_isEventEditable(event)) ...[
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                color: Colors.amber.shade700,
                onPressed: () => _showCreateEditDialog(context, event: event),
              ),
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: _buildActionButton(
              icon: Icons.delete,
              label: 'Delete',
              color: Colors.red.shade400,
              onPressed: () => _confirmDelete(context, event),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildStudentActionButtonsRow(EventDTO event, bool isPast, bool isOngoing) {
    List<Widget> buttons = [];

    // Register/Cancel button logic
    if (!isPast && _isEventEditable(event)) {
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: event.isRegistered ? Icons.cancel : Icons.event_available,
            label: event.isRegistered ? 'Cancel' : 'Register',
            color: event.isRegistered ? Colors.red.shade400 : Colors.green.shade600,
            onPressed: event.capacityLeft != null && event.capacityLeft! <= 0 && !event.isRegistered
                ? null // Disable if event is full and not registered
                : () async {
              try {
                if (event.isRegistered) {
                  await _eventService.cancelRegistration(event.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registration canceled successfully'),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  await _eventService.registerForEvent(event.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Registered successfully!'),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
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
        ),
      );
    }

    // Join button for online events
    if (event.isOnline && (isOngoing || (isPast && event.isRegistered))) {
      buttons.add(SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.videocam,
            label: 'Join',
            color: Colors.indigo,
            onPressed: () {
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
          ),
        ),
      );
    }

    return buttons.isNotEmpty
        ? Row(children: buttons)
        : SizedBox.shrink(); // No buttons if none apply
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
    required VoidCallback? onPressed,
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
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userRole != "ADMIN") return; // Only admins can create/edit events

    showDialog(
      context: context,
      builder: (dialogContext) => CreateEditEventDialog(
        event: event,
        eventService: _eventService,
        onSave: (updatedEvent) async {
          try {
            if (event == null) {
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
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userRole != "ADMIN") return; // Only admins can delete events

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