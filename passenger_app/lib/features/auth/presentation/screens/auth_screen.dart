import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedLanguage = 'ar';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = AppValidators.normalizePhone(_phoneController.text.trim());
    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.sendOtp(phone);

    if (success && mounted) {
      context.push(AppRoutes.otp, extra: phone);
    }
  }

  void _changeLanguage(String? lang) {
    if (lang == null) return;
    setState(() => _selectedLanguage = lang);
    ref.read(selectedLanguageProvider.notifier).state = lang;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;
    final errorMsg = authState is AsyncError ? authState.error.toString() : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Language Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.language, color: AppColors.primary),
                    items: AppConstants.languageNames.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _changeLanguage,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Logo
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'W',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'مرحباً بك في ويديت',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'رحلتك الموثوقة في أديس أبابا',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Phone input
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رقم الهاتف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\+\-\(\) ]'),
                        ),
                      ],
                      onFieldSubmitted: (_) => _sendOtp(),
                      validator: AppValidators.validatePhone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '+251 9X XXX XXXX',
                        hintStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          color: AppColors.textHint,
                        ),
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🇪🇹',
                                style: TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '+251',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                width: 1,
                                height: 24,
                                color: AppColors.textDisabled,
                              ),
                            ],
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.textDisabled,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              CustomButton(
                label: 'إرسال رمز التحقق',
                onPressed: _sendOtp,
                isLoading: isLoading,
              ),

              const SizedBox(height: 24),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إرسال رمز التحقق إلى رقم هاتفك عبر رسالة نصية.',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
