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
    final filteredSessions = widget.sessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Drawer(
      backgroundColor: AppTheme.bgSidebar,
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
                      const Text(
                        'Axom AI',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 20),
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
                        color: AppTheme.accentPurple.withValues(alpha: 0.3),
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
                  color: AppTheme.bgPill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search chats...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.clear_rounded,
                            size: 14, color: AppTheme.textMuted),
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
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
                                    color: AppTheme.accentPurple
                                        .withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Material(
                            color: isActive
                                ? AppTheme.bgPillActive
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
                                    ? AppTheme.accentPurple
                                    : AppTheme.textSecondary,
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
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppTheme.textMuted),
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

            const Divider(color: AppTheme.borderColor, height: 1),

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
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppTheme.textPrimary,
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
                                                color: AppTheme.accentPink,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.settings_outlined,
                                        size: 16,
                                        color: AppTheme.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                  size: 18, color: AppTheme.textSecondary),
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
                              color: AppTheme.bgPill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded,
                                    size: 16, color: AppTheme.accentPurple),
                                SizedBox(width: 8),
                                Text(
                                  'Sign In / Register',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
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
