import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../widgets/subscription_card.dart';
import '../widgets/bank_transfer_widget.dart';

final _selectedPlanProvider = StateProvider<String>((ref) => 'weekly');
final _selectedPaymentProvider = StateProvider<String>((ref) => 'telebirr');
final _subscriptionLoadingProvider = StateProvider<bool>((ref) => false);

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  File? _receiptFile;

  Future<void> _subscribe() async {
    final plan = ref.read(_selectedPlanProvider);
    final payment = ref.read(_selectedPaymentProvider);
    final loading = ref.read(_subscriptionLoadingProvider.notifier);

    if (payment == 'bank_transfer' && _receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع إيصال التحويل البنكي'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    loading.state = true;

    try {
      final datasource = SubscriptionRemoteDatasourceImpl(
        Supabase.instance.client,
      );
      final repo = SubscriptionRepositoryImpl(datasource);

      final result = await repo.createSubscription(plan, payment);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red,
            ),
          );
        },
        (sub) async {
          // Upload receipt if bank transfer
          if (payment == 'bank_transfer' && _receiptFile != null) {
            final price = _getPlanPrice(plan);
            await repo.uploadBankTransferReceipt(_receiptFile!, price);
          }

          if (mounted) {
            if (payment == 'bank_transfer') {
              _showBankTransferSuccessDialog();
            } else {
              context.go('/home');
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) loading.state = false;
    }
  }

  double _getPlanPrice(String plan) {
    switch (plan) {
      case 'daily':
        return AppConstants.dailyPrice;
      case 'weekly':
        return AppConstants.weeklyPrice;
      case 'monthly':
        return AppConstants.monthlyPrice;
      default:
        return AppConstants.weeklyPrice;
    }
  }

  void _showBankTransferSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_empty_rounded,
            color: AppTheme.tertiaryColor, size: 48),
        title: const Text('تم استلام الطلب'),
        content: const Text(
          'تم استلام إيصالك. سيتم تفعيل اشتراكك بعد التحقق خلال ساعات قليلة.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _receiptFile = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPlan = ref.watch(_selectedPlanProvider);
    final selectedPayment = ref.watch(_selectedPaymentProvider);
    final isLoading = ref.watch(_subscriptionLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اشتراك السائق'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر خطة اشتراكك',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اشترك للبدء في استقبال الطلبات',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Plan cards
            const Text(
              'خطط الاشتراك',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...['daily', 'weekly', 'monthly'].map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SubscriptionCard(
                  plan: plan,
                  isSelected: selectedPlan == plan,
                  onTap: () => ref.read(_selectedPlanProvider.notifier).state = plan,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Payment methods
            const Text(
              'طريقة الدفع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...['telebirr', 'chapa', 'bank_transfer'].map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentMethodTile(theme, method, selectedPayment),
              ),
            ),
            const SizedBox(height: 16),
            if (selectedPayment == 'bank_transfer') ...[
              BankTransferWidget(
                receiptFile: _receiptFile,
                onPickReceipt: _pickReceipt,
              ),
              const SizedBox(height: 16),
            ],
            // Terms
            Text(
              'بالاشتراك، توافق على شروط الخدمة. يمكن إلغاء الاشتراك في أي وقت.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomButton(
              label: selectedPayment == 'bank_transfer'
                  ? 'تأكيد الطلب'
                  : 'الدفع والاشتراك',
              isLoading: isLoading,
              onPressed: _subscribe,
              icon: Icon(
                selectedPayment == 'bank_transfer'
                    ? Icons.check_rounded
                    : Icons.payment_rounded,
                size: 20,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
      ThemeData theme, String method, String selected) {
    final isSelected = method == selected;
    final label = method == 'telebirr'
        ? 'Telebirr'
        : method == 'chapa'
            ? 'Chapa'
            : 'تحويل بنكي';
    final icon = method == 'telebirr'
        ? Icons.phone_android_rounded
        : method == 'chapa'
            ? Icons.account_balance_rounded
            : Icons.receipt_long_rounded;

    return InkWell(
      onTap: () =>
          ref.read(_selectedPaymentProvider.notifier).state = method,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryColor
                    : theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
