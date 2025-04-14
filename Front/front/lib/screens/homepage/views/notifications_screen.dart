import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/SessionService.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/course_service.dart'; // Import CourseService
import '../../instructor/views/LobbyScreen.dart';
import '../../instructor/views/instructor_course_details_screen.dart'; // Import InstructorCourseDetailsScreen
import '../course_details_screen.dart';
import 'all_sessions_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    setState(() {
      _isLoading = true;
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    final username = authService.username;
    if (username != null) {
      final userId = await authService.getUserIdByUsername(username);
      if (userId != null) {
        try {
          await notificationService.fetchNotifications(userId);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load notifications: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final username = authService.username;
    if (username != null) {
      final userId = await authService.getUserIdByUsername(username);
      if (userId != null) {
        try {
          await notificationService.markAllAsRead(userId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read'),
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to mark all as read: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    final authService = Provider.of<AuthService>(context);
    final sessionService = Provider.of<SessionService>(context);

    print('NotificationsScreen rebuilt with ${notificationService.notifications.length} notifications');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (notificationService.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              tooltip: 'Mark All as Read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      )
          : notificationService.notifications.isEmpty
          ? const Center(
        child: Text(
          'No notifications available',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.textGray,
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notificationService.notifications.length,
          itemBuilder: (context, index) {
            final notification = notificationService.notifications[index];
            return NotificationCard(
              notification: notification,
              onMarkAsRead: () async {
                if (!notification.isRead) {
                  final username = authService.username;
                  if (username != null) {
                    final userId = await authService.getUserIdByUsername(username);
                    if (userId != null) {
                      try {
                        await notificationService.markAsRead(notification.id, userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification marked as read'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to mark as read: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }
              },
              onDelete: () async {
                final username = authService.username;
                if (username != null) {
                  final userId = await authService.getUserIdByUsername(username);
                  if (userId != null) {
                    try {
                      await notificationService.deleteNotification(notification.id, userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification deleted'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete notification: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              onTap: () async {
                if (!notification.isRead) {
                  final username = authService.username;
                  if (username != null) {
                    final userId = await authService.getUserIdByUsername(username);
                    if (userId != null) {
                      try {
                        await notificationService.markAsRead(notification.id, userId);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to mark as read: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }

                final subtype = notification.getNotificationSubtype();
                final sessionId = notification.getSessionId();
                final courseId = notification.getCourseId();
                final username = authService.username;
                if (username == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please log in to perform this action'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final userId = await authService.getUserIdByUsername(username);
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User ID not found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final token = authService.token;
                if (token == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Authentication token not found. Please log in again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                sessionService.setToken(token);

                if (subtype == 'LIVE' && sessionId != null) {
                  try {
                    final sessionData = await sessionService.getSessionJoinDetails(sessionId);
                    final meetingLink = sessionData['meetingLink'] as String?;
                    final meetingToken = sessionData['meetingToken'] as String?;
                    if (meetingLink != null && meetingToken != null) {
                      HMSSDK hmsSDK = HMSSDK();
                      await hmsSDK.build();

                      final sessionTitle = notification.title.replaceFirst('Session Live: ', '');

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LobbyScreen(
                            hmsSDK: hmsSDK,
                            meetingToken: meetingToken,
                            username: username,
                            sessionTitle: sessionTitle,
                          ),
                        ),
                      );
                    } else {
                      throw Exception('Invalid session data');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to join session: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else if (subtype == 'SCHEDULED') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AllSessionsScreen()),
                  );
                } else if (subtype == 'COURSE' && courseId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsScreen(courseId: courseId),
                    ),
                  );
                } else if (subtype == 'REVIEW' && courseId != null) {
                  try {
                    final courseService = CourseService(baseUrl: 'http://192.168.1.13:8080');
                    courseService.setToken(token);
                    final course = await courseService.getCourseDetails(courseId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InstructorCourseDetailsScreen(
                          initialTabIndex: 2, // Select the "Reviews" tab
                        ),
                        settings: RouteSettings(arguments: course),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load course details: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationDTO notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        child: Card(
          elevation: 3,
          color: notification.isRead ? Colors.white : Colors.blue[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: notification.isRead ? Colors.grey[200]! : AppColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Icon(
                  _getIconForType(notification.type),
                  color: notification.isRead ? Colors.grey : AppColors.primary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: notification.isRead ? Colors.grey[700] : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.getFormattedMessage(),
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isRead ? Colors.grey[600] : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.getFormattedDate(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'mark_as_read') {
                      onMarkAsRead();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (!notification.isRead)
                      const PopupMenuItem(
                        value: 'mark_as_read',
                        child: Text('Mark as Read'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'SESSION':
        return Icons.event;
      case 'COURSE':
        return Icons.book;
      case 'SYSTEM':
        return Icons.info;
      case 'FOLLOWERS':
        return Icons.person_add;
      case 'REVIEW':
        return Icons.star;
      case 'CATEGORY':
        return Icons.category;
      default:
        return Icons.notifications;
    }
  }
}