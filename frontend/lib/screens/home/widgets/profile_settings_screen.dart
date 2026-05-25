import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

/// Profile settings screen with user info editing and logout.
class ProfileSettingsScreen extends StatefulWidget {
  final User? user;
  const ProfileSettingsScreen({super.key, this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ApiService().updateProfile(fullName: _nameController.text.trim());
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        final locale = context.read<SettingsCubit>().state.locale;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('profile_updated', locale)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final locale = context.read<SettingsCubit>().state.locale;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get('save_error', locale)}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(widget.user?.name ?? '?'),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Name field ───────────────────────────────────────────
            _isEditing
                ? TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: AppStrings.get('name', locale),
                      labelStyle: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                      ),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  )
                : _InfoTile(
                    icon: Icons.person_outline_rounded,
                    label: AppStrings.get('name', locale),
                    value:
                        widget.user?.name ??
                        AppStrings.get('not_specified', locale),
                  ),
            const SizedBox(height: 12),

            // ── Phone field ──────────────────────────────────────────
            _InfoTile(
              icon: Icons.phone_outlined,
              label: AppStrings.get('phone', locale),
              value:
                  widget.user?.phone ?? AppStrings.get('not_specified', locale),
            ),
            const SizedBox(height: 12),

            // ── Rating field ─────────────────────────────────────────
            _InfoTile(
              icon: Icons.star_outline_rounded,
              label: AppStrings.get('rating', locale),
              value: '${(widget.user?.rating ?? 5.0).toStringAsFixed(1)} ★',
            ),

            const Spacer(),

            // ── Logout Button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
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
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  ),
                ),
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
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
