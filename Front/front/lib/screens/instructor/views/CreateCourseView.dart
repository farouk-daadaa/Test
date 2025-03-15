import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:decimal/decimal.dart';
import '../../../services/admin_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/course_service.dart';
import 'package:path_provider/path_provider.dart';

class CreateCourseView extends StatefulWidget {
  const CreateCourseView({Key? key}) : super(key: key);

  @override
  _CreateCourseViewState createState() => _CreateCourseViewState();
}

class _CreateCourseViewState extends State<CreateCourseView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  CourseLevel _selectedLevel = CourseLevel.BEGINNER;
  CourseLanguage _selectedLanguage = CourseLanguage.ENGLISH;
  PricingType _selectedPricingType = PricingType.PAID;
  File? _imageFile;
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final adminService = AdminService();
      final categories = await adminService.getAllCategories();
      setState(() => _categories = categories);
    } catch (e) {
      setState(() => _error = 'Failed to load categories: ${e.toString()}');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _createCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;

      if (token == null) throw Exception('Unauthorized: Please log in');
      if (_selectedCategoryId == null) throw Exception('Please select a category');

      final courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
      courseService.setToken(token);

      final courseDTO = CourseDTO(
        title: _titleController.text,
        description: _descriptionController.text,
        price: _selectedPricingType == PricingType.FREE
            ? Decimal.zero
            : Decimal.parse(_priceController.text),
        pricingType: _selectedPricingType,
        imageUrl: '', // Will be set by backend
        level: _selectedLevel,
        language: _selectedLanguage,
        categoryId: int.parse(_selectedCategoryId!),
      );

      await courseService.createCourse(
        course: courseDTO,
        imageFile: _imageFile != null ? _imageFile : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form and pop back
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _imageFile = null;
        _selectedCategoryId = null;
      });
      Navigator.pop(context); // Go back to MyCoursesView after creation

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String newPath = '${appDir.path}/${image.name}';
      File newImage = await File(image.path).copy(newPath);

      setState(() => _imageFile = newImage);
    } else {
      setState(() => _error = 'No image selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Course'),
        backgroundColor: Color(0xFFDB2777),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_box, color: Color(0xFFDB2777), size: 32),
                const SizedBox(width: 12),
                Text(
                  'Create New Course',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDB2777),
                  ),
                ),
              ],
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Container(
                          padding: EdgeInsets.all(16),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Image Upload
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Color(0xFFDB2777).withOpacity(0.3),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: _imageFile != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 64,
                                  color: Color(0xFFDB2777),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload Course Image',
                                  style: TextStyle(
                                    color: Color(0xFFDB2777),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Course Title',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          if (value.length > 255) {
                            return 'Title must be less than 255 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Pricing Type
                      DropdownButtonFormField<PricingType>(
                        value: _selectedPricingType,
                        decoration: InputDecoration(
                          labelText: 'Pricing Type',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        items: PricingType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedPricingType = value!);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price
                      if (_selectedPricingType == PricingType.PAID)
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'Price',
                            prefixText: '\$',
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDB2777)),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            try {
                              final price = Decimal.parse(value);
                              if (price < Decimal.zero) {
                                return 'Price cannot be negative';
                              }
                            } catch (e) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 16),

                      // Level
                      DropdownButtonFormField<CourseLevel>(
                        value: _selectedLevel,
                        decoration: InputDecoration(
                          labelText: 'Course Level',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        items: CourseLevel.values.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(level.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedLevel = value!);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Language
                      DropdownButtonFormField<CourseLanguage>(
                        value: _selectedLanguage,
                        decoration: InputDecoration(
                          labelText: 'Course Language',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        items: CourseLanguage.values.map((language) {
                          return DropdownMenuItem(
                            value: language,
                            child: Text(language.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedLanguage = value!);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      _isLoadingCategories
                          ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDB2777)),
                        ),
                      )
                          : DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFDB2777)),
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category['id'].toString(),
                            child: Text(category['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createCourse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFDB2777),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Text('Create Course'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}