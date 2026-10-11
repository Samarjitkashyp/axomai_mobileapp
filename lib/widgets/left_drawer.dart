import 'package:flutter/material.dart';
import '../models/chat_session.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

class LeftDrawer extends StatefulWidget {
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final Function(String) onSelectSession;
  final Function(String) onDeleteSession;
  final VoidCallback onNewChat;
  final VoidCallback onClose;
  final AuthUser user;
  final VoidCallback onOpenLogin;
  final VoidCallback onLogout;
  final VoidCallback? onOpenSettings;

  const LeftDrawer({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onDeleteSession,
    required this.onNewChat,
    required this.onClose,
    required this.user,
    required this.onOpenLogin,
    required this.onLogout,
    this.onOpenSettings,
  });

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSidebar = isDark ? AppTheme.bgSidebar : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF94A3B8);
    final bgPill = isDark ? AppTheme.bgPill : const Color(0xFFF1F5F9);
    final borderColor = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final activePillBg = isDark ? AppTheme.bgPillActive : const Color(0xFFECFDF5);

    final filteredSessions = widget.sessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Drawer(
      backgroundColor: bgSidebar,
      child: SafeArea(
        child: Column(
          children: [
            // Brand Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Axom AI',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: textSecondary, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // + New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: InkWell(
                onTap: () {
                  widget.onNewChat();
                  widget.onClose();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search History Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgPill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 16, color: textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(
                          fontSize: 13,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search chats...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.clear_rounded,
                            size: 14, color: textMuted),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Chat Sessions List
            Expanded(
              child: filteredSessions.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No chat history yet'
                            : 'No chats match "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 13,
                          color: textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        final isActive = session.id == widget.activeSessionId;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: isActive
                                ? Border.all(
                                    color: AppTheme.accentEmerald
                                        .withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Material(
                            color: isActive
                                ? activePillBg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0),
                              leading: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 16,
                                color: isActive
                                    ? AppTheme.accentEmerald
                                    : textSecondary,
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isActive
                                      ? (isDark ? AppTheme.textPrimary : AppTheme.accentEmerald)
                                      : textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 16, color: textMuted),
                                onPressed: () =>
                                    widget.onDeleteSession(session.id),
                              ),
                              onTap: () {
                                widget.onSelectSession(session.id);
                                widget.onClose();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Divider(color: borderColor, height: 1),

            // Bottom Profile / Settings Row matching updated sidebar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: ValueListenableBuilder<AuthUser>(
                valueListenable: AuthService.currentUserNotifier,
                builder: (context, user, _) {
                  final activeUser = user.isAuthenticated ? user : widget.user;
                  return activeUser.isAuthenticated
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  widget.onClose();
                                  widget.onOpenSettings?.call();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 4),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        user: activeUser,
                                        size: 38,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              activeUser.name.isNotEmpty
                                                  ? activeUser.name
                                                  : (activeUser.username.isNotEmpty
                                                      ? activeUser.username
                                                      : 'Samarjit'),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              activeUser.isStaff
                                                  ? 'Admin'
                                                  : (activeUser.planName.isNotEmpty
                                                      ? activeUser.planName
                                                      : 'Member'),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppTheme.accentAmber,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.settings_outlined,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.logout_rounded,
                                  size: 18, color: textSecondary),
                              onPressed: () {
                                widget.onLogout();
                                widget.onClose();
                              },
                              tooltip: 'Logout',
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: () {
                            widget.onClose();
                            widget.onOpenLogin();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: bgPill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded,
                                    size: 16, color: AppTheme.accentEmerald),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign In / Register',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
