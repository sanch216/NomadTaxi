import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/models.dart';

/// Low-level HTTP + WebSocket client for the AIS-TAXI backend.
///
/// All REST calls go through [_dio]; real-time ride updates arrive
/// via a STOMP subscription over WebSocket.
class ApiService {
  // ─── Configuration ────────────────────────────────────────────────────
  // TODO: move to environment config / .env
  static const String _baseUrl = 'http://192.168.88.87:8080';
  static const String _wsUrl = 'http://192.168.88.87:8080/ws';

  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';

  // ─── Internals ────────────────────────────────────────────────────────
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  StompClient? _stompClient;

  // Singleton ----------------------------------------------------------
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Attach JWT to every outgoing request automatically.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // TODO: handle 401 → refresh or redirect to login
          handler.next(error);
        },
      ),
    );
  }

  // ─── Auth ─────────────────────────────────────────────────────────────

  /// POST /api/auth/login
  /// Returns the authenticated [User] and persists the JWT.
  /// POST /auth/login
  /// Returns the JWT token and persists it.
  Future<String> login({
    required String phone,
    required String password,
  }) async {
    // Clear old token to avoid 403 from stale sessions on permitAll endpoints
    await logout();

    final response = await _dio.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;

    // Persist JWT + role
    final token = data['token'] as String;
    final role = data['role'] as String? ?? 'CLIENT';
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    return role;
  }

  /// POST /auth/register
  /// Registers a new user and persists the JWT.
  Future<String> register({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'role': 'CLIENT',
      },
    );
    final data = response.data as Map<String, dynamic>;

    // Persist JWT + role
    final token = data['token'] as String;
    final role = data['role'] as String? ?? 'CLIENT';
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    return role;
  }

  /// Remove the stored JWT and role (log out).
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    _stompClient?.deactivate();
  }

  /// Check whether a JWT is present (quick gate check, no server call).
  Future<bool> get isAuthenticated async =>
      (await _storage.read(key: _tokenKey)) != null;

  /// Returns the stored user role ('CLIENT' or 'DRIVER'), or null if not set.
  Future<String?> get userRole async => await _storage.read(key: _roleKey);

  // ─── Profile ──────────────────────────────────────────────────────────

  /// GET /api/users/me
  /// Returns the authenticated user's profile.
  Future<User> getProfile() async {
    final response = await _dio.get('/api/users/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// PUT /api/users/me
  /// Updates the user's profile (name).
  Future<User> updateProfile({required String fullName}) async {
    final response = await _dio.put(
      '/api/users/me',
      data: {'fullName': fullName},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Ride History ─────────────────────────────────────────────────────

  /// GET /api/rides/history
  /// Returns completed & cancelled rides for the authenticated user.
  Future<List<Ride>> getRideHistory() async {
    final response = await _dio.get('/api/rides/history');
    final list = response.data as List;
    return list.map((e) => Ride.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Rides ────────────────────────────────────────────────────────────

  /// GET /api/rides/current
  /// Returns the currently active ride (if any) — used on startup.
  Future<Ride?> getCurrentRide() async {
    try {
      final response = await _dio.get('/api/rides/current');
      if (response.statusCode == 200 && response.data != null) {
        return Ride.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /api/rides/estimate
  /// Returns price estimates for all available car classes.
  Future<List<RideEstimate>> getEstimates({
    required double pickupLat,
    required double pickupLon,
    required double dropoffLat,
    required double dropoffLon,
  }) async {
    final response = await _dio.post(
      '/api/rides/estimate',
      data: {
        'pickupLat': pickupLat,
        'pickupLon': pickupLon,
        'dropoffLat': dropoffLat,
        'dropoffLon': dropoffLon,
      },
    );
    final list = response.data as List;
    return list
        .map((e) => RideEstimate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/rides
  /// Creates a new ride order and returns the ride object.
  Future<Ride> createRide({
    required double pickupLat,
    required double pickupLon,
    required double dropoffLat,
    required double dropoffLon,
    required String pickupAddress,
    required String dropoffAddress,
    required CarClass carClass,
    String? comment,
  }) async {
    final response = await _dio.post(
      '/api/rides',
      data: {
        'pickupLat': pickupLat,
        'pickupLon': pickupLon,
        'dropoffLat': dropoffLat,
        'dropoffLon': dropoffLon,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'requestedCarClass': carClass.value,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return Ride.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/rides/{id}
  /// Polls the current status of a ride by its [rideId].
  Future<Ride> getRideById(int rideId) async {
    final response = await _dio.get('/api/rides/$rideId');
    return Ride.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── WebSocket (STOMP) ────────────────────────────────────────────────

  /// Opens a STOMP connection and subscribes to updates for [rideId].
  /// Each update is decoded into a [Ride] and emitted to [onUpdate].
  void subscribeToRideUpdates({
    required int rideId,
    required void Function(Ride ride) onUpdate,
  }) {
    _stompClient?.deactivate();

    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: _wsUrl,
        onConnect: (frame) {
          _stompClient!.subscribe(
            destination: '/topic/ride/$rideId',
            callback: (frame) {
              if (frame.body != null) {
                final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                onUpdate(Ride.fromJson(data));
              }
            },
          );
        },
        onWebSocketError: (error) {
          // TODO: implement reconnection / error handling
          // ignore: avoid_print
          print('WebSocket error: $error');
        },
      ),
    );

    _stompClient!.activate();
  }

  /// Disconnects the active STOMP session.
  void unsubscribeFromRideUpdates() {
    _stompClient?.deactivate();
    _stompClient = null;
  }

  // ─── Driver Endpoints ─────────────────────────────────────────────────

  /// GET /api/rides/feed
  /// Returns available ride requests for the driver.
  Future<List<Map<String, dynamic>>> getDriverFeed() async {
    final response = await _dio.get('/api/rides/feed');
    final list = response.data as List;
    return list.cast<Map<String, dynamic>>();
  }

  /// GET /api/rides/current (raw map for driver)
  Future<Map<String, dynamic>?> getDriverCurrentRide() async {
    try {
      final response = await _dio.get('/api/rides/current');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// POST /api/rides/{id}/accept
  Future<Map<String, dynamic>> acceptRide(int rideId) async {
    final response = await _dio.post('/api/rides/$rideId/accept');
    return response.data as Map<String, dynamic>;
  }

  /// PUT /api/rides/{id}/status?status={status}
  Future<Map<String, dynamic>> updateRideStatus(
    int rideId,
    String status,
  ) async {
    final response = await _dio.put(
      '/api/rides/$rideId/status',
      queryParameters: {'status': status},
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /api/rides/{id}/rate-passenger?rating={rating}
  Future<void> ratePassenger(int rideId, double rating) async {
    await _dio.post(
      '/api/rides/$rideId/rate-passenger',
      queryParameters: {'rating': rating},
    );
  }

  /// PUT /api/driver/location
  Future<void> updateDriverLocation({
    required double lat,
    required double lon,
    String? status,
  }) async {
    final params = <String, dynamic>{'lat': lat, 'lon': lon};
    if (status != null) params['status'] = status;
    await _dio.put('/api/driver/location', queryParameters: params);
  }

  /// POST /api/rides/{id}/cancel (driver-side cancel)
  Future<void> cancelRide(int rideId) async {
    await _dio.post('/api/rides/$rideId/cancel');
  }

  /// GET /api/driver/earnings
  Future<DriverEarnings> getEarnings() async {
    final response = await _dio.get('/api/driver/earnings');
    return DriverEarnings.fromJson(response.data as Map<String, dynamic>);
  }
}
