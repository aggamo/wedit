import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  String _selectedLanguage = 'ar';
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() => _selectedImage = file);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    String? avatarUrl;

    // Upload photo if selected
    if (_selectedImage != null) {
      setState(() => _isUploadingImage = true);
      try {
        final bytes = await _selectedImage!.readAsBytes();
        final ext = _selectedImage!.name.split('.').last.toLowerCase();
        avatarUrl = await SupabaseService.instance.uploadAvatar(
          currentUser.id,
          bytes,
          ext,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل رفع الصورة: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }

    final updatedUser = currentUser.copyWith(
      fullName: _nameController.text.trim(),
      avatarUrl: avatarUrl ?? currentUser.avatarUrl,
      preferredLanguage: _selectedLanguage,
    );

    final controller = ref.read(authControllerProvider.notifier);
    final result = await controller.updateProfile(updatedUser);

    if (!mounted) return;

    if (result != null) {
      // If referral code provided, apply it (call Supabase RPC)
      if (_referralController.text.isNotEmpty) {
        try {
          await SupabaseService.instance.client.rpc('apply_referral_code', params: {
            'p_user_id': currentUser.id,
            'p_referral_code': _referralController.text.trim().toUpperCase(),
          });
        } catch (_) {
          // Non-critical - ignore
        }
      }
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading || _isUploadingImage;
    final errorMsg = authState is AsyncError ? authState.error.toString() : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'إكمال الملف الشخصي',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar picker
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipOval(
                              child: FutureBuilder<bool>(
                                future: Future.value(true),
                                builder: (context, _) => Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.primary,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'صورة اختيارية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),

              const SizedBox(height: 32),

              // Name field
              Align(
                alignment: Alignment.centerRight,
                child: const Text(
                  'الاسم الكامل *',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: AppValidators.validateFullName,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'أدخل اسمك الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 20),

              // Language selector
              Align(
                alignment: Alignment.centerRight,
                child: const Text(
                  'اللغة المفضلة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                items: AppConstants.languageNames.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.language_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // Referral code
              Align(
                alignment: Alignment.centerRight,
                child: const Text(
                  'رمز الإحالة (اختياري)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referralController,
                validator: AppValidators.validateReferralCode,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: 'XXXXXXX',
                  hintStyle: TextStyle(letterSpacing: 3),
                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                ),
              ),

              const SizedBox(height: 16),

              if (errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              CustomButton(
                label: 'حفظ وبدء الرحلة',
                onPressed: _saveProfile,
                isLoading: isLoading,
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        // Skip profile setup - go to home anyway
                        _nameController.text = 'مستخدم جديد';
                        _saveProfile();
                      },
                child: const Text(
                  'تخطي الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
