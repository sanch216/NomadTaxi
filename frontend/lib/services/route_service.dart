import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route data with polyline points and estimated travel time.
class RouteInfo {
  final List<LatLng> points;
  final Duration eta;
  const RouteInfo({required this.points, required this.eta});
}

/// Service that fetches real road routes from OSRM (free, no API key needed).
class RouteService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://router.project-osrm.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Fetch the road route between [origin] and [destination].
  /// Returns a list of [LatLng] points tracing the road.
  static Future<List<LatLng>> getRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await _dio.get(
        '/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'polyline'},
      );

      final data = response.data;
      if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
        return [origin, destination]; // fallback to straight line
      }

      final geometry = data['routes'][0]['geometry'] as String;
      return _decodePolyline(geometry);
    } catch (_) {
      // If OSRM is unreachable, fallback to straight line.
      return [origin, destination];
    }
  }

  /// Fetch route + estimated travel time.
  static Future<RouteInfo> getRouteWithEta(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await _dio.get(
        '/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'polyline'},
      );

      final data = response.data;
      if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
        return RouteInfo(points: [origin, destination], eta: Duration.zero);
      }

      final route = data['routes'][0];
      final geometry = route['geometry'] as String;
      final durationSec = (route['duration'] as num).toDouble();
      return RouteInfo(
        points: _decodePolyline(geometry),
        eta: Duration(seconds: durationSec.round()),
      );
    } catch (_) {
      return RouteInfo(points: [origin, destination], eta: Duration.zero);
    }
  }

  /// Decode a Google-encoded polyline string into a list of [LatLng].
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
