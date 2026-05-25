import 'package:equatable/equatable.dart';

/// Represents an authenticated passenger.
class User extends Equatable {
  final int id;
  final String phone;
  final String name;
  final double rating;
  // Driver-only fields (null for passengers)
  final String? carModel;
  final String? licensePlate;

  const User({
    required this.id,
    required this.phone,
    required this.name,
    this.rating = 5.0,
    this.carModel,
    this.licensePlate,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    phone: json['phone'] as String,
    name: (json['name'] ?? json['fullName'] ?? '') as String,
    rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    carModel: json['carModel'] as String?,
    licensePlate:
        json['carNumber'] as String? ?? json['licensePlate'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'rating': rating,
  };

  @override
  List<Object?> get props => [id, phone, name, rating, carModel, licensePlate];
}
