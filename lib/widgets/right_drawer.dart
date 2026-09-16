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
    return Drawer(
      backgroundColor: AppTheme.bgSidebar,
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
                  const Text(
                    'Plan & Usage',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 20),
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
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
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
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
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
                                      color: AppTheme.accentPink,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                        if (!activeUser.isAuthenticated) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.bgPill,
                              foregroundColor: AppTheme.accentPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: AppTheme.borderColor),
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
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Word Allowance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
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
                      child: const LinearProgressIndicator(
                        value: 0.35,
                        minHeight: 6,
                        backgroundColor: AppTheme.bgPill,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentPurple),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '3,500 / 10,000 words used today',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
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
                  gradient: AppTheme.glowGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentPurple.withValues(alpha: 0.3),
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
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF090A14),
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
