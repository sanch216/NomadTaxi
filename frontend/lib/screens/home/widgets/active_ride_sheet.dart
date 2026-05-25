import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet showing driver info during an active ride
/// (ACCEPTED / ARRIVED / IN_PROGRESS).
class ActiveRideSheet extends StatelessWidget {
  final Ride ride;
  final Duration? eta;

  const ActiveRideSheet({super.key, required this.ride, this.eta});

  String get _statusLabel => switch (ride.status) {
    RideStatus.accepted => 'Driver is on the way',
    RideStatus.arrived => 'Driver has arrived',
    RideStatus.inProgress => 'Trip in progress',
    _ => '',
  };

  String get _etaText {
    if (ride.status == RideStatus.accepted) {
      if (eta != null && eta! > Duration.zero) {
        final min = eta!.inMinutes;
        return min <= 1 ? 'Arriving in ~1 min' : 'Arriving in ~$min min';
      }
      return 'Arriving soon';
    }
    return switch (ride.status) {
      RideStatus.arrived => 'Waiting at pickup',
      RideStatus.inProgress => 'En route to destination',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final driver = ride.driverDetails;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.bottomSheetRadius),
        ),
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
          // ── Drag handle ───────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Status label ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Driver header ─────────────────────────────────────────────
          if (driver != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Photo placeholder (circle avatar)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.inputGray,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.divider, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 28,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name + rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppTheme.accentYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              driver.rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Car info ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    driver.carModel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.inputGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      driver.licensePlate,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons (Call / Message) ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_rounded,
                      label: 'Message',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── ETA status bar ────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: AppTheme.cardWhite,
                ),
                const SizedBox(width: 8),
                Text(
                  _etaText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cardWhite,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Color get _statusColor => switch (ride.status) {
    RideStatus.accepted => AppTheme.accentGreen,
    RideStatus.arrived => const Color(0xFF3B82F6),
    RideStatus.inProgress => AppTheme.primaryNavy,
    _ => AppTheme.textSecondary,
  };
}

// ─── Reusable action button ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.inputGray,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryNavy),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
