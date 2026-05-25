import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../blocs/auth_cubit.dart';
import '../../blocs/driver_cubit.dart';
import '../../blocs/settings_cubit.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import 'widgets/incoming_ride_sheet.dart';
import 'widgets/active_ride_panel.dart';
import 'widgets/ride_complete_card.dart';

const String _nightMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#121212"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

/// The main driver screen — fullscreen Google Map with status overlays.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;

  // Default camera — Bishkek centre
  static const _defaultLocation = LatLng(42.8746, 74.5698);
  static const _initialCamera = CameraPosition(
    target: _defaultLocation,
    zoom: 14.5,
  );

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  Future<void> _initGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );

      // Update cubit with location
      if (!mounted) return;
      final cubit = context.read<DriverCubit>();
      cubit.currentLat = pos.latitude;
      cubit.currentLon = pos.longitude;
    } catch (_) {}
  }

  Set<Marker> _buildMarkers(DriverState state) {
    final markers = <Marker>{};

    if (state is DriverHasRequest) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(state.request.pickupLat, state.request.pickupLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: state.request.pickupAddress,
          ),
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(state.request.dropoffLat, state.request.dropoffLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: state.request.dropoffAddress,
          ),
        ),
      );
    }

    if (state is DriverActiveRide) {
      final ride = state.ride;
      if (ride.status == 'ACCEPTED' || ride.status == 'ARRIVED') {
        markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: LatLng(ride.pickupLat, ride.pickupLon),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Pickup',
              snippet: ride.pickupAddress,
            ),
          ),
        );
      }
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(ride.dropoffLat, ride.dropoffLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: ride.dropoffAddress,
          ),
        ),
      );
    }

    if (state is DriverRideComplete) {
      final ride = state.ride;
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(ride.pickupLat, ride.pickupLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(ride.dropoffLat, ride.dropoffLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(DriverState state) {
    List<LatLng> points = const [];
    // dashed = heading to pickup; solid = in ride (heading to destination)
    bool dashed = false;

    if (state is DriverHasRequest) {
      points = state.routePoints;
      dashed = true; // driver → pickup preview
    } else if (state is DriverActiveRide) {
      points = state.routePoints;
      // Dashed while still going to pickup (ACCEPTED/ARRIVED),
      // solid once passenger is aboard (IN_PROGRESS)
      dashed = state.ride.status != 'IN_PROGRESS';
    }

    if (points.isEmpty) return {};

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF82B4FF) : AppTheme.primaryNavy;

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: color,
        width: dashed ? 4 : 5,
        patterns: dashed ? [PatternItem.dash(20), PatternItem.gap(12)] : [],
      ),
    };
  }

  void _fitBounds(DriverState state) {
    if (_mapController == null) return;

    LatLng? a, b;

    if (state is DriverHasRequest) {
      a = LatLng(state.request.pickupLat, state.request.pickupLon);
      b = LatLng(state.request.dropoffLat, state.request.dropoffLon);
    } else if (state is DriverActiveRide) {
      if (_currentLocation != null) {
        a = _currentLocation!;
        final r = state.ride;
        b = (r.status == 'ACCEPTED' || r.status == 'ARRIVED')
            ? LatLng(r.pickupLat, r.pickupLon)
            : LatLng(r.dropoffLat, r.dropoffLon);
      }
    }

    if (a != null && b != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          a.latitude < b.latitude ? a.latitude : b.latitude,
          a.longitude < b.longitude ? a.longitude : b.longitude,
        ),
        northeast: LatLng(
          a.latitude > b.latitude ? a.latitude : b.latitude,
          a.longitude > b.longitude ? a.longitude : b.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverCubit, DriverState>(
      listener: (context, state) {
        // Vibrate on new ride request.
        if (state is DriverHasRequest) {
          HapticFeedback.heavyImpact();
        }
        // Fit map bounds when ride state changes
        if (state is DriverHasRequest || state is DriverActiveRide) {
          Future.delayed(
            const Duration(milliseconds: 300),
            () => _fitBounds(state),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              // ── Layer 1: Google Map ─────────────────────────────
              GoogleMap(
                initialCameraPosition: _initialCamera,
                style: Theme.of(context).brightness == Brightness.dark
                    ? _nightMapStyle
                    : null,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (Theme.of(context).brightness == Brightness.dark) {
                    controller.setMapStyle(_nightMapStyle);
                  }
                  if (_currentLocation != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                    );
                  }
                },
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: const EdgeInsets.only(bottom: 280),
              ),

              // ── Layer 2: Top Bar ───────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusPill(state: state),
                      Row(
                        children: [
                          // GPS button
                          _buildCircleButton(
                            icon: Icons.my_location,
                            onTap: () {
                              if (_currentLocation != null) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    _currentLocation!,
                                    15,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // Theme toggle
                          _buildCircleButton(
                            icon:
                                Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            onTap: () =>
                                context.read<SettingsCubit>().toggleTheme(),
                          ),
                          const SizedBox(width: 8),
                          // Logout button
                          _buildCircleButton(
                            icon: Icons.logout_rounded,
                            onTap: () async {
                              await ApiService().logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => AuthCubit(),
                                      child: const LoginPage(),
                                    ),
                                  ),
                                  (_) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Layer 3: Bottom Panels ─────────────────────────
              if (state is DriverOffline || state is DriverOnline)
                _DriverTogglePanel(state: state),

              if (state is DriverHasRequest)
                IncomingRideSheet(
                  request: state.request,
                  secondsLeft: state.secondsLeft,
                ),

              if (state is DriverActiveRide) ActiveRidePanel(ride: state.ride),

              if (state is DriverRideComplete)
                RideCompleteCard(ride: state.ride),

              if (state is DriverError) _ErrorBanner(message: state.message),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: isDark ? Colors.white70 : AppTheme.primaryNavy,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final DriverState state;
  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsCubit>().state.locale;
    String text;
    Color color;

    if (state is DriverOffline) {
      text = AppStrings.get('offline_label', locale);
      color = Colors.grey;
    } else if (state is DriverOnline) {
      text = AppStrings.get('online_label', locale);
      color = AppTheme.accentGreen;
    } else if (state is DriverHasRequest) {
      text = AppStrings.get('new_request_label', locale);
      color = AppTheme.accentYellow;
    } else if (state is DriverActiveRide) {
      text = AppStrings.get('on_ride_label', locale);
      color = const Color(0xFF3B82F6);
    } else if (state is DriverRideComplete) {
      text = AppStrings.get('completed_label', locale);
      color = AppTheme.accentGreen;
    } else {
      text = AppStrings.get('error_label', locale);
      color = AppTheme.accentRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.3
                  : 0.12,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Panel ─────────────────────────────────────────────────────────────

class _DriverTogglePanel extends StatefulWidget {
  final DriverState state;
  const _DriverTogglePanel({required this.state});

  @override
  State<_DriverTogglePanel> createState() => _DriverTogglePanelState();
}

class _DriverTogglePanelState extends State<_DriverTogglePanel>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.state is DriverOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DriverTogglePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state is DriverOnline && oldWidget.state is! DriverOnline) {
      _pulseController.repeat(reverse: true);
    } else if (widget.state is! DriverOnline &&
        oldWidget.state is DriverOnline) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.state is DriverOnline;
    final theme = Theme.of(context);
    final locale = context.watch<SettingsCubit>().state.locale;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastLinearToSlowEaseIn,
      bottom: isOnline ? 40 : 0,
      left: isOnline ? 20 : 0,
      right: isOnline ? 20 : 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastLinearToSlowEaseIn,
        padding: isOnline
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
            : const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: isOnline
              ? BorderRadius.circular(100)
              : const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: isOnline
                  ? AppTheme.accentGreen.withValues(alpha: 0.2)
                  : Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
                    ),
              blurRadius: isOnline ? 30 : 20,
              spreadRadius: isOnline ? 5 : 0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: isOnline
            ? _buildOnlineState(theme, locale)
            : _buildOfflineState(theme, locale),
      ),
    );
  }

  Widget _buildOfflineState(ThemeData theme, String locale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF444455)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          AppStrings.get('you_offline', locale),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.get('go_online_hint', locale),
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            context.read<DriverCubit>().goOnline();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.get('go_online', locale),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineState(ThemeData theme, String locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(
                      alpha: 0.2 * (2 - _pulseAnimation.value),
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.get('searching_orders', locale),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppStrings.get('waiting_passengers', locale),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.read<DriverCubit>().goOffline(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppStrings.get('offline_label', locale),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsCubit>().state.locale;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.3
                    : 0.12,
              ),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.accentRed,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.read<DriverCubit>().goOffline(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.get('dismiss', locale)),
            ),
          ],
        ),
      ),
    );
  }
}
