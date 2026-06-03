import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/call_center_provider.dart';

class CallCenterPage extends ConsumerStatefulWidget {
  const CallCenterPage({super.key});

  @override
  ConsumerState<CallCenterPage> createState() => _CallCenterPageState();
}

class _CallCenterPageState extends ConsumerState<CallCenterPage> {
  final _formKey         = GlobalKey<FormState>();
  final _phoneCtrl       = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _notesCtrl       = TextEditingController();

  String  _vehicleType     = 'sedan';
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  bool    _addingDestination = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  static const LatLng _addisCenter = LatLng(9.0280, 38.7469);

  static const _vehicleTypes = [
    ('sedan', 'سيدان'),
    ('suv', 'SUV'),
    ('vip', 'VIP'),
    ('minibus', 'ميني باص'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _destinationCtrl.dispose();
    _notesCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTap(LatLng position) {
    setState(() {
      if (_addingDestination) {
        _dropoffLocation = position;
        _markers = {
          if (_pickupLocation != null)
            Marker(
              markerId: const MarkerId('pickup'),
              position: _pickupLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'موقع الراكب'),
            ),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'الوجهة'),
          ),
        };
      } else {
        _pickupLocation = position;
        _markers = {
          Marker(
            markerId: const MarkerId('pickup'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'موقع الراكب'),
          ),
          if (_dropoffLocation != null)
            Marker(
              markerId: const MarkerId('dropoff'),
              position: _dropoffLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'الوجهة'),
            ),
        };
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد موقع الراكب على الخريطة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ref.read(callCenterProvider.notifier).createRide(
          passengerPhone:  _phoneCtrl.text.trim(),
          pickupLat:       _pickupLocation!.latitude,
          pickupLng:       _pickupLocation!.longitude,
          pickupAddress:   _addressCtrl.text.trim(),
          vehicleType:     _vehicleType,
          notes:           _notesCtrl.text.trim(),
          dropoffLat:      _dropoffLocation?.latitude,
          dropoffLng:      _dropoffLocation?.longitude,
          dropoffAddress:  _destinationCtrl.text.trim(),
        );
  }

  void _reset() {
    _formKey.currentState?.reset();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _destinationCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _vehicleType       = 'sedan';
      _pickupLocation    = null;
      _dropoffLocation   = null;
      _addingDestination = false;
      _markers           = {};
    });
    ref.read(callCenterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callCenterProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 1,
              title: const Text(
                'إنشاء رحلة — الكول سنتر',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              actions: [
                if (state.result != null)
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.add),
                    label: const Text('طلب جديد', style: TextStyle(fontFamily: 'Cairo')),
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: state.result != null
                    ? _SuccessCard(result: state.result!, onNewRide: _reset)
                    : isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _FormCard(
                                  formKey: _formKey,
                                  phoneCtrl: _phoneCtrl,
                                  addressCtrl: _addressCtrl,
                                  destinationCtrl: _destinationCtrl,
                                  notesCtrl: _notesCtrl,
                                  vehicleType: _vehicleType,
                                  pickupLocation: _pickupLocation,
                                  dropoffLocation: _dropoffLocation,
                                  addingDestination: _addingDestination,
                                  isLoading: state.isLoading,
                                  error: state.error,
                                  onVehicleTypeChanged: (v) =>
                                      setState(() => _vehicleType = v),
                                  onToggleDestination: (v) =>
                                      setState(() => _addingDestination = v),
                                  onSubmit: _submit,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: _MapCard(
                                  markers: _markers,
                                  onMapCreated: (c) => _mapController = c,
                                  onTap: _onMapTap,
                                  pickupLocation: _pickupLocation,
                                  addingDestination: _addingDestination,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _MapCard(
                                markers: _markers,
                                onMapCreated: (c) => _mapController = c,
                                onTap: _onMapTap,
                                pickupLocation: _pickupLocation,
                                addingDestination: _addingDestination,
                                height: 300,
                              ),
                              const SizedBox(height: 16),
                              _FormCard(
                                formKey: _formKey,
                                phoneCtrl: _phoneCtrl,
                                addressCtrl: _addressCtrl,
                                destinationCtrl: _destinationCtrl,
                                notesCtrl: _notesCtrl,
                                vehicleType: _vehicleType,
                                pickupLocation: _pickupLocation,
                                dropoffLocation: _dropoffLocation,
                                addingDestination: _addingDestination,
                                isLoading: state.isLoading,
                                error: state.error,
                                onVehicleTypeChanged: (v) =>
                                    setState(() => _vehicleType = v),
                                onToggleDestination: (v) =>
                                    setState(() => _addingDestination = v),
                                onSubmit: _submit,
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
}

// ─── Form Card ────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController destinationCtrl;
  final TextEditingController notesCtrl;
  final String vehicleType;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final bool addingDestination;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onVehicleTypeChanged;
  final ValueChanged<bool> onToggleDestination;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.destinationCtrl,
    required this.notesCtrl,
    required this.vehicleType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.addingDestination,
    required this.isLoading,
    required this.error,
    required this.onVehicleTypeChanged,
    required this.onToggleDestination,
    required this.onSubmit,
  });

  static const _vehicleTypes = [
    ('sedan', 'سيدان'),
    ('suv', 'SUV'),
    ('vip', 'VIP'),
    ('minibus', 'ميني باص'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'بيانات الطلب',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Phone field
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                decoration: _inputDecoration(
                  label: 'رقم هاتف الراكب',
                  hint: '+251912345678',
                  icon: Icons.phone,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'رقم الهاتف مطلوب';
                  if (v.trim().length < 9) return 'رقم هاتف غير صالح';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address field
              TextFormField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: _inputDecoration(
                  label: 'وصف الموقع',
                  hint: 'مثال: أمام محطة أبا نفسو',
                  icon: Icons.location_on,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'وصف الموقع مطلوب';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Destination toggle + field
              Row(
                children: [
                  Switch(
                    value: addingDestination,
                    onChanged: onToggleDestination,
                    activeColor: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'إضافة وجهة (اختياري)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ],
              ),
              if (addingDestination) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: destinationCtrl,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    label: 'وصف الوجهة',
                    hint: 'مثال: ميسكل سكوير',
                    icon: Icons.flag,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: dropoffLocation != null
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: dropoffLocation != null
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dropoffLocation != null
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: dropoffLocation != null
                            ? Colors.blue.shade700
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dropoffLocation != null
                            ? 'تم تحديد الوجهة على الخريطة (pin أخضر)'
                            : 'انقر على الخريطة لتحديد الوجهة (pin أخضر)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: dropoffLocation != null
                              ? Colors.blue.shade800
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Map location indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: pickupLocation != null
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: pickupLocation != null
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pickupLocation != null
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 18,
                      color: pickupLocation != null
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickupLocation != null
                            ? 'تم تحديد الموقع: ${pickupLocation!.latitude.toStringAsFixed(4)}, ${pickupLocation!.longitude.toStringAsFixed(4)}'
                            : 'انقر على الخريطة لتحديد موقع الراكب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: pickupLocation != null
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Vehicle type
              DropdownButtonFormField<String>(
                value: vehicleType,
                decoration: _inputDecoration(
                  label: 'نوع السيارة',
                  hint: '',
                  icon: Icons.directions_car,
                ),
                items: _vehicleTypes
                    .map((t) => DropdownMenuItem(
                          value: t.$1,
                          child: Text(
                            t.$2,
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onVehicleTypeChanged(v);
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: _inputDecoration(
                  label: 'ملاحظات (اختياري)',
                  hint: 'مثال: ينتظر عند البوابة الخضراء',
                  icon: Icons.notes,
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.directions_car),
                  label: Text(isLoading ? 'جاري الإرسال...' : 'إرسال الطلب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

// ─── Map Card ─────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  final Set<Marker> markers;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(LatLng) onTap;
  final LatLng? pickupLocation;
  final bool addingDestination;
  final double? height;

  const _MapCard({
    required this.markers,
    required this.onMapCreated,
    required this.onTap,
    required this.pickupLocation,
    this.addingDestination = false,
    this.height,
  });

  static const LatLng _addisCenter = LatLng(9.0280, 38.7469);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.map, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  addingDestination ? 'تحديد الوجهة' : 'تحديد موقع الراكب',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  addingDestination ? 'انقر لوضع pin أخضر' : 'انقر لوضع pin أحمر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height ?? 500,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _addisCenter,
                zoom: 13,
              ),
              markers: markers,
              onMapCreated: onMapCreated,
              onTap: onTap,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success Card ─────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onNewRide;

  const _SuccessCard({required this.result, required this.onNewRide});

  @override
  Widget build(BuildContext context) {
    final driverName     = result['driver_name']     as String? ?? 'سائق';
    final driverPhone    = result['driver_phone']    as String? ?? '';
    final etaMinutes     = result['eta_minutes']     as int? ?? 5;
    final rideId         = result['ride_id']         as String? ?? '';
    final estimatedPrice = result['estimated_price'] as num?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text(
              'تم إرسال الطلب بنجاح',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow(icon: Icons.person, label: 'السائق', value: driverName),
            if (driverPhone.isNotEmpty)
              _InfoRow(icon: Icons.phone, label: 'هاتف السائق', value: driverPhone),
            _InfoRow(
              icon: Icons.access_time,
              label: 'الوقت المتوقع للوصول',
              value: '$etaMinutes دقائق',
            ),
            if (estimatedPrice != null && estimatedPrice > 0)
              _InfoRow(
                icon: Icons.payments,
                label: 'السعر التقديري',
                value: '${estimatedPrice.toStringAsFixed(0)} ETB',
              )
            else
              _InfoRow(
                icon: Icons.timer,
                label: 'السعر',
                value: 'يُحسب عند الإنهاء',
              ),
            _InfoRow(
              icon: Icons.tag,
              label: 'رقم الرحلة',
              value: rideId.length > 8 ? rideId.substring(0, 8).toUpperCase() : rideId,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onNewRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_call),
                label: const Text(
                  'طلب رحلة جديدة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
