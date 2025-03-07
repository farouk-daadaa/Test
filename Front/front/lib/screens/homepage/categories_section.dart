import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/admin_service.dart';
import '../../services/course_service.dart';
import 'views/all_categories_screen.dart';

typedef CategorySelectedCallback = void Function(String categoryId, String categoryName);

class CategoriesSection extends StatelessWidget {
  final List<CourseDTO> allCourses; // Added to receive courses from HomeScreen
  final CategorySelectedCallback onCategorySelected; // Callback from HomeScreen

  const CategoriesSection({
    super.key,
    required this.allCourses,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: adminService.getAllCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final categories = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllCategoriesScreen(
                            categories: categories,
                            allCourses: allCourses, // Pass the received allCourses
                            onCategorySelected: onCategorySelected, // Pass the callback
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final imageUrl = AdminService.getCategoryImageUrl(category['imageUrl']);

                  return GestureDetector(
                    onTap: () {
                      onCategorySelected(category['id']?.toString() ?? '-1', category['name'] ?? 'Unknown');
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: category['imageUrl'] == null
                              ? Icon(
                            _getCategoryIcon(category['name']),
                            color: AppColors.primary,
                          )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['name'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    return Icons.category;
  }
}