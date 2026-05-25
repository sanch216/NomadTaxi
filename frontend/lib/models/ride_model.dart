import 'package:equatable/equatable.dart';

import 'driver_model.dart';

/// Possible ride lifecycle statuses.
enum RideStatus {
  searching('SEARCHING'),
  accepted('ACCEPTED'),
  arrived('ARRIVED'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  noDriver('NO_DRIVER_FOUND');

  final String value;
  const RideStatus(this.value);

  static RideStatus fromString(String value) => RideStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => RideStatus.searching,
  );
}

/// Represents a single ride from creation through completion.
class Ride extends Equatable {
  final int id;
  final RideStatus status;
  final double price;
  final Driver? driverDetails;
  // Additional fields from RideResponse (for history)
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? carClass;
  final DateTime? createdAt;

  const Ride({
    required this.id,
    required this.status,
    required this.price,
    this.driverDetails,
    this.pickupAddress,
    this.dropoffAddress,
    this.carClass,
    this.createdAt,
  });

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
    id: json['id'] as int,
    status: RideStatus.fromString(json['status'] as String),
    price: (json['price'] as num).toDouble(),
    driverDetails: _parseDriver(json),
    pickupAddress: json['pickupAddress'] as String?,
    dropoffAddress: json['dropoffAddress'] as String?,
    carClass: json['requestedCarClass'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
  );

  /// Parse driver info from either a nested `driverDetails` map
  /// or flat fields (`driverName`, `carModel`, `carNumber`) sent by backend.
  static Driver? _parseDriver(Map<String, dynamic> json) {
    // Option 1: nested object (e.g. from mock or future refactor)
    if (json['driverDetails'] != null && json['driverDetails'] is Map) {
      return Driver.fromJson(json['driverDetails'] as Map<String, dynamic>);
    }
    // Option 2: flat fields from RideResponse DTO
    final driverName = json['driverName'] as String?;
    if (driverName != null && driverName.isNotEmpty) {
      return Driver(
        name: driverName,
        carModel: (json['carModel'] as String?) ?? '',
        licensePlate: (json['carNumber'] as String?) ?? '',
        rating: 0.0,
        currentLat: (json['driverLat'] as num?)?.toDouble(),
        currentLon: (json['driverLon'] as num?)?.toDouble(),
      );
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.value,
    'price': price,
    'driverDetails': driverDetails?.toJson(),
  };

  /// Returns a copy of this ride with optionally overridden fields.
  Ride copyWith({
    int? id,
    RideStatus? status,
    double? price,
    Driver? driverDetails,
  }) => Ride(
    id: id ?? this.id,
    status: status ?? this.status,
    price: price ?? this.price,
    driverDetails: driverDetails ?? this.driverDetails,
    pickupAddress: pickupAddress,
    dropoffAddress: dropoffAddress,
    carClass: carClass,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, status, price, driverDetails];
}
