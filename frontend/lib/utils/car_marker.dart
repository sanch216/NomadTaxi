import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws a top-down 2D car icon and returns a [BitmapDescriptor]
/// for use as a Google Maps marker.
class CarMarker {
  static BitmapDescriptor? _cached;

  /// Returns a cached car marker icon (navy blue, top-down view).
  static Future<BitmapDescriptor> create() async {
    if (_cached != null) return _cached!;
    _cached = await _draw();
    return _cached!;
  }

  static Future<BitmapDescriptor> _draw() async {
    const double w = 48;
    const double h = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final bodyPaint = Paint()..color = const Color(0xFF1A2B4A);
    final windowPaint = Paint()..color = const Color(0xFF6C8FFF);
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final lightPaint = Paint()..color = const Color(0xFFFFD54F);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 6, w - 8, h - 8),
        const Radius.circular(14),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Car body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 2, w - 16, h - 6),
        const Radius.circular(12),
      ),
      bodyPaint,
    );

    // Front windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 10, w - 24, 16),
        const Radius.circular(6),
      ),
      windowPaint,
    );

    // Rear windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, h - 26, w - 24, 14),
        const Radius.circular(6),
      ),
      windowPaint,
    );

    // Wheels (4 rounded rects)
    final wheelRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 18, 6, 14),
      const Radius.circular(3),
    );
    canvas.drawRRect(wheelRect, wheelPaint); // front-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 10, 18, 6, 14),
        const Radius.circular(3),
      ),
      wheelPaint,
    ); // front-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, h - 32, 6, 14),
        const Radius.circular(3),
      ),
      wheelPaint,
    ); // rear-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 10, h - 32, 6, 14),
        const Radius.circular(3),
      ),
      wheelPaint,
    ); // rear-right

    // Headlights
    canvas.drawCircle(Offset(14, 8), 3, lightPaint);
    canvas.drawCircle(Offset(w - 14, 8), 3, lightPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }
}
