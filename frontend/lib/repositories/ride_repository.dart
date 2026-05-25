import 'dart:async';

import '../models/models.dart';
import '../services/api_service.dart';

/// Repository layer that sits between BLoCs / UI and [ApiService].
///
/// Provides higher-level operations such as estimate fetching,
/// ride creation, status polling, and real-time subscriptions.
class RideRepository {
  final ApiService _api;

  RideRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  // ─── Auth ─────────────────────────────────────────────────────────────

  Future<void> login({required String phone, required String password}) =>
      _api.login(phone: phone, password: password);

  Future<void> logout() => _api.logout();

  Future<bool> get isAuthenticated => _api.isAuthenticated;

  // ─── Rides ────────────────────────────────────────────────────────────

  /// Checks if the user has an ongoing ride (e.g. on app startup).
  Future<Ride?> getCurrentRide() => _api.getCurrentRide();

  /// Fetches price estimates for available car classes.
  Future<List<RideEstimate>> getEstimates({
    required double pickupLat,
    required double pickupLon,
    required double dropoffLat,
    required double dropoffLon,
  }) => _api.getEstimates(
    pickupLat: pickupLat,
    pickupLon: pickupLon,
    dropoffLat: dropoffLat,
    dropoffLon: dropoffLon,
  );

  /// Creates a new ride.
  Future<Ride> createRide({
    required double pickupLat,
    required double pickupLon,
    required double dropoffLat,
    required double dropoffLon,
    required String pickupAddress,
    required String dropoffAddress,
    required CarClass carClass,
    String? comment,
  }) => _api.createRide(
    pickupLat: pickupLat,
    pickupLon: pickupLon,
    dropoffLat: dropoffLat,
    dropoffLon: dropoffLon,
    pickupAddress: pickupAddress,
    dropoffAddress: dropoffAddress,
    carClass: carClass,
    comment: comment,
  );

  /// One-shot poll for ride status.
  Future<Ride> getRide(int rideId) => _api.getRideById(rideId);

  /// Cancels an active or searching ride.
  Future<void> cancelRide(int rideId) => _api.cancelRide(rideId);

  /// Returns a broadcast stream of [Ride] updates over STOMP WebSocket.
  ///
  /// The stream emits every real-time update for the given [rideId].
  /// Disposing the subscription calls [ApiService.unsubscribeFromRideUpdates].
  Stream<Ride> watchRide(int rideId) {
    final controller = StreamController<Ride>.broadcast();

    _api.subscribeToRideUpdates(
      rideId: rideId,
      onUpdate: (ride) {
        if (!controller.isClosed) {
          controller.add(ride);
        }
      },
    );

    controller.onCancel = () {
      _api.unsubscribeFromRideUpdates();
      controller.close();
    };

    return controller.stream;
  }
}
