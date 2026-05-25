import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../blocs/settings_cubit.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/geocoding_service.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Represents a user-saved quick-access location (Home, Work, or custom).
class _SavedPlace {
  final String id; // 'home' | 'work' | 'custom_<timestamp>'
  final String name; // display name
  final String emoji; // single emoji character
  final double lat;
  final double lon;
  final String address; // shown as subtitle

  const _SavedPlace({
    required this.id,
    required this.name,
    required this.emoji,
    required this.lat,
    required this.lon,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'lat': lat,
    'lon': lon,
    'address': address,
  };

  factory _SavedPlace.fromJson(Map<String, dynamic> j) => _SavedPlace(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '\u{1F4CD}',
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    address: j['address'] as String? ?? j['title'] as String? ?? '',
  );

  _SavedPlace copyWith({
    String? id,
    String? name,
    String? emoji,
    double? lat,
    double? lon,
    String? address,
  }) => _SavedPlace(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    address: address ?? this.address,
  );
}
// ─────────────────────────────────────────────────────────────────────────────

/// Dialog that allows destination selection via Search (OSM) or Map.
///
/// Returns a map `{pickup: LatLng, dropoff: LatLng, ...addresses}` or `null`.
class DestinationSearchDialog extends StatefulWidget {
  /// The user's current GPS location (used as default pickup).
  final LatLng currentLocation;

  // Initial values to pre-fill (if re-opening after map pick)
  final LatLng? initialPickup;
  final LatLng? initialDropoff;
  final String? initialPickupAddress;
  final String? initialDropoffAddress;

  const DestinationSearchDialog({
    super.key,
    required this.currentLocation,
    this.initialPickup,
    this.initialDropoff,
    this.initialPickupAddress,
    this.initialDropoffAddress,
  });

  /// Show the dialog and return the selected locations.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required LatLng currentLocation,
    LatLng? initialPickup,
    LatLng? initialDropoff,
    String? initialPickupAddress,
    String? initialDropoffAddress,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => DestinationSearchDialog(
        currentLocation: currentLocation,
        initialPickup: initialPickup,
        initialDropoff: initialDropoff,
        initialPickupAddress: initialPickupAddress,
        initialDropoffAddress: initialDropoffAddress,
      ),
    );
  }

  @override
  State<DestinationSearchDialog> createState() =>
      _DestinationSearchDialogState();
}

class _DestinationSearchDialogState extends State<DestinationSearchDialog> {
  late TextEditingController _pickupController;
  late TextEditingController _dropoffController;
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropoffFocus = FocusNode();

  /// The actual pickup LatLng — starts as GPS location, user can change.
  late LatLng _pickupLatLng;

  /// Whether the user is editing the pickup field.
  bool _editingPickup = false;
  String _searchQuery = '';

  // Mock preset destinations (Bishkek landmarks).
  static const _allPresets = [
    {
      'title': 'Dordoi Plaza',
      'subtitle': 'ул. Ибраимова, Бишкек',
      'lat': 42.8743,
      'lon': 74.6180,
    },
    {
      'title': 'Ала-Тоо площадь',
      'subtitle': 'Центральная площадь, Бишкек',
      'lat': 42.8764,
      'lon': 74.6039,
    },
    {
      'title': 'Аэропорт Манас',
      'subtitle': 'Международный аэропорт Манас',
      'lat': 43.0613,
      'lon': 74.4774,
    },
    {
      'title': 'Asia Mall',
      'subtitle': 'пр. Ч. Айтматова 3, Бишкек',
      'lat': 42.8556,
      'lon': 74.5864,
    },
    {
      'title': 'ЦУМ Айчурек',
      'subtitle': 'пр. Чуй, Бишкек',
      'lat': 42.8745,
      'lon': 74.6130,
    },
    {
      'title': 'Vefa Center',
      'subtitle': 'ул. Горького, Бишкек',
      'lat': 42.8596,
      'lon': 74.6120,
    },
    {
      'title': 'Ошский рынок',
      'subtitle': 'ул. Токтогула, Бишкек',
      'lat': 42.8750,
      'lon': 74.5700,
    },
  ];

  // ── Search State ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _isLoading = false;

  // Saved Places & History
  List<_SavedPlace> _savedPlaces = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _pickupLatLng = widget.initialPickup ?? widget.currentLocation;

    _pickupController = TextEditingController(
      text: widget.initialPickupAddress,
    );
    _dropoffController = TextEditingController(
      text: widget.initialDropoffAddress,
    );

    _pickupController.addListener(() {
      if (_editingPickup) {
        _onSearchChanged(_pickupController.text);
      }
    });

    _dropoffController.addListener(() {
      if (!_editingPickup) {
        _onSearchChanged(_dropoffController.text);
      }
    });

    _loadFavoritesAndHistory();

    // Auto-fill pickup address from GPS if not already provided.
    if (_pickupController.text.isEmpty) {
      _resolvePickupAddress();
    }

    // Autofocus: if pickup is already filled → go straight to "Куда".
    // If not, focus on "Откуда" first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pickupController.text.isNotEmpty) {
        _onDropoffTap();
      } else {
        _onPickupTap();
      }
    });
  }

  /// Reverse-geocode the current GPS position to fill "Откуда" automatically.
  Future<void> _resolvePickupAddress() async {
    final address = await GeocodingService.getAddressFromLatLng(_pickupLatLng);
    if (!mounted) return;
    setState(() {
      if (address != null && _pickupController.text.isEmpty) {
        _pickupController.text = address;
        // After GPS resolved, switch focus to "Куда".
        if (_editingPickup) {
          _editingPickup = false;
          _onSearchChanged('');
          _dropoffFocus.requestFocus();
        }
      }
    });
  }

  static const _placesKey = 'saved_places_v2';

  Future<void> _loadFavoritesAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_placesKey);
    List<_SavedPlace> places;
    if (raw != null) {
      places = raw
          .map(
            (s) => _SavedPlace.fromJson(jsonDecode(s) as Map<String, dynamic>),
          )
          .toList();
    } else {
      // First run: migrate old fav_home / fav_work keys.
      places = [];
      final homeRaw = prefs.getString('fav_home');
      final workRaw = prefs.getString('fav_work');
      if (homeRaw != null) {
        final m = jsonDecode(homeRaw) as Map<String, dynamic>;
        places.add(
          _SavedPlace(
            id: 'home',
            name: 'Дом',
            emoji: '🏠',
            lat: (m['lat'] as num).toDouble(),
            lon: (m['lon'] as num).toDouble(),
            address: m['title'] as String? ?? '',
          ),
        );
      }
      if (workRaw != null) {
        final m = jsonDecode(workRaw) as Map<String, dynamic>;
        places.add(
          _SavedPlace(
            id: 'work',
            name: 'Работа',
            emoji: '💼',
            lat: (m['lat'] as num).toDouble(),
            lon: (m['lon'] as num).toDouble(),
            address: m['title'] as String? ?? '',
          ),
        );
      }
      await prefs.setStringList(
        _placesKey,
        places.map((p) => jsonEncode(p.toJson())).toList(),
      );
    }
    final historyJson = prefs.getStringList('search_history') ?? [];
    if (!mounted) return;
    setState(() {
      _savedPlaces = places;
      _history = historyJson
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _saveToHistory(
    String title,
    String subtitle,
    LatLng latLng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final newItem = {
      'title': title,
      'subtitle': subtitle,
      'lat': latLng.latitude,
      'lon': latLng.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _history.removeWhere((item) => item['title'] == title);
    _history.insert(0, newItem);
    if (_history.length > 10) _history = _history.sublist(0, 10);
    await prefs.setStringList(
      'search_history',
      _history.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> _savePlace(_SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = _savedPlaces.indexWhere((p) => p.id == place.id);
    if (idx >= 0) {
      _savedPlaces[idx] = place;
    } else {
      _savedPlaces.add(place);
    }
    await prefs.setStringList(
      _placesKey,
      _savedPlaces.map((p) => jsonEncode(p.toJson())).toList(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deletePlace(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _savedPlaces.removeWhere((p) => p.id == id);
    await prefs.setStringList(
      _placesKey,
      _savedPlaces.map((p) => jsonEncode(p.toJson())).toList(),
    );
    if (mounted) setState(() {});
  }

  /// Opens the Saved Places management sheet.
  Future<void> _openManagePlaces() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedPlacesManagerSheet(
        initialPlaces: List.from(_savedPlaces),
        currentLocation: widget.currentLocation,
        onSave: _savePlace,
        onDelete: _deletePlace,
      ),
    );
  }

  /// Opens the add/edit sheet. Pass [editing] to pre-fill an existing place.
  Future<void> _openAddPlaceSheet({_SavedPlace? editing}) async {
    final place = await showModalBottomSheet<_SavedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditPlaceSheet(
        editing: editing,
        currentLocation: widget.currentLocation,
      ),
    );
    if (place == null || !mounted) return;
    await _savePlace(place);
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 700), () async {
      setState(() => _isLoading = true);

      try {
        final results = await GeocodingService.searchAddress(
          query,
          nearLocation: widget.currentLocation,
        );
        if (!mounted) return;

        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  // ... (dispose and other methods) ...
  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPickupTap() {
    setState(() {
      _editingPickup = true;
      _onSearchChanged(_pickupController.text);
    });
    _pickupFocus.requestFocus();
  }

  void _onDropoffTap() {
    setState(() {
      _editingPickup = false;
      _onSearchChanged(_dropoffController.text);
    });
    _dropoffFocus.requestFocus();
  }

  void _confirmSelection(
    String title,
    String subtitle,
    LatLng? latLng, {
    String? placeId, // kept for API compatibility but unused with 2GIS
  }) {
    if (latLng == null) return;

    if (_editingPickup) {
      setState(() {
        _pickupLatLng = latLng;
        _pickupController.text = title;
        _editingPickup = false;
        _onSearchChanged(_dropoffController.text);
      });
      _dropoffFocus.requestFocus();
    } else {
      _saveToHistory(title, subtitle, latLng);

      Navigator.of(context).pop({
        'pickup': _pickupLatLng,
        'dropoff': latLng,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': title,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = context.watch<SettingsCubit>().state.locale;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final surfaceColor = isDark ? const Color(0xFF1E1E2A) : AppTheme.cardWhite;
    final dividerColor = isDark ? const Color(0xFF444455) : AppTheme.divider;
    final inputFill = isDark ? const Color(0xFF2A2A3A) : AppTheme.inputGray;
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;

    // Combine Presets + Search Results
    // If query is empty -> show Presets
    // If query is valid -> show Search Results

    final queryLower = _searchQuery.toLowerCase().trim();
    final showPresets = queryLower.isEmpty;

    final List<Map<String, dynamic>> displayList;

    if (showPresets) {
      displayList = _allPresets;
    } else {
      // Google Places already returns {place_id, title, subtitle, lat, lon}
      // No transformation needed — pass through directly.
      displayList = _searchResults;
    }

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.bottomSheetRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── Dual Field Container (Yandex style) ──────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Vertical Line joining points
                  Positioned(
                    left: 19,
                    top: 30,
                    bottom: 30,
                    child: Container(width: 1.5, color: dividerColor),
                  ),
                  Column(
                    children: [
                      _buildLocationField(
                        context: context,
                        controller: _pickupController,
                        focusNode: _pickupFocus,
                        icon: Icons.circle,
                        iconColor: AppTheme.accentGreen,
                        // Show 'Determining...' while GPS is still resolving
                        hint: _pickupController.text.isEmpty
                            ? 'Определяем адрес...'
                            : AppStrings.get('from', locale),
                        isDark: isDark,
                        onTap: _onPickupTap,
                        isActive: _editingPickup,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Divider(
                          color: dividerColor.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _buildLocationField(
                        context: context,
                        controller: _dropoffController,
                        focusNode: _dropoffFocus,
                        icon: Icons.square,
                        iconColor: AppTheme.accentRed,
                        hint: AppStrings.get('to', locale),
                        isDark: isDark,
                        onTap: _onDropoffTap,
                        isActive: !_editingPickup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── List ──────────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _editingPickup
                    ? AppStrings.get('pickup_point', locale)
                    : AppStrings.get('suggested_places', locale),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Scrollable Results Area
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // ── Saved Places Section ─────────────────────────────
                  if (showPresets) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Мои места',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openManagePlaces,
                          icon: const Icon(Icons.tune_rounded, size: 15),
                          label: const Text('Управление'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            textStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 76,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: [
                          ..._savedPlaces.map(
                            (place) => Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _SavedPlaceTile(
                                place: place,
                                isDark: isDark,
                                onTap: () => _confirmSelection(
                                  place.name,
                                  place.address,
                                  LatLng(place.lat, place.lon),
                                ),
                              ),
                            ),
                          ),
                          _AddPlaceTile(
                            isDark: isDark,
                            onTap: _openAddPlaceSheet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // History Section
                  if (showPresets && _history.isNotEmpty) ...[
                    ..._history.map(
                      (h) => _PresetTile(
                        title: h['title'],
                        subtitle: h['subtitle'],
                        icon: Icons.history_rounded,
                        isDark: isDark,
                        onTap: () {
                          _confirmSelection(
                            h['title'],
                            h['subtitle'],
                            LatLng(h['lat'], h['lon']),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 32),
                  ],

                  // "Set on map" option
                  _PresetTile(
                    title: 'Указать на карте',
                    subtitle: 'Выбрать точку вручную',
                    icon: Icons.map_rounded,
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pop({'map_pick': true, 'is_pickup': _editingPickup});
                    },
                  ),

                  // "My Location" option (only for pickup & empty query)
                  if (_editingPickup && showPresets)
                    _PresetTile(
                      title: AppStrings.get('my_location', locale),
                      subtitle: AppStrings.get('current_gps', locale),
                      icon: Icons.my_location_rounded,
                      isDark: isDark,
                      onTap: () {
                        _confirmSelection(
                          AppStrings.get('my_location', locale),
                          AppStrings.get('current_gps', locale),
                          widget.currentLocation,
                        );
                      },
                    ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // Search Results or Presets
                  ...displayList.map(
                    (p) => _PresetTile(
                      title: p['title'] as String,
                      subtitle: p['subtitle'] as String,
                      icon: showPresets
                          ? Icons.location_on_outlined
                          : Icons.search_rounded,
                      isDark: isDark,
                      onTap: () {
                        final placeId = p['place_id'] as String?;
                        final lat = p['lat'];
                        final lon = p['lon'];

                        if (placeId != null && (lat == null || lon == null)) {
                          // Google Place — coordinates resolved asynchronously
                          _confirmSelection(
                            p['title'] as String,
                            p['subtitle'] as String,
                            null,
                            placeId: placeId,
                          );
                        } else {
                          // Static preset — coordinates already known
                          _confirmSelection(
                            p['title'] as String,
                            p['subtitle'] as String,
                            LatLng(lat as double, lon as double),
                          );
                        }
                      },
                      onLongPress: () {
                        final lat = p['lat'];
                        final lon = p['lon'];
                        if (lat != null && lon != null) {
                          _showSaveFavoritePicker(
                            p['title'] as String,
                            p['subtitle'] as String,
                            LatLng(lat as double, lon as double),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveFavoritePicker(String title, String subtitle, LatLng latLng) {
    showModalBottomSheet(
      context: context,
      builder: (modalCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Сохранить как Дом'),
              leading: const Icon(Icons.home_rounded),
              onTap: () {
                _savePlace(
                  _SavedPlace(
                    id: 'home',
                    name: 'Дом',
                    emoji: '🏠',
                    lat: latLng.latitude,
                    lon: latLng.longitude,
                    address: title,
                  ),
                );
                Navigator.pop(modalCtx);
              },
            ),
            ListTile(
              title: const Text('Сохранить как Работа'),
              leading: const Icon(Icons.work_rounded),
              onTap: () {
                _savePlace(
                  _SavedPlace(
                    id: 'work',
                    name: 'Работа',
                    emoji: '💼',
                    lat: latLng.latitude,
                    lon: latLng.longitude,
                    address: title,
                  ),
                );
                Navigator.pop(modalCtx);
              },
            ),
            ListTile(
              title: const Text('Сохранить как...'),
              leading: const Icon(Icons.star_rounded),
              onTap: () {
                Navigator.pop(modalCtx);
                _openAddPlaceSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color iconColor,
    required String hint,
    required bool isDark,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final hintColor = isDark ? const Color(0xFF9CA3AF) : AppTheme.textSecondary;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onTap: onTap,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isActive ? textColor : textColor.withValues(alpha: 0.5),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: hintColor),
        filled: false,
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }
}

class _SavedPlaceTile extends StatelessWidget {
  final _SavedPlace place;
  final bool isDark;
  final VoidCallback onTap;

  const _SavedPlaceTile({
    required this.place,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2A3A) : AppTheme.inputGray;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (place.address.isNotEmpty)
              Text(
                place.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaceTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddPlaceTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2A3A) : AppTheme.inputGray;
    final color = isDark ? Colors.white54 : Colors.black38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c',
              style: GoogleFonts.inter(fontSize: 10, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData icon;
  final bool isDark;

  const _PresetTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.icon = Icons.location_on_outlined,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark ? const Color(0xFF2A2A3A) : AppTheme.inputGray;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtitleColor = isDark
        ? const Color(0xFF9CA3AF)
        : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: subtitleColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SaveFavoriteSheet — proper StatefulWidget for saving Home/Work address.
// Using a StatefulWidget (not StatefulBuilder) to get correct lifecycle and
// reliable mounted checks that prevent _dependents.isEmpty errors.
// ─────────────────────────────────────────────────────────────────────────────
class _SaveFavoriteSheet extends StatefulWidget {
  final String label;
  final LatLng currentLocation;

  const _SaveFavoriteSheet({
    required this.label,
    required this.currentLocation,
  });

  @override
  State<_SaveFavoriteSheet> createState() => _SaveFavoriteSheetState();
}

class _SaveFavoriteSheetState extends State<_SaveFavoriteSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _doSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final r = await GeocodingService.searchAddress(
        q,
        nearLocation: widget.currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF4F4F8);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u0430\u0434\u0440\u0435\u0441 "${widget.label}"',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _doSearch,
              decoration: InputDecoration(
                hintText:
                    '\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0430\u0434\u0440\u0435\u0441...',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        r['title'] as String,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      subtitle: Text(
                        r['subtitle'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      onTap: () {
                        final lat = r['lat'] as double?;
                        final lon = r['lon'] as double?;
                        if (lat == null || lon == null) return;
                        // Return result to caller — no async work here
                        Navigator.of(context).pop({
                          'title': r['title'] as String,
                          'subtitle': r['subtitle'] as String? ?? '',
                          'lat': lat,
                          'lon': lon,
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SavedPlacesManagerSheet
// ─────────────────────────────────────────────────────────────────────────────
class _SavedPlacesManagerSheet extends StatefulWidget {
  final List<_SavedPlace> initialPlaces;
  final LatLng currentLocation;
  final Future<void> Function(_SavedPlace) onSave;
  final Future<void> Function(String) onDelete;

  const _SavedPlacesManagerSheet({
    required this.initialPlaces,
    required this.currentLocation,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_SavedPlacesManagerSheet> createState() =>
      _SavedPlacesManagerSheetState();
}

class _SavedPlacesManagerSheetState extends State<_SavedPlacesManagerSheet> {
  late List<_SavedPlace> _places;

  @override
  void initState() {
    super.initState();
    _places = List.from(widget.initialPlaces);
  }

  Future<void> _edit(_SavedPlace place) async {
    final updated = await showModalBottomSheet<_SavedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditPlaceSheet(
        editing: place,
        currentLocation: widget.currentLocation,
      ),
    );
    if (updated == null || !mounted) return;
    await widget.onSave(updated);
    if (mounted) {
      setState(() {
        final idx = _places.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _places[idx] = updated;
      });
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u043c\u0435\u0441\u0442\u043e?',
        ),
        content: const Text(
          '\u042d\u0442\u043e \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u043d\u0435\u043b\u044c\u0437\u044f \u043e\u0442\u043c\u0435\u043d\u0438\u0442\u044c.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('\u0423\u0434\u0430\u043b\u0438\u0442\u044c'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.onDelete(id);
    if (mounted) setState(() => _places.removeWhere((p) => p.id == id));
  }

  Future<void> _add() async {
    final place = await showModalBottomSheet<_SavedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditPlaceSheet(
        editing: null,
        currentLocation: widget.currentLocation,
      ),
    );
    if (place == null || !mounted) return;
    await widget.onSave(place);
    if (mounted) setState(() => _places.add(place));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final surface = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF4F4F8);
    final accent = isDark ? const Color(0xFF6C8FFF) : AppTheme.primaryNavy;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
            child: Row(
              children: [
                Text(
                  '\u041c\u043e\u0438 \u043c\u0435\u0441\u0442\u0430',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (_places.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '\u041d\u0435\u0442 \u0441\u043e\u0445\u0440\u0430\u043d\u0451\u043d\u043d\u044b\u0445 \u043c\u0435\u0441\u0442',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _places.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final p = _places[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      p.address.isNotEmpty
                          ? p.address
                          : '\u0410\u0434\u0440\u0435\u0441 \u043d\u0435 \u0437\u0430\u0434\u0430\u043d',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: accent,
                          ),
                          onPressed: () => _edit(p),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(p.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043c\u0435\u0441\u0442\u043e',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddEditPlaceSheet
// ─────────────────────────────────────────────────────────────────────────────
const _kEmojis = [
  '\ud83d\udccd',
  '\ud83c\udfe0',
  '\ud83d\udcbc',
  '\u2605',
  '\u2764',
  '\ud83c\udf93',
  '\ud83c\udfe5',
  '\ud83d\uded2',
  '\ud83c\udfcb',
  '\u2615',
  '\ud83c\udfad',
  '\ud83c\udfb5',
];

class _AddEditPlaceSheet extends StatefulWidget {
  final _SavedPlace? editing;
  final LatLng currentLocation;

  const _AddEditPlaceSheet({
    required this.editing,
    required this.currentLocation,
  });

  @override
  State<_AddEditPlaceSheet> createState() => _AddEditPlaceSheetState();
}

class _AddEditPlaceSheetState extends State<_AddEditPlaceSheet> {
  final _nameCtrl = TextEditingController();
  Timer? _timer;
  late String _emoji;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  double? _lat;
  double? _lon;
  String _address = '';

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emoji = e.emoji;
      _lat = e.lat;
      _lon = e.lon;
      _address = e.address;
    } else {
      _emoji = _kEmojis.first;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _doSearch(String q) {
    _timer?.cancel();
    if (q.trim().length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final r = await GeocodingService.searchAddress(
        q,
        nearLocation: widget.currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _lat != null && _lon != null;

  void _save() {
    if (!_canSave) return;
    final id =
        widget.editing?.id ??
        'custom_' + DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.of(context).pop(
      _SavedPlace(
        id: id,
        name: _nameCtrl.text.trim(),
        emoji: _emoji,
        lat: _lat!,
        lon: _lon!,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF4F4F8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final accent = isDark ? const Color(0xFF6C8FFF) : AppTheme.primaryNavy;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.editing != null
                    ? '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043c\u0435\u0441\u0442\u043e'
                    : '\u041d\u043e\u0432\u043e\u0435 \u043c\u0435\u0441\u0442\u043e',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '\u0418\u043a\u043e\u043d\u043a\u0430',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kEmojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = _kEmojis[i];
                    final selected = _emoji == e;
                    return GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.15)
                              : inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: selected
                              ? Border.all(color: accent, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      '\u043d\u0430\u043f\u0440. \u0414\u043e\u043c, \u0420\u0430\u0431\u043e\u0442\u0430...',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '\u0410\u0434\u0440\u0435\u0441',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 8),
              if (_lat != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _lat = null;
                          _lon = null;
                          _address = '';
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  autofocus: widget.editing == null,
                  onChanged: _doSearch,
                  decoration: InputDecoration(
                    hintText:
                        '\u041f\u043e\u0438\u0441\u043a \u0430\u0434\u0440\u0435\u0441\u0430...',
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                          title: Text(
                            r['title'] as String,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          onTap: () {
                            final lat = r['lat'] as double?;
                            final lon = r['lon'] as double?;
                            if (lat == null || lon == null) return;
                            setState(() {
                              _lat = lat;
                              _lon = lon;
                              _address = r['title'] as String;
                              _results = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark
                        ? Colors.white12
                        : Colors.black12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  child: const Text(
                    '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
