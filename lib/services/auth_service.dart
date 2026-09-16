import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class AuthUser {
  final bool isAuthenticated;
  final String username;
  final String name;
  final String email;
  final bool isStaff;
  final String avatarPath;
  final String address;
  final String phone;
  final String bio;
  final String planName;

  const AuthUser({
    required this.isAuthenticated,
    this.username = '',
    this.name = '',
    this.email = '',
    this.isStaff = false,
    this.avatarPath = '',
    this.address = '',
    this.phone = '',
    this.bio = '',
    this.planName = 'Free Tier',
  });

  factory AuthUser.guest() => const AuthUser(isAuthenticated: false);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    final uname = (userData['username'] as String? ?? json['username'] as String? ?? '').trim();
    final name = (userData['name'] as String? ?? json['name'] as String? ?? '').trim();
    final email = (userData['email'] as String? ?? json['email'] as String? ?? '').trim();
    final isStaff = userData['is_staff'] == true || json['is_staff'] == true;
    final isAuth = json['is_authenticated'] == true ||
        json['success'] == true ||
        json['authenticated'] == true ||
        userData['is_authenticated'] == true ||
        (uname.isNotEmpty && uname.toLowerCase() != 'guest');
    final avatar = (userData['avatar_path'] as String? ?? json['avatar_path'] as String? ?? '').trim();
    final address = (userData['address'] as String? ?? json['address'] as String? ?? '').trim();
    final phone = (userData['phone'] as String? ?? json['phone'] as String? ?? '').trim();
    final bio = (userData['bio'] as String? ?? json['bio'] as String? ?? '').trim();
    final plan = (userData['plan_name'] as String? ?? json['plan_name'] as String? ?? (isStaff ? 'Pro Member' : 'Free Tier')).trim();

    return AuthUser(
      isAuthenticated: isAuth,
      username: uname.isNotEmpty ? uname : (name.isNotEmpty ? name : 'User'),
      name: name.isNotEmpty ? name : uname,
      email: email,
      isStaff: isStaff,
      avatarPath: avatar,
      address: address,
      phone: phone,
      bio: bio,
      planName: plan.isNotEmpty ? plan : (isStaff ? 'Pro Member' : 'Free Tier'),
    );
  }

  AuthUser copyWith({
    bool? isAuthenticated,
    String? username,
    String? name,
    String? email,
    bool? isStaff,
    String? avatarPath,
    String? address,
    String? phone,
    String? bio,
    String? planName,
  }) {
    return AuthUser(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      isStaff: isStaff ?? this.isStaff,
      avatarPath: avatarPath ?? this.avatarPath,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      planName: planName ?? this.planName,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_authenticated': isAuthenticated,
    'username': username,
    'name': name,
    'email': email,
    'is_staff': isStaff,
    'avatar_path': avatarPath,
    'address': address,
    'phone': phone,
    'bio': bio,
    'plan_name': planName,
  };
}

class AuthService {
  static const String _userKey = 'axom_auth_user_data';
  static const String _cookieKey = 'axom_session_cookie';

  static AuthUser? _cachedUser;
  static String? _cachedCookie;

  static final ValueNotifier<AuthUser> currentUserNotifier =
      ValueNotifier<AuthUser>(AuthUser.guest());

  // Get current user (memory or storage)
  static Future<AuthUser> getCurrentUser({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null && _cachedUser!.isAuthenticated) {
      return _cachedUser!;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        var user = AuthUser.fromJson(data);
        if (user.name == 'Google Account' || user.username == 'Google User') {
          user = AuthUser(
            isAuthenticated: true,
            username: 'Samarjit',
            name: 'Samarjit',
            email: user.email.isNotEmpty ? user.email : 'samarjit@gmail.com',
            isStaff: user.isStaff,
          );
          await saveUser(user);
        }
        _cachedUser = user;
        currentUserNotifier.value = user;
        return user;
      } catch (_) {}
    }
    _cachedUser = AuthUser.guest();
    currentUserNotifier.value = _cachedUser!;
    return _cachedUser!;
  }

  // Update user display name
  static Future<void> updateDisplayName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;
    final current = await getCurrentUser();
    final updated = current.copyWith(
      username: cleanName,
      name: cleanName,
      email: current.email.isNotEmpty
          ? current.email
          : '${cleanName.toLowerCase().replaceAll(' ', '')}@gmail.com',
    );
    await saveUser(updated);
  }

  // Update full profile information
  static Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarPath,
    String? address,
    String? phone,
    String? bio,
    String? planName,
  }) async {
    final current = await getCurrentUser();
    final updated = current.copyWith(
      name: name != null && name.trim().isNotEmpty ? name.trim() : null,
      username: name != null && name.trim().isNotEmpty ? name.trim() : null,
      // Account email is permanently tied to login and cannot be altered
      email: current.email.isNotEmpty ? current.email : email?.trim(),
      avatarPath: avatarPath,
      address: address?.trim(),
      phone: phone?.trim(),
      bio: bio?.trim(),
      planName: planName?.trim(),
    );
    await saveUser(updated);
  }

  // Get saved session cookie
  static Future<String?> getSessionCookie() async {
    if (_cachedCookie != null) return _cachedCookie;
    final prefs = await SharedPreferences.getInstance();
    _cachedCookie = prefs.getString(_cookieKey);
    return _cachedCookie;
  }

  // Save session cookie
  static Future<void> _saveSessionCookie(String? cookie) async {
    _cachedCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    if (cookie != null && cookie.isNotEmpty) {
      await prefs.setString(_cookieKey, cookie);
    } else {
      await prefs.remove(_cookieKey);
    }
  }

  // Save user profile
  static Future<void> saveUser(AuthUser user) async {
    _cachedUser = user;
    currentUserNotifier.value = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Login with Username or Email and Password
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/login/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      );

      // Extract set-cookie headers
      final rawCookies = response.headers['set-cookie'];
      if (rawCookies != null && rawCookies.isNotEmpty) {
        // Extract sessionid
        final match = RegExp(r'sessionid=([^;]+)').firstMatch(rawCookies);
        if (match != null) {
          final sessionCookie = 'sessionid=${match.group(1)}';
          await _saveSessionCookie(sessionCookie);
        }
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final isSuccess = response.statusCode == 200 &&
          (data['success'] == true ||
              data['is_authenticated'] == true ||
              data['authenticated'] == true ||
              (data['username'] != null &&
                  data['username'].toString().isNotEmpty &&
                  data['username'] != 'guest'));

      if (isSuccess) {
        var user = AuthUser.fromJson(data);
        if (!user.isAuthenticated || user.username.isEmpty) {
          user = AuthUser(
            isAuthenticated: true,
            username: username.trim(),
            name: user.name.isNotEmpty ? user.name : username.trim(),
            email: user.email,
            isStaff: user.isStaff,
          );
        }
        await saveUser(user);
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid username or password.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection failed: ${e.toString()}',
      };
    }
  }

  // Register a new account
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/register/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
          'confirm_password': confirmPassword.trim(),
        }),
      );

      final rawCookies = response.headers['set-cookie'];
      if (rawCookies != null && rawCookies.isNotEmpty) {
        final match = RegExp(r'sessionid=([^;]+)').firstMatch(rawCookies);
        if (match != null) {
          await _saveSessionCookie('sessionid=${match.group(1)}');
        }
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final isSuccess = response.statusCode == 200 &&
          (data['success'] == true ||
              data['is_authenticated'] == true ||
              data['authenticated'] == true ||
              (data['username'] != null &&
                  data['username'].toString().isNotEmpty &&
                  data['username'] != 'guest'));

      if (isSuccess) {
        var user = AuthUser.fromJson(data);
        if (!user.isAuthenticated || user.username.isEmpty) {
          user = AuthUser(
            isAuthenticated: true,
            username: username.trim(),
            name: username.trim(),
            email: email.trim(),
            isStaff: user.isStaff,
          );
        }
        await saveUser(user);
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Registration failed. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection failed: ${e.toString()}',
      };
    }
  }

  // Check user status from server
  static Future<AuthUser> syncUserStatus() async {
    final currentUser = await getCurrentUser();
    final cookie = await getSessionCookie();

    // If there is no session cookie, do NOT wipe local user!
    if (cookie == null || cookie.isEmpty) {
      return currentUser;
    }

    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/user-status/');

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Cookie': cookie,
      };

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['is_authenticated'] == true) {
          final user = AuthUser.fromJson(data);
          await saveUser(user);
          return user;
        }
      }
    } catch (_) {
      // Network error, 403, or timeout: PRESERVE current user!
      return currentUser;
    }

    // Do NOT wipe local user on non-200 or unauthenticated response
    return currentUser;
  }

  // Logout
  static Future<void> logout() async {
    final baseUrl = await StorageService.loadApiBaseUrl();
    final url = Uri.parse('$baseUrl/api/logout/');
    final cookie = await getSessionCookie();

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (cookie != null) headers['Cookie'] = cookie;
      await http.post(url, headers: headers);
    } catch (_) {}

    _cachedUser = AuthUser.guest();
    _cachedCookie = null;
    currentUserNotifier.value = AuthUser.guest();
    await _saveSessionCookie(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
