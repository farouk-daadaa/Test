import 'package:flutter/material.dart';
import 'package:front/screens/instructor/views/video_player_screen.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LessonDialog(),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _lessonService.addLesson(
          widget.courseId,
          result['title'] as String,
          result['videoFile'] as File?,
        );
        _loadLessons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editLesson(LessonDTO lesson) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _LessonDialog(lesson: lesson),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _lessonService.updateLesson(
          widget.courseId,
          lesson.id!,
          result['title'] as String,
          result['videoFile'] as File?,
        );
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No lessons yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your first lesson to get started',
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
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
                  onTap: lesson.videoUrl != null ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoUrl: lesson.videoUrl!,
                          lessonTitle: lesson.title,
                        ),
                      ),
                    );
                  } : null,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFDB2777),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(lesson.title),
                  subtitle: lesson.videoUrl != null
                      ? Row(
                    children: [
                      Icon(Icons.video_library, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Video available'),
                    ],
                  )
                      : Text('No video uploaded'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      if (lesson.videoUrl != null)
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Preview Video'),
                            ],
                          ),
                        ),
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
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _editLesson(lesson);
                      } else if (value == 'delete') {
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
            child: Icon(
              Icons.add,
              color: Colors.white,
            ),
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
  File? _videoFile;
  String? _videoFileName;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleController.text = widget.lesson!.title;
    }
  }
  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mpeg', 'mov', 'avi'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        // Check file size (500MB in bytes)
        if (fileSize > 500 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video file size must be less than 500MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _videoFile = file;
          _videoFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              decoration: InputDecoration(
                labelText: 'Title',
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
            Text(
              'Supported video formats: MP4, MPEG, MOV, AVI',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Maximum file size: 500MB',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: Icon(Icons.video_library),
              label: Text(_videoFileName ?? 'Select Video'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFFDB2777),
              ),
            ),
            if (_videoFileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _videoFileName!,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
                {
                  'title': _titleController.text,
                  'videoFile': _videoFile,
                },
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
    super.dispose();
  }
}


