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
        title: const Text(
          'Filter Courses',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,

      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Filter
                    _buildSectionHeader('Category', Icons.category),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _categoriesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Error loading categories: ${snapshot.error}',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          );
                        }
                        final categories = snapshot.data ?? [{'id': null, 'name': 'All'}];

                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: categories.map((category) {
                            final categoryName = category['name'] ?? 'Unknown';
                            final isSelected = _selectedCategory == categoryName;
                            return ChoiceChip(
                              label: Text(categoryName),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = categoryName;
                                });
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Price Range Filter
                    _buildSectionHeader('Price Range', Icons.attach_money),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '\$${_priceRange.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.grey[300],
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withOpacity(0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            ),
                            child: Slider(
                              value: _priceRange,
                              min: 0,
                              max: 200,
                              divisions: 20,
                              onChanged: (value) {
                                setState(() {
                                  _priceRange = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reviews Filter
                    _buildSectionHeader('Reviews', Icons.star),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildReviewOption('4.5 and above', 5),
                          _buildReviewOption('4.0 - 4.5', 4),
                          _buildReviewOption('3.5 - 4.0', 3),
                          _buildReviewOption('3.0 - 3.5', 3),
                          _buildReviewOption('Below 3.0', 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Language Filter
                    _buildSectionHeader('Language', Icons.language),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _languages.map((language) {
                        final isSelected = _selectedLanguage == language;
                        return ChoiceChip(
                          label: Text(
                            language == 'All' ? language : _formatEnumValue(language),
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedLanguage = language;
                            });
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Course Level Filter
                    _buildSectionHeader('Course Level', Icons.school),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _levels.map((level) {
                        final isSelected = _selectedLevel == level;
                        return ChoiceChip(
                          label: Text(
                            level == 'All' ? level : _formatEnumValue(level),
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedLevel = level;
                            });
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewOption(String label, int starCount) {
    final isSelected = _selectedReviewRange == label;

    return RadioListTile<String>(
      title: Row(
        children: [
          ...List.generate(5, (index) {
            return Icon(
              index < starCount ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 20,
            );
          }),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
      value: label,
      groupValue: _selectedReviewRange,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: true,
      onChanged: (value) {
        setState(() {
          _selectedReviewRange = value!;
        });
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), // Added bottom padding
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = 'All';
                  _priceRange = 200.0;
                  _selectedReviewRange = 'All';
                  _selectedLanguage = 'All';
                  _selectedLevel = 'All';
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Reset Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final filteredCourses = _applyFilters(widget.allCourses);
                widget.onApply(filteredCourses);
                // Do NOT call Navigator.pop(context) here as per original code
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEnumValue(String value) {
    // Convert UPPERCASE_WITH_UNDERSCORES to Title Case
    return value.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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

