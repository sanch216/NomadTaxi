import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/auth_cubit.dart';
import 'blocs/home_cubit.dart';
import 'blocs/driver_cubit.dart';
import 'blocs/settings_cubit.dart';
import 'screens/auth/login_page.dart';
import 'screens/driver/driver_main_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AisTaxiApp());
}

class AisTaxiApp extends StatelessWidget {
  const AisTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          final isDark = settings.themeMode == ThemeMode.dark;
          SystemChrome.setSystemUIOverlayStyle(
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          );

          return MaterialApp(
            title: 'AIS-TAXI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

/// Checks for an existing JWT on startup.
/// Routes by role: DRIVER → DriverHomeScreen, CLIENT → HomeScreen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService().isAuthenticated,
      builder: (context, snapshot) {
        // Show a splash / loading while checking token.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAuth = snapshot.data ?? false;

        if (isAuth) {
          return FutureBuilder<String?>(
            future: ApiService().userRole,
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = roleSnapshot.data ?? 'CLIENT';
              if (role == 'DRIVER') {
                return BlocProvider(
                  create: (_) => DriverCubit(),
                  child: const DriverMainScreen(),
                );
              }
              return BlocProvider(
                create: (_) => HomeCubit(),
                child: const HomeScreen(),
              );
            },
          );
        }

        return BlocProvider(
          create: (_) => AuthCubit(),
          child: const LoginPage(),
        );
      },
    );
  }
}
