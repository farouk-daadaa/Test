import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';
import '../../../services/image_service.dart';
import '../../../services/instructor_service.dart'; // Add this import
import 'instructor_profile_screen.dart';

class AllInstructorsScreen extends StatefulWidget {
  const AllInstructorsScreen({super.key});

  @override
  State<AllInstructorsScreen> createState() => _AllInstructorsScreenState();
}

class _AllInstructorsScreenState extends State<AllInstructorsScreen> {
  late AuthService _authService;
  late CourseService _courseService;
  late ImageService _imageService;
  late InstructorService _instructorService; // Add InstructorService
  List<Map<String, dynamic>> _instructors = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _authService = Provider.of<AuthService>(context, listen: false);
    _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
    _imageService = ImageService();
    _instructorService = InstructorService(); // Initialize InstructorService
    final token = await _authService.getToken();
    if (token != null) {
      _courseService.setToken(token);
      _imageService.setToken(token);
      _instructorService.setToken(token); // Set token for InstructorService
      await _fetchAllInstructors(token);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
    }
  }

  Future<void> _fetchAllInstructors(String token) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allCourses = await _courseService.getAllCourses();
      final instructorData = <String, Map<String, dynamic>>{};

      for (var course in allCourses) {
        if (course.instructorName != null) {
          final instructorName = course.instructorName!;
          if (!instructorData.containsKey(instructorName)) {
            final instructorId = await _instructorService.getInstructorIdByUsername(instructorName); // Use InstructorService
            Uint8List? imageBytes;
            if (instructorId != null) {
              final userId = await _instructorService.getUserIdByInstructorId(instructorId); // Get userId for image
              if (userId != null) {
                imageBytes = await _imageService.getUserImage(context, userId);
              }
            }
            instructorData[instructorName] = {
              'id': instructorId, // Store instructorId
              'name': instructorName,
              'image': imageBytes,
              'courseCount': 0,
              'avgRating': 0.0,
              'ratings': <double>[],
            };
          }
          instructorData[instructorName]!['courseCount'] = (instructorData[instructorName]!['courseCount'] as int) + 1;
          if (course.rating != null) {
            instructorData[instructorName]!['ratings'].add(course.rating!);
          }
        }
      }

      final instructorsList = instructorData.values.map((data) {
        final ratings = data['ratings'] as List<double>;
        final avgRating = ratings.isNotEmpty ? ratings.reduce((a, b) => a + b) / ratings.length : 0.0;
        return {
          'id': data['id'] as int?, // instructorId
          'name': data['name'] as String,
          'image': data['image'] as Uint8List?,
          'courseCount': data['courseCount'] as int,
          'avgRating': avgRating,
        };
      }).toList();

      instructorsList.sort((a, b) => (b['avgRating'] as double).compareTo(a['avgRating'] as double));

      setState(() {
        _instructors = instructorsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load instructors: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _instructors.isEmpty
          ? _buildEmptyState()
          : _buildInstructorsList(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'All Instructors',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            showSearch(
              context: context,
              delegate: InstructorSearchDelegate(_instructors),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 102,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchAllInstructors(_authService.token!),
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorMessage!.length > 100 ? '${_errorMessage!.substring(0, 97)}...' : _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _fetchAllInstructors(_authService.token!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No instructors found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any instructors at the moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorsList() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchAllInstructors(_authService.token!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _instructors.length,
        itemBuilder: (context, index) {
          final instructor = _instructors[index];
          return _buildInstructorCard(instructor, index);
        },
      ),
    );
  }

  Widget _buildInstructorCard(Map<String, dynamic> instructor, int index) {
    final avgRating = instructor['avgRating'] as double;
    final courseCount = instructor['courseCount'] as int;
    final instructorId = instructor['id'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Semantics(
        label: 'Instructor ${instructor['name']}, $courseCount courses, rating $avgRating',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (instructorId != null) {
                print('Navigating to profile for instructorId: $instructorId, name: ${instructor['name']}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstructorProfileScreen(
                      instructorId: instructorId,
                      instructorName: instructor['name'] as String,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Instructor ID not available'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildInstructorAvatar(instructor, index),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                instructor['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (index < 3) _buildTopInstructorBadge(index),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.book,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$courseCount ${courseCount == 1 ? 'Course' : 'Courses'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildRatingStars(avgRating),
                            const SizedBox(width: 8),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorAvatar(Map<String, dynamic> instructor, int index) {
    return Stack(
      children: [
        Hero(
          tag: 'instructor-${instructor['name']}',
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: instructor['image'] != null
                  ? MemoryImage(instructor['image'] as Uint8List)
                  : null,
              backgroundColor: instructor['image'] == null
                  ? AppColors.primary.withOpacity(0.1)
                  : null,
              child: instructor['image'] == null
                  ? Text(
                (instructor['name'] as String)[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
                  : null,
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.star,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopInstructorBadge(int index) {
    final colors = [
      Colors.amber,
      Colors.blueGrey,
      Colors.brown.shade300,
    ];
    final labels = ['Top Rated', '2nd Best', '3rd Best'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[index].withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[index], width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 12,
            color: colors[index],
          ),
          const SizedBox(width: 4),
          Text(
            labels[index],
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors[index],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, size: 16, color: Colors.amber[700]);
        } else if (index < rating.ceil() && rating.floor() != rating.ceil()) {
          return Icon(Icons.star_half, size: 16, color: Colors.amber[700]);
        } else {
          return Icon(Icons.star_border, size: 16, color: Colors.amber[700]);
        }
      }),
    );
  }
}

class InstructorSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> instructors;

  InstructorSearchDelegate(this.instructors);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = instructors
        .where((instructor) => instructor['name'].toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: filtered[index]['image'] != null
              ? MemoryImage(filtered[index]['image'] as Uint8List)
              : null,
          backgroundColor: filtered[index]['image'] == null
              ? AppColors.primary.withOpacity(0.1)
              : null,
          child: filtered[index]['image'] == null
              ? Text(
            (filtered[index]['name'] as String)[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          )
              : null,
        ),
        title: Text(filtered[index]['name']),
        subtitle: Text(
          'Courses: ${filtered[index]['courseCount']} | Rating: ${(filtered[index]['avgRating'] as double).toStringAsFixed(1)}',
        ),
        onTap: () {
          final instructorId = filtered[index]['id'] as int?;
          if (instructorId != null) {
            print('Navigating to profile from search for instructorId: $instructorId, name: ${filtered[index]['name']}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InstructorProfileScreen(
                  instructorId: instructorId,
                  instructorName: filtered[index]['name'] as String,
                ),
              ),
            ).then((_) {
              // Close the search overlay after navigation
              close(context, null);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Instructor ID not available'),
                duration: Duration(seconds: 2),
              ),
            );
            close(context, null); // Still close if no ID
          }
        },
      ),
    );
  }
}