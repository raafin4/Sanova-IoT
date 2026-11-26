import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _usersKey = 'registered_users';

  // Hash password untuk keamanan
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Register user baru
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      String? existingUsersJson = prefs.getString(_usersKey);
      List<Map<String, dynamic>> users = [];

      if (existingUsersJson != null) {
        List<dynamic> usersList = jsonDecode(existingUsersJson);
        users = usersList.cast<Map<String, dynamic>>();
      }

      // Check if user already exists
      for (var user in users) {
        if (user['email'] == email || user['username'] == username) {
          return {
            'success': false,
            'message': 'User already exists with this email or username'
          };
        }
      }

      // Add new user
      users.add({
        'username': username,
        'email': email,
        'password': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Save users
      await prefs.setString(_usersKey, jsonEncode(users));

      return {
        'success': true,
        'message': 'Registration successful'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: $e'
      };
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing users
      String? existingUsersJson = prefs.getString(_usersKey);
      if (existingUsersJson == null) {
        return {
          'success': false,
          'message': 'No registered users found'
        };
      }

      List<dynamic> usersList = jsonDecode(existingUsersJson);
      List<Map<String, dynamic>> users = usersList.cast<Map<String, dynamic>>();

      // Find user
      Map<String, dynamic>? foundUser;
      for (var user in users) {
        if ((user['email'] == emailOrUsername || user['username'] == emailOrUsername) &&
            user['password'] == _hashPassword(password)) {
          foundUser = user;
          break;
        }
      }

      if (foundUser != null) {
        // Save login session
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_usernameKey, foundUser['username']);
        await prefs.setString(_emailKey, foundUser['email']);

        return {
          'success': true,
          'message': 'Login successful',
          'user': foundUser
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid credentials'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e'
      };
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Get current user info
  static Future<Map<String, String?>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_usernameKey),
      'email': prefs.getString(_emailKey),
    };
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
  }
}