import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/settings_cubit.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'driver_home_screen.dart';
import 'driver_profile_screen.dart';
import 'earnings_screen.dart';

/// Entry screen for drivers — bottom nav with Map, Earnings, Profile.
class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await ApiService().getProfile();
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsCubit>().state.locale;

    final screens = [
      const DriverHomeScreen(),
      const EarningsScreen(),
      DriverProfileScreen(user: _user),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map_rounded),
            label: AppStrings.get('map', locale),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.payments_outlined),
            activeIcon: const Icon(Icons.payments_rounded),
            label: AppStrings.get('earnings', locale),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: AppStrings.get('profile_settings', locale),
          ),
        ],
      ),
    );
  }
}
