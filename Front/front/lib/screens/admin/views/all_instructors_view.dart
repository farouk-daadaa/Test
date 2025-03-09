import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute
import '../../../services/admin_service.dart';
import 'dart:typed_data';

class AllInstructorsView extends StatefulWidget {
  const AllInstructorsView({Key? key}) : super(key: key);

  @override
  _AllInstructorsViewState createState() => _AllInstructorsViewState();
}

class _AllInstructorsViewState extends State<AllInstructorsView> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _filteredInstructors = [];
  final Map<int, Uint8List?> _imageCache = {}; // Cache for images
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  Future<void> _loadInstructors() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final instructors = await _adminService.getAllInstructors();
      setState(() {
        _instructors = instructors;
        _filteredInstructors = List.from(instructors);
        _filterAndSortInstructors();
        // Remove _precacheImages call to load images lazily
      });
    } catch (e) {
      print('Error loading instructors: $e');
      setState(() => _error = 'Failed to load instructors. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _filterAndSortInstructors() async {
    _filteredInstructors = List.from(_instructors);

    if (_searchQuery.isNotEmpty || _statusFilter != null) {
      _filteredInstructors = _filteredInstructors.where((instructor) {
        final searchLower = _searchQuery.toLowerCase();
        final name = '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.toLowerCase();
        final email = instructor['email']?.toString().toLowerCase() ?? '';
        final status = instructor['instructor']?['status']?.toString().toUpperCase();

        if (_statusFilter != null && status != _statusFilter) return false;
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    }

    if (_filteredInstructors.length > 50) {
      _filteredInstructors = await compute(_sortInstructors, {
        'instructors': _filteredInstructors,
        'sortBy': _sortBy,
        'sortAscending': _sortAscending,
      });
    } else {
      _filteredInstructors.sort((a, b) {
        if (_sortBy == 'name') {
          final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
          final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
          return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        } else {
          DateTime? dateA = _parseDate(a['creationDate']);
          DateTime? dateB = _parseDate(b['creationDate']);
          dateA ??= DateTime.now();
          dateB ??= DateTime.now();
          return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        }
      });
    }
    setState(() {});
  }

  static List<Map<String, dynamic>> _sortInstructors(Map<String, dynamic> params) {
    final instructors = params['instructors'] as List<Map<String, dynamic>>;
    final sortBy = params['sortBy'] as String;
    final sortAscending = params['sortAscending'] as bool;

    instructors.sort((a, b) {
      if (sortBy == 'name') {
        final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
        final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
        return sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      } else {
        DateTime? dateA = _parseDate(a['creationDate']);
        DateTime? dateB = _parseDate(b['creationDate']);
        dateA ??= DateTime.now();
        dateB ??= DateTime.now();
        return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      }
    });
    return instructors;
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is int) return DateTime.fromMillisecondsSinceEpoch(dateValue);
      if (dateValue is String) return DateTime.parse(dateValue);
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchAndFilter(),
          const SizedBox(height: 16),
          Expanded(child: _buildInstructorsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.school, color: const Color(0xFFDB2777), size: 32),
        const SizedBox(width: 12),
        Text(
          'All Instructors',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDB2777)),
        ),
        const Spacer(),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: Icon(Icons.refresh, color: Color(0xFFDB2777)),
      tooltip: 'Refresh list',
      onPressed: _loadInstructors,
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) {
              _searchQuery = value;
              _filterAndSortInstructors();
            },
            decoration: InputDecoration(
              hintText: 'Search instructors...',
              prefixIcon: Icon(Icons.search, color: Color(0xFFDB2777)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFDB2777)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Name'),
                  selected: _sortBy == 'name',
                  onSelected: (selected) {
                    if (selected) {
                      _sortBy = 'name';
                      _filterAndSortInstructors();
                    }
                  },
                  selectedColor: Color(0xFFDB2777).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Date'),
                  selected: _sortBy == 'date',
                  onSelected: (selected) {
                    if (selected) {
                      _sortBy = 'date';
                      _filterAndSortInstructors();
                    }
                  },
                  selectedColor: Color(0xFFDB2777).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Color(0xFFDB2777),
                  ),
                  onPressed: () {
                    _sortAscending = !_sortAscending;
                    _filterAndSortInstructors();
                  },
                  tooltip: _sortAscending ? 'Sort ascending' : 'Sort descending',
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  initialValue: _statusFilter,
                  tooltip: 'Filter by status',
                  icon: Icon(
                    Icons.filter_list,
                    color: _statusFilter != null ? Color(0xFFDB2777) : Colors.grey,
                  ),
                  onSelected: (status) {
                    _statusFilter = _statusFilter == status ? null : status;
                    _filterAndSortInstructors();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text('Status', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ),
                    PopupMenuItem(
                      value: 'APPROVED',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: _statusFilter == 'APPROVED' ? Color(0xFFDB2777) : Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Approved',
                              style: TextStyle(
                                  color: _statusFilter == 'APPROVED' ? Color(0xFFDB2777) : null,
                                  fontWeight: _statusFilter == 'APPROVED' ? FontWeight.bold : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'REJECTED',
                      child: Row(
                        children: [
                          Icon(Icons.cancel,
                              color: _statusFilter == 'REJECTED' ? Color(0xFFDB2777) : Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Rejected',
                              style: TextStyle(
                                  color: _statusFilter == 'REJECTED' ? Color(0xFFDB2777) : null,
                                  fontWeight: _statusFilter == 'REJECTED' ? FontWeight.bold : null)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'PENDING',
                      child: Row(
                        children: [
                          Icon(Icons.pending,
                              color: _statusFilter == 'PENDING' ? Color(0xFFDB2777) : Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Pending',
                              style: TextStyle(
                                  color: _statusFilter == 'PENDING' ? Color(0xFFDB2777) : null,
                                  fontWeight: _statusFilter == 'PENDING' ? FontWeight.bold : null)),
                        ],
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
  }

  Widget _buildInstructorsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777))),
            const SizedBox(height: 16),
            Text('Loading instructors...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInstructors,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFDB2777), foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_filteredInstructors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No instructors found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Try adjusting your search', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstructors,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        cacheExtent: 2000, // Increase cache extent slightly for smoother scrolling
        itemCount: _filteredInstructors.length,
        itemBuilder: (context, index) {
          final instructor = _filteredInstructors[index];
          return _buildInstructorCard(instructor);
        },
      ),
    );
  }

  Widget _buildInstructorCard(Map<String, dynamic> instructor) {
    final name = '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.trim();
    final email = instructor['email'] ?? 'No email';
    final phone = instructor['phoneNumber'] ?? 'No phone';
    final creationDate = _formatDate(instructor['creationDate']);
    final status = instructor['instructor']?['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final id = instructor['id'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
          child: _buildInstructorAvatar(id, name),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('Joined: $creationDate', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status, style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Color(0xFFDB2777)),
          onSelected: (value) => _handleMenuAction(value, instructor),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility, color: Color(0xFFDB2777)),
                title: Text('View Details'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (status == 'PENDING')
              PopupMenuItem(
                value: 'approve',
                child: ListTile(
                  leading: Icon(Icons.check, color: Colors.green),
                  title: Text('Approve'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (status == 'PENDING')
              PopupMenuItem(
                value: 'reject',
                child: ListTile(
                  leading: Icon(Icons.close, color: Colors.red),
                  title: Text('Reject'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorAvatar(int? id, String name) {
    if (id == null) return _buildFallbackAvatar(name);

    if (_imageCache.containsKey(id)) {
      return _imageCache[id] != null && _imageCache[id]!.isNotEmpty
          ? ClipOval(child: Image.memory(_imageCache[id]!, fit: BoxFit.cover, width: 48, height: 48))
          : _buildFallbackAvatar(name);
    }

    return FutureBuilder<Uint8List?>(
      future: _adminService.getImageBytes(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
            strokeWidth: 2,
          );
        }
        if (snapshot.hasError) {
          print('Error loading image for instructor $id: ${snapshot.error}');
          _imageCache[id] = null;
          return _buildFallbackAvatar(name);
        }
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          _imageCache[id] = snapshot.data;
          // Limit cache size to prevent memory issues
          if (_imageCache.length > 50) {
            _imageCache.remove(_imageCache.keys.first);
          }
          return ClipOval(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Duration(milliseconds: 200),
                  child: child,
                );
              },
            ),
          );
        }
        print('No valid image data for instructor $id');
        _imageCache[id] = null;
        return _buildFallbackAvatar(name);
      },
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: Color(0xFFDB2777), fontWeight: FontWeight.bold),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    try {
      DateTime date = dateValue is int ? DateTime.fromMillisecondsSinceEpoch(dateValue) : DateTime.parse(dateValue);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid date';
    }
  }

  void _handleMenuAction(String action, Map<String, dynamic> instructor) {
    switch (action) {
      case 'view':
        _showInstructorDetails(instructor);
        break;
      case 'approve':
        _handleApproval(instructor['instructor']['id']);
        break;
      case 'reject':
        _handleRejection(instructor['instructor']['id']);
        break;
    }
  }

  Future<void> _handleApproval(int id) async {
    final tempList = List<Map<String, dynamic>>.from(_filteredInstructors);
    setState(() => _filteredInstructors.removeWhere((inst) => inst['instructor']['id'] == id));
    try {
      await _adminService.approveInstructor(id);
      _showSnackBar('Instructor approved successfully', Colors.green);
    } catch (e) {
      print('Approval error: $e');
      setState(() => _filteredInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      await _loadInstructors();
    }
  }

  Future<void> _handleRejection(int id) async {
    final tempList = List<Map<String, dynamic>>.from(_filteredInstructors);
    setState(() => _filteredInstructors.removeWhere((inst) => inst['instructor']['id'] == id));
    try {
      await _adminService.rejectInstructor(id);
      _showSnackBar('Instructor rejected', Colors.orange);
    } catch (e) {
      print('Rejection error: $e');
      setState(() => _filteredInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      await _loadInstructors();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showInstructorDetails(Map<String, dynamic> instructor) {
    final instructorData = instructor['instructor'] ?? {};
    final status = instructorData['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final name = '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.trim();
    final id = instructor['id'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
                    child: _buildInstructorAvatar(id, name), // Reuse the same avatar widget
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status,
                              style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildDetailItem(Icons.email, 'Email', instructor['email'] ?? 'No email'),
              _buildDetailItem(Icons.phone, 'Phone', instructor['phoneNumber'] ?? 'No phone'),
              _buildDetailItem(Icons.description, 'CV', instructorData['cv'] ?? 'No CV'),
              _buildDetailItem(Icons.link, 'LinkedIn', instructorData['linkedinLink'] ?? 'No LinkedIn'),
              _buildDetailItem(Icons.calendar_today, 'Joined', _formatDate(instructor['creationDate'])),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: Color(0xFFDB2777))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Color(0xFFDB2777)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}