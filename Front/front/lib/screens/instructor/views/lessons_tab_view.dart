import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/lesson_service.dart';

class LessonsTabView extends StatefulWidget {
  final int courseId;
  final Function(int) onLessonsCountChanged;

  const LessonsTabView({
    Key? key,
    required this.courseId,
    required this.onLessonsCountChanged,
  }) : super(key: key);

  @override
  _LessonsTabViewState createState() => _LessonsTabViewState();
}

class _LessonsTabViewState extends State<LessonsTabView> {
  final LessonService _lessonService = LessonService(baseUrl: 'http://192.168.1.13:8080');
  List<LessonDTO> _lessons = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token != null) {
      _lessonService.setToken(token);
      _loadLessons();
    }
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lessons = await _lessonService.getLessons(widget.courseId);
      setState(() {
        _lessons = lessons;
        widget.onLessonsCountChanged(lessons.length);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addLesson() async {
    final result = await showDialog<LessonDTO>(
      context: context,
      builder: (context) => _LessonDialog(),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _lessonService.addLesson(widget.courseId, result);
        _loadLessons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editLesson(LessonDTO lesson) async {
    final result = await showDialog<LessonDTO>(
      context: context,
      builder: (context) => _LessonDialog(lesson: lesson),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _lessonService.updateLesson(
          widget.courseId,
          lesson.id!,
          result,
        );
        _loadLessons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteLesson(LessonDTO lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Lesson'),
        content: Text('Are you sure you want to delete this lesson?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _lessonService.deleteLesson(widget.courseId, lesson.id!);
        _loadLessons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFFDB2777)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLessons,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDB2777),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        if (_lessons.isEmpty)
          Center(
            child: Text('No lessons yet'),
          )
        else
          ListView.builder(
            itemCount: _lessons.length,
            padding: EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFDB2777),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(lesson.title),
                  subtitle: Text('Duration: ${lesson.duration} minutes'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editLesson(lesson);
                      } else if (value == 'delete') {
                        _deleteLesson(lesson);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _addLesson,
            backgroundColor: Color(0xFFDB2777),
            child: Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _LessonDialog extends StatefulWidget {
  final LessonDTO? lesson;

  const _LessonDialog({Key? key, this.lesson}) : super(key: key);

  @override
  __LessonDialogState createState() => __LessonDialogState();
}

class __LessonDialogState extends State<_LessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _videoUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleController.text = widget.lesson!.title;
      _durationController.text = widget.lesson!.duration.toString();
      _videoUrlController.text = widget.lesson!.videoUrl ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lesson == null ? 'Add Lesson' : 'Edit Lesson'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter duration';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _videoUrlController,
              decoration: InputDecoration(labelText: 'Video URL '),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                LessonDTO(
                  title: _titleController.text,
                  duration: int.parse(_durationController.text),
                  videoUrl: _videoUrlController.text.isEmpty
                      ? null
                      : _videoUrlController.text,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFDB2777),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.lesson == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }
}