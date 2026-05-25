import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/models.dart';
import '../../repositories/ride_repository.dart';
import '../../services/geocoding_service.dart';
import '../../services/route_service.dart';
import 'package:dio/dio.dart';

// ─── State ──────────────────────────────────────────────────────────────────

enum HomePhase {
  /// Map visible, "Where to?" bar shown.
  idle,

  /// User picked a destination → ride estimates loaded.
  rideOptions,

  /// Ride request sent, searching for a driver.
  findingDriver,

  /// Driver found, ride in progress (ACCEPTED / ARRIVED / IN_PROGRESS).
  rideActive,

  /// Ride finished — show rating screen.
  completed,
}

class HomeState extends Equatable {
  final HomePhase phase;
  final LatLng? pickup;
  final LatLng? dropoff;
  final String? pickupAddress;
  final String? dropoffAddress;
  final List<RideEstimate> estimates;
  final CarClass selectedClass;
  final Ride? activeRide;
  final bool isLoading;
  final String? error;
  final int rating;
  final List<LatLng> routePoints;
  final Duration routeEta;
  final String comment;

  const HomeState({
    this.phase = HomePhase.idle,
    this.pickup,
    this.dropoff,
    this.pickupAddress,
    this.dropoffAddress,
    this.estimates = const [],
    this.selectedClass = CarClass.economy,
    this.activeRide,
    this.isLoading = false,
    this.error,
    this.rating = 0,
    this.routePoints = const [],
    this.routeEta = Duration.zero,
    this.comment = '',
  });

  HomeState copyWith({
    HomePhase? phase,
    LatLng? pickup,
    LatLng? dropoff,
    String? pickupAddress,
    String? dropoffAddress,
    List<RideEstimate>? estimates,
    CarClass? selectedClass,
    Ride? activeRide,
    bool? isLoading,
    String? error,
    int? rating,
    List<LatLng>? routePoints,
    Duration? routeEta,
    String? comment,
  }) => HomeState(
    phase: phase ?? this.phase,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    pickupAddress: pickupAddress ?? this.pickupAddress,
    dropoffAddress: dropoffAddress ?? this.dropoffAddress,
    estimates: estimates ?? this.estimates,
    selectedClass: selectedClass ?? this.selectedClass,
    activeRide: activeRide ?? this.activeRide,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    rating: rating ?? this.rating,
    routePoints: routePoints ?? this.routePoints,
    routeEta: routeEta ?? this.routeEta,
    comment: comment ?? this.comment,
  );

  @override
  List<Object?> get props => [
    phase,
    pickup,
    dropoff,
    pickupAddress,
    dropoffAddress,
    estimates,
    selectedClass,
    activeRide,
    isLoading,
    error,
    rating,
    routePoints,
    routeEta,
    comment,
  ];
}

// ─── Cubit ──────────────────────────────────────────────────────────────────

class HomeCubit extends Cubit<HomeState> {
  final RideRepository _repo;
  StreamSubscription<Ride>? _rideSub;
  Timer? _pollTimer;

  HomeCubit({RideRepository? repository})
    : _repo = repository ?? RideRepository(),
      super(const HomeState());

  /// Called on app startup to resume an active ride if one exists.
  Future<void> loadCurrentRide() async {
    try {
      final ride = await _repo.getCurrentRide();
      if (ride != null) {
        _onRideUpdate(ride);
        _subscribeToRide(ride.id);
        _startPolling(ride.id);
      }
    } catch (_) {
      // Ignore errors (e.g., 404 No active ride or network issue)
    }
  }

  // ── Destination selection ──────────────────────────────────────────────

  /// Called when the user picks a destination from the search dialog.
  Future<void> setDestination({
    required LatLng pickup,
    required LatLng dropoff,
    String? pickupAddress,
    String? dropoffAddress,
  }) async {
    emit(
      state.copyWith(
        pickup: pickup,
        dropoff: dropoff,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        isLoading: true,
        error: null,
      ),
    );

    try {
      // Fetch route and estimates in parallel.
      final results = await Future.wait([
        RouteService.getRouteWithEta(pickup, dropoff),
        _repo.getEstimates(
          pickupLat: pickup.latitude,
          pickupLon: pickup.longitude,
          dropoffLat: dropoff.latitude,
          dropoffLon: dropoff.longitude,
        ),
      ]);

      final routeInfo = results[0] as RouteInfo;
      final estimates = results[1] as List<RideEstimate>;

      emit(
        state.copyWith(
          phase: HomePhase.rideOptions,
          estimates: estimates,
          routePoints: routeInfo.points,
          routeEta: routeInfo.eta,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Update the passenger comment for the ride.
  void setComment(String comment) {
    emit(state.copyWith(comment: comment));
  }

  /// Select a car class from the estimate list.
  void selectCarClass(CarClass carClass) {
    emit(state.copyWith(selectedClass: carClass));
  }

  // ── Ride request ──────────────────────────────────────────────────────

  /// Create the ride order, subscribe to WebSocket updates,
  /// and transition to [HomePhase.findingDriver].
  Future<void> requestRide() async {
    if (state.pickup == null || state.dropoff == null) return;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final ride = await _repo.createRide(
        pickupLat: state.pickup!.latitude,
        pickupLon: state.pickup!.longitude,
        dropoffLat: state.dropoff!.latitude,
        dropoffLon: state.dropoff!.longitude,
        pickupAddress: state.pickupAddress ?? '',
        dropoffAddress: state.dropoffAddress ?? '',
        carClass: state.selectedClass,
        comment: state.comment.isNotEmpty ? state.comment : null,
      );

      emit(
        state.copyWith(
          phase: HomePhase.findingDriver,
          activeRide: ride,
          isLoading: false,
        ),
      );

      // Subscribe to real-time ride updates via WebSocket.
      _subscribeToRide(ride.id);

      // Start polling as fallback in case WebSocket fails.
      _startPolling(ride.id);
    } on DioException catch (e) {
      String msg = 'Failed to request ride';
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        if (data.containsKey('error')) {
          msg = data['error'].toString();
        }
      }
      emit(state.copyWith(isLoading: false, error: msg));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Cancel the current ride search / request.
  Future<void> cancelRequest() async {
    if (state.activeRide != null) {
      try {
        await _repo.cancelRide(state.activeRide!.id);
      } catch (_) {
        // Ignore API error if it was already cancelled or network failed
      }
    }
    _rideSub?.cancel();
    _rideSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    emit(state.copyWith(phase: HomePhase.idle, activeRide: null));
  }

  // ── WebSocket subscription ────────────────────────────────────────────

  void _subscribeToRide(int rideId) {
    _rideSub?.cancel();
    _rideSub = _repo.watchRide(rideId).listen(_onRideUpdate);
  }

  void _onRideUpdate(Ride ride) {
    final newPhase = switch (ride.status) {
      RideStatus.searching => HomePhase.findingDriver,
      RideStatus.accepted ||
      RideStatus.arrived ||
      RideStatus.inProgress => HomePhase.rideActive,
      RideStatus.completed => HomePhase.completed,
      RideStatus.cancelled || RideStatus.noDriver => HomePhase.idle,
    };

    emit(state.copyWith(phase: newPhase, activeRide: ride));

    // Stop polling and WebSocket once ride ends.
    if (ride.status == RideStatus.completed ||
        ride.status == RideStatus.cancelled ||
        ride.status == RideStatus.noDriver) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _rideSub?.cancel();
      _rideSub = null;
    }
  }

  // ── Polling fallback ───────────────────────────────────────────────────

  /// Periodically polls ride status as a fallback in case WebSocket
  /// doesn't deliver updates (common with emulators / firewalls).
  void _startPolling(int rideId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (isClosed) return;
      try {
        final ride = await _repo.getRide(rideId);
        _onRideUpdate(ride);
      } catch (_) {
        // Ignore polling errors — WebSocket or next poll will catch up.
      }
    });
  }

  // ── Rating ────────────────────────────────────────────────────────────

  void setRating(int stars) {
    emit(state.copyWith(rating: stars));
  }

  /// Submit rating and reset to idle.
  Future<void> submitRating() async {
    // TODO: call _repo.submitRating(state.activeRide!.id, state.rating)
    // For now just reset.
    reset();
  }

  // ── Mock: simulate driver acceptance (for testing without backend) ────

  /// Call this to simulate the full lifecycle without a real server.
  void mockDriverFound() {
    if (state.activeRide == null) return;

    final mockDriver = const Driver(
      name: 'Arman K.',
      carModel: 'Toyota Camry 70',
      licensePlate: '123 ABC 02',
      rating: 4.9,
      currentLat: 43.2400,
      currentLon: 76.9500,
    );

    final updatedRide = state.activeRide!.copyWith(
      status: RideStatus.accepted,
      driverDetails: mockDriver,
    );

    emit(state.copyWith(phase: HomePhase.rideActive, activeRide: updatedRide));
  }

  /// Simulate ride completion.
  void mockRideCompleted() {
    if (state.activeRide == null) return;

    final updatedRide = state.activeRide!.copyWith(
      status: RideStatus.completed,
    );

    emit(state.copyWith(phase: HomePhase.completed, activeRide: updatedRide));
  }

  // ─── Picking on Map ────────────────────────────────────────────────────────

  void startPicking(bool isPickup) {
    emit(
      state.copyWith(
        phase:
            HomePhase.idle, // Ensure we are in idle or special picking phase?
        // We'll use a separate boolean or just rely on the UI knowing we are in picking mode?
        // Logic: If picking, we show the pin.
        // Let's add specific logic for this.
      ),
    );
    // Actually, `startPicking` is better handled by HomeScreen locally OR by a state flag.
    // Let's stick to the plan: HomeScreen handles the UI overlay, but Cubit needs to know WHERE we are picking to update the address.
  }

  // Actually, for "Pick on Map", the flow is:
  // 1. User taps "Set on Map" in Dialog.
  // 2. Dialog closes returning special flag.
  // 3. HomeScreen sees flag -> Enters "Picking Mode" (local state in HomeScreen or Cubit?)
  // If we want the address to update in real-time as we drag, HomeScreen needs to allow dragging.
  // And call `cubit.updatePickingLocation(LatLng)`.
  // Cubit then does reverse geocoding and updates `state.pickup` or `state.dropoff` depending on what we are picking.

  Future<void> updatePickingLocation(LatLng location, bool isPickup) async {
    // We update the coordinate immediately for smooth UI
    if (isPickup) {
      emit(state.copyWith(pickup: location, pickupAddress: 'Loading...'));
    } else {
      emit(state.copyWith(dropoff: location, dropoffAddress: 'Loading...'));
    }

    try {
      // Real Reverse Geocoding
      final address = await GeocodingService.getAddressFromLatLng(location);
      final formattedAddress =
          address ??
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';

      if (isPickup) {
        emit(state.copyWith(pickup: location, pickupAddress: formattedAddress));
      } else {
        emit(
          state.copyWith(dropoff: location, dropoffAddress: formattedAddress),
        );
      }
    } catch (_) {
      // Keep "Loading..." or show error? Better show coords on error.
      final coords =
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      if (isPickup) {
        emit(state.copyWith(pickup: location, pickupAddress: coords));
      } else {
        emit(state.copyWith(dropoff: location, dropoffAddress: coords));
      }
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────

  void reset() {
    _rideSub?.cancel();
    _rideSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    emit(const HomeState());
  }

  @override
  Future<void> close() {
    _rideSub?.cancel();
    _pollTimer?.cancel();
    return super.close();
  }
}
