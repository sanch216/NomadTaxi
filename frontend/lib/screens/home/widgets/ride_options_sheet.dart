import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'ride_estimate_card.dart';

/// Persistent bottom sheet displaying ride estimates and the "Request" button.
class RideOptionsSheet extends StatefulWidget {
  final List<RideEstimate> estimates;
  final CarClass selectedClass;
  final bool isLoading;
  final ValueChanged<CarClass> onClassSelected;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onRequest;
  final VoidCallback onClose;

  const RideOptionsSheet({
    super.key,
    required this.estimates,
    required this.selectedClass,
    required this.isLoading,
    required this.onClassSelected,
    required this.onCommentChanged,
    required this.onRequest,
    required this.onClose,
  });

  @override
  State<RideOptionsSheet> createState() => _RideOptionsSheetState();
}

class _RideOptionsSheetState extends State<RideOptionsSheet> {
  final _commentController = TextEditingController();
  bool _showCommentField = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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
    final locale = context.watch<SettingsCubit>().state.locale;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.bottomSheetRadius),
        ),
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
          // ── Drag Handle ───────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444455) : AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.get('choose_ride', locale),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Estimate cards ────────────────────────────────────────────
          ...widget.estimates.map(
            (estimate) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: RideEstimateCard(
                estimate: estimate,
                isSelected: estimate.carClass == widget.selectedClass,
                onTap: () => widget.onClassSelected(estimate.carClass),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Divider(
            indent: 20,
            endIndent: 20,
            color: isDark ? const Color(0xFF333344) : AppTheme.divider,
          ),
          const SizedBox(height: 12),

          // ── Payment Method ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: onSurface),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.get('cash', locale),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: secondaryText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Comment Section ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _showCommentField
                ? TextField(
                    controller: _commentController,
                    onChanged: widget.onCommentChanged,
                    maxLines: 2,
                    maxLength: 200,
                    style: GoogleFonts.inter(fontSize: 14, color: onSurface),
                    decoration: InputDecoration(
                      hintText: AppStrings.get('comment_hint', locale),
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      counterStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _commentController.clear();
                          widget.onCommentChanged('');
                          setState(() => _showCommentField = false);
                        },
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _showCommentField = true),
                    child: Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 18,
                          color: secondaryText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.get('add_comment', locale),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Request Button ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onRequest,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppStrings.get('request_taxi', locale),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
