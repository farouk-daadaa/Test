import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class AllCategoriesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const AllCategoriesScreen({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(category['name']),
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                category['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Handle category tap (e.g., navigate to category details)
              },
            ),
          );
        },
      ),
    );
  }

  // Reuse the same icon mapping logic
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'art':
        return Icons.palette;
      case 'coding':
        return Icons.code;
      case 'marketing':
        return Icons.trending_up;
      case 'business':
        return Icons.business;
      default:
        return Icons.category;
    }
  }
}