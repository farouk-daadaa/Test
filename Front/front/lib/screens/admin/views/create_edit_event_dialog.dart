import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:front/constants/colors.dart';
import 'package:front/services/event_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'MapPickerScreen.dart'; // Import the new MapPickerScreen

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
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDateTime : _endDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime),
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
          SnackBar(content: Text('Error uploading image: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400, // Set a reasonable maximum width for the dialog
          minWidth: 280, // Ensure a minimum width for smaller screens
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent the dialog from taking full height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                widget.event == null ? 'Create Event' : 'Edit Event',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
            // Content Section
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Section
                        Container(
                          height: 150,
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isImageError ? Colors.red : Colors.grey,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isUploadingImage)
                                CircularProgressIndicator()
                              else
                                _selectedImage != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                                    : _imageUrl != null && _imageUrl!.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _getFullImageUrl(_imageUrl),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  ),
                                )
                                    : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No Image Selected',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isImageError)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Text(
                              'Image is required',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: Icon(Icons.photo_library, size: 18),
                              label: Text(
                                _selectedImage != null || _imageUrl != null
                                    ? 'Change Image'
                                    : 'Select Image',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            if (_selectedImage != null || _imageUrl != null) ...[
                              SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _imageUrl = null;
                                    _isImageError = true;
                                  });
                                },
                                icon: Icon(Icons.delete, size: 18),
                                label: Text('Remove'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 16),
                        // Title Field
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          validator: (value) => value!.isEmpty ? 'Title is required' : null,
                        ),
                        SizedBox(height: 12),
                        // Description Field
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          maxLines: 3,
                          validator: (value) => value!.isEmpty ? 'Description is required' : null,
                        ),
                        SizedBox(height: 12),
                        // Online Event Switch
                        SwitchListTile(
                          title: Text(
                            'Online Event',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: _isOnline,
                          activeColor: AppColors.primary,
                          onChanged: (value) => setState(() => _isOnline = value),
                        ),
                        // Location Field (if not online)
                        if (!_isOnline) ...[
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 400),
                            child: ListTile(
                              title: Text(
                                _locationController.text.isEmpty
                                    ? 'Select Location'
                                    : _locationController.text,
                                style: TextStyle(
                                  color: _locationController.text.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing: Icon(Icons.map, color: AppColors.primary),
                              onTap: _selectLocation,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                            child: Text(
                              _locationController.text.isEmpty ? 'Location is required' : '',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                        SizedBox(height: 12),
                        // Max Participants Field
                        TextFormField(
                          controller: _maxParticipantsController,
                          decoration: InputDecoration(
                            labelText: 'Max Participants (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        // Start DateTime
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 400),
                          child: ListTile(
                            title: Text(
                              'Start: ${DateFormat('MMM dd, yyyy HH:mm').format(_startDateTime)}',
                              style: TextStyle(color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: Icon(Icons.calendar_today, color: AppColors.primary),
                            onTap: () => _selectDateTime(context, true),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        // End DateTime
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 400),
                          child: ListTile(
                            title: Text(
                              'End: ${DateFormat('MMM dd, yyyy HH:mm').format(_endDateTime)}',
                              style: TextStyle(color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: Icon(Icons.calendar_today, color: AppColors.primary),
                            onTap: () => _selectDateTime(context, false),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Actions Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;

                      if (_selectedImage == null && _imageUrl == null) {
                        setState(() {
                          _isImageError = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please select an image')),
                        );
                        return;
                      }

                      if (!_isOnline && _locationController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Location is required for in-person events')),
                        );
                        return;
                      }

                      if (_endDateTime.isBefore(_startDateTime) ||
                          _endDateTime.isAtSameMomentAs(_startDateTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('End time must be after start time')),
                        );
                        return;
                      }

                      final maxParticipants = _maxParticipantsController.text.isEmpty
                          ? null
                          : int.tryParse(_maxParticipantsController.text);
                      if (maxParticipants == null && _maxParticipantsController.text.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Max Participants must be a valid number')),
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}