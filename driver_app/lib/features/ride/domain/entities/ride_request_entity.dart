class RideRequestEntity {
  final String rideId;
  final String passengerId;
  final String passengerName;
  final double passengerRating;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String vehicleType;
  final double estimatedPrice;
  final double distanceKm;
  final DateTime expiresAt;
  final int competitorCount;

  const RideRequestEntity({
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.vehicleType,
    required this.estimatedPrice,
    required this.distanceKm,
    required this.expiresAt,
    this.competitorCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get secondsRemaining =>
      expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 45);
}
