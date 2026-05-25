import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/driver_cubit.dart';
import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';

/// Shown after a ride is completed. Displays earnings and passenger rating.
class RideCompleteCard extends StatefulWidget {
  final ActiveRide ride;
  const RideCompleteCard({super.key, required this.ride});

  @override
  State<RideCompleteCard> createState() => _RideCompleteCardState();
}

class _RideCompleteCardState extends State<RideCompleteCard> {
  double _rating = 5.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;
    final cardBg = isDark ? const Color(0xFF252535) : AppTheme.inputGray;
    final locale = context.watch<SettingsCubit>().state.locale;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Success icon ──────────────────────────────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accentGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              AppStrings.get('completed_ride', locale),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.get('you_earned', locale),
              style: GoogleFonts.inter(fontSize: 14, color: onSurfaceMuted),
            ),

            // ── Earnings ──────────────────────────────────────────
            const SizedBox(height: 4),
            Text(
              '${widget.ride.price.toStringAsFixed(0)} ${AppStrings.get('som', locale)}',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(height: 20),

            // ── Route summary ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.radio_button_checked,
                    iconColor: AppTheme.accentGreen,
                    text: widget.ride.pickupAddress,
                    textColor: onSurface,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Container(
                      width: 2,
                      height: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.grey[300],
                    ),
                  ),
                  _SummaryRow(
                    icon: Icons.location_on,
                    iconColor: AppTheme.accentRed,
                    text: widget.ride.dropoffAddress,
                    textColor: onSurface,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Rate Passenger ────────────────────────────────────
            Text(
              AppStrings.get('rate_passenger', locale),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppTheme.accentYellow,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // ── Done button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  context.read<DriverCubit>().ratePassenger(
                    widget.ride.rideId,
                    _rating,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF3B82F6)
                      : AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppStrings.get('dismiss', locale),
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;

  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
