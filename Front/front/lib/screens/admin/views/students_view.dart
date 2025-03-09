import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute
import '../../../services/admin_service.dart';
import 'dart:typed_data';

class StudentsView extends StatefulWidget {
  const StudentsView({Key? key}) : super(key: key);

  @override
  _StudentsViewState createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final Map<int, Uint8List?> _imageCache = {}; // Cache for images
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final students = await _adminService.getAllStudents();
      setState(() {
        _students = students;
        _filterAndSortStudents();
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _error = 'Failed to load students. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAndSortStudents() {
    _filteredStudents = _students.where((student) {
      final searchLower = _searchQuery.toLowerCase();
      final name = '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.toLowerCase();
      final email = student['email']?.toString().toLowerCase() ?? '';
      return name.contains(searchLower) || email.contains(searchLower);
    }).toList();

    if (_filteredStudents.length > 50) {
      compute(_sortStudents, {
        'students': _filteredStudents,
        'sortBy': _sortBy,
        'sortAscending': _sortAscending,
      }).then((sorted) {
        if (mounted) {
          setState(() => _filteredStudents = sorted);
        }
      });
    } else {
      _filteredStudents.sort((a, b) {
        switch (_sortBy) {
          case 'name':
            final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
            final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
            return _sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
          case 'courses':
            final coursesA = (a['courses'] as List?)?.length ?? 0;
            final coursesB = (b['courses'] as List?)?.length ?? 0;
            return _sortAscending ? coursesA.compareTo(coursesB) : coursesB.compareTo(coursesA);
          case 'creationDate':
            DateTime? dateA = _parseDate(a['creationDate']);
            DateTime? dateB = _parseDate(b['creationDate']);
            dateA ??= DateTime.now();
            dateB ??= DateTime.now();
            return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
          default:
            return 0;
        }
      });
      setState(() {});
    }
  }

  static List<Map<String, dynamic>> _sortStudents(Map<String, dynamic> params) {
    final students = params['students'] as List<Map<String, dynamic>>;
    final sortBy = params['sortBy'] as String;
    final sortAscending = params['sortAscending'] as bool;

    students.sort((a, b) {
      switch (sortBy) {
        case 'name':
          final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
          final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
          return sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        case 'courses':
          final coursesA = (a['courses'] as List?)?.length ?? 0;
          final coursesB = (b['courses'] as List?)?.length ?? 0;
          return sortAscending ? coursesA.compareTo(coursesB) : coursesB.compareTo(coursesA);
        case 'creationDate':
          DateTime? dateA = _parseDate(a['creationDate']);
          DateTime? dateB = _parseDate(b['creationDate']);
          dateA ??= DateTime.now();
          dateB ??= DateTime.now();
          return sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        default:
          return 0;
      }
    });
    return students;
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
          SizedBox(height: 16),
          _buildSearchAndFilter(),
          SizedBox(height: 16),
          _buildStats(),
          SizedBox(height: 16),
          Expanded(child: _buildStudentsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.people, color: Color(0xFFDB2777), size: 32),
        SizedBox(width: 12),
        Text(
          'Students',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDB2777)),
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
      onPressed: _loadStudents,
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterAndSortStudents();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search students...',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                        _filterAndSortStudents();
                      });
                    }
                  },
                  selectedColor: Color(0xFFDB2777).withOpacity(0.2),
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Courses'),
                  selected: _sortBy == 'courses',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sortBy = 'courses';
                        _filterAndSortStudents();
                      });
                    }
                  },
                  selectedColor: Color(0xFFDB2777).withOpacity(0.2),
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Creation Date'),
                  selected: _sortBy == 'creationDate',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sortBy = 'creationDate';
                        _filterAndSortStudents();
                      });
                    }
                  },
                  selectedColor: Color(0xFFDB2777).withOpacity(0.2),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Color(0xFFDB2777)),
                  onPressed: () {
                    setState(() {
                      _sortAscending = !_sortAscending;
                      _filterAndSortStudents();
                    });
                  },
                  tooltip: _sortAscending ? 'Sort ascending' : 'Sort descending',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final totalStudents = _students.length;
    final activeStudents = _students.where((s) => s['isActive'] == true).length;
    final enrolledCourses = _students.fold<int>(0, (sum, student) => sum + ((student['courses'] as List?)?.length ?? 0));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(icon: Icons.people, label: 'Total Students', value: totalStudents.toString()),
          _buildStatCard(icon: Icons.person_outline, label: 'Active Students', value: activeStudents.toString()),
          _buildStatCard(icon: Icons.book, label: 'Total Enrollments', value: enrolledCourses.toString()),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFDB2777), size: 24),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDB2777))),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStudentsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777))),
            SizedBox(height: 16),
            Text('Loading students...', style: TextStyle(color: Colors.grey[600])),
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
            Text(_error!, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStudents,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFDB2777), foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No students found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Try adjusting your search', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        cacheExtent: 2000, // Increased for smoother scrolling
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index]),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final courses = (student['courses'] as List?)?.length ?? 0;
    final isActive = student['isActive'] ?? false;
    final firstName = student['firstName'] ?? '';
    final lastName = student['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = student['email'] ?? 'No email';
    final id = student['id'];

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
          child: _buildStudentAvatar(id, name),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.book, size: 14, color: Colors.grey[500]),
                SizedBox(width: 4),
                Text('$courses ${courses == 1 ? 'course' : 'courses'} enrolled',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Color(0xFFDB2777)),
          onSelected: (value) => _handleMenuAction(value, student),
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
              value: 'courses',
              child: ListTile(
                leading: Icon(Icons.book, color: Color(0xFFDB2777)),
                title: Text('View Courses'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(int? id, String name) {
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
          print('Error loading image for student $id: ${snapshot.error}');
          _imageCache[id] = null;
          return _buildFallbackAvatar(name);
        }
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          _imageCache[id] = snapshot.data;
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
        print('No valid image data for student $id');
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

  void _handleMenuAction(String action, Map<String, dynamic> student) {
    switch (action) {
      case 'view':
        _showStudentDetails(student);
        break;
      case 'courses':
      // TODO: Implement view courses
        break;
    }
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    final firstName = student['firstName'] ?? '';
    final lastName = student['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = student['email'] ?? 'No email';
    final username = student['username'] ?? 'No username';
    final gender = student['gender'] ?? 'No gender';
    final phoneNumber = student['phoneNumber'] ?? 'No phone number';
    final creationDate = _formatDate(student['creationDate']);
    final courses = (student['courses'] as List?)?.length ?? 0;
    final isActive = student['isActive'] ?? false;
    final id = student['id'];

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
                    child: _buildStudentAvatar(id, name),
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
                            color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildDetailItem(Icons.email, 'Email', email),
              _buildDetailItem(Icons.person, 'Username', username),
              _buildDetailItem(Icons.transgender, 'Gender', gender),
              _buildDetailItem(Icons.phone, 'Phone Number', phoneNumber),
              _buildDetailItem(Icons.calendar_today, 'Creation Date', creationDate),
              _buildDetailItem(Icons.book, 'Courses Enrolled', '$courses'),
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
}