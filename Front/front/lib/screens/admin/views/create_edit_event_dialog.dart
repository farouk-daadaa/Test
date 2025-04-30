import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:front/constants/colors.dart';
import 'package:front/services/event_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'MapPickerScreen.dart';

class CreateEditEventDialog extends StatefulWidget {
  final EventDTO? event;
  final Function(EventDTO) onSave;
  final EventService eventService;

  const CreateEditEventDialog({
    Key? key,
    this.event,
    required this.onSave,
    required this.eventService,
  }) : super(key: key);

  @override
  _CreateEditEventDialogState createState() => _CreateEditEventDialogState();
}

class _CreateEditEventDialogState extends State<CreateEditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _maxParticipantsController;
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late bool _isOnline;
  File? _selectedImage;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isImageError = false;
  bool _isUploadingImage = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _maxParticipantsController =
        TextEditingController(text: widget.event?.maxParticipants?.toString() ?? '');
    _startDateTime = widget.event?.startDateTime ?? DateTime.now().add(Duration(hours: 1));
    _endDateTime = widget.event?.endDateTime ?? _startDateTime.add(Duration(hours: 1));
    _isOnline = widget.event?.isOnline ?? false;
    _imageUrl = widget.event?.imageUrl;
    _isImageError = (_selectedImage == null && _imageUrl == null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isImageError = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDateTime : _endDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startDateTime = newDateTime;
            if (_endDateTime.isBefore(_startDateTime) || _endDateTime.isAtSameMomentAs(_startDateTime)) {
              _endDateTime = _startDateTime.add(Duration(hours: 1));
            }
          } else {
            _endDateTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _selectLocation() async {
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialAddress: _locationController.text),
      ),
    );
    if (selectedAddress != null) {
      setState(() {
        _locationController.text = selectedAddress;
      });
    }
  }

  Future<String?> _uploadImageIfSelected() async {
    if (_selectedImage != null) {
      try {
        setState(() {
          _isUploadingImage = true;
        });
        String relativeUrl = await widget.eventService.uploadImage(_selectedImage!);
        setState(() {
          _isUploadingImage = false;
        });
        return relativeUrl;
      } catch (e) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
    }
    return _imageUrl;
  }

  String _getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';
    return '${widget.eventService.baseUrl}$relativeUrl';
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Info
        return _titleController.text.isNotEmpty && _descriptionController.text.isNotEmpty;
      case 1: // Image
        return _selectedImage != null || _imageUrl != null;
      case 2: // Location & Time
        if (!_isOnline && _locationController.text.isEmpty) {
          return false;
        }
        return _endDateTime.isAfter(_startDateTime);
      default:
        return true;
    }
  }

  void _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null && _imageUrl == null) {
      setState(() {
        _isImageError = true;
        _currentStep = 1; // Go to image step
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an image'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isOnline && _locationController.text.isEmpty) {
      setState(() {
        _currentStep = 2; // Go to location step
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location is required for in-person events'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_endDateTime.isBefore(_startDateTime) || _endDateTime.isAtSameMomentAs(_startDateTime)) {
      setState(() {
        _currentStep = 2; // Go to time step
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final maxParticipants = _maxParticipantsController.text.isEmpty
        ? null
        : int.tryParse(_maxParticipantsController.text);
    if (maxParticipants == null && _maxParticipantsController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Max Participants must be a valid number'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uploadedImageUrl = await _uploadImageIfSelected();
    if (uploadedImageUrl == null && _selectedImage != null) {
      return;
    }

    final event = EventDTO(
      id: widget.event?.id ?? 0,
      title: _titleController.text,
      description: _descriptionController.text,
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      isOnline: _isOnline,
      location: _isOnline ? null : _locationController.text,
      imageUrl: uploadedImageUrl,
      maxParticipants: maxParticipants,
      currentParticipants: widget.event?.currentParticipants ?? 0,
      capacityLeft: widget.event?.capacityLeft ?? 0,
      status: widget.event?.status ?? 'UPCOMING',
    );
    widget.onSave(event);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: _buildStepContent(_currentStep),
                  ),
                ),
              ),

              // Stepper Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildStepIndicator(index)),
                ),
              ),

              // Actions
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.event == null ? Icons.add_circle : Icons.edit,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.event == null ? 'Create New Event' : 'Edit Event',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            splashRadius: 24,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildImageStep();
      case 2:
        return _buildLocationTimeStep();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 24),

        // Title Field
        _buildInputLabel('Event Title'),
        SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: _inputDecoration(
            hintText: 'Enter event title',
            prefixIcon: Icons.title,
          ),
          validator: (value) => value!.isEmpty ? 'Title is required' : null,
        ),
        SizedBox(height: 20),

        // Description Field
        _buildInputLabel('Event Description'),
        SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: _inputDecoration(
            hintText: 'Enter event description',
            prefixIcon: Icons.description,
          ),
          maxLines: 4,
          validator: (value) => value!.isEmpty ? 'Description is required' : null,
        ),
        SizedBox(height: 20),

        // Max Participants Field
        _buildInputLabel('Maximum Participants (Optional)'),
        SizedBox(height: 8),
        TextFormField(
          controller: _maxParticipantsController,
          decoration: _inputDecoration(
            hintText: 'Enter maximum number of participants',
            prefixIcon: Icons.people,
          ),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 20),

        // Online Event Switch
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.videocam : Icons.location_on,
                color: _isOnline ? Colors.indigo : Colors.amber.shade700,
                size: 24,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Online Event',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _isOnline
                          ? 'This event will be held online'
                          : 'This event will be held in-person',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                activeColor: AppColors.primary,
                onChanged: (value) => setState(() => _isOnline = value),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Event Image',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Upload an attractive image for your event',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 24),

        // Image Preview
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isImageError ? Colors.red.shade300 : Colors.grey.shade300,
              width: 2,
            ),
            color: Colors.grey.shade100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _isUploadingImage
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Uploading image...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : _selectedImage != null
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            )
                : _imageUrl != null && _imageUrl!.isNotEmpty
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _getFullImageUrl(_imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            )
                : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image,
                    size: 64,
                    color: _isImageError ? Colors.red.shade300 : Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _isImageError
                        ? 'Image is required'
                        : 'No image selected',
                    style: TextStyle(
                      color: _isImageError ? Colors.red.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap to select an image',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: 24),

        // Image Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(
                  _selectedImage != null || _imageUrl != null
                      ? Icons.photo_library
                      : Icons.add_photo_alternate,
                  size: 20,
                ),
                label: Text(
                  _selectedImage != null || _imageUrl != null
                      ? 'Change Image'
                      : 'Select Image',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_selectedImage != null || _imageUrl != null) ...[
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _imageUrl = null;
                    });
                  },
                  icon: Icon(Icons.delete, size: 20),
                  label: Text('Remove Image', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLocationTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Location & Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 24),

        // Location (for in-person events)
        if (!_isOnline) ...[
          _buildInputLabel('Event Location'),
          SizedBox(height: 8),
          InkWell(
            onTap: _selectLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationController.text.isEmpty
                      ? Colors.red.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationController.text.isEmpty
                              ? 'Select Location'
                              : _locationController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: _locationController.text.isEmpty
                                ? Colors.grey.shade500
                                : Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_locationController.text.isEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            'Required for in-person events',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade500,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
        ],

        // Date and Time Section
        _buildInputLabel('Event Schedule'),
        SizedBox(height: 16),

        // Start Date/Time
        InkWell(
          onTap: () => _selectDateTime(context, true),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date & Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_startDateTime),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm a').format(_startDateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16),

        // End Date/Time
        InkWell(
          onTap: () => _selectDateTime(context, false),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _endDateTime.isBefore(_startDateTime) || _endDateTime.isAtSameMomentAs(_startDateTime)
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_busy,
                    color: Colors.red.shade400,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date & Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_endDateTime),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm a').format(_endDateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_endDateTime.isBefore(_startDateTime) || _endDateTime.isAtSameMomentAs(_startDateTime)) ...[
                        SizedBox(height: 4),
                        Text(
                          'End time must be after start time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.edit,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 24),

        // Duration Info
        if (!_endDateTime.isBefore(_startDateTime) && !_endDateTime.isAtSameMomentAs(_startDateTime))
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: Colors.teal,
                  size: 24,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Duration',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getDurationText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 16),
      ],
    );
  }

  String _getDurationText() {
    final duration = _endDateTime.difference(_startDateTime);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    String result = '';
    if (days > 0) {
      result += '$days day${days > 1 ? 's' : ''} ';
    }
    if (hours > 0) {
      result += '$hours hour${hours > 1 ? 's' : ''} ';
    }
    if (minutes > 0) {
      result += '$minutes minute${minutes > 1 ? 's' : ''}';
    }
    return result.trim();
  }

  Widget _buildStepIndicator(int index) {
    final isActive = _currentStep == index;
    final isCompleted = _currentStep > index;

    return Row(
      children: [
        if (index > 0)
          Container(
            width: 20,
            height: 1,
            color: isCompleted ? AppColors.primary : Colors.grey.shade300,
          ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.primary
                : isCompleted
                ? Colors.green
                : Colors.grey.shade200,
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : isCompleted
                  ? Colors.green
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            )
                : Text(
              '${index + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (index < 2)
          Container(
            width: 20,
            height: 1,
            color: isCompleted ? AppColors.primary : Colors.grey.shade300,
          ),
      ],
    );
  }

  Widget _buildActions() {
    // Fix for overflow: Use a Column instead of Row for smaller screens
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // If screen is too narrow, use a column layout
          if (constraints.maxWidth < 350) {
            return Column(
              children: [
                // Step indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Step ${_currentStep + 1} of 3',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    _currentStep > 0
                        ? Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        icon: Icon(Icons.arrow_back, size: 18),
                        label: Text('Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                        : SizedBox(width: 0),

                    if (_currentStep > 0) SizedBox(width: 16),

                    // Next/Save button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_currentStep < 2) {
                            if (_validateCurrentStep()) {
                              setState(() {
                                _currentStep++;
                              });
                            } else {
                              // Show validation message
                              String message = '';
                              switch (_currentStep) {
                                case 0:
                                  message = 'Please fill in all required fields';
                                  break;
                                case 1:
                                  message = 'Please select an image';
                                  break;
                                case 2:
                                  if (!_isOnline && _locationController.text.isEmpty) {
                                    message = 'Location is required for in-person events';
                                  } else {
                                    message = 'End time must be after start time';
                                  }
                                  break;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            _saveEvent();
                          }
                        },
                        icon: Icon(
                          _currentStep == 2 ? Icons.save : Icons.arrow_forward,
                          size: 18,
                        ),
                        label: Text(
                          _currentStep == 2 ? 'Save Event' : 'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            // For wider screens, use the original row layout
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button (except for first step)
                _currentStep > 0
                    ? ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  icon: Icon(Icons.arrow_back, size: 18),
                  label: Text('Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                    : SizedBox(width: 80), // Placeholder for alignment

                // Step indicator text
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Next/Save button
                ElevatedButton.icon(
                  onPressed: () {
                    if (_currentStep < 2) {
                      if (_validateCurrentStep()) {
                        setState(() {
                          _currentStep++;
                        });
                      } else {
                        // Show validation message
                        String message = '';
                        switch (_currentStep) {
                          case 0:
                            message = 'Please fill in all required fields';
                            break;
                          case 1:
                            message = 'Please select an image';
                            break;
                          case 2:
                            if (!_isOnline && _locationController.text.isEmpty) {
                              message = 'Location is required for in-person events';
                            } else {
                              message = 'End time must be after start time';
                            }
                            break;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      _saveEvent();
                    }
                  },
                  icon: Icon(
                    _currentStep == 2 ? Icons.save : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: Text(
                    _currentStep == 2 ? 'Save Event' : 'Next',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 2),
      ),
    );
  }
}



