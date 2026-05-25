import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import 'payment_methods_screen.dart';
import 'profile_settings_screen.dart';
import 'ride_history_screen.dart';
import '../../driver/driver_profile_screen.dart';
import '../../driver/earnings_screen.dart';

/// Side drawer for the home screen.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  User? _user;
  String? _role;
  bool _loading = true;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadProfile();
    // Start animation slightly after rendering.
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _animController.forward();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final user = await ApiService().getProfile();
      final role = await ApiService().userRole;
      if (mounted) {
        setState(() {
          _user = user;
          _role = role;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsCubit>().state;
    final locale = settings.locale;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2A) : AppTheme.primaryNavy,
              ),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar circle with initials (Hero for smooth transition)
                        Hero(
                          tag: 'avatar_${_user?.id ?? 'guest'}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _initials(_user?.name ?? '?'),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Name
                        Text(
                          _user?.name ?? AppStrings.get('user', locale),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Rating + Phone
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppTheme.accentYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_user?.rating ?? 5.0).toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _user?.phone ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 8),

            // ── Menu Items (staggered slide-in) ──────────────────────
            _StaggeredItem(
              controller: _animController,
              index: 0,
              child: _DrawerItem(
                icon: Icons.history_rounded,
                title: AppStrings.get('my_rides', locale),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RideHistoryScreen(),
                    ),
                  );
                },
              ),
            ),
            if (_role == 'DRIVER')
              _StaggeredItem(
                controller: _animController,
                index: 1,
                child: _DrawerItem(
                  icon: Icons.payments_rounded,
                  title: AppStrings.get('earnings', locale),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsScreen()),
                    );
                  },
                ),
              ),
            _StaggeredItem(
              controller: _animController,
              index: 2,
              child: _DrawerItem(
                icon: Icons.payment_rounded,
                title: AppStrings.get('payment_methods', locale),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  );
                },
              ),
            ),
            _StaggeredItem(
              controller: _animController,
              index: 3,
              child: _DrawerItem(
                icon: Icons.person_outline_rounded,
                title: AppStrings.get('profile_settings', locale),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _role == 'DRIVER'
                          ? DriverProfileScreen(user: _user)
                          : ProfileSettingsScreen(user: _user),
                    ),
                  );
                },
              ),
            ),

            _StaggeredItem(
              controller: _animController,
              index: 4,
              child: const Divider(height: 24, indent: 20, endIndent: 20),
            ),

            // ── Dark Theme Toggle ────────────────────────────────────
            _StaggeredItem(
              controller: _animController,
              index: 5,
              child: _DrawerItem(
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                title: isDark
                    ? AppStrings.get('light_theme', locale)
                    : AppStrings.get('dark_theme', locale),
                onTap: () => context.read<SettingsCubit>().toggleTheme(),
              ),
            ),

            // ── Language Picker ──────────────────────────────────────
            _StaggeredItem(
              controller: _animController,
              index: 6,
              child: _DrawerItem(
                icon: Icons.language_rounded,
                title: _languageLabel(locale),
                onTap: () => _showLanguagePicker(context, locale),
              ),
            ),

            const Spacer(),

            // ── Support (bottom) ─────────────────────────────────────
            _StaggeredItem(
              controller: _animController,
              index: 7,
              child: Column(
                children: [
                  const Divider(indent: 20, endIndent: 20),
                  _DrawerItem(
                    icon: Icons.headset_mic_outlined,
                    title: AppStrings.get('support', locale),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('support@ais-taxi.kg'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _languageLabel(String locale) {
    switch (locale) {
      case 'ky':
        return 'Тил: Кыргызча';
      case 'en':
        return 'Language: English';
      default:
        return 'Язык: Русский';
    }
  }

  void _showLanguagePicker(BuildContext context, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              AppStrings.get('choose_language', current),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _LangTile(
              flag: '🇷🇺',
              label: 'Русский',
              selected: current == 'ru',
              onTap: () {
                context.read<SettingsCubit>().setLocale('ru');
                Navigator.pop(context);
              },
            ),
            _LangTile(
              flag: '🇰🇬',
              label: 'Кыргызча',
              selected: current == 'ky',
              onTap: () {
                context.read<SettingsCubit>().setLocale('ky');
                Navigator.pop(context);
              },
            ),
            _LangTile(
              flag: '🇬🇧',
              label: 'English',
              selected: current == 'en',
              onTap: () {
                context.read<SettingsCubit>().setLocale('en');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 22, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
    );
  }
}

class _LangTile extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.accentGreen)
          : null,
      onTap: onTap,
    );
  }
}

/// Animates each drawer item with a staggered slide-from-right + fade effect.
class _StaggeredItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _StaggeredItem({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double start = (index * 0.08).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(50 * (1 - curve.value), 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
