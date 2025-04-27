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
            if (_endDateTime.isBefore(_startDateTime)) {
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
        String relativeUrl = await widget.eventService.uploadImage(_selectedImage!);
        return relativeUrl;
      } catch (e) {
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
    return AlertDialog(
      title: Text(widget.event == null ? 'Create Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                )
                    : _imageUrl != null && _imageUrl!.isNotEmpty
                    ? Image.network(
                  _getFullImageUrl(_imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                )
                    : Center(
                  child: Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: Text(_selectedImage != null || _imageUrl != null ? 'Change Image' : 'Select Image'),
                  ),
                  if (_selectedImage != null || _imageUrl != null)
                    SizedBox(width: 8),
                  if (_selectedImage != null || _imageUrl != null)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _imageUrl = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Remove'),
                    ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Title is required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Description is required' : null,
              ),
              SwitchListTile(
                title: Text('Online Event'),
                value: _isOnline,
                activeColor: AppColors.primary,
                onChanged: (value) => setState(() => _isOnline = value),
              ),
              if (!_isOnline)
                ListTile(
                  title: Text(
                    _locationController.text.isEmpty
                        ? 'Select Location'
                        : _locationController.text,
                    style: TextStyle(
                      color: _locationController.text.isEmpty ? Colors.grey : Colors.black87,
                    ),
                  ),
                  trailing: Icon(Icons.map),
                  onTap: _selectLocation,
                ),
              if (!_isOnline)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _locationController.text.isEmpty ? 'Location is required' : '',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ),
              TextFormField(
                controller: _maxParticipantsController,
                decoration: InputDecoration(labelText: 'Max Participants (optional)'),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                title: Text(
                  'Start: ${DateFormat('MMM dd, yyyy HH:mm').format(_startDateTime)}',
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, true),
              ),
              ListTile(
                title: Text(
                  'End: ${DateFormat('MMM dd, yyyy HH:mm').format(_endDateTime)}',
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (!_isOnline && _locationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location is required for in-person events')),
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
          },
          child: Text('Save', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}