import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../blocs/home_cubit.dart';
import '../../blocs/settings_cubit.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../rating/rating_screen.dart';
import 'widgets/active_ride_sheet.dart';
import 'widgets/destination_search_dialog.dart';
import 'widgets/finding_driver_overlay.dart';
import 'widgets/app_drawer.dart';
import 'widgets/ride_options_sheet.dart';
import 'widgets/where_to_bar.dart';
import '../../utils/car_marker.dart';

const String _nightMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#121212"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [{"color": "#1b1b1b"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

/// The main screen of the app — fullscreen Google Map with overlays.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Whether the ride options sheet is collapsed.
  bool _sheetCollapsed = false;
  bool _rideSheetCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _controller;
  BitmapDescriptor? _carIcon;

  // Smooth driver marker animation
  late AnimationController _driverAnimController;
  LatLng? _driverOldPos;
  LatLng? _driverNewPos;
  LatLng? _animatedDriverPos;
  double _animatedDriverHeading = 0;

  // Animation for the bouncing pin
  late AnimationController _pinAnimationController;
  late Animation<double> _pinJumpAnimation;

  // Default camera — Bishkek centre (fallback if GPS unavailable).
  static const _defaultLocation = LatLng(42.8746, 74.5698);
  static const _initialCamera = CameraPosition(
    target: _defaultLocation,
    zoom: 14.5,
  );

  /// User's current GPS location (null until resolved).
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initGps();
    _loadCarIcon();

    _pinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinJumpAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _pinAnimationController, curve: Curves.easeOut),
    );

    _driverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _driverAnimController.addListener(() {
      if (_driverOldPos != null && _driverNewPos != null) {
        final t = _driverAnimController.value;
        setState(() {
          _animatedDriverPos = LatLng(
            _driverOldPos!.latitude +
                (_driverNewPos!.latitude - _driverOldPos!.latitude) * t,
            _driverOldPos!.longitude +
                (_driverNewPos!.longitude - _driverOldPos!.longitude) * t,
          );
        });
      }
    });

    // Check for an active ride on app startup
    context.read<HomeCubit>().loadCurrentRide();
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _driverAnimController.dispose();
    super.dispose();
  }

  Future<void> _initGps() async {
    try {
      // Check if location services are enabled.
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Check / request permission.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      // Get current position.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final loc = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() => _currentLocation = loc);

      // Animate camera to user's location.
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(loc, 15));
    } catch (_) {
      // GPS unavailable — keep default location.
    }
  }

  Future<void> _loadCarIcon() async {
    final icon = await CarMarker.create();
    if (mounted) setState(() => _carIcon = icon);
  }

  /// Starts smooth interpolation when driver position changes.
  void _updateDriverAnimation(HomeState state) {
    final driver = state.activeRide?.driverDetails;
    if (driver == null ||
        driver.currentLat == null ||
        driver.currentLon == null) {
      return;
    }
    final newPos = LatLng(driver.currentLat!, driver.currentLon!);
    if (_driverNewPos != null &&
        _driverNewPos!.latitude == newPos.latitude &&
        _driverNewPos!.longitude == newPos.longitude) {
      return;
    }
    _driverOldPos = _animatedDriverPos ?? newPos;
    _driverNewPos = newPos;
    if (_driverOldPos != null &&
        _driverNewPos != null &&
        _driverOldPos != _driverNewPos) {
      _animatedDriverHeading = Geolocator.bearingBetween(
        _driverOldPos!.latitude,
        _driverOldPos!.longitude,
        _driverNewPos!.latitude,
        _driverNewPos!.longitude,
      );
    }
    _driverAnimController.forward(from: 0);
  }

  // ── Markers ─────────────────────────────────────────────────────────────

  // ── Markers ─────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers(HomeState state) {
    final markers = <Marker>{};

    // Show pickup/dropoff markers only when user has confirmed route (rideOptions+)
    final showPins = state.phase != HomePhase.idle;

    // If picking pickup, don't show the GMap pickup marker (we show the overlay pin).
    if (showPins && state.pickup != null && !(_isPicking && _pickingPickup)) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: state.pickup!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: state.pickupAddress ?? '',
          ),
        ),
      );
    }

    // If picking dropoff, don't show the GMap dropoff marker.
    if (showPins && state.dropoff != null && !(_isPicking && !_pickingPickup)) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: state.dropoff!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Drop-off',
            snippet: state.dropoffAddress ?? '',
          ),
        ),
      );
    }

    // Driver marker during active ride — use animated position for smooth movement.
    final driver = state.activeRide?.driverDetails;
    final driverPos = _animatedDriverPos;
    if (driver != null && driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          rotation: _animatedDriverHeading,
          infoWindow: InfoWindow(title: driver.name),
        ),
      );
    } else if (driver != null &&
        driver.currentLat != null &&
        driver.currentLon != null) {
      // Fallback: no animation yet, show raw position
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver.currentLat!, driver.currentLon!),
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          rotation: _animatedDriverHeading,
          infoWindow: InfoWindow(title: driver.name),
        ),
      );
    }

    return markers;
  }

  // ── Route Polyline ──────────────────────────────────────────────────────

  Set<Polyline> _buildPolylines(HomeState state) {
    // Don't draw route in idle phase (after cancel or before route is confirmed)
    if (state.routePoints.isEmpty || state.phase == HomePhase.idle) return {};

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: state.routePoints,
        color: isDark ? const Color(0xFF82B4FF) : AppTheme.primaryNavy,
        width: 5,
      ),
    };
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  // ─── Picking Logic ────────────────────────────────────────────────────────

  bool _isPicking = false;
  bool _pickingPickup = true; // true = pickup, false = dropoff

  void _startPicking(bool isPickup) {
    setState(() {
      _isPicking = true;
      _pickingPickup = isPickup;
    });
  }

  Future<void> _confirmPick() async {
    setState(() => _isPicking = false);
    final cubit = context.read<HomeCubit>();
    final state = cubit.state;

    // If both points are set, trigger destination setting directly.
    if (state.pickup != null && state.dropoff != null) {
      await cubit.setDestination(
        pickup: state.pickup!,
        dropoff: state.dropoff!,
        pickupAddress: state.pickupAddress,
        dropoffAddress: state.dropoffAddress,
      );
    } else {
      // If one is missing, open search to let user pick the other or review.
      _openSearch();
    }
  }

  void _onCameraMoveStarted() {
    if (_isPicking) {
      _pinAnimationController.forward();
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (_isPicking) {
      _lastCameraPosition = position.target;
    }
  }

  LatLng? _lastCameraPosition;

  void _onCameraIdle() {
    if (_isPicking && _lastCameraPosition != null) {
      _pinAnimationController.reverse();
      context.read<HomeCubit>().updatePickingLocation(
        _lastCameraPosition!,
        _pickingPickup,
      );
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _openSearch() async {
    // If we are picking, we don't open search yet?
    // No, _openSearch is the entry point.

    final cubit = context.read<HomeCubit>();
    final state = cubit.state;

    final result = await DestinationSearchDialog.show(
      context,
      currentLocation: _currentLocation ?? _defaultLocation,
      initialPickup: state.pickup,
      initialDropoff: state.dropoff,
      initialPickupAddress: state.pickupAddress,
      initialDropoffAddress: state.dropoffAddress,
    );

    if (result == null || !mounted) return;

    if (result['map_pick'] == true) {
      _startPicking(result['is_pickup']);
      return;
    }

    await cubit.setDestination(
      pickup: result['pickup'] as LatLng,
      dropoff: result['dropoff'] as LatLng,
      pickupAddress: result['pickupAddress'] as String?,
      dropoffAddress: result['dropoffAddress'] as String?,
    );

    // Animate camera to show both markers.
    final pickupLL = result['pickup'] as LatLng;
    final dropoffLL = result['dropoff'] as LatLng;

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            pickupLL.latitude < dropoffLL.latitude
                ? pickupLL.latitude
                : dropoffLL.latitude,
            pickupLL.longitude < dropoffLL.longitude
                ? pickupLL.longitude
                : dropoffLL.longitude,
          ),
          northeast: LatLng(
            pickupLL.latitude > dropoffLL.latitude
                ? pickupLL.latitude
                : dropoffLL.latitude,
            pickupLL.longitude > dropoffLL.longitude
                ? pickupLL.longitude
                : dropoffLL.longitude,
          ),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCubit, HomeState>(
      listenWhen: (prev, curr) =>
          prev.phase != curr.phase ||
          prev.error != curr.error ||
          prev.activeRide != curr.activeRide,
      listener: (context, state) {
        // Smooth driver marker animation.
        _updateDriverAnimation(state);

        // Bug 3 fix: reset _sheetCollapsed whenever phase returns to idle.
        if (state.phase == HomePhase.idle) {
          setState(() {
            _sheetCollapsed = false;
            _rideSheetCollapsed = false;
          });
        }

        // Haptic feedback on key transitions.
        if (state.phase == HomePhase.rideActive) {
          HapticFeedback.mediumImpact();
        } else if (state.phase == HomePhase.completed) {
          HapticFeedback.heavyImpact();
        }

        // Show error snackbar when API calls fail.
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }

        // Navigate to the RatingScreen when ride is completed.
        if (state.phase == HomePhase.completed) {
          _rideSheetCollapsed = false;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<HomeCubit>(),
                child: RatingScreen(
                  price: state.activeRide?.price ?? 0,
                  driverName: state.activeRide?.driverDetails?.name,
                  onRatingChanged: (stars) =>
                      context.read<HomeCubit>().setRating(stars),
                  onSubmit: () {
                    context.read<HomeCubit>().submitRating();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final locale = context.watch<SettingsCubit>().state.locale;

        // Bug 6 fix: intercept Android back button during active ride flow.
        final bool inRideFlow =
            state.phase == HomePhase.rideOptions ||
            state.phase == HomePhase.findingDriver ||
            state.phase == HomePhase.rideActive;

        return PopScope(
          canPop: !inRideFlow,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !inRideFlow) return;
            // Capture cubit BEFORE await to avoid BuildContext async gap lint.
            final cubit = context.read<HomeCubit>();
            final isActiveRide = state.phase == HomePhase.rideActive;
            final needsApiCancel =
                state.phase == HomePhase.findingDriver || isActiveRide;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Отменить поездку?'),
                content: Text(
                  isActiveRide
                      ? 'Поездка уже началась. Вы уверены, что хотите выйти?'
                      : 'Вы уверены, что хотите отменить заказ?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: const Text('Остаться'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                    ),
                    child: const Text('Отменить'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              if (needsApiCancel) {
                await cubit.cancelRequest();
              } else {
                cubit.reset();
              }
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            drawer: const AppDrawer(),
            body: Stack(
              children: [
                // ── Layer 1: Google Map ────────────────────────────────────
                GoogleMap(
                  initialCameraPosition: _initialCamera,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? _nightMapStyle
                      : null,
                  onMapCreated: (controller) {
                    _controller = controller;
                    if (Theme.of(context).brightness == Brightness.dark) {
                      controller.setMapStyle(_nightMapStyle);
                    }
                  },
                  onCameraMoveStarted: _onCameraMoveStarted,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  markers: _buildMarkers(state),
                  polylines: _buildPolylines(state),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  padding: EdgeInsets.only(
                    bottom: _isPicking ? 0 : _mapBottomPadding(state.phase),
                  ),
                ),

                // ── Layer 2: Menu button (top-left) ──────────────────────
                if (state.phase != HomePhase.findingDriver && !_isPicking)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    child: _MenuButton(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ),

                // ── Layer 3: FABs (GPS Snap) ───────────────────────────────
                if (!_isPicking)
                  Positioned(
                    right: 16,
                    bottom: state.phase == HomePhase.idle
                        ? MediaQuery.of(context).padding.bottom + 100
                        : _mapBottomPadding(state.phase) + 16,
                    child: _GpsButton(
                      onTap: () {
                        if (_currentLocation != null) {
                          _controller?.animateCamera(
                            CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                          );
                        }
                      },
                    ),
                  ),

                // ── STATE: idle → "Where to?" bar ────────────────────────
                if (state.phase == HomePhase.idle && !_isPicking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                    child: WhereToBar(onTap: _openSearch),
                  ),

                // ── STATE: Picking on Map ────────────────────────────────
                if (_isPicking) ...[
                  // Center Pin (Smooth "Fixed" Marker)
                  // Hides the actual GMap marker for the point being picked.
                  Center(
                    child: AnimatedBuilder(
                      animation: _pinJumpAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _pinJumpAnimation.value - 23),
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.location_on,
                        size: 45,
                        color: _pickingPickup
                            ? const Color(0xFF2ECC71) // Green for Pickup
                            : const Color(0xFFE74C3C), // Red for Dropoff
                      ),
                    ),
                  ),

                  // Confirm Button Overlay
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ColorFilter.mode(
                                Colors.white.withValues(alpha: 0.1),
                                BlendMode.dstATop,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(
                                          0xFF1E1E2A,
                                        ).withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: state.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            AppTheme.primaryNavy,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _pickingPickup
                                            ? (state.pickupAddress ?? '...')
                                            : (state.dropoffAddress ?? '...'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _confirmPick,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '\u041f\u043e\u0434\u0442\u0432\u0435\u0440\u0434\u0438\u0442\u044c',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── STATE: rideOptions → Collapsible Bottom Sheet ─────────
                if (state.phase == HomePhase.rideOptions && !_isPicking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.velocity.pixelsPerSecond.dy > 200) {
                          // Swipe down → just collapse, no dialog
                          setState(() => _sheetCollapsed = true);
                        } else if (details.velocity.pixelsPerSecond.dy < -200) {
                          setState(() => _sheetCollapsed = false);
                        }
                      },
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        offset: Offset(0, _sheetCollapsed ? 1.0 : 0.0),
                        child: RideOptionsSheet(
                          estimates: state.estimates,
                          selectedClass: state.selectedClass,
                          isLoading: state.isLoading,
                          onClassSelected: (c) =>
                              context.read<HomeCubit>().selectCarClass(c),
                          onCommentChanged: (c) =>
                              context.read<HomeCubit>().setComment(c),
                          onRequest: () =>
                              context.read<HomeCubit>().requestRide(),
                          onClose: () {
                            setState(() => _sheetCollapsed = false);
                            context.read<HomeCubit>().reset();
                          },
                        ),
                      ),
                    ),
                  ),

                // ── Collapsed peek bar (tap or swipe up to reopen) ─────────
                if (state.phase == HomePhase.rideOptions && _sheetCollapsed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _sheetCollapsed = false),
                      onVerticalDragEnd: (details) {
                        if (details.velocity.pixelsPerSecond.dy < -100) {
                          setState(() => _sheetCollapsed = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.bottomSheetRadius),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.1,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF444455)
                                    : AppTheme.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppStrings.get('return_to_order', locale),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── STATE: findingDriver → Radar Overlay ─────────────────
                if (state.phase == HomePhase.findingDriver)
                  Positioned.fill(
                    child: FindingDriverOverlay(
                      onCancel: () => context.read<HomeCubit>().cancelRequest(),
                    ),
                  ),

                // ── STATE: rideActive → Driver Sheet ─────────────────────
                if (state.phase == HomePhase.rideActive &&
                    state.activeRide != null &&
                    !_rideSheetCollapsed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.velocity.pixelsPerSecond.dy > 200) {
                          setState(() => _rideSheetCollapsed = true);
                        }
                      },
                      child: ActiveRideSheet(
                        ride: state.activeRide!,
                        eta: state.routeEta,
                      ),
                    ),
                  ),

                // ── Collapsed peek bar for active ride ─────────────────────
                if (state.phase == HomePhase.rideActive &&
                    state.activeRide != null &&
                    _rideSheetCollapsed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _rideSheetCollapsed = false),
                      onVerticalDragEnd: (details) {
                        if (details.velocity.pixelsPerSecond.dy < -100) {
                          setState(() => _rideSheetCollapsed = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.bottomSheetRadius),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.1,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF444455)
                                    : AppTheme.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _rideStatusLabel(state.activeRide!.status),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _mapBottomPadding(HomePhase phase) => switch (phase) {
    HomePhase.rideOptions => 380,
    HomePhase.rideActive => _rideSheetCollapsed ? 80 : 320,
    _ => 120,
  };

  String _rideStatusLabel(RideStatus status) => switch (status) {
    RideStatus.accepted => 'Driver is on the way',
    RideStatus.arrived => 'Driver has arrived',
    RideStatus.inProgress => 'Trip in progress',
    _ => 'Active ride',
  };
}

// ─── Small helper widgets ───────────────────────────────────────────────────

class _GpsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GpsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.gps_fixed,
          size: 20,
          color: isDark ? const Color(0xFF6C8FFF) : AppTheme.primaryNavy,
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.menu_rounded,
          size: 22,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
