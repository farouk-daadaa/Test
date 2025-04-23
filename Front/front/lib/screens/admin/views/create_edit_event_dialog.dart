import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:front/constants/colors.dart';
import 'package:front/services/event_service.dart';

class CreateEditEventDialog extends StatefulWidget {
  final EventDTO? event;
  final Function(EventDTO) onSave;

  const CreateEditEventDialog({Key? key, this.event, required this.onSave}) : super(key: key);

  @override
  _CreateEditEventDialogState createState() => _CreateEditEventDialogState();
}

class _CreateEditEventDialogState extends State<CreateEditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _imageUrlController;
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late bool _isOnline;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _maxParticipantsController =
        TextEditingController(text: widget.event?.maxParticipants?.toString() ?? '');
    _imageUrlController = TextEditingController(text: widget.event?.imageUrl ?? '');
    _startDateTime = widget.event?.startDateTime ?? DateTime.now().add(Duration(hours: 1));
    _endDateTime = widget.event?.endDateTime ?? _startDateTime.add(Duration(hours: 1));
    _isOnline = widget.event?.isOnline ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
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
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) =>
                value!.isEmpty ? 'Title is required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) =>
                value!.isEmpty ? 'Description is required' : null,
              ),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(labelText: 'Image URL (optional)'),
              ),
              SwitchListTile(
                title: Text('Online Event'),
                value: _isOnline,
                activeColor: AppColors.primary,
                onChanged: (value) => setState(() => _isOnline = value),
              ),
              if (!_isOnline)
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(labelText: 'Location'),
                  validator: (value) =>
                  value!.isEmpty && !_isOnline ? 'Location is required' : null,
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final maxParticipants = _maxParticipantsController.text.isEmpty
                  ? null
                  : int.tryParse(_maxParticipantsController.text); // Changed to tryParse
              if (maxParticipants == null && _maxParticipantsController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Max Participants must be a valid number')),
                );
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
                imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
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