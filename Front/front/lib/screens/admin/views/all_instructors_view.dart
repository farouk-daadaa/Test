import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/admin_service.dart';

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
  String _sortBy = 'name'; // 'name', 'email', 'date'
  bool _sortAscending = true;

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
      final name = instructor['name']?.toString().toLowerCase() ?? '';
      final email = instructor['email']?.toString().toLowerCase() ?? '';
      return name.contains(searchLower) || email.contains(searchLower);
    }).toList();

    _filteredInstructors.sort((a, b) {
      if (_sortBy == 'name') {
        return _sortAscending
            ? a['name'].toString().compareTo(b['name'].toString())
            : b['name'].toString().compareTo(a['name'].toString());
      } else if (_sortBy == 'email') {
        return _sortAscending
            ? a['email'].toString().compareTo(b['email'].toString())
            : b['email'].toString().compareTo(a['email'].toString());
      } else {
        // Sort by registration date
        final dateA = DateTime.tryParse(a['registrationDate'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['registrationDate'] ?? '') ?? DateTime.now();
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
          SizedBox(height: 16),
          _buildSearchAndFilter(),
          SizedBox(height: 16),
          Expanded(child: _buildInstructorsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.school, color: Color(0xFFDB2777), size: 32),
        SizedBox(width: 12),
        Text(
          'All Instructors',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
        ),
        Spacer(),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
          SizedBox(height: 16),
          Row(
            children: [
              Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
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
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Email'),
                selected: _sortBy == 'email',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortBy = 'email';
                      _filterAndSortInstructors();
                    });
                  }
                },
                selectedColor: Color(0xFFDB2777).withOpacity(0.2),
              ),
              SizedBox(width: 8),
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
              Spacer(),
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
            SizedBox(height: 16),
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
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
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
            SizedBox(height: 16),
            Text(
              'No instructors found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
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
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
          child: Text(
            instructor['name']?[0]?.toUpperCase() ?? '?',
            style: TextStyle(
              color: Color(0xFFDB2777),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          instructor['name'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              instructor['email'] ?? 'No email',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                SizedBox(width: 4),
                Text(
                  'Joined: ${_formatDate(instructor['registrationDate'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
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
            PopupMenuItem(
              value: 'message',
              child: ListTile(
                leading: Icon(Icons.message, color: Color(0xFFDB2777)),
                title: Text('Send Message'),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'Invalid date';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleMenuAction(String action, Map<String, dynamic> instructor) {
    // Implement menu actions
    switch (action) {
      case 'view':
      // TODO: Implement view details
        break;
      case 'message':
      // TODO: Implement message sending
        break;
    }
  }
}