import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

/// A single selectable card displaying a ride estimate.
class RideEstimateCard extends StatelessWidget {
  final RideEstimate estimate;
  final bool isSelected;
  final VoidCallback onTap;

  const RideEstimateCard({
    super.key,
    required this.estimate,
    required this.isSelected,
    required this.onTap,
  });

  /// Returns an emoji/icon representation for each car class.
  String get _carEmoji => switch (estimate.carClass) {
    CarClass.economy => '🚗',
    CarClass.comfort => '🚙',
    CarClass.business => '🚘',
  };

  String _className(String locale) => switch (estimate.carClass) {
    CarClass.economy => AppStrings.get('economy', locale),
    CarClass.comfort => AppStrings.get('comfort', locale),
    CarClass.business => AppStrings.get('business', locale),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;
    final inputBg = isDark ? const Color(0xFF2A2A3A) : AppTheme.inputGray;
    final dividerColor = isDark ? const Color(0xFF444455) : AppTheme.divider;
    final locale = context.watch<SettingsCubit>().state.locale;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? inputBg : surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Car icon ──────────────────────────────────────────────────
            Text(_carEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),

            // ── Class name + ETA ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _className(locale),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${estimate.arrivalTime} ${AppStrings.get('min', locale)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            // ── Price ─────────────────────────────────────────────────────
            Text(
              '${estimate.price.toStringAsFixed(0)} ${AppStrings.get('som', locale)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
