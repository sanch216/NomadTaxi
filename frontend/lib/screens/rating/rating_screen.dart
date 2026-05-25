import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Full-screen modal shown when a ride is completed.
///
/// Displays the trip summary, price, and a 5-star rating selector.
class RatingScreen extends StatefulWidget {
  final double price;
  final String? driverName;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  const RatingScreen({
    super.key,
    required this.price,
    this.driverName,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setRating(int stars) {
    setState(() => _selectedStars = stars);
    widget.onRatingChanged(stars);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: AppTheme.cardWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Check icon ────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: AppTheme.accentGreen,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  'You arrived!',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.driverName != null)
                  Text(
                    'Thanks for riding with ${widget.driverName}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                const SizedBox(height: 32),

                // ── Price ─────────────────────────────────────────────────
                Text(
                  '${widget.price.toStringAsFixed(0)} сом',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Total fare',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 40),

                // ── "How was your ride?" ──────────────────────────────────
                Text(
                  'How was your ride?',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Star row ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final isActive = star <= _selectedStars;
                    return GestureDetector(
                      onTap: () => _setRating(star),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          isActive
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 44,
                          color: isActive
                              ? AppTheme.accentYellow
                              : AppTheme.divider,
                        ),
                      ),
                    );
                  }),
                ),

                const Spacer(flex: 3),

                // ── Submit button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _selectedStars > 0 ? widget.onSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: AppTheme.cardWhite,
                      disabledBackgroundColor: AppTheme.divider,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.buttonRadius,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Submit Rating',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Skip link ─────────────────────────────────────────────
                GestureDetector(
                  onTap: widget.onSubmit,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
