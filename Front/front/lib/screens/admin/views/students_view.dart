import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'courses'
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
      setState(() => _error = e.toString());
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
          DateTime? dateA = _parseDate(a['CreationDate']);
          DateTime? dateB = _parseDate(b['CreationDate']);
          dateA ??= DateTime.now();
          dateB ??= DateTime.now();
          return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        default:
          return 0;
      }
    });
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
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
      onPressed: _loadStudents,
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
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Color(0xFFDB2777),
                  ),
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
    final enrolledCourses = _students.fold<int>(
        0, (sum, student) => sum + ((student['courses'] as List?)?.length ?? 0));

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            icon: Icons.people,
            label: 'Total Students',
            value: totalStudents.toString(),
          ),
          _buildStatCard(
            icon: Icons.person_outline,
            label: 'Active Students',
            value: activeStudents.toString(),
          ),
          _buildStatCard(
            icon: Icons.book,
            label: 'Total Enrollments',
            value: enrolledCourses.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFDB2777), size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDB2777),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsList() {
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
              'Loading students...',
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
              onPressed: _loadStudents,
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

    if (_filteredStudents.isEmpty) {
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
              'No students found',
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
      onRefresh: _loadStudents,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          return _buildStudentCard(student, index);
        },
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final courses = (student['courses'] as List?)?.length ?? 0;
    final isActive = student['isActive'] ?? false;
    final firstName = student['firstName'] ?? '';
    final lastName = student['lastName'] ?? '';
    final name = '$firstName $lastName'.trim(); // Combine first and last name
    final email = student['email'] ?? 'No email';

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
        leading: FutureBuilder<Uint8List?>(
          future: student['id'] != null
              ? _adminService.getImageBytes(student['id'])
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
            SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.book, size: 14, color: Colors.grey[500]),
                SizedBox(width: 4),
                Text(
                  '$courses ${courses == 1 ? 'course' : 'courses'} enrolled',
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
    final name = '$firstName $lastName'.trim(); // Combine first and last name
    final email = student['email'] ?? 'No email';
    final username = student['username'] ?? 'No username';
    final gender = student['gender'] ?? 'No gender';
    final phoneNumber = student['phoneNumber'] ?? 'No phone number';
    final creationDate = _formatDate(student['CreationDate']);
    final courses = (student['courses'] as List?)?.length ?? 0;
    final isActive = student['isActive'] ?? false;

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
                      future: student['id'] != null
                          ? _adminService.getImageBytes(student['id'])
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
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                              color: isActive ? Colors.green : Colors.grey,
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
}