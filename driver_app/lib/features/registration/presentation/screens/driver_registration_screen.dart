import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/datasources/registration_remote_datasource.dart';
import '../../data/repositories/registration_repository_impl.dart';
import '../../domain/entities/driver_registration_entity.dart';

final _registrationDataProvider =
    StateProvider<DriverRegistrationEntity>((ref) => const DriverRegistrationEntity());

final _registrationLoadingProvider = StateProvider<bool>((ref) => false);

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  int _currentStep = 0;

  // Step 1 controllers
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();

  // Step 2 controllers
  final _licenseNumberController = TextEditingController();
  DateTime? _licenseExpiry;

  // Step 3
  File? _nationalIdFile;
  File? _licenseFile;
  String? _nationalIdUrl;
  String? _licenseUrl;

  // Step 4 controllers
  String? _selectedVehicleType;
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isNationalId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final file = File(image.path);
      setState(() {
        if (isNationalId) {
          _nationalIdFile = file;
        } else {
          _licenseFile = file;
        }
      });
    }
  }

  Future<void> _uploadDocuments() async {
    final loading = ref.read(_registrationLoadingProvider.notifier);
    loading.state = true;

    try {
      final datasource = RegistrationRemoteDatasourceImpl(
        Supabase.instance.client,
      );

      if (_nationalIdFile != null && _nationalIdUrl == null) {
        final result = await RegistrationRepositoryImpl(datasource)
            .uploadDocument(_nationalIdFile!, 'national_id');
        result.fold(
          (f) => throw Exception(f.message),
          (url) => _nationalIdUrl = url,
        );
      }

      if (_licenseFile != null && _licenseUrl == null) {
        final result = await RegistrationRepositoryImpl(datasource)
            .uploadDocument(_licenseFile!, 'license');
        result.fold(
          (f) => throw Exception(f.message),
          (url) => _licenseUrl = url,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الملفات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      loading.state = false;
    }
  }

  Future<void> _submitRegistration() async {
    final loading = ref.read(_registrationLoadingProvider.notifier);
    loading.state = true;

    try {
      final entity = DriverRegistrationEntity(
        fullName: _nameController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        licenseExpiry: _licenseExpiry,
        nationalIdUrl: _nationalIdUrl,
        licenseUrl: _licenseUrl,
        vehicleType: _selectedVehicleType,
        plateNumber: _plateController.text.trim().toUpperCase(),
        vehicleModel: _modelController.text.trim(),
        vehicleYear: int.tryParse(_yearController.text),
        vehicleColor: _colorController.text.trim(),
      );

      final datasource = RegistrationRemoteDatasourceImpl(
        Supabase.instance.client,
      );
      final result = await RegistrationRepositoryImpl(datasource)
          .submitRegistration(entity);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red,
            ),
          );
        },
        (_) {
          if (mounted) context.go('/pending-approval');
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) loading.state = false;
    }
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _nameController.text.isNotEmpty &&
            _nationalIdController.text.isNotEmpty;
      case 1:
        return _licenseNumberController.text.isNotEmpty &&
            _licenseExpiry != null;
      case 2:
        return _nationalIdFile != null && _licenseFile != null;
      case 3:
        return _selectedVehicleType != null &&
            _plateController.text.isNotEmpty &&
            _modelController.text.isNotEmpty &&
            _yearController.text.isNotEmpty &&
            _colorController.text.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(_registrationLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل السائق'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isCompleted = index < _currentStep;
                    final isActive = index == _currentStep;
                    return Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isActive ? 32 : 24,
                          height: isActive ? 32 : 24,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppTheme.secondaryColor
                                : isActive
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isActive ? Colors.white : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        if (index < 4)
                          Container(
                            width: 32,
                            height: 2,
                            color: index < _currentStep
                                ? AppTheme.secondaryColor
                                : Colors.grey.shade300,
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(theme),
              ),
            ),
          ),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: CustomButton(
                      label: 'السابق',
                      variant: ButtonVariant.outlined,
                      onPressed: () => setState(() => _currentStep--),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    label: _currentStep == 4 ? 'تقديم الطلب' : 'التالي',
                    isLoading: isLoading,
                    onPressed: _canProceedFromStep(_currentStep)
                        ? () async {
                            if (_currentStep == 2) {
                              await _uploadDocuments();
                              if (mounted) setState(() => _currentStep++);
                            } else if (_currentStep == 4) {
                              await _submitRegistration();
                            } else {
                              setState(() => _currentStep++);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep(theme);
      case 1:
        return _buildLicenseInfoStep(theme);
      case 2:
        return _buildDocumentsStep(theme);
      case 3:
        return _buildVehicleInfoStep(theme);
      case 4:
        return _buildReviewStep(theme);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInfoStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step1'),
      children: [
        _stepHeader('المعلومات الشخصية', Icons.person_rounded),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'الاسم الكامل',
            prefixIcon: Icon(Icons.badge_rounded),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nationalIdController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'رقم الهوية الوطنية',
            prefixIcon: Icon(Icons.credit_card_rounded),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildLicenseInfoStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step2'),
      children: [
        _stepHeader('معلومات الرخصة', Icons.drive_eta_rounded),
        const SizedBox(height: 24),
        TextFormField(
          controller: _licenseNumberController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'رقم رخصة القيادة',
            prefixIcon: Icon(Icons.assignment_ind_rounded),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (date != null) {
              setState(() => _licenseExpiry = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'تاريخ انتهاء الرخصة',
              prefixIcon: Icon(Icons.calendar_today_rounded),
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _licenseExpiry != null
                  ? DateFormat('yyyy-MM-dd').format(_licenseExpiry!)
                  : 'اختر التاريخ',
              style: TextStyle(
                color: _licenseExpiry != null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step3'),
      children: [
        _stepHeader('رفع المستندات', Icons.upload_file_rounded),
        const SizedBox(height: 8),
        Text(
          'يرجى رفع صور واضحة للمستندات المطلوبة',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildDocumentUploadCard(
          title: 'الهوية الوطنية',
          subtitle: 'صورة واضحة للوجهين',
          icon: Icons.credit_card_rounded,
          file: _nationalIdFile,
          onTap: () => _pickImage(true),
        ),
        const SizedBox(height: 16),
        _buildDocumentUploadCard(
          title: 'رخصة القيادة',
          subtitle: 'صورة واضحة للوجهين',
          icon: Icons.drive_eta_rounded,
          file: _licenseFile,
          onTap: () => _pickImage(false),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasFile
                ? AppTheme.secondaryColor
                : Theme.of(context).colorScheme.outline.withOpacity(0.4),
            width: hasFile ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasFile
              ? AppTheme.secondaryColor.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hasFile
                    ? AppTheme.secondaryColor
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasFile
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(file!, fit: BoxFit.cover),
                    )
                  : Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    hasFile ? 'تم رفع الصورة ✓' : subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFile
                          ? AppTheme.secondaryColor
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.upload_rounded,
              color: hasFile ? AppTheme.secondaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step4'),
      children: [
        _stepHeader('معلومات المركبة', Icons.directions_car_rounded),
        const SizedBox(height: 24),
        // Vehicle type selector
        Text('نوع المركبة', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: ['sedan', 'suv', 'minibus'].map((type) {
            final isSelected = _selectedVehicleType == type;
            final label = type == 'sedan'
                ? 'سيدان'
                : type == 'suv'
                    ? 'SUV'
                    : 'ميكروباص';
            final icon = type == 'sedan'
                ? Icons.directions_car_rounded
                : type == 'suv'
                    ? Icons.airport_shuttle_rounded
                    : Icons.directions_bus_rounded;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedVehicleType = type),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _plateController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'رقم اللوحة',
            prefixIcon: Icon(Icons.confirmation_number_rounded),
            hintText: 'مثال: AA 12345',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _modelController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'موديل المركبة',
            prefixIcon: Icon(Icons.directions_car_filled_rounded),
            hintText: 'مثال: Toyota Corolla',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _yearController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سنة الصنع',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _colorController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'اللون',
                  prefixIcon: Icon(Icons.color_lens_rounded),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step5'),
      children: [
        _stepHeader('مراجعة وتقديم الطلب', Icons.fact_check_rounded),
        const SizedBox(height: 8),
        Text(
          'يرجى مراجعة المعلومات قبل التقديم',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _reviewSection('المعلومات الشخصية', [
          ('الاسم', _nameController.text),
          ('رقم الهوية', _nationalIdController.text),
        ]),
        _reviewSection('معلومات الرخصة', [
          ('رقم الرخصة', _licenseNumberController.text),
          ('تاريخ الانتهاء',
              _licenseExpiry != null
                  ? DateFormat('yyyy-MM-dd').format(_licenseExpiry!)
                  : '-'),
        ]),
        _reviewSection('المستندات', [
          ('الهوية الوطنية', _nationalIdFile != null ? '✓ مرفوعة' : '✗ غير مرفوعة'),
          ('رخصة القيادة', _licenseFile != null ? '✓ مرفوعة' : '✗ غير مرفوعة'),
        ]),
        _reviewSection('معلومات المركبة', [
          ('النوع', _selectedVehicleType ?? '-'),
          ('اللوحة', _plateController.text),
          ('الموديل', _modelController.text),
          ('السنة', _yearController.text),
          ('اللون', _colorController.text),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.tertiaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.tertiaryColor.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.tertiaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سيتم مراجعة طلبك خلال 24-48 ساعة. ستتلقى إشعاراً عند الموافقة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.brown.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewSection(String title, List<(String, String)> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const Divider(),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.$1,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.$2,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
