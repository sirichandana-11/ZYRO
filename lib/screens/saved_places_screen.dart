import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/saved_place_model.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/saved_places_service.dart';
import '../theme/zyro_theme.dart';
import '../widgets/zyro_button.dart';

class SavedPlacesScreen extends StatefulWidget {
  final User? user;
  final bool isSelectionMode;

  const SavedPlacesScreen({
    super.key,
    this.user,
    this.isSelectionMode = false,
  });

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final AuthService _authService = AuthService();
  final SavedPlacesService _placesService = SavedPlacesService();
  final GeocodingService _geocodingService = GeocodingService.instance;
  final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Places')),
        body: const Center(child: Text('Please log in to view saved places.')),
      );
    }

    return Scaffold(
      backgroundColor: ZyroTheme.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: ZyroTheme.cardBg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ZyroTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isSelectionMode ? 'Select Location' : 'Saved Places',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: ZyroTheme.textPrimary(context),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditPlaceSheet(context, user.uid),
        backgroundColor: ZyroTheme.primaryColor,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text(
          'Add Place',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<SavedPlaceModel>>(
        stream: _placesService.watchSavedPlaces(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ZyroTheme.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_add_outlined,
                        size: 48,
                        color: ZyroTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No saved places yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ZyroTheme.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save your frequent locations like Home, Office, or Gym for one-tap booking from Home.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: ZyroTheme.bodyText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ZyroButton(
                      text: 'Add Your First Place',
                      width: 220,
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddOrEditPlaceSheet(context, user.uid),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceCard(context, user.uid, place);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, String uid, SavedPlaceModel place) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (place.tag) {
      case 'home':
        icon = Icons.home_rounded;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        break;
      case 'work':
        icon = Icons.work_rounded;
        iconBg = const Color(0xFFE0F2FE);
        iconColor = const Color(0xFF0284C7);
        break;
      default:
        icon = Icons.location_on_rounded;
        iconBg = ZyroTheme.primarySurfaceAdaptive(context);
        iconColor = ZyroTheme.primaryColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZyroTheme.borderColor(context)),
        boxShadow: ZyroTheme.softCardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          if (widget.isSelectionMode) {
            Navigator.pop(context, place);
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Text(
              place.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ZyroTheme.textPrimary(context),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ZyroTheme.scaffoldBg(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ZyroTheme.borderColor(context)),
              ),
              child: Text(
                place.tag.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ZyroTheme.mutedText,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            place.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: ZyroTheme.mutedText,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: ZyroTheme.mutedText),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) {
            if (val == 'edit') {
              _showAddOrEditPlaceSheet(context, uid, existingPlace: place);
            } else if (val == 'delete') {
              _confirmDeletePlace(context, uid, place);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: ZyroTheme.textPrimary(context)),
                  const SizedBox(width: 8),
                  const Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: ZyroTheme.errorRed),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: ZyroTheme.errorRed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlace(BuildContext context, String uid, SavedPlaceModel place) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZyroTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Saved Place',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ZyroTheme.textPrimary(context)),
        ),
        content: Text('Are you sure you want to delete "${place.title}"?', style: TextStyle(color: ZyroTheme.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _placesService.deleteSavedPlace(uid: uid, placeId: place.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ZyroTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditPlaceSheet(BuildContext context, String uid, {SavedPlaceModel? existingPlace}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOrEditPlaceSheet(
        uid: uid,
        existingPlace: existingPlace,
        geocodingService: _geocodingService,
        locationService: _locationService,
        placesService: _placesService,
      ),
    );
  }
}

class _AddOrEditPlaceSheet extends StatefulWidget {
  final String uid;
  final SavedPlaceModel? existingPlace;
  final GeocodingService geocodingService;
  final LocationService locationService;
  final SavedPlacesService placesService;

  const _AddOrEditPlaceSheet({
    required this.uid,
    this.existingPlace,
    required this.geocodingService,
    required this.locationService,
    required this.placesService,
  });

  @override
  State<_AddOrEditPlaceSheet> createState() => _AddOrEditPlaceSheetState();
}

class _AddOrEditPlaceSheetState extends State<_AddOrEditPlaceSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedTag;
  late TextEditingController _titleController;
  late TextEditingController _addressSearchController;

  double _latitude = 0.0;
  double _longitude = 0.0;
  String _formattedAddress = '';

  List<GeocodingLocation> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isAcquiringGps = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlace;
    _selectedTag = p?.tag ?? 'home';
    _titleController = TextEditingController(text: p?.title ?? 'Home');
    _addressSearchController = TextEditingController(text: p?.address ?? '');
    _latitude = p?.latitude ?? 0.0;
    _longitude = p?.longitude ?? 0.0;
    _formattedAddress = p?.address ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().length < 2) return;
    setState(() {
      _isSearching = true;
    });
    final results = await widget.geocodingService.search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _useCurrentGps() async {
    setState(() {
      _isAcquiringGps = true;
    });
    final result = await widget.locationService.determinePosition();
    if (!mounted) return;

    if (result.isSuccess && result.validatedLocation != null) {
      final loc = result.validatedLocation!;
      final address = await widget.geocodingService.reverseGeocode(loc.latitude, loc.longitude);
      if (!mounted) return;

      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        _formattedAddress = address ?? 'Current Device GPS Location';
        _addressSearchController.text = _formattedAddress;
        _searchResults = [];
        _isAcquiringGps = false;
      });
    } else {
      setState(() {
        _isAcquiringGps = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZyroTheme.errorRed,
          content: Text(result.message ?? 'Failed to get current GPS location.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPlace != null;

    return Container(
      decoration: BoxDecoration(
        color: ZyroTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZyroTheme.borderColor(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Saved Place' : 'Add Saved Place',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ZyroTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),

              // Tag Selector (Home / Work / Other)
              Row(
                children: [
                  _buildTagChip('home', 'Home', Icons.home_rounded),
                  const SizedBox(width: 8),
                  _buildTagChip('work', 'Work', Icons.work_rounded),
                  const SizedBox(width: 8),
                  _buildTagChip('other', 'Other', Icons.bookmark_border_rounded),
                ],
              ),
              const SizedBox(height: 14),

              // Title input
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Place Label',
                  hintText: 'e.g. Home, Office, Gym',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Place name is required' : null,
              ),
              const SizedBox(height: 14),

              // Address Search input
              TextFormField(
                controller: _addressSearchController,
                decoration: InputDecoration(
                  labelText: 'Search Address / Landmark',
                  hintText: 'Type address and press Search',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, color: ZyroTheme.primaryColor),
                    onPressed: () => _searchAddress(_addressSearchController.text),
                  ),
                ),
                onFieldSubmitted: _searchAddress,
              ),
              const SizedBox(height: 8),

              // Use Device GPS button
              TextButton.icon(
                onPressed: _isAcquiringGps ? null : _useCurrentGps,
                icon: _isAcquiringGps
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, size: 16, color: ZyroTheme.successGreen),
                label: Text(
                  'Use Current GPS Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ZyroTheme.successGreen,
                  ),
                ),
              ),

              // Address Suggestions List
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_searchResults.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: ZyroTheme.scaffoldBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZyroTheme.borderColor(context)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: ZyroTheme.borderColor(context)),
                    itemBuilder: (ctx, i) {
                      final item = _searchResults[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, size: 18, color: ZyroTheme.primaryColor),
                        title: Text(item.shortName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ZyroTheme.textPrimary(context))),
                        subtitle: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ZyroTheme.mutedText)),
                        onTap: () {
                          setState(() {
                            _latitude = item.latitude;
                            _longitude = item.longitude;
                            _formattedAddress = item.displayName;
                            _addressSearchController.text = item.displayName;
                            _searchResults = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              if (_latitude != 0.0 && _longitude != 0.0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: ZyroTheme.successGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Geocoded: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ZyroTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Save Button
              ZyroButton(
                text: _isSaving ? 'Saving...' : 'Save Place',
                isLoading: _isSaving,
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_latitude == 0.0 && _longitude == 0.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: ZyroTheme.errorRed,
                              content: Text('Please search and select a verified address or use GPS.'),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _isSaving = true;
                        });

                        final title = _titleController.text.trim();
                        final address = _formattedAddress.isNotEmpty ? _formattedAddress : _addressSearchController.text.trim();

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        try {
                          if (widget.existingPlace != null) {
                            await widget.placesService.updateSavedPlace(
                              uid: widget.uid,
                              placeId: widget.existingPlace!.id,
                              tag: _selectedTag,
                              title: title,
                              address: address,
                              latitude: _latitude,
                              longitude: _longitude,
                            );
                          } else {
                            await widget.placesService.addSavedPlace(
                              uid: widget.uid,
                              tag: _selectedTag,
                              title: title,
                              address: address,
                              latitude: _latitude,
                              longitude: _longitude,
                            );
                          }

                          if (!mounted) return;
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              backgroundColor: ZyroTheme.successGreen,
                              content: Text('Saved "$title" successfully!'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setState(() {
                            _isSaving = false;
                          });
                          scaffoldMessenger.showSnackBar(
                            SnackBar(backgroundColor: ZyroTheme.errorRed, content: Text('Error: $e')),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, String label, IconData icon) {
    final isSelected = _selectedTag == tag;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : ZyroTheme.textPrimary(context)),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : ZyroTheme.textPrimary(context),
        ),
      ),
      selected: isSelected,
      selectedColor: ZyroTheme.primaryColor,
      backgroundColor: ZyroTheme.scaffoldBg(context),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedTag = tag;
            if (_titleController.text == 'Home' || _titleController.text == 'Work' || _titleController.text == 'Other') {
              _titleController.text = label;
            }
          });
        }
      },
    );
  }
}
