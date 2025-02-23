import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final instructors = await _adminService.getAllInstructors();
      setState(() {
        _instructors = instructors;
        _filterAndSortInstructors();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortInstructors() {
    _filteredInstructors = _instructors.where((instructor) {
      final searchLower = _searchQuery.toLowerCase();
      final name = '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.toLowerCase();
      final email = instructor['email']?.toString().toLowerCase() ?? '';
      final status = instructor['instructor']?['status']?.toString().toUpperCase();

      // Apply status filter if selected
      if (_statusFilter != null && status != _statusFilter) {
        return false;
      }

      return name.contains(searchLower) || email.contains(searchLower);
    }).toList();

    _filteredInstructors.sort((a, b) {
      if (_sortBy == 'name') {
        final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
        final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
        return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      } else {
        // Sort by creation date
        DateTime? dateA;
        DateTime? dateB;

        try {
          if (a['creationDate'] is int) {
            dateA = DateTime.fromMillisecondsSinceEpoch(a['creationDate']);
          } else if (a['creationDate'] is String) {
            dateA = DateTime.parse(a['creationDate']);
          }

          if (b['creationDate'] is int) {
            dateB = DateTime.fromMillisecondsSinceEpoch(b['creationDate']);
          } else if (b['creationDate'] is String) {
            dateB = DateTime.parse(b['creationDate']);
          }
        } catch (e) {
          print('Error parsing dates: $e');
        }

        dateA ??= DateTime.now();
        dateB ??= DateTime.now();

        return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      }
    });
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
        Icon(Icons.school, color: Color(0xFFDB2777), size: 32),
        const SizedBox(width: 12),
        Text(
          'All Instructors',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
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
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 2.seconds, color: Color(0xFFDB2777).withOpacity(0.2));
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterAndSortInstructors();
              });
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
              ChoiceChip(
                label: Text('Name'),
                selected: _sortBy == 'name',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortBy = 'name';
                      _filterAndSortInstructors();
                    });
                  }
                },
                selectedColor: Color(0xFFDB2777).withOpacity(0.2),
              ),
              ChoiceChip(
                label: Text('Date'),
                selected: _sortBy == 'date',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortBy = 'date';
                      _filterAndSortInstructors();
                    });
                  }
                },
                selectedColor: Color(0xFFDB2777).withOpacity(0.2),
              ),
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Color(0xFFDB2777),
                ),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _filterAndSortInstructors();
                  });
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
                  setState(() {
                    // Toggle off if same status is selected
                    _statusFilter = _statusFilter == status ? null : status;
                    _filterAndSortInstructors();
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'APPROVED',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _statusFilter == 'APPROVED' ? Color(0xFFDB2777) : Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Approved',
                          style: TextStyle(
                            color: _statusFilter == 'APPROVED' ? Color(0xFFDB2777) : null,
                            fontWeight: _statusFilter == 'APPROVED' ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'REJECTED',
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: _statusFilter == 'REJECTED' ? Color(0xFFDB2777) : Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Rejected',
                          style: TextStyle(
                            color: _statusFilter == 'REJECTED' ? Color(0xFFDB2777) : null,
                            fontWeight: _statusFilter == 'REJECTED' ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'PENDING',
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending,
                          color: _statusFilter == 'PENDING' ? Color(0xFFDB2777) : Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: _statusFilter == 'PENDING' ? Color(0xFFDB2777) : null,
                            fontWeight: _statusFilter == 'PENDING' ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading instructors...',
              style: TextStyle(color: Colors.grey[600]),
            ),
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
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInstructors,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
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
            Icon(
              Icons.person_search,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No instructors found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstructors,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        itemCount: _filteredInstructors.length,
        itemBuilder: (context, index) {
          final instructor = _filteredInstructors[index];
          return _buildInstructorCard(instructor, index);
        },
      ),
    );
  }

  Widget _buildInstructorCard(Map<String, dynamic> instructor, int index) {
    final name = '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.trim();
    final email = instructor['email'] ?? 'No email';
    final phone = instructor['phoneNumber'] ?? 'No phone';
    final creationDate = _formatDate(instructor['creationDate']);
    final status = instructor['instructor']?['status']?.toString().toUpperCase() ?? 'UNKNOWN';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: FutureBuilder<Uint8List?>(
          future: instructor['id'] != null
              ? _adminService.getImageBytes(instructor['id'])
              : Future.value(null),
          builder: (context, snapshot) {
            return CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                strokeWidth: 2,
              )
                  : snapshot.hasData
                  ? ClipOval(
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return _buildFallbackAvatar(name);
                  },
                ),
              )
                  : _buildFallbackAvatar(name),
            );
          },
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Joined: $creationDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    ).animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn()
        .slideX();
  }

  Widget _buildFallbackAvatar(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        color: Color(0xFFDB2777),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';

    try {
      DateTime date;
      if (dateValue is int) {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid date';
      }

      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
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
    setState(() => _filteredInstructors.removeWhere(
            (inst) => inst['instructor']['id'] == id));

    try {
      await _adminService.approveInstructor(id);
      _showSnackBar('Instructor approved successfully', Colors.green);
    } catch (e) {
      setState(() => _filteredInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      _loadInstructors();
    }
  }

  Future<void> _handleRejection(int id) async {
    final tempList = List<Map<String, dynamic>>.from(_filteredInstructors);
    setState(() => _filteredInstructors.removeWhere(
            (inst) => inst['instructor']['id'] == id));

    try {
      await _adminService.rejectInstructor(id);
      _showSnackBar('Instructor rejected', Colors.orange);
    } catch (e) {
      setState(() => _filteredInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      _loadInstructors();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showInstructorDetails(Map<String, dynamic> instructor) {
    final instructorData = instructor['instructor'] ?? {};
    final status = instructorData['status']?.toString().toUpperCase() ?? 'UNKNOWN';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                    child: FutureBuilder<Uint8List?>(
                      future: instructor['id'] != null
                          ? _adminService.getImageBytes(instructor['id'])
                          : Future.value(null),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                          );
                        }
                        if (snapshot.hasData) {
                          return ClipOval(
                            child: Image.memory(
                              snapshot.data!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return Text(
                          '${instructor['firstName']?[0] ?? '?'}',
                          style: TextStyle(
                            color: Color(0xFFDB2777),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'.trim(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
              _buildDetailItem(
                Icons.calendar_today,
                'Joined',
                _formatDate(instructor['creationDate']),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFDB2777)),
                    ),
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
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
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