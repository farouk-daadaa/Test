// lib/screens/homepage/views/instructor_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:front/constants/colors.dart';
import 'package:front/services/image_service.dart';
import 'package:front/services/instructor_service.dart' as instructorService; // Alias for clarity
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:decimal/decimal.dart';

// Local definitions for this file only
enum LocalCourseLanguage { ENGLISH, FRENCH, TUNISIAN }
enum LocalCourseLevel { BEGINNER, INTERMEDIATE, EXPERT }
enum LocalPricingType { FREE, PAID }

class LocalCourseDTO {
  final int? id;
  final String title;
  final String description;
  final Decimal price;
  final LocalPricingType pricingType;
  final double? rating;
  final int totalReviews;
  final String imageUrl;
  final LocalCourseLevel level;
  final LocalCourseLanguage language;
  final int totalStudents;
  final DateTime? lastUpdate;
  final int categoryId;
  final String? instructorName;
  bool isBookmarked;

  LocalCourseDTO({
    this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.pricingType,
    this.rating,
    this.totalReviews = 0,
    required this.imageUrl,
    required this.level,
    required this.language,
    this.totalStudents = 0,
    this.lastUpdate,
    required this.categoryId,
    this.instructorName,
    this.isBookmarked = false,
  });

  factory LocalCourseDTO.fromJson(Map<String, dynamic> json) {
    return LocalCourseDTO(
      id: json['id'] != null ? json['id'] as int : 0,
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      price: Decimal.parse(json['price']?.toString() ?? '0.0'),
      pricingType: LocalPricingType.values.firstWhere(
            (e) => e.toString().split('.').last == json['pricingType'],
        orElse: () => LocalPricingType.FREE,
      ),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      totalReviews: json['totalReviews'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
      level: LocalCourseLevel.values.firstWhere(
            (e) => e.toString().split('.').last == json['level'],
        orElse: () => LocalCourseLevel.BEGINNER,
      ),
      language: LocalCourseLanguage.values.firstWhere(
            (e) => e.toString().split('.').last == json['language'],
        orElse: () => LocalCourseLanguage.ENGLISH,
      ),
      totalStudents: json['totalStudents'] ?? 0,
      lastUpdate: json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate']) : null,
      categoryId: json['categoryId'] ?? 0,
      instructorName: json['instructorName'],
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }
}

class InstructorProfileScreen extends StatefulWidget {
  final int instructorId;
  final String instructorName;

  const InstructorProfileScreen({
    Key? key,
    required this.instructorId,
    required this.instructorName,
  }) : super(key: key);

  @override
  _InstructorProfileScreenState createState() => _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  late instructorService.InstructorService _instructorService;
  late ImageService _imageService;
  instructorService.InstructorProfileDTO? _profile;
  List<LocalCourseDTO> _courses = [];
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _instructorService = instructorService.InstructorService();
    _imageService = ImageService();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      if (token == null) throw Exception('No authentication token found');

      _instructorService.setToken(token);
      _imageService.setToken(token);

      print('Fetching profile for instructorId: ${widget.instructorId}');
      final profile = await _instructorService.getInstructorProfile(widget.instructorId);
      print('Profile fetched: ${profile.username}, isFollowed: ${profile.isFollowed}, '
          'followers: ${profile.followersCount}, avgRating: ${profile.averageRating}, '
          'students: ${profile.totalStudents}');

      final courses = await _instructorService.getInstructorCourses(widget.instructorId);
      print('Courses fetched: ${courses.length} courses');

      final userId = await _instructorService.getUserIdByInstructorId(widget.instructorId);
      Uint8List? imageBytes;
      if (userId != null) {
        print('Fetching image for userId: $userId');
        imageBytes = await _imageService.getUserImage(context, userId);
        print('Image bytes: ${imageBytes?.length ?? 0} bytes');
      }

      setState(() {
        _profile = profile;
        _courses = courses.map((course) => LocalCourseDTO(
          id: course.id,
          title: course.title,
          description: course.description,
          price: course.price,
          pricingType: LocalPricingType.values.firstWhere(
                (e) => e.toString().split('.').last == course.pricingType.toString().split('.').last,
            orElse: () => LocalPricingType.FREE,
          ),
          rating: course.rating,
          totalReviews: course.totalReviews,
          imageUrl: course.imageUrl,
          level: LocalCourseLevel.values.firstWhere(
                (e) => e.toString().split('.').last == course.level.toString().split('.').last,
            orElse: () => LocalCourseLevel.BEGINNER,
          ),
          language: LocalCourseLanguage.values.firstWhere(
                (e) => e.toString().split('.').last == course.language.toString().split('.').last,
            orElse: () => LocalCourseLanguage.ENGLISH,
          ),
          totalStudents: course.totalStudents,
          lastUpdate: course.lastUpdate,
          categoryId: course.categoryId,
          instructorName: course.instructorName,
          isBookmarked: course.isBookmarked,
        )).toList();
        _imageBytes = imageBytes;
        _isLoading = false;
      });
    } catch (e) {
      print('Fetch error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    setState(() => _isLoading = true);
    try {
      if (_profile!.isFollowed) {
        await _instructorService.unfollowInstructor(widget.instructorId);
      } else {
        await _instructorService.followInstructor(widget.instructorId);
      }
      await _fetchData();
    } catch (e) {
      print('Toggle follow error: $e');
      String errorMessage = 'Error: $e';
      if (e.toString().contains('409')) {
        errorMessage = 'You already follow this instructor';
      } else if (e.toString().contains('404')) {
        errorMessage = 'You are not following this instructor';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.instructorName}\'s Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _profile == null
          ? const Center(child: Text('Profile not found'))
          : CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageBytes != null && _imageBytes!.isNotEmpty
                        ? MemoryImage(_imageBytes!)
                        : null,
                    child: _imageBytes == null || _imageBytes!.isEmpty
                        ? Text(
                      widget.instructorName[0],
                      style: const TextStyle(fontSize: 40, color: AppColors.primary),
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_profile!.firstName} ${_profile!.lastName}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${_profile!.username}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textGray),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 16,
                    children: [
                      _buildStat('Followers', _profile!.followersCount),
                      _buildStat('Courses', _profile!.coursesCount),
                      _buildStat('Reviews', _profile!.totalReviews),
                      _buildStat('Avg Rating', _profile!.averageRating.toStringAsFixed(1)),
                      _buildStat('Students', _profile!.totalStudents),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (authService.token != null)
                    ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _profile!.isFollowed ? AppColors.secondary : AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _profile!.isFollowed ? 'Unfollow' : 'Follow',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses by ${widget.instructorName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  _courses.isEmpty
                      ? const Text('No courses available yet.')
                      : Column(
                    children: _courses.map((course) => _buildCourseCard(course)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, dynamic value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
        ),
      ],
    );
  }

  Widget _buildCourseCard(LocalCourseDTO course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: course.imageUrl.isNotEmpty
            ? Image.network(
          course.imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 50, color: AppColors.primary),
        )
            : const Icon(Icons.book, size: 50, color: AppColors.primary),
        title: Text(course.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          course.description,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            Text(
              course.rating?.toStringAsFixed(1) ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped ${course.title} - Coming soon!')),
          );
        },
      ),
    );
  }
}