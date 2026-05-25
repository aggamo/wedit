import 'package:equatable/equatable.dart';

class DriverLocationEntity extends Equatable {
  final String driverId;
  final double lat;
  final double lng;
  final double? heading;
  final bool isOnline;
  final String? vehicleType;
  final DateTime? updatedAt;

  const DriverLocationEntity({
    required this.driverId,
    required this.lat,
    required this.lng,
    this.heading,
    this.isOnline = true,
    this.vehicleType,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [driverId, lat, lng, isOnline];
}
