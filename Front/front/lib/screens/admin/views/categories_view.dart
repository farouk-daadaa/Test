import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({Key? key}) : super(key: key);

  @override
  _CategoriesViewState createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await _adminService.getAllCategories();
      setState(() => _categories = categories);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _isLoading = false);
  }

  void _showAddCategoryDialog(BuildContext context) {
    _categoryNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Color(0xFFDB2777)),
            SizedBox(width: 8),
            Text('Add Category'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _categoryNameController,
            decoration: InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFDB2777)),
              ),
              prefixIcon: Icon(Icons.category, color: Color(0xFFDB2777)),
            ),
            validator: (value) =>
            value?.isEmpty ?? true ? 'Please enter a category name' : null,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
          ElevatedButton(
            onPressed: _handleAddCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDB2777),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddCategory() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final newCategory =
      await _adminService.addCategory(_categoryNameController.text);
      setState(() => _categories.insert(0, newCategory));
      Navigator.pop(context);
      _showSnackBar('Category added successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
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
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category,
                    color: Color(0xFFDB2777),
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Course Categories',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDB2777),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFDB2777),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showAddCategoryDialog(context),
              ),
            ],
          ),
          SizedBox(height: 24),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
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
              'Loading categories...',
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
              onPressed: _loadCategories,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No categories found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add a category to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: Color(0xFFDB2777),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryItem(category, index);
        },
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category, int index) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color(0xFFDB2777).withOpacity(0.1),
          child: Text(
            category['name']?[0]?.toUpperCase() ?? '?',
            style: TextStyle(
              color: Color(0xFFDB2777),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          category['name'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: SizedBox(
          width: 96, // Fixed width for action buttons
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Color(0xFFDB2777)),
                tooltip: 'Edit category',
                onPressed: () => _showEditDialog(context, category),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete category',
                onPressed: () => _showDeleteConfirmation(category),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().slideX();
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> category) {
    final controller = TextEditingController(text: category['name']);
    final originalName = category['name'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Color(0xFFDB2777)),
            SizedBox(width: 8),
            Text('Edit Category'),
          ],
        ),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFDB2777)),
            ),
            prefixIcon: Icon(Icons.category, color: Color(0xFFDB2777)),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                _handleUpdateCategory(category, controller.text, originalName),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDB2777),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Category'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${category['name']}"? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateCategory(
      Map<String, dynamic> category, String newName, String originalName) async {
    if (newName.isEmpty) {
      _showSnackBar('Category name cannot be empty', Colors.red);
      return;
    }

    final index = _categories.indexWhere((c) => c['id'] == category['id']);
    if (index == -1) return;

    setState(() => _categories[index]['name'] = newName);
    Navigator.pop(context);

    try {
      await _adminService.updateCategory(category['id'], newName);
      _showSnackBar('Category updated successfully', Colors.green);
      await _loadCategories();
    } catch (e) {
      setState(() => _categories[index]['name'] = originalName);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final tempCategories = List<Map<String, dynamic>>.from(_categories);
    setState(() => _categories.removeWhere((cat) => cat['id'] == id));

    try {
      await _adminService.deleteCategory(id);
      _showSnackBar('Category deleted successfully', Colors.green);
      await _loadCategories();
    } catch (e) {
      setState(() => _categories = tempCategories);
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }
}