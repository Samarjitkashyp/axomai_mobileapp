import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final AuthUser? user;
  final String? avatarPath;
  final String? displayName;
  final double size;
  final bool showEditBadge;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.user,
    this.avatarPath,
    this.displayName,
    this.size = 36,
    this.showEditBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePath = avatarPath ?? user?.avatarPath ?? '';
    final name = displayName ?? user?.name ?? user?.username ?? 'Samarjit';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

    final hasValidFile =
        effectivePath.isNotEmpty && File(effectivePath).existsSync();

    Widget avatarWidget;
    if (hasValidFile) {
      avatarWidget = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.accentPurple.withValues(alpha: 0.4),
            width: size > 50 ? 2.0 : 1.2,
          ),
        ),
        child: ClipOval(
          child: Image.file(
            File(effectivePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackInitial(initial),
          ),
        ),
      );
    } else {
      avatarWidget = _buildFallbackInitial(initial);
    }

    if (showEditBadge) {
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0C0E1C),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildFallbackInitial(String initial) {
    final fontSize = size * 0.42;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
