class DriverRegistrationEntity {
  final String? fullName;
  final String? nationalId;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final String? nationalIdUrl;
  final String? licenseUrl;
  final String? vehicleType;
  final String? plateNumber;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;

  const DriverRegistrationEntity({
    this.fullName,
    this.nationalId,
    this.licenseNumber,
    this.licenseExpiry,
    this.nationalIdUrl,
    this.licenseUrl,
    this.vehicleType,
    this.plateNumber,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
  });

  DriverRegistrationEntity copyWith({
    String? fullName,
    String? nationalId,
    String? licenseNumber,
    DateTime? licenseExpiry,
    String? nationalIdUrl,
    String? licenseUrl,
    String? vehicleType,
    String? plateNumber,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
  }) {
    return DriverRegistrationEntity(
      fullName: fullName ?? this.fullName,
      nationalId: nationalId ?? this.nationalId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      nationalIdUrl: nationalIdUrl ?? this.nationalIdUrl,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
    );
  }

  bool get isPersonalInfoComplete =>
      fullName != null &&
      fullName!.isNotEmpty &&
      nationalId != null &&
      nationalId!.isNotEmpty;

  bool get isLicenseInfoComplete =>
      licenseNumber != null &&
      licenseNumber!.isNotEmpty &&
      licenseExpiry != null;

  bool get isDocumentsComplete =>
      nationalIdUrl != null && licenseUrl != null;

  bool get isVehicleInfoComplete =>
      vehicleType != null &&
      plateNumber != null &&
      plateNumber!.isNotEmpty &&
      vehicleModel != null &&
      vehicleModel!.isNotEmpty &&
      vehicleYear != null &&
      vehicleColor != null &&
      vehicleColor!.isNotEmpty;

  bool get isComplete =>
      isPersonalInfoComplete &&
      isLicenseInfoComplete &&
      isDocumentsComplete &&
      isVehicleInfoComplete;

  Map<String, dynamic> toDriverUpdate() {
    return {
      'name': fullName,
      'national_id': nationalId,
      'status': 'pending',
    };
  }

  Map<String, dynamic> toRegistrationJson() {
    return {
      'full_name': fullName,
      'national_id': nationalId,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'national_id_url': nationalIdUrl,
      'license_url': licenseUrl,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
    };
  }
}
