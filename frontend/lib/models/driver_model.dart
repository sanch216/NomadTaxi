import 'package:equatable/equatable.dart';

/// Driver details attached to an active ride.
class Driver extends Equatable {
  final String name;
  final String carModel;
  final String licensePlate;
  final double rating;
  final double? currentLat;
  final double? currentLon;

  const Driver({
    required this.name,
    required this.carModel,
    required this.licensePlate,
    required this.rating,
    this.currentLat,
    this.currentLon,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    name: json['name'] as String,
    carModel: json['carModel'] as String,
    licensePlate: json['licensePlate'] as String,
    rating: (json['rating'] as num).toDouble(),
    currentLat: (json['currentLat'] as num?)?.toDouble(),
    currentLon: (json['currentLon'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'carModel': carModel,
    'licensePlate': licensePlate,
    'rating': rating,
    'currentLat': currentLat,
    'currentLon': currentLon,
  };

  @override
  List<Object?> get props => [
    name,
    carModel,
    licensePlate,
    rating,
    currentLat,
    currentLon,
  ];
}
