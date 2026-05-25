import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

/// Driver profile screen with user/driver info and logout.
class DriverProfileScreen extends StatefulWidget {
  final User? user;
  const DriverProfileScreen({super.key, this.user});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoadingDriver = true;
  Driver? _driverDetails;

  late AnimationController _skeletonController;
  late Animation<double> _skeletonAnimation;

  @override
  void initState() {
    super.initState();

    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _skeletonAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );

    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    try {
      // Use real User data immediately — no fake delay
      if (mounted) {
        setState(() {
          _driverDetails = Driver(
            name: widget.user?.name ?? '',
            carModel: widget.user?.carModel ?? '',
            licensePlate: widget.user?.licensePlate ?? '',
            rating: widget.user?.rating ?? 5.0,
          );
          _isLoadingDriver = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<SettingsCubit>().state.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.get('profile', locale),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingDriver
          ? _buildSkeletonUI(theme)
          : _buildProfileUI(theme, locale),
    );
  }

  Widget _buildSkeletonUI(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _skeletonAnimation,
        builder: (context, child) {
          final color = Colors.grey.withValues(alpha: _skeletonAnimation.value);
          return Column(
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSkeletonBlock(color),
              const SizedBox(height: 12),
              _buildSkeletonBlock(color),
              const SizedBox(height: 12),
              _buildSkeletonBlock(color),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 100,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSkeletonBlock(color, height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonBlock(Color color, {double height = 60}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
    );
  }

  Widget _buildProfileUI(ThemeData theme, String locale) {
    final isDark = theme.brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Avatar with Glow ───────────────────────────────────────
        _ScaleInAnimation(
          delay: 0,
          child: Center(
            child: Hero(
              tag: 'avatar_${widget.user?.id ?? 'guest'}',
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGreen.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: AppTheme.accentGreen, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    _initials(widget.user?.name ?? '?'),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Personal Section ─────────────────────────────────────
        _ScaleInAnimation(
          delay: 100,
          child: _InfoCard(
            icon: Icons.person_rounded,
            label: AppStrings.get('name', locale),
            value: widget.user?.name ?? AppStrings.get('not_specified', locale),
            theme: theme,
          ),
        ),
        const SizedBox(height: 12),
        _ScaleInAnimation(
          delay: 200,
          child: _InfoCard(
            icon: Icons.phone_rounded,
            label: AppStrings.get('phone', locale),
            value:
                widget.user?.phone ?? AppStrings.get('not_specified', locale),
            theme: theme,
          ),
        ),
        const SizedBox(height: 12),
        _ScaleInAnimation(
          delay: 300,
          child: Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.star_rounded,
                  label: AppStrings.get('rating', locale),
                  value:
                      '${_driverDetails?.rating.toStringAsFixed(1) ?? "5.0"}',
                  valueColor: AppTheme.accentYellow,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.check_circle_rounded,
                  label: AppStrings.get('rides_count', locale),
                  value: '—',
                  valueColor: AppTheme.accentGreen,
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Car Details Section ──────────────────────────────────
        _ScaleInAnimation(
          delay: 400,
          child: Text(
            AppStrings.get('vehicle_details', locale),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ScaleInAnimation(
          delay: 500,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      (_driverDetails?.carModel ?? '').isNotEmpty
                          ? _driverDetails!.carModel
                          : AppStrings.get('not_specified', locale),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (_driverDetails?.licensePlate ?? '').isNotEmpty
                          ? _driverDetails!.licensePlate
                          : AppStrings.get('not_specified', locale),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Settings Section ─────────────────────────────
        _ScaleInAnimation(
          delay: 560,
          child: Text(
            AppStrings.get('theme', locale),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ScaleInAnimation(
          delay: 580,
          child: _SettingsRow(
            theme: theme,
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: isDark
                ? AppStrings.get('light_theme', locale)
                : AppStrings.get('dark_theme', locale),
            trailing: Switch(
              value: isDark,
              activeColor: AppTheme.primaryNavy,
              onChanged: (_) => context.read<SettingsCubit>().toggleTheme(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ScaleInAnimation(
          delay: 600,
          child: _SettingsRow(
            theme: theme,
            icon: Icons.language_rounded,
            label: AppStrings.get('language', locale),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: locale,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'ru', child: Text('Русский')),
                  DropdownMenuItem(value: 'ky', child: Text('Кыргызча')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (lang) {
                  if (lang != null)
                    context.read<SettingsCubit>().setLocale(lang);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Logout Button ────────────────────────────────────────
        _ScaleInAnimation(
          delay: 600,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ApiService().logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                AppStrings.get('logout', locale),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.brightness == Brightness.dark
                    ? AppTheme.accentRed.withValues(alpha: 0.2)
                    : AppTheme.accentRed.withValues(alpha: 0.1),
                foregroundColor: AppTheme.accentRed,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  side: const BorderSide(color: AppTheme.accentRed, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final ThemeData theme;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.cardColor.withValues(alpha: 0.4)
                : theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? theme.colorScheme.onSurface,
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
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final Widget trailing;

  const _SettingsRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ScaleInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;

  const _ScaleInAnimation({required this.child, required this.delay});

  @override
  State<_ScaleInAnimation> createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<_ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _timer = Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
