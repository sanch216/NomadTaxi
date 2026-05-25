import 'package:equatable/equatable.dart';

/// Available vehicle classes for ride estimates.
enum CarClass {
  economy('ECONOMY'),
  comfort('COMFORT'),
  business('BUSINESS');

  final String value;
  const CarClass(this.value);

  static CarClass fromString(String value) => CarClass.values.firstWhere(
    (c) => c.value == value,
    orElse: () => CarClass.economy,
  );
}

/// A price / ETA estimate for a specific car class.
class RideEstimate extends Equatable {
  final CarClass carClass;
  final double price;
  final int arrivalTime; // Estimated arrival in minutes.

  const RideEstimate({
    required this.carClass,
    required this.price,
    required this.arrivalTime,
  });

  factory RideEstimate.fromJson(Map<String, dynamic> json) => RideEstimate(
    carClass: CarClass.fromString(json['carClass'] as String),
    price: (json['price'] as num).toDouble(),
    arrivalTime: json['arrivalTime'] as int,
  );

  Map<String, dynamic> toJson() => {
    'carClass': carClass.value,
    'price': price,
    'arrivalTime': arrivalTime,
  };

  @override
  List<Object?> get props => [carClass, price, arrivalTime];
}
