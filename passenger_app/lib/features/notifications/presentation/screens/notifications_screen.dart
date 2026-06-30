import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';

// Simple notification model
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

final _notificationsProvider =
    FutureProvider<List<NotificationItem>>((ref) async {
  final userId = SupabaseService.instance.currentUserId;
  if (userId == null) return [];

  try {
    final data = await SupabaseService.instance.notificationsTable
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List)
        .map((json) => NotificationItem.fromJson(json))
        .toList();
  } on PostgrestException {
    return [];
  }
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () {
              // Mark all as read
              ref.invalidate(_notificationsProvider);
            },
            child: const Text('قراءة الكل'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyNotificationsState(),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const _EmptyNotificationsState();
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              return NotificationTile(
                  notification: notifications[index]);
            },
          );
        },
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'لا إشعارات جديدة',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا إشعاراتك عند وصولها',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationItem notification;

  const NotificationTile({super.key, required this.notification});

  IconData _iconForType(String type) {
    switch (type) {
      case 'ride':
        return Icons.directions_car;
      case 'payment':
        return Icons.payment;
      case 'promo':
        return Icons.local_offer;
      case 'points':
        return Icons.stars;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'ride':
        return AppColors.statusAccepted;
      case 'payment':
        return AppColors.secondary;
      case 'promo':
        return AppColors.tertiary;
      case 'points':
        return AppColors.tertiaryDark;
      case 'system':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dateTime.day}/${dateTime.month}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _colorForType(notification.type);

    return Container(
      color: notification.isRead
          ? null
          : AppColors.primary.withOpacity(0.03),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: typeColor.withOpacity(0.15),
              child: Icon(_iconForType(notification.type),
                  color: typeColor, size: 22),
            ),
            if (!notification.isRead)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: notification.isRead
                ? FontWeight.w400
                : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          notification.body,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTime(notification.createdAt),
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
