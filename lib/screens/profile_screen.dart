import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'auth_gate_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final bool isModal;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.isModal = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser _user = AuthUser.guest();
  int _dailyUsage = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();

    AuthService.currentUserNotifier.addListener(_onAuthChanged);
    _loadProfileData();
  }

  void _onAuthChanged() {
    if (mounted) {
      final updated = AuthService.currentUserNotifier.value;
      setState(() {
        _user = updated;
        _populateControllers(updated);
      });
    }
  }

  void _populateControllers(AuthUser user) {
    if (_nameController.text.isEmpty ||
        _nameController.text == 'Google Account' ||
        _nameController.text == 'Google User') {
      _nameController.text = user.name.isNotEmpty
          ? user.name
          : (user.username.isNotEmpty ? user.username : 'Samarjit');
    }
    if (_emailController.text.isEmpty && user.email.isNotEmpty) {
      _emailController.text = user.email;
    }
    if (_addressController.text.isEmpty && user.address.isNotEmpty) {
      _addressController.text = user.address;
    }
    if (_phoneController.text.isEmpty && user.phone.isNotEmpty) {
      _phoneController.text = user.phone;
    }
    if (_bioController.text.isEmpty && user.bio.isNotEmpty) {
      _bioController.text = user.bio;
    }
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onAuthChanged);
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = await AuthService.getCurrentUser();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final usage = prefs.getInt('axom_w2p_usage_$today') ?? 0;

    if (mounted) {
      setState(() {
        _user = user;
        _dailyUsage = usage;
        _isLoading = false;
        _populateControllers(user);
      });
    }

    // Background sync with server
    AuthService.syncUserStatus().then((synced) {
      if (mounted) {
        setState(() => _user = synced);
      }
    });
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await AuthService.updateProfile(avatarPath: path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated!'),
              backgroundColor: AppTheme.accentPurple,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick photo: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    await AuthService.updateProfile(avatarPath: '');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isSaving = true);

    final newName = _nameController.text.trim();
    final newAddress = _addressController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newBio = _bioController.text.trim();

    await AuthService.updateProfile(
      name: newName.isNotEmpty ? newName : 'Samarjit',
      email: _user.email,
      address: newAddress,
      phone: newPhone,
      bio: newBio,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Profile changes saved successfully!'),
            ],
          ),
          backgroundColor: AppTheme.accentPurple,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Are you sure you want to sign out of Axom AI?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AuthGateScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Clear Chat History',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will delete all stored conversations on this device. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.saveSessions([]);
      await StorageService.saveCurrentSessionId('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared.'),
            backgroundColor: AppTheme.accentPurple,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const freeDailyLimit = 20;
    final remaining = (freeDailyLimit - _dailyUsage).clamp(0, freeDailyLimit);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.isModal
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          widget.isModal ? 'Settings & Profile' : 'Account & Profile',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentPurple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. User Profile Hero Card with Photo Upload
                  _buildProfilePhotoCard(),

                  const SizedBox(height: 18),

                  // 2. Personal Details Card (Name, Email, Address, Phone, Bio)
                  _buildPersonalDetailsCard(),

                  const SizedBox(height: 18),

                  // 3. Subscription & Plan Section (ChatGPT Plus style)
                  _buildSubscriptionCard(freeDailyLimit, remaining),

                  const SizedBox(height: 18),

                  // 4. App Preferences (Theme, Sound, etc.)
                  _buildPreferencesCard(),

                  const SizedBox(height: 18),

                  // 5. Data & Privacy Controls
                  _buildDataControlsCard(),

                  const SizedBox(height: 18),

                  // 6. Sign Out Danger Button
                  _buildSignOutButton(),

                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Axom AI Mobile v1.0.0 • Neural Edition',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- Widget 1: Profile Photo Card ---
  Widget _buildProfilePhotoCard() {
    final displayName = _user.name.isNotEmpty
        ? _user.name
        : (_user.username.isNotEmpty ? _user.username : 'Samarjit');
    final hasCustomPhoto = _user.avatarPath.isNotEmpty &&
        File(_user.avatarPath).existsSync();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151833), AppTheme.bgCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentPurple.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPurple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Large Avatar with tap-to-upload
              UserAvatar(
                user: _user,
                size: 68,
                showEditBadge: true,
                onTap: _pickProfilePhoto,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user.isAuthenticated ? displayName : 'Guest Explorer',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _user.isAuthenticated
                          ? (_user.email.isNotEmpty
                              ? _user.email
                              : '@${_user.username}')
                          : 'Sign in to sync your profile & chats',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _user.isStaff
                            ? Colors.amber.withValues(alpha: 0.2)
                            : AppTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _user.isStaff
                              ? Colors.amber.withValues(alpha: 0.4)
                              : AppTheme.accentPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _user.isStaff
                                ? Icons.workspace_premium_rounded
                                : Icons.bolt_rounded,
                            size: 12,
                            color: _user.isStaff
                                ? Colors.amber
                                : AppTheme.accentPurple,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _user.isStaff
                                ? 'Pro Member • Unlimited'
                                : 'Free Tier • Active',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _user.isStaff
                                  ? Colors.amber
                                  : AppTheme.accentPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 12),

          // Photo Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentCyan,
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Change Photo',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  onPressed: _pickProfilePhoto,
                ),
              ),
              if (hasCustomPhoto) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(
                        color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  onPressed: _removeProfilePhoto,
                ),
              ],
            ],
          ),

          if (!_user.isAuthenticated) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login_rounded,
                  size: 16, color: Colors.white),
              label: const Text(
                'Sign In / Register Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      onLoginSuccess: _loadProfileData,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // --- Widget 2: Personal Details Card (Name, Address, Phone, Bio) ---
  Widget _buildPersonalDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: AppTheme.accentPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Display Name
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Your display name (e.g. Samarjit)',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),

          // Email (Account ID - Read-Only)
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'user@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
            suffixIcon: Icons.lock_outline_rounded,
            helperText: 'Email is permanently linked to your account and cannot be changed.',
          ),
          const SizedBox(height: 12),

          // Address / Location
          _buildTextField(
            controller: _addressController,
            label: 'Location / Address',
            hint: 'e.g. Guwahati, Assam, India',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),

          // Phone / Contact
          _buildTextField(
            controller: _phoneController,
            label: 'Phone / Mobile (Optional)',
            hint: 'e.g. +91 9876543210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          // Bio / Status
          _buildTextField(
            controller: _bioController,
            label: 'Bio / About You',
            hint: 'e.g. AI Explorer, Creator & Researcher',
            icon: Icons.notes_rounded,
            maxLines: 2,
          ),

          const SizedBox(height: 18),

          // Save Changes Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 44),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Profile Changes',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _isSaving ? null : _saveProfileChanges,
          ),
        ],
      ),
    );
  }

  // --- Widget 3: Subscription & Plan Section (ChatGPT Plus Style) ---
  Widget _buildSubscriptionCard(int freeDailyLimit, int remaining) {
    final isPro = _user.isStaff;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPro
              ? Colors.amber.withValues(alpha: 0.4)
              : AppTheme.accentPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPro ? Icons.workspace_premium_rounded : Icons.star_outline_rounded,
                    color: isPro ? Colors.amber : AppTheme.accentPink,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Subscription & Plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPro ? 'Axom AI Pro Plus' : 'Axom AI Free Plan',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPro
                ? 'Unlimited access to advanced reasoning, web synthesis, and file vision.'
                : 'Daily free allowance with standard model rotation.',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Plan Features List (ChatGPT Plus style checkmarks)
          _buildPlanFeature('Access to Axom 2.0 Pro model rotation', true),
          _buildPlanFeature('Bilingual Assamese & English reasoning', true),
          _buildPlanFeature('Document & PDF intelligence synthesis', true),
          _buildPlanFeature('Live Web Search & real-time citations', true),
          _buildPlanFeature(
            isPro ? '5x faster generation speed' : 'Standard generation speed',
            isPro,
          ),

          const SizedBox(height: 16),

          // Upgrade CTA or Manage Plan
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPro ? AppTheme.bgPill : AppTheme.accentPurple,
              foregroundColor: isPro ? AppTheme.accentPurple : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isPro ? AppTheme.borderColor : Colors.transparent,
                ),
              ),
              minimumSize: const Size(double.infinity, 42),
            ),
            onPressed: () =>
                _openUrl('https://chat.aiaxom.co.in/subscription'),
            child: Text(
              isPro ? 'Manage Subscription' : 'Upgrade to Axom Pro Plus',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFeature(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: active ? AppTheme.successGreen : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: active ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget 4: Preferences Card ---
  Widget _buildPreferencesCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.dark_mode_rounded,
            iconColor: AppTheme.accentPurple,
            title: 'Dark Theme',
            subtitle: widget.isDarkMode
                ? 'Obsidian dark theme active'
                : 'Light theme active',
            trailing: Switch(
              value: widget.isDarkMode,
              activeTrackColor: AppTheme.accentPurple,
              onChanged: (_) => widget.onToggleTheme(),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          _buildSettingTile(
            icon: Icons.translate_rounded,
            iconColor: AppTheme.accentCyan,
            title: 'Primary AI Language',
            subtitle: 'Assamese, English, Hindi bilingual',
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // --- Widget 5: Data Controls Card ---
  Widget _buildDataControlsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.delete_sweep_outlined,
            iconColor: AppTheme.errorRed,
            title: 'Clear Chat History',
            subtitle: 'Erase all conversation logs on this device',
            onTap: _handleClearHistory,
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.accentPink,
            title: 'Privacy Policy & Terms',
            subtitle: 'Read how your data is secured',
            onTap: () => _openUrl('https://aiaxom.co.in/privacy'),
          ),
        ],
      ),
    );
  }

  // --- Widget 6: Sign Out Button ---
  Widget _buildSignOutButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.errorRed,
        side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text(
        'Sign Out of Axom AI',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
      ),
      onPressed: _handleLogout,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    IconData? suffixIcon,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            if (readOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 9.5, color: AppTheme.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'READ-ONLY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 13.5,
            color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: readOnly
                ? AppTheme.bgCard.withValues(alpha: 0.6)
                : AppTheme.bgMain,
            prefixIcon: Icon(
              icon,
              color: readOnly ? AppTheme.textMuted : AppTheme.accentPurple,
              size: 18,
            ),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, size: 16, color: AppTheme.textMuted)
                : null,
            helperText: helperText,
            helperStyle: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.textMuted,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly
                    ? AppTheme.borderColor.withValues(alpha: 0.5)
                    : AppTheme.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? AppTheme.borderColor : AppTheme.accentPurple,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
