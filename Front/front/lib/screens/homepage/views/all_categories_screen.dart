import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../services/admin_service.dart';

class AllCategoriesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const AllCategoriesScreen({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Category',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8, // Adjusted to accommodate image and text
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final imageUrl = AdminService.getCategoryImageUrl(category['imageUrl']);

            return Container(
              constraints: const BoxConstraints(
                minHeight: 100,
                maxHeight: 120,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade100,
                      ),
                      child: category['imageUrl'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              _getCategoryIcon(category['name']),
                              color: Colors.blue,
                              size: 30,
                            );
                          },
                        ),
                      )
                          : Icon(
                        _getCategoryIcon(category['name']),
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      category['name'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    return Icons.category;
  }
}