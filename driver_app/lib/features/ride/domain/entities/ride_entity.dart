class RideEntity {
  final String id;
  final String passengerId;
  final String? driverId;
  final String passengerName;
  final double passengerRating;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String vehicleType;
  final double agreedPrice;
  final String status; // requested, accepted, driver_arrived, in_progress, completed, cancelled
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? passengerPhone;
  final double? driverLat;
  final double? driverLng;
  final double? driverHeading;
  final String rideType; // 'app_request' | 'street_hail' | 'call_center' | 'ai_call'
  final double? estimatedPrice;

  const RideEntity({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.vehicleType,
    required this.agreedPrice,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.passengerPhone,
    this.driverLat,
    this.driverLng,
    this.driverHeading,
    this.rideType = 'app_request',
    this.estimatedPrice,
  });

  bool get isAccepted => status == 'accepted';
  bool get isDriverArrived => status == 'driver_arrived';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isStreetHail => rideType == 'street_hail';
  bool get isCallCenter => rideType == 'call_center';
  bool get isAiCall     => rideType == 'ai_call';

  bool get isActive =>
      status == 'accepted' ||
      status == 'driver_arrived' ||
      status == 'in_progress';
}
