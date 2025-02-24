import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _selectedImage;
  File? _selectedImageForUpdate;

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
    _selectedImage = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            constraints: BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Category',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDB2777),
                    ),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() => _selectedImage = File(pickedFile.path));
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Color(0xFFDB2777).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(0xFFDB2777).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Color(0xFFDB2777),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                color: Color(0xFFDB2777),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
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
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Enter a category name' : null,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleAddCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFDB2777),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Add Category'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddCategory() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final newCategory = await _adminService.addCategory(
        _categoryNameController.text,
        _selectedImage,
      );
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
          Row(
            children: [
              Icon(Icons.category, color: Color(0xFFDB2777), size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Course Categories',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDB2777),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showAddCategoryDialog(context),
                icon: Icon(Icons.add, color: Color(0xFFFFFFFF)),
                style: IconButton.styleFrom(
                  backgroundColor: Color(0xFFDB2777),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(12),
                ),
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
              'Add your first category',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 :
        MediaQuery.of(context).size.width > 800 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildCategoryCard(category, index);
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditDialog(category),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (category['imageUrl'] != null)
                      FutureBuilder<Map<String, String>>(
                        future: _adminService.getImageHeaders(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return CachedNetworkImage(
                              imageUrl: '${AdminService.baseUrl}${category['imageUrl']}',
                              httpHeaders: snapshot.data,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Color(0xFFDB2777).withOpacity(0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Color(0xFFDB2777).withOpacity(0.1),
                                child: Icon(
                                  Icons.broken_image,
                                  color: Color(0xFFDB2777),
                                ),
                              ),
                            );
                          }
                          return Container(
                            color: Color(0xFFDB2777).withOpacity(0.1),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Color(0xFFDB2777).withOpacity(0.1),
                        child: Icon(
                          Icons.category,
                          size: 40,
                          color: Color(0xFFDB2777),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.white),
                            onPressed: () => _showEditDialog(category),
                            style: IconButton.styleFrom(
                              backgroundColor: Color(0xFFDB2777).withOpacity(0.8),
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.white),
                            onPressed: () => _showDeleteConfirmation(category['id']),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                category['name'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn()
        .slideX();
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Category',
          style: TextStyle(color: Colors.red),
        ),
        content: Text('Are you sure you want to delete this category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> category) {
    _categoryNameController.text = category['name'];
    _selectedImageForUpdate = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                Text(
                  'Edit Category',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDB2777),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() => _selectedImageForUpdate = File(pickedFile.path));
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Color(0xFFDB2777).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFFDB2777).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (_selectedImageForUpdate != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImageForUpdate!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (category['imageUrl'] != null)
                            FutureBuilder<Map<String, String>>(
                              future: _adminService.getImageHeaders(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: '${AdminService.baseUrl}${category['imageUrl']}',
                                      httpHeaders: snapshot.data,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Color(0xFFDB2777),
                                      ),
                                    ),
                                  );
                                }
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                                  ),
                                );
                              },
                            )
                          else
                            Icon(
                              Icons.category,
                              size: 40,
                              color: Color(0xFFDB2777),
                            ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(0xFFDB2777),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                TextFormField(
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
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _updateCategory(category['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDB2777),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateCategory(int id) async {
    try {
      final newName = _categoryNameController.text;
      if (newName.isEmpty) {
        _showSnackBar('Category name cannot be empty', Colors.red);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
          ),
        ),
      );

      if (_selectedImageForUpdate != null) {
        await _adminService.updateCategoryWithImage(id, newName, _selectedImageForUpdate);
      } else {
        await _adminService.updateCategory(id, newName);
      }

      await _loadCategories();

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close edit dialog

      _showSnackBar('Category updated successfully', Colors.green);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Error updating category: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
          ),
        ),
      );

      await _adminService.deleteCategory(id);
      await _loadCategories();

      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Category deleted successfully', Colors.green);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showSnackBar('Error deleting category: ${e.toString()}', Colors.red);
    }
  }
}

