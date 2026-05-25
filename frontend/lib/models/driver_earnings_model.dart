import 'package:equatable/equatable.dart';

/// DTO for driver earnings summary.
class DriverEarnings extends Equatable {
  final double todayEarnings;
  final double weekEarnings;
  final int totalRides;

  const DriverEarnings({
    required this.todayEarnings,
    required this.weekEarnings,
    required this.totalRides,
  });

  factory DriverEarnings.fromJson(Map<String, dynamic> json) => DriverEarnings(
    todayEarnings: (json['todayEarnings'] as num).toDouble(),
    weekEarnings: (json['weekEarnings'] as num).toDouble(),
    totalRides: json['totalRides'] as int,
  );

  @override
  List<Object?> get props => [todayEarnings, weekEarnings, totalRides];
}
