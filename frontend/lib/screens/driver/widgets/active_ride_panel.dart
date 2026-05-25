import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blocs/driver_cubit.dart';
import '../../../blocs/settings_cubit.dart';

import '../../../theme/app_theme.dart';

/// Bottom panel during an active ride showing full ride details and
/// phase-specific action buttons with slide animations on status change.
///
/// Phases: ACCEPTED → ARRIVED → IN_PROGRESS → (RideCompleteCard).
class ActiveRidePanel extends StatelessWidget {
  final ActiveRide ride;
  const ActiveRidePanel({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.58,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Phase indicator (animated on status change) ──────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _PhaseIndicator(
                  key: ValueKey('phase_${ride.status}'),
                  status: ride.status,
                ),
              ),
              const SizedBox(height: 16),

              // ── Passenger + Price Row ────────────────────────────
              _PassengerPriceRow(ride: ride),
              const SizedBox(height: 14),

              // ── Addresses ────────────────────────────────────────
              _AddressCard(ride: ride),
              const SizedBox(height: 12),

              // ── Ride Details (comment) ────────────────────────────
              _RideDetailsRow(ride: ride),
              const SizedBox(height: 16),

              // ── Action Button (animated on status change) ────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      );
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _ActionButton(
                  key: ValueKey('btn_${ride.status}'),
                  ride: ride,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Phase Indicator ──────────────────────────────────────────────────────────

class _PhaseIndicator extends StatelessWidget {
  final String status;
  const _PhaseIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsCubit>().state.locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final phases = [
      (_phaseLabel('heading_to_pickup', locale), 'ACCEPTED'),
      (_phaseLabel('arrived', locale), 'ARRIVED'),
      (_phaseLabel('trip_in_progress', locale), 'IN_PROGRESS'),
    ];

    return Row(
      children: [
        for (int i = 0; i < phases.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isActive(status, phases[i].$2)
                        ? const Color(0xFF3B82F6)
                        : _isCompleted(status, phases[i].$2)
                        ? AppTheme.accentGreen
                        : isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  phases[i].$1,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: _isActive(status, phases[i].$2)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _isActive(status, phases[i].$2)
                        ? const Color(0xFF3B82F6)
                        : _isCompleted(status, phases[i].$2)
                        ? AppTheme.accentGreen
                        : isDark
                        ? const Color(0xFF9CA3AF)
                        : AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (i < phases.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  String _phaseLabel(String key, String locale) {
    // Inline phase labels (not in app_strings yet)
    final labels = {
      'heading_to_pickup': {
        'ru': 'К пассажиру',
        'ky': 'Жолоочуга',
        'en': 'To pickup',
      },
      'arrived': {'ru': 'Прибыл', 'ky': 'Жеттим', 'en': 'Arrived'},
      'trip_in_progress': {
        'ru': 'В поездке',
        'ky': 'Сапарда',
        'en': 'In progress',
      },
    };
    return labels[key]?[locale] ?? labels[key]?['ru'] ?? key;
  }

  bool _isActive(String current, String phase) => current == phase;
  bool _isCompleted(String current, String phase) {
    const order = ['ACCEPTED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'];
    return order.indexOf(current) > order.indexOf(phase);
  }
}

// ─── Passenger + Price Row ────────────────────────────────────────────────────

class _PassengerPriceRow extends StatelessWidget {
  final ActiveRide ride;
  const _PassengerPriceRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF252535) : AppTheme.inputGray;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark
                ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                : AppTheme.primaryNavy,
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),

          // Name + Rating + Phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.passengerName ?? 'Пассажир',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (ride.passengerRating != null) ...[
                      const Icon(
                        Icons.star,
                        color: AppTheme.accentYellow,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ride.passengerRating!.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (ride.passengerPhone != null)
                      Text(
                        ride.passengerPhone!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${ride.price.toStringAsFixed(0)} сом',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGreen,
                ),
              ),
              Text(
                ride.carClass,
                style: GoogleFonts.inter(fontSize: 11, color: onSurfaceMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final ActiveRide ride;
  const _AddressCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF252535) : AppTheme.inputGray;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;
    final showPickup = ride.status == 'ACCEPTED' || ride.status == 'ARRIVED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Pickup
          _LocationRow(
            icon: Icons.radio_button_checked,
            iconColor: AppTheme.accentGreen,
            label: 'Отправление',
            address: ride.pickupAddress,
            isHighlighted: showPickup,
            onSurface: onSurface,
            onSurfaceMuted: onSurfaceMuted,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
            child: Container(
              width: 2,
              height: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.grey[300],
            ),
          ),
          // Dropoff
          _LocationRow(
            icon: Icons.location_on,
            iconColor: AppTheme.accentRed,
            label: 'Назначение',
            address: ride.dropoffAddress,
            isHighlighted: !showPickup,
            onSurface: onSurface,
            onSurfaceMuted: onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final bool isHighlighted;
  final Color onSurface;
  final Color onSurfaceMuted;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    this.isHighlighted = false,
    required this.onSurface,
    required this.onSurfaceMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                  color: onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isHighlighted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Навигация',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Ride Details Row ─────────────────────────────────────────────────────────

class _RideDetailsRow extends StatelessWidget {
  final ActiveRide ride;
  const _RideDetailsRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    if (ride.comment == null || ride.comment!.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.accentYellow.withValues(alpha: 0.1)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentYellow.withValues(alpha: isDark ? 0.2 : 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: AppTheme.accentYellow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ride.comment!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final ActiveRide ride;
  const _ActionButton({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = context.watch<SettingsCubit>().state.locale;

    String label;
    String nextStatus;
    Color bgColor;
    IconData icon;

    switch (ride.status) {
      case 'ACCEPTED':
        label = 'Я прибыл';
        nextStatus = 'ARRIVED';
        bgColor = const Color(0xFF3B82F6);
        icon = Icons.place_rounded;
        break;
      case 'ARRIVED':
        label = 'Начать поездку';
        nextStatus = 'IN_PROGRESS';
        bgColor = AppTheme.accentGreen;
        icon = Icons.directions_car_rounded;
        break;
      case 'IN_PROGRESS':
        label = 'Завершить поездку';
        nextStatus = 'COMPLETED';
        bgColor = AppTheme.primaryNavy;
        icon = Icons.check_circle_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    final navBtnColor = isDark ? Colors.white70 : AppTheme.primaryNavy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ride.status == 'ACCEPTED' || ride.status == 'IN_PROGRESS')
          _buildNavigateButton(context, isDark, navBtnColor, locale),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => context.read<DriverCubit>().updateRideStatus(
              ride.rideId,
              nextStatus,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigateButton(
    BuildContext context,
    bool isDark,
    Color btnColor,
    String locale,
  ) {
    final double lat;
    final double lon;
    final String label;
    if (ride.status == 'ACCEPTED') {
      lat = ride.pickupLat;
      lon = ride.pickupLon;
      label = 'Навигация к пассажиру';
    } else {
      lat = ride.dropoffLat;
      lon = ride.dropoffLon;
      label = 'Навигация к точке Б';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              final webUri = Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
              );
              await launchUrl(webUri, mode: LaunchMode.externalApplication);
            }
          },
          icon: Icon(Icons.navigation_rounded, size: 20, color: btnColor),
          label: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: btnColor,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: btnColor,
            side: BorderSide(
              color: isDark ? Colors.white24 : AppTheme.primaryNavy,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
