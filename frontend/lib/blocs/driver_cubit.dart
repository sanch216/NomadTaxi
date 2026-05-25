import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_service.dart';
import '../services/route_service.dart';

// ─── Feed Item Model ────────────────────────────────────────────────────────

/// A single ride request shown in the driver's feed.
class RideRequest extends Equatable {
  final int rideId;
  final double price;
  final String carClass;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLon;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLon;

  const RideRequest({
    required this.rideId,
    required this.price,
    required this.carClass,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLon,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLon,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
    rideId: json['rideId'] as int,
    price: (json['price'] as num).toDouble(),
    carClass: json['carClass'] as String? ?? 'ECONOMY',
    pickupAddress: json['pickupAddress'] as String? ?? 'Pickup',
    pickupLat: (json['pickupLat'] as num).toDouble(),
    pickupLon: (json['pickupLon'] as num).toDouble(),
    dropoffAddress: json['dropoffAddress'] as String? ?? 'Dropoff',
    dropoffLat: (json['dropoffLat'] as num).toDouble(),
    dropoffLon: (json['dropoffLon'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [rideId];
}

// ─── Active Ride Model ──────────────────────────────────────────────────────

class ActiveRide extends Equatable {
  final int rideId;
  final String status;
  final double price;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLon;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLon;
  final String? passengerName;
  final String? passengerPhone;
  final double? passengerRating;
  final String carClass;
  final String? comment;

  const ActiveRide({
    required this.rideId,
    required this.status,
    required this.price,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLon,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLon,
    this.passengerName,
    this.passengerPhone,
    this.passengerRating,
    this.carClass = 'ECONOMY',
    this.comment,
  });

  factory ActiveRide.fromJson(Map<String, dynamic> json) => ActiveRide(
    rideId: json['id'] as int,
    status: json['status'] as String,
    price: (json['price'] as num).toDouble(),
    pickupAddress: json['pickupAddress'] as String? ?? '',
    pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 0,
    pickupLon: (json['pickupLon'] as num?)?.toDouble() ?? 0,
    dropoffAddress: json['dropoffAddress'] as String? ?? '',
    dropoffLat: (json['dropoffLat'] as num?)?.toDouble() ?? 0,
    dropoffLon: (json['dropoffLon'] as num?)?.toDouble() ?? 0,
    passengerName: json['clientName'] as String?,
    passengerPhone: json['clientPhone'] as String?,
    passengerRating: (json['clientRating'] as num?)?.toDouble(),
    carClass: json['requestedCarClass'] as String? ?? 'ECONOMY',
    comment: json['comment'] as String?,
  );

  ActiveRide copyWith({String? status}) => ActiveRide(
    rideId: rideId,
    status: status ?? this.status,
    price: price,
    pickupAddress: pickupAddress,
    pickupLat: pickupLat,
    pickupLon: pickupLon,
    dropoffAddress: dropoffAddress,
    dropoffLat: dropoffLat,
    dropoffLon: dropoffLon,
    passengerName: passengerName,
    passengerPhone: passengerPhone,
    passengerRating: passengerRating,
    carClass: carClass,
    comment: comment,
  );

  @override
  List<Object?> get props => [rideId, status];
}

// ─── States ─────────────────────────────────────────────────────────────────

abstract class DriverState extends Equatable {
  const DriverState();
  @override
  List<Object?> get props => [];
}

/// Driver is offline — big toggle is off.
class DriverOffline extends DriverState {
  const DriverOffline();
}

/// Driver is online and waiting for orders.
class DriverOnline extends DriverState {
  const DriverOnline();
}

/// An incoming ride request is available.
class DriverHasRequest extends DriverState {
  final RideRequest request;
  final int secondsLeft;
  final List<LatLng> routePoints;
  const DriverHasRequest({
    required this.request,
    this.secondsLeft = 15,
    this.routePoints = const [],
  });
  @override
  List<Object?> get props => [request, secondsLeft, routePoints];
}

/// Driver is on an active ride.
class DriverActiveRide extends DriverState {
  final ActiveRide ride;
  final List<LatLng> routePoints;
  const DriverActiveRide({required this.ride, this.routePoints = const []});
  @override
  List<Object?> get props => [ride, routePoints];
}

/// Ride just completed — show summary.
class DriverRideComplete extends DriverState {
  final ActiveRide ride;
  const DriverRideComplete({required this.ride});
  @override
  List<Object?> get props => [ride];
}

/// An error occurred.
class DriverError extends DriverState {
  final String message;
  const DriverError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ──────────────────────────────────────────────────────────────────

class DriverCubit extends Cubit<DriverState> {
  final ApiService _api = ApiService();
  Timer? _pollTimer;
  Timer? _countdownTimer;

  // GPS
  double? currentLat;
  double? currentLon;

  DriverCubit() : super(const DriverOffline()) {
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLat = pos.latitude;
      currentLon = pos.longitude;
    } catch (_) {
      // Default to Bishkek center
      currentLat = 42.8746;
      currentLon = 74.5698;
    }
  }

  // ── Go Online ───────────────────────────────────────────────────────────

  Future<void> goOnline() async {
    try {
      await _updateDriverStatus('AVAILABLE');
      emit(const DriverOnline());
      _startPolling();
    } catch (e) {
      emit(DriverError('Failed to go online: $e'));
    }
  }

  // ── Go Offline ──────────────────────────────────────────────────────────

  Future<void> goOffline() async {
    _stopPolling();
    try {
      await _updateDriverStatus('OFFLINE');
    } catch (_) {}
    emit(const DriverOffline());
  }

  // ── Polling for ride requests ──────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    // Don't poll if we're not in the Online state
    if (state is! DriverOnline) return;

    try {
      // First check for an active ride
      final currentRide = await _api.getDriverCurrentRide();
      if (currentRide != null) {
        final ride = ActiveRide.fromJson(currentRide);
        if (ride.status == 'COMPLETED') {
          _stopPolling();
          emit(DriverRideComplete(ride: ride));
        } else {
          _stopPolling();
          emit(DriverActiveRide(ride: ride));
        }
        return;
      }

      // Then check for new ride requests
      final feed = await _api.getDriverFeed();
      if (feed.isNotEmpty) {
        final request = RideRequest.fromJson(feed.first);
        _stopPolling();
        _startCountdown(request);
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  void _startCountdown(RideRequest request) async {
    int seconds = 15;

    // Fetch route: driver's current location → passenger pickup
    List<LatLng> route = const [];
    try {
      if (currentLat != null && currentLon != null) {
        route = await RouteService.getRoute(
          LatLng(currentLat!, currentLon!),
          LatLng(request.pickupLat, request.pickupLon),
        );
      }
    } catch (_) {}

    if (isClosed) return;
    emit(
      DriverHasRequest(
        request: request,
        secondsLeft: seconds,
        routePoints: route,
      ),
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      if (seconds <= 0) {
        timer.cancel();
        emit(const DriverOnline());
        _startPolling();
      } else {
        emit(
          DriverHasRequest(
            request: request,
            secondsLeft: seconds,
            routePoints: route,
          ),
        );
      }
    });
  }

  // ── Accept / Decline ──────────────────────────────────────────────────

  Future<void> acceptRide(int rideId) async {
    _countdownTimer?.cancel();
    try {
      final response = await _api.acceptRide(rideId);
      final ride = ActiveRide.fromJson(response);

      // Route: driver → passenger pickup point
      List<LatLng> route = const [];
      try {
        if (currentLat != null && currentLon != null) {
          route = await RouteService.getRoute(
            LatLng(currentLat!, currentLon!),
            LatLng(ride.pickupLat, ride.pickupLon),
          );
        }
      } catch (_) {}

      if (isClosed) return;
      emit(DriverActiveRide(ride: ride, routePoints: route));
    } catch (e) {
      emit(const DriverOnline());
      _startPolling();
    }
  }

  void declineRide() {
    _countdownTimer?.cancel();
    emit(const DriverOnline());
    _startPolling();
  }

  // ── Status Transitions ────────────────────────────────────────────────

  Future<void> updateRideStatus(int rideId, String newStatus) async {
    try {
      final response = await _api.updateRideStatus(rideId, newStatus);
      final ride = ActiveRide.fromJson(response);

      if (newStatus == 'COMPLETED') {
        emit(DriverRideComplete(ride: ride));
      } else if (newStatus == 'IN_PROGRESS') {
        // Passenger is in car — switch route to pickup → dropoff
        List<LatLng> route = const [];
        try {
          route = await RouteService.getRoute(
            LatLng(ride.pickupLat, ride.pickupLon),
            LatLng(ride.dropoffLat, ride.dropoffLon),
          );
        } catch (_) {}
        emit(DriverActiveRide(ride: ride, routePoints: route));
      } else {
        // ACCEPTED / ARRIVED — keep driver→pickup route
        final currentRoute = state is DriverActiveRide
            ? (state as DriverActiveRide).routePoints
            : const <LatLng>[];
        emit(DriverActiveRide(ride: ride, routePoints: currentRoute));
      }
    } catch (e) {
      emit(DriverError('Failed to update status: $e'));
    }
  }

  // ── Rate Passenger ────────────────────────────────────────────────────

  Future<void> ratePassenger(int rideId, double rating) async {
    try {
      await _api.ratePassenger(rideId, rating);
    } catch (_) {}
    emit(const DriverOnline());
    _startPolling();
  }

  /// Back to online after viewing complete screen without rating.
  void backToOnline() {
    emit(const DriverOnline());
    _startPolling();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<void> _updateDriverStatus(String status) async {
    await _api.updateDriverLocation(
      lat: currentLat ?? 42.8746,
      lon: currentLon ?? 74.5698,
      status: status,
    );
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    return super.close();
  }
}
