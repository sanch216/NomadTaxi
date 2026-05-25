import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../services/api_service.dart';

// ─── States ─────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  final String role;
  const AuthSuccess({this.role = 'CLIENT'});
  @override
  List<Object?> get props => [role];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Cubit ──────────────────────────────────────────────────────────────────

class AuthCubit extends Cubit<AuthState> {
  final ApiService _api = ApiService();

  AuthCubit() : super(const AuthInitial());

  /// Attempt login with phone + password.
  Future<void> login({required String phone, required String password}) async {
    emit(const AuthLoading());
    try {
      final role = await _api.login(phone: phone, password: password);
      emit(AuthSuccess(role: role));
    } catch (e) {
      emit(AuthError(_extractMessage(e)));
    }
  }

  /// Register a new account.
  Future<void> register({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    emit(const AuthLoading());
    try {
      final role = await _api.register(
        phone: phone,
        password: password,
        fullName: fullName,
      );
      emit(AuthSuccess(role: role));
    } catch (e) {
      emit(AuthError(_extractMessage(e)));
    }
  }

  /// Check if a stored JWT exists.
  Future<bool> isAuthenticated() => _api.isAuthenticated;

  /// Reset state (e.g. after showing error).
  void resetState() => emit(const AuthInitial());

  String _extractMessage(Object error) {
    if (error is Exception) {
      final str = error.toString();
      // DioException often wraps the real message
      if (str.contains('message:')) {
        return str.split('message:').last.trim();
      }
      return str.replaceFirst('Exception: ', '');
    }
    return 'Что-то пошло не так';
  }
}
