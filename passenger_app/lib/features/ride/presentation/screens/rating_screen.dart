import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ride_provider.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RatingScreen({super.key, required this.rideId});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  final Set<String> _selectedCategories = {};

  final _categories = [
    ('punctuality', 'الالتزام بالوقت'),
    ('cleanliness', 'النظافة'),
    ('politeness', 'اللياقة'),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notifier = ref.read(rideStateProvider.notifier);
    final success = await notifier.submitRating(
      rideId: widget.rideId,
      score: _rating,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    if (success && mounted) {
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(rideStateProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideState = ref.watch(rideStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الرحلة'),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(
              'تخطي',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'كيف كانت رحلتك؟',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Driver card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          color: AppColors.primary, size: 36),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سائقك', style: theme.textTheme.titleSmall),
                        Text('رحلة مكتملة',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.secondary,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _rating >= starIndex ? Icons.star : Icons.star_border,
                        color: _rating >= starIndex
                            ? AppColors.tertiary
                            : AppColors.textDisabled,
                        size: 48,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),

            Text(
              _ratingLabel(_rating),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // Category chips
            Text(
              'ما الذي أعجبك؟ (اختياري)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _categories.map((cat) {
                final isSelected = _selectedCategories.contains(cat.$1);
                return FilterChip(
                  label: Text(cat.$2),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedCategories.add(cat.$1);
                      } else {
                        _selectedCategories.remove(cat.$1);
                      }
                    });
                  },
                  selectedColor: AppColors.secondary.withOpacity(0.2),
                  checkmarkColor: AppColors.secondary,
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Comment field
            TextField(
              controller: _commentController,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'أضف تعليقاً... (اختياري)',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: rideState.isLoading ? null : _submitRating,
                child: rideState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إرسال التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'سيء جداً';
      case 2:
        return 'سيء';
      case 3:
        return 'مقبول';
      case 4:
        return 'جيد';
      case 5:
        return 'ممتاز';
      default:
        return 'اختر تقييمك';
    }
  }
}
