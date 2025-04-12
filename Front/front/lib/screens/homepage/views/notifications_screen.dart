import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart'; // Import the 100ms SDK
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/SessionService.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../instructor/views/LobbyScreen.dart';
import 'all_sessions_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
      ),
      body: notificationService.notifications.isEmpty
          ? const Center(
        child: Text(
          'No notifications available',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.textGray,
          ),
        ),
      )
          : ListView.builder(
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
              final subtype = notification.getNotificationSubtype();
              final sessionId = notification.getSessionId();
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

              // Retrieve the token from AuthService and set it in SessionService
              final token = authService.token; // Assuming AuthService has a token getter
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
                  // Fetch session details
                  final sessionData = await sessionService.getSessionJoinDetails(sessionId);
                  final meetingLink = sessionData['meetingLink'] as String?;
                  final meetingToken = sessionData['meetingToken'] as String?;
                  if (meetingLink != null && meetingToken != null) {
                    // Initialize the 100ms SDK
                    HMSSDK hmsSDK = HMSSDK();
                    await hmsSDK.build(); // Build the SDK instance

                    // Extract session title from notification title (e.g., "Session Live: hh" -> "hh")
                    final sessionTitle = notification.title.replaceFirst('Session Live: ', '');

                    // Navigate to LobbyScreen
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
              }
            },
          );
        },
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
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _getIconForType(notification.type),
                color: notification.isRead ? Colors.grey : AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: notification.isRead ? Colors.grey : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.getFormattedMessage(),
                      style: TextStyle(
                        fontSize: 14,
                        color: notification.isRead ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.getFormattedDate(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                icon: const Icon(Icons.more_vert),
              ),
            ],
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