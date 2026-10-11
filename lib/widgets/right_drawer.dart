import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class RightDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onApiUrlChanged;
  final AuthUser user;
  final VoidCallback onOpenLogin;

  const RightDrawer({
    super.key,
    required this.onClose,
    this.onApiUrlChanged,
    required this.user,
    required this.onOpenLogin,
  });

  @override
  State<RightDrawer> createState() => _RightDrawerState();
}

class _RightDrawerState extends State<RightDrawer> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSidebar = isDark ? AppTheme.bgSidebar : Colors.white;
    final bgCard = isDark ? AppTheme.bgCard : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF94A3B8);
    final bgPill = isDark ? AppTheme.bgPill : const Color(0xFFF1F5F9);
    final borderColor = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);

    return Drawer(
      backgroundColor: bgSidebar,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plan & Usage',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: textSecondary, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Plan Card with Reactive User State
              ValueListenableBuilder<AuthUser>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, liveUser, _) {
                  final activeUser =
                      liveUser.isAuthenticated ? liveUser : widget.user;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(user: activeUser, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeUser.isAuthenticated
                                        ? (activeUser.name.isNotEmpty
                                            ? activeUser.name
                                            : activeUser.username)
                                        : 'Free Guest Tier',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeUser.isAuthenticated
                                        ? activeUser.planName
                                        : 'Guest Mode',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.accentAmber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                activeUser.isAuthenticated
                                    ? (activeUser.isStaff ? 'Admin' : 'Member')
                                    : 'Guest',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          activeUser.isAuthenticated
                              ? 'Synced with your Axom AI account. Access to Axom 2.0 Pro model rotation.'
                              : 'Sign in with your account to unlock full history sync & models.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                        if (!activeUser.isAuthenticated) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bgPill,
                              foregroundColor: AppTheme.accentEmerald,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: borderColor),
                              ),
                              minimumSize: const Size.fromHeight(36),
                            ),
                            onPressed: () {
                              widget.onClose();
                              widget.onOpenLogin();
                            },
                            child: const Text(
                              'Sign In with Website Account',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Usage Widget
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Word Allowance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: 0.35,
                        minHeight: 6,
                        backgroundColor: bgPill,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentEmerald),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '3,500 / 10,000 words used today',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Upgrade Promo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppTheme.glowGradient
                      : const LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Want Unlimited Assamese AI?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Get Pro with zero limits, HD studio & fast generation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFD1FAE5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF065F46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size.fromHeight(38),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Visit https://aiaxom.co.in/pricing to upgrade!'),
                          ),
                        );
                      },
                      child: const Text(
                        'Explore Pro Plans',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
