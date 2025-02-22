import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PendingInstructorsView extends StatefulWidget {
  const PendingInstructorsView({Key? key}) : super(key: key);

  @override
  _PendingInstructorsViewState createState() => _PendingInstructorsViewState();
}

class _PendingInstructorsViewState extends State<PendingInstructorsView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _pendingInstructors = [];

  @override
  void initState() {
    super.initState();
    _loadPendingInstructors();
  }

  Future<void> _loadPendingInstructors() async {
    setState(() => _isLoading = true);
    try {
      final instructors = await _adminService.getPendingInstructors();
      setState(() => _pendingInstructors = instructors);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleApproval(int id) async {
    final tempList = List<Map<String, dynamic>>.from(_pendingInstructors);
    setState(() => _pendingInstructors.removeWhere(
            (inst) => inst['instructor']['id'] == id));

    try {
      await _adminService.approveInstructor(id);
      _showSnackBar('Instructor approved successfully', Colors.green);
    } catch (e) {
      setState(() => _pendingInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      _loadPendingInstructors();
    }
  }

  Future<void> _handleRejection(int id) async {
    final tempList = List<Map<String, dynamic>>.from(_pendingInstructors);
    setState(() => _pendingInstructors.removeWhere(
            (inst) => inst['instructor']['id'] == id));

    try {
      await _adminService.rejectInstructor(id);
      _showSnackBar('Instructor rejected', Colors.orange);
    } catch (e) {
      setState(() => _pendingInstructors = tempList);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      _loadPendingInstructors();
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: Color(0xFFDB2777),
                size: 32,
              ),
              SizedBox(width: 12),
              Text(
                'Pending Instructors',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDB2777),
                ),
              ),
            ],
          ).animate().fadeIn().slideX(),
          SizedBox(height: 24),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
              'Loading pending instructors...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
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
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingInstructors,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_pendingInstructors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.grey[400],
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No pending instructors',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingInstructors,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        itemCount: _pendingInstructors.length,
        itemBuilder: (context, index) {
          final instructor = _pendingInstructors[index];
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Show more details if needed
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFDB2777),
                    child: Text(
                      (instructor['firstName']?.isNotEmpty ?? false)
                          ? instructor['firstName'][0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          instructor['email'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (instructor['phoneNumber'] != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      instructor['phoneNumber'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _handleRejection(instructor['instructor']['id']),
                    icon: Icon(Icons.close),
                    label: Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleApproval(instructor['instructor']['id']),
                    icon: Icon(Icons.check),
                    label: Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX();
  }
}