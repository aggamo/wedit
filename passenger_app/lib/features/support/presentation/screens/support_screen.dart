import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ride/presentation/providers/ride_provider.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _rideIdController = TextEditingController();

  String _selectedCategory = 'app_issue';
  bool _isSubmitting = false;

  static const _categories = [
    ('driver_behavior', 'سلوك السائق'),
    ('payment', 'مشكلة في الدفع'),
    ('app_issue', 'مشكلة في التطبيق'),
    ('other', 'أخرى'),
  ];

  @override
  void initState() {
    super.initState();
    _prefillLastRideId();
  }

  void _prefillLastRideId() {
    final rideState = ref.read(rideStateProvider);
    if (rideState.currentRide != null) {
      _rideIdController.text = rideState.currentRide!.id;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _rideIdController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await SupabaseService.instance.client.from('complaints').insert({
        'user_id': userId,
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'ride_id': _rideIdController.text.trim().isEmpty
            ? null
            : _rideIdController.text.trim(),
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _descriptionController.clear();
        _rideIdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال شكواك بنجاح. سنتواصل معك قريباً.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإرسال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم والشكاوى'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent,
                      color: AppColors.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('فريق الدعم متاح 24/7',
                            style: theme.textTheme.titleSmall),
                        Text('+251 911 123 456 | support@wedit.et',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('إرسال شكوى', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category dropdown
                  Text('نوع الشكوى', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories
                        .map((cat) => DropdownMenuItem(
                              value: cat.$1,
                              child: Text(cat.$2),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Text('وصف المشكلة', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'اشرح مشكلتك بالتفصيل...',
                      alignLabelWithHint: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 10) {
                        return 'يرجى كتابة وصف تفصيلي (10 أحرف على الأقل)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Ride ID (optional)
                  Text('رقم الرحلة (اختياري)',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rideIdController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      hintText: 'أدخل رقم الرحلة إن وجد',
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitComplaint,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                          _isSubmitting ? 'جاري الإرسال...' : 'إرسال الشكوى'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Past support requests
            Text('طلبات الدعم السابقة',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _PastSupportRequests(),
          ],
        ),
      ),
    );
  }
}

class _PastSupportRequests extends ConsumerWidget {
  const _PastSupportRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = SupabaseService.instance.currentUserId;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchComplaints(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        final complaints = snapshot.data ?? [];

        if (complaints.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'لا توجد شكاوى سابقة',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final c = complaints[index];
            return _ComplaintTile(complaint: c);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchComplaints(
      String userId) async {
    try {
      final data = await SupabaseService.instance.client
          .from('complaints')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }
}

class _ComplaintTile extends StatelessWidget {
  final Map<String, dynamic> complaint;

  const _ComplaintTile({required this.complaint});

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return AppColors.secondary;
      case 'in_progress':
        return AppColors.statusAccepted;
      default:
        return AppColors.statusPending;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved':
        return 'محلولة';
      case 'in_progress':
        return 'قيد المعالجة';
      default:
        return 'مفتوحة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = complaint['status'] as String? ?? 'open';
    final createdAt = complaint['created_at'] != null
        ? DateTime.tryParse(complaint['created_at'] as String)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withOpacity(0.15),
          child: Icon(Icons.support, color: _statusColor(status)),
        ),
        title: Text(
          complaint['description'] as String? ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: createdAt != null
            ? Text(
                '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusLabel(status),
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
