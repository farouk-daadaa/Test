import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/image_service.dart';
import '../homepage/HomeScreen.dart';

// Filter Screen
class FilterScreen extends StatefulWidget {
  final List<CourseDTO> allCourses;
  final Function(List<CourseDTO>) onApply;

  const FilterScreen({super.key, required this.allCourses, required this.onApply});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String _selectedCategory = 'All'; // Default to "All"
  double _priceRange = 200.0;
  String _selectedReviewRange = 'All';
  String _selectedLanguage = 'All';
  String _selectedLevel = 'All'; // Default to "All" for levels

  // Use Future to fetch categories dynamically
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late List<Map<String, dynamic>> _categories;

  final List<String> _languages = ['All', 'ENGLISH', 'TUNISIAN', 'FRENCH']; // Match enum values (uppercase)
  final List<String> _levels = ['All', 'BEGINNER', 'INTERMEDIATE', 'EXPERT']; // Add "All" and use strings to match enum

  // Review ranges
  final List<String> _reviewRanges = [
    'All',
    '4.5 and above',
    '4.0 - 4.5',
    '3.5 - 4.0',
    'Below 3.5'
  ];

  @override
  void initState() {
    super.initState();
    // Fetch categories from AdminService
    final adminService = Provider.of<AdminService>(context, listen: false);
    _categoriesFuture = adminService.getAllCategories().then((categories) {
      // Add "All" as the first option
      _categories = [{'id': null, 'name': 'All'}] +
          categories.map((cat) => {
            'id': cat['id']?.toString(), // Ensure 'id' is String?
            'name': cat['name']?.toString()
          }).toList();
      return _categories;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Filter', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter
              const Text('Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error loading categories: ${snapshot.error}');
                  }
                  final categories = snapshot.data ?? [{'id': null, 'name': 'All'}];

                  return Wrap(
                    spacing: 8.0,
                    children: categories.map((category) {
                      final categoryName = category['name'] ?? 'Unknown';
                      return ChoiceChip(
                        label: Text(categoryName),
                        selected: _selectedCategory == categoryName,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = categoryName;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Price Range Filter
              const Text('Price Range',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: _priceRange,
                min: 0,
                max: 200,
                divisions: 20,
                label: _priceRange.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() {
                    _priceRange = value;
                  });
                },
              ),
              Text('Max: ${_priceRange.toStringAsFixed(0)}'),
              const SizedBox(height: 16),

              // Reviews Filter
              const Text('Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Column(
                children: _reviewRanges.map((range) {
                  return RadioListTile<String>(
                    title: Text(range),
                    value: range,
                    groupValue: _selectedReviewRange,
                    onChanged: (value) {
                      setState(() {
                        _selectedReviewRange = value!;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Language Filter
              const Text('Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: _languages.map((language) {
                  return ChoiceChip(
                    label: Text(language),
                    selected: _selectedLanguage == language,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLanguage = language;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Course Level Filter
              const Text('Course Level',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: _levels.map((level) {
                  return ChoiceChip(
                    label: Text(level),
                    selected: _selectedLevel == level,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLevel = level;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Bottom Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _priceRange = 200.0;
                        _selectedReviewRange = 'All';
                        _selectedLanguage = 'All';
                        _selectedLevel = 'All';
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Reset Filter'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final filteredCourses = _applyFilters(widget.allCourses);
                      widget.onApply(filteredCourses); // Pass filtered courses back to the parent
                      // Do NOT call Navigator.pop(context) here
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CourseDTO> _applyFilters(List<CourseDTO> courses) {
    return courses.where((course) {
      // Category Filter
      bool matchesCategory = _selectedCategory == 'All' ||
          course.categoryId.toString() ==
              (_categories.firstWhere(
                    (category) => category['name'] == _selectedCategory,
                orElse: () => {'id': '-1'} as Map<String, String?>,
              )['id'] ??
                  '-1');

      // Price Filter
      bool matchesPrice = course.price <= Decimal.fromInt(_priceRange.toInt());

      // Review Filter
      bool matchesReview = _selectedReviewRange == 'All' ||
          (_selectedReviewRange == '4.5 and above' && (course.rating ?? 0) >= 4.5) ||
          (_selectedReviewRange == '4.0 - 4.5' && (course.rating ?? 0) >= 4.0 && (course.rating ?? 0) < 4.5) ||
          (_selectedReviewRange == '3.5 - 4.0' && (course.rating ?? 0) >= 3.5 && (course.rating ?? 0) < 4.0) ||
          (_selectedReviewRange == 'Below 3.5' && (course.rating ?? 0) < 3.5);

      // Language Filter
      bool matchesLanguage = _selectedLanguage == 'All' ||
          course.language.toString().split('.').last.toUpperCase() == _selectedLanguage;

      // Level Filter
      bool matchesLevel = _selectedLevel == 'All' ||
          course.level.toString().split('.').last.toUpperCase() == _selectedLevel;

      return matchesCategory && matchesPrice && matchesReview && matchesLanguage && matchesLevel;
    }).toList();
  }
}