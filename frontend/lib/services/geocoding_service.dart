import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service that fetches real address data using 2GIS APIs:
/// - 2GIS Suggest API (/3.0/suggests) for address autocomplete
/// - 2GIS Geocode API (/3.0/items/geocode) for reverse geocoding
class GeocodingService {
  static const String _apiKey = 'a9c39875-6326-4dd8-a557-65cdcff63749';

  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://catalog.api.2gis.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// In-memory cache: cacheKey → results.
  static final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  /// Cache for reverse geocoding results.
  static final Map<String, String> _reverseCache = {};

  /// Search for an address using 2GIS Suggest API.
  ///
  /// Uses /3.0/suggests with suggest_type=route_endpoint to get
  /// location-aware suggestions with coordinates.
  static Future<List<Map<String, dynamic>>> searchAddress(
    String query, {
    LatLng? nearLocation,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final locKey = nearLocation != null
        ? '${nearLocation.latitude.toStringAsFixed(2)},${nearLocation.longitude.toStringAsFixed(2)}'
        : '';
    final cacheKey = '$trimmed:$locKey';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final params = <String, dynamic>{
        'key': _apiKey,
        'q': trimmed,
        'locale': 'ru_KG',
        'suggest_type': 'route_endpoint',
        'fields':
            'items.point,items.full_name,items.geometry,items.address_name',
        'page_size': 7,
      };

      // Bias results to user's location (format: lon,lat)
      if (nearLocation != null) {
        params['location'] =
            '${nearLocation.longitude},${nearLocation.latitude}';
      }

      final response = await _dio.get('/3.0/suggests', queryParameters: params);
      final data = response.data;

      if (data['meta']?['code'] != 200) return [];

      final items = data['result']?['items'] as List? ?? [];

      final results = <Map<String, dynamic>>[];
      for (final item in items) {
        final type = item['type'] as String? ?? '';

        // Skip pure text query suggestions (type == "user_query")
        if (type == 'user_query') continue;

        final name = item['name'] as String? ?? '';
        final fullName =
            item['full_name'] as String? ??
            item['address_name'] as String? ??
            name;

        // Parse coordinates from "point" field (object: {"lat": ..., "lon": ...})
        double? lat;
        double? lon;

        final point = item['point'];
        if (point is Map) {
          lat = (point['lat'] as num?)?.toDouble();
          lon = (point['lon'] as num?)?.toDouble();
        }

        if (lat == null || lon == null) continue;

        results.add({
          'title': name,
          'subtitle': fullName,
          'lat': lat,
          'lon': lon,
        });
      }

      _searchCache[cacheKey] = results;
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Get address string from coordinates using 2GIS Reverse Geocode API.
  static Future<String?> getAddressFromLatLng(LatLng latLng) async {
    final key =
        '${latLng.latitude.toStringAsFixed(5)},${latLng.longitude.toStringAsFixed(5)}';
    if (_reverseCache.containsKey(key)) return _reverseCache[key];

    try {
      final response = await _dio.get(
        '/3.0/items/geocode',
        queryParameters: {
          'lat': latLng.latitude,
          'lon': latLng.longitude,
          'key': _apiKey,
          'locale': 'ru_KG',
          'fields': 'items.address_name,items.full_name',
        },
      );

      final data = response.data;
      if (data['meta']?['code'] != 200) return null;

      final items = data['result']?['items'] as List? ?? [];
      if (items.isEmpty) return null;

      final first = items.first;
      final addrName = first['address_name'] as String? ?? '';
      final name = first['name'] as String? ?? '';

      final result = addrName.isNotEmpty ? addrName : name;
      if (result.isNotEmpty) {
        _reverseCache[key] = result;
      }
      return result.isNotEmpty ? result : null;
    } catch (_) {
      return null;
    }
  }

  /// Clear the search cache.
  static void clearCache() {
    _searchCache.clear();
  }
}
