import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../services/course_service.dart';
import '../../../services/auth_service.dart';
import 'package:decimal/decimal.dart';
import '../../../services/admin_service.dart';

class EditCourseView extends StatefulWidget {
  const EditCourseView({Key? key}) : super(key: key);

  @override
  _EditCourseViewState createState() => _EditCourseViewState();
}

class _EditCourseViewState extends State<EditCourseView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  CourseLevel _selectedLevel = CourseLevel.BEGINNER;
  CourseLanguage _selectedLanguage = CourseLanguage.ENGLISH;
  PricingType _selectedPricingType = PricingType.PAID;
  File? _imageFile;
  bool _isLoading = false;
  CourseDTO? _course;
  late CourseService _courseService;
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
    _fetchCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      _courseService.setToken(authService.token!);

      // Get course data from route arguments
      _course = ModalRoute.of(context)!.settings.arguments as CourseDTO;
      _initializeFormData();
    });
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final adminService = AdminService();
      final categories = await adminService.getAllCategories();
      setState(() => _categories = categories);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load categories: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  void _initializeFormData() {
    if (_course != null) {
      _titleController.text = _course!.title;
      _descriptionController.text = _course!.description;
      _priceController.text = _course!.price.toString();
      _selectedLevel = _course!.level;
      _selectedLanguage = _course!.language;
      _selectedPricingType = _course!.pricingType;
      _selectedCategoryId = _course!.categoryId.toString();
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _updateCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedCourse = CourseDTO(
        id: _course!.id,
        title: _titleController.text,
        description: _descriptionController.text,
        price: Decimal.parse(_priceController.text),
        pricingType: _selectedPricingType,
        level: _selectedLevel,
        language: _selectedLanguage,
        imageUrl: _course!.imageUrl,
        categoryId: int.parse(_selectedCategoryId!),
      );

      await _courseService.updateCourse(
        course: updatedCourse,
        imageFile: _imageFile,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating course: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Course'),
        backgroundColor: Color(0xFFDB2777),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : _course?.imageUrl.isNotEmpty == true
                      ? Image.network(
                    _courseService.getImageUrl(_course!.imageUrl),
                    fit: BoxFit.cover,
                  )
                      : Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Course Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<PricingType>(
                value: _selectedPricingType,
                decoration: InputDecoration(
                  labelText: 'Pricing Type',
                  border: OutlineInputBorder(),
                ),
                items: PricingType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPricingType = value!;
                  });
                },
              ),
              if (_selectedPricingType == PricingType.PAID) ...[
                SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_selectedPricingType == PricingType.PAID) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Price must be greater than 0';
                      }
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 16),
              DropdownButtonFormField<CourseLevel>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  labelText: 'Course Level',
                  border: OutlineInputBorder(),
                ),
                items: CourseLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<CourseLanguage>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Course Language',
                  border: OutlineInputBorder(),
                ),
                items: CourseLanguage.values.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              SizedBox(height: 16),
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
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDB2777),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Update Course'),
                ),
              ),
            ],
          ),
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

