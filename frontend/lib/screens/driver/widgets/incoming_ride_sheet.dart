import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/driver_cubit.dart';
import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';

/// Modal bottom sheet showing an incoming ride request with countdown.
class IncomingRideSheet extends StatelessWidget {
  final RideRequest request;
  final int secondsLeft;

  const IncomingRideSheet({
    super.key,
    required this.request,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = context.watch<SettingsCubit>().state.locale;
    // Card background adapts to theme
    final cardBg = isDark ? const Color(0xFF252535) : AppTheme.inputGray;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header + Countdown ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.get('new_request_label', locale),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                _CountdownCircle(secondsLeft: secondsLeft, isDark: isDark),
              ],
            ),
            const SizedBox(height: 20),

            // ── Price + Car Class ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.accentGreen.withValues(alpha: 0.12)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(
                    alpha: isDark ? 0.25 : 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      color: AppTheme.accentGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.price.toStringAsFixed(0)} ${AppStrings.get('som', locale)}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          request.carClass,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Pickup & Dropoff ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _LocationRow(
                    icon: Icons.radio_button_checked,
                    iconColor: AppTheme.accentGreen,
                    label: AppStrings.get('pickup_point', locale),
                    address: request.pickupAddress,
                    onSurface: onSurface,
                    onSurfaceMuted: onSurfaceMuted,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
                    child: Container(
                      width: 2,
                      height: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.grey[300],
                    ),
                  ),
                  _LocationRow(
                    icon: Icons.location_on,
                    iconColor: AppTheme.accentRed,
                    label: 'Dropoff',
                    address: request.dropoffAddress,
                    onSurface: onSurface,
                    onSurfaceMuted: onSurfaceMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────
            Row(
              children: [
                // Decline
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () =>
                          context.read<DriverCubit>().declineRide(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRed,
                        side: const BorderSide(color: AppTheme.accentRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppStrings.get('go_offline', locale),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => context.read<DriverCubit>().acceptRide(
                        request.rideId,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppStrings.get('go_online', locale),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown Circle ─────────────────────────────────────────────────────────

class _CountdownCircle extends StatelessWidget {
  final int secondsLeft;
  final bool isDark;
  const _CountdownCircle({required this.secondsLeft, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = secondsLeft <= 5
        ? AppTheme.accentRed
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: secondsLeft / 15,
            strokeWidth: 3,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              secondsLeft <= 5 ? AppTheme.accentRed : AppTheme.accentYellow,
            ),
          ),
          Text(
            '$secondsLeft',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Location Row ─────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final Color onSurface;
  final Color onSurfaceMuted;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.onSurface,
    required this.onSurfaceMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
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
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
