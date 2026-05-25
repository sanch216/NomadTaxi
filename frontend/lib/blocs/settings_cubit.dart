import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final String locale; // 'ru', 'ky', 'en'

  const SettingsState({this.themeMode = ThemeMode.light, this.locale = 'ru'});

  SettingsState copyWith({ThemeMode? themeMode, String? locale}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );

  @override
  List<Object?> get props => [themeMode, locale];
}

// ─── Cubit ──────────────────────────────────────────────────────────────────

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void toggleTheme() {
    emit(
      state.copyWith(
        themeMode: state.themeMode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light,
      ),
    );
  }

  void setLocale(String locale) {
    emit(state.copyWith(locale: locale));
  }
}
