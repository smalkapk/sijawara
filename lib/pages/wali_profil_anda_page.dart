import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../services/wali_service.dart';
import '../widgets/skeleton_loader.dart';

class WaliProfilAndaPage extends StatefulWidget {
  final WaliDashboardData? dashboardData;

  const WaliProfilAndaPage({super.key, this.dashboardData});

  @override
  State<WaliProfilAndaPage> createState() => _WaliProfilAndaPageState();
}

class _WaliProfilAndaPageState extends State<WaliProfilAndaPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  WaliParentInfo? _profileData;

  // Map
  LatLng _mapCenter = const LatLng(-7.5755, 110.8243); // default: Sukoharjo
  LatLng? _markerPosition;
  final MapController _mapController = MapController();
  bool _isReverseGeocoding = false;

  // Avatar
  String? _avatarUrl;
  File? _localAvatarFile;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await WaliService.getWaliProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
          _nameController.text = profile.name;
          _phoneController.text = profile.phone;
          _addressController.text = profile.address ?? '';
          _avatarUrl = profile.avatarUrl;

          if (profile.addressLat != null && profile.addressLng != null) {
            _markerPosition =
                LatLng(profile.addressLat!, profile.addressLng!);
            _mapCenter = _markerPosition!;
          }

          _isLoading = false;
        });
      }
    } on WaliServiceException catch (e) {
      // Fallback: use dashboardData if available
      if (widget.dashboardData != null && mounted) {
        final parent = widget.dashboardData!.parent;
        setState(() {
          _profileData = parent;
          _nameController.text = parent.name;
          _phoneController.text = parent.phone;
          _addressController.text = parent.address ?? '';
          _avatarUrl = parent.avatarUrl;

          if (parent.addressLat != null && parent.addressLng != null) {
            _markerPosition =
                LatLng(parent.addressLat!, parent.addressLng!);
            _mapCenter = _markerPosition!;
          }

          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        color: AppTheme.primaryGreen,
                        onTap: () => Navigator.pop(ctx, 'camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        color: AppTheme.softBlue,
                        onTap: () => Navigator.pop(ctx, 'gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.face_rounded,
                        label: 'Avatar',
                        color: AppTheme.warmOrange,
                        onTap: () => Navigator.pop(ctx, 'avatar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'avatar') {
      _showDiceBearPicker();
      return;
    }

    // Camera or Gallery
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source:
            choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (picked == null) return;

      // Crop the image
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Foto Profil',
            toolbarColor: AppTheme.primaryGreen,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primaryGreen,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Potong Foto Profil',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped == null) return;

      final file = File(cropped.path);
      setState(() {
        _localAvatarFile = file;
        _isUploadingAvatar = true;
      });

      final newUrl = await WaliService.uploadWaliAvatar(file);
      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
          _isUploadingAvatar = false;
        });
        _showSnackBar('Foto profil berhasil diperbarui', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showSnackBar(
          e is WaliServiceException ? e.message : 'Gagal upload foto',
          isSuccess: false,
        );
      }
    }
  }

  // DiceBear avatar styles & seeds
  static const _diceBearStyles = [
    'adventurer',
    'avataaars',
    'big-ears',
    'bottts',
    'fun-emoji',
    'lorelei',
    'notionists',
    'thumbs',
  ];

  static const _diceBearSeeds = [
    'Aneka', 'Bella', 'Charlie', 'Daisy', 'Felix',
    'Ginger', 'Harley', 'Indie', 'Jasper', 'Kiki',
    'Luna', 'Milo', 'Nala', 'Oscar', 'Pepper',
    'Quinn', 'Rascal', 'Simba', 'Toby', 'Uma',
  ];

  String _diceBearUrl(String style, String seed) {
    return 'https://api.dicebear.com/9.x/$style/png?seed=$seed&size=128';
  }

  void _showDiceBearPicker() {
    String selectedStyle = _diceBearStyles[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.grey200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pilih Avatar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih gaya lalu ketuk karakter favorit',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Style tabs
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _diceBearStyles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final style = _diceBearStyles[i];
                    final isActive = style == selectedStyle;
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() => selectedStyle = style);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primaryGreen
                                : AppTheme.grey200,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            style.replaceAll('-', ' '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Avatar grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _diceBearSeeds.length,
                  itemBuilder: (_, i) {
                    final seed = _diceBearSeeds[i];
                    final url = _diceBearUrl(selectedStyle, seed);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectDiceBearAvatar(url);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.grey200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryGreen,
                                    value: progress.expectedTotalBytes !=
                                            null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  size: 24, color: AppTheme.grey400),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDiceBearAvatar(String url) async {
    setState(() {
      _isUploadingAvatar = true;
      _localAvatarFile = null;
    });

    try {
      final savedUrl = await WaliService.setWaliAvatarUrl(url);
      if (mounted) {
        setState(() {
          _avatarUrl = savedUrl;
          _isUploadingAvatar = false;
        });
        _showSnackBar('Avatar berhasil diperbarui!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showSnackBar(
          e is WaliServiceException ? e.message : 'Gagal memperbarui avatar',
          isSuccess: false,
        );
      }
    }
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reverseGeocode(LatLng position) async {
    setState(() => _isReverseGeocoding = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SijawaraApp/1.0',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] ?? '';
        if (mounted && displayName.isNotEmpty) {
          setState(() {
            _addressController.text = displayName;
          });
        }
      }
    } catch (_) {
      // Silently fail - user can still type manually
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Nama tidak boleh kosong', isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await WaliService.updateWaliProfile(
        name: name,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        addressLat: _markerPosition?.latitude,
        addressLng: _markerPosition?.longitude,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Profil berhasil disimpan!', isSuccess: true);
      }
    } on WaliServiceException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(e.message, isSuccess: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Terjadi kesalahan', isSuccess: false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? AppTheme.primaryGreen : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              size: 20,
              color: AppTheme.textPrimary,
            ),
            splashRadius: 22,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Pengaturan',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Profil Anda',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Avatar section
          _buildAvatarSection(),

          const SizedBox(height: 24),

          // Form fields
          _buildFormSection(),

          const SizedBox(height: 24),

          // Map section
          _buildMapSection(),

          const SizedBox(height: 24),

          // Save button
          _buildSaveButton(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.mainGradient,
                    border: Border.all(color: AppTheme.grey100, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.white,
                        image: _localAvatarFile != null
                            ? DecorationImage(
                                image: FileImage(_localAvatarFile!),
                                fit: BoxFit.cover,
                              )
                            : _avatarUrl != null &&
                                    _avatarUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      _avatarUrl!.startsWith('http')
                                          ? _avatarUrl!
                                          : 'https://portal-smalka.com/${_avatarUrl!}',
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (_localAvatarFile == null &&
                              (_avatarUrl == null ||
                                  _avatarUrl!.isEmpty))
                          ? Center(
                              child: Text(
                                _getInitials(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),

                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryGreen,
                      border: Border.all(color: AppTheme.grey100, width: 1),
                    ),
                    child: _isUploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _profileData?.email ?? '',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk foto untuk mengubah',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_rounded,
                  size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              const Text(
                'Informasi Pribadi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name
          _buildInputField(
            label: 'Nama Lengkap',
            controller: _nameController,
            icon: Icons.person_rounded,
            hint: 'Masukkan nama lengkap',
          ),

          const SizedBox(height: 16),

          // Phone
          _buildInputField(
            label: 'Nomor Telepon',
            controller: _phoneController,
            icon: Icons.phone_rounded,
            hint: 'Contoh: 08123456789',
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          // Address
          _buildInputField(
            label: 'Alamat Rumah',
            controller: _addressController,
            icon: Icons.home_rounded,
            hint: 'Masukkan alamat atau pilih dari peta',
            maxLines: 3,
            suffix: _isReverseGeocoding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.grey400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.grey400),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: suffix,
                  )
                : null,
            filled: true,
            fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.map_rounded,
                    size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lokasi di Peta',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (_markerPosition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 12, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Titik dipilih',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Seret pin atau ketuk peta untuk menentukan lokasi rumah Anda',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Map widget
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 15.0,
                      onTap: (tapPosition, point) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _markerPosition = point;
                        });
                        _reverseGeocode(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.smalka.sijawara',
                      ),
                      if (_markerPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _markerPosition!,
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  // Convert drag to map coordinates
                                  final renderBox = context
                                      .findRenderObject() as RenderBox;
                                  final camera = _mapController.camera;
                                  final offset =
                                      renderBox.globalToLocal(
                                          details.globalPosition);
                                  // Approximate new position
                                  final newPoint = camera.pointToLatLng(
                                    math.Point(offset.dx, offset.dy),
                                  );
                                  setState(() {
                                    _markerPosition = newPoint;
                                  });
                                },
                                onPanEnd: (_) {
                                  if (_markerPosition != null) {
                                    _reverseGeocode(_markerPosition!);
                                  }
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.grey100, width: 1),
                                      ),
                                      child: const Icon(
                                        Icons.home_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    Container(
                                      width: 3,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    Container(
                                      width: 8,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Zoom controls
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      children: [
                        _buildMapButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            final currentZoom =
                                _mapController.camera.zoom;
                            _mapController.move(
                                _mapController.camera.center,
                                currentZoom + 1);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildMapButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            final currentZoom =
                                _mapController.camera.zoom;
                            _mapController.move(
                                _mapController.camera.center,
                                currentZoom - 1);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Attribution
                  Positioned(
                    left: 8,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '© OpenStreetMap',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
        child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveProfile,
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _isSaving ? null : AppTheme.mainGradient,
          color: _isSaving ? AppTheme.grey200 : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.save_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          
          // Avatar skeleton
          Center(
            child: SkeletonLoader(
              height: 100,
              width: 100,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Form skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.grey100, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(height: 16, width: 16, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    SkeletonLoader(height: 16, width: 120, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 20),
                SkeletonLoader(height: 14, width: 100, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonLoader(height: 48, width: double.infinity, borderRadius: BorderRadius.circular(12)),
                const SizedBox(height: 16),
                SkeletonLoader(height: 14, width: 100, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonLoader(height: 48, width: double.infinity, borderRadius: BorderRadius.circular(12)),
                const SizedBox(height: 16),
                SkeletonLoader(height: 14, width: 100, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonLoader(height: 60, width: double.infinity, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Map skeleton
          SkeletonLoader(
            height: 150,
            width: double.infinity,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          
          const SizedBox(height: 24),
          
          // Save button skeleton
          SkeletonLoader(
            height: 52,
            width: double.infinity,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
