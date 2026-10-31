import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// App-wide login state. One shared instance: [app].
class AppState extends ChangeNotifier {
  final Api api = Api();
  Json? user;

  bool get loggedIn => api.token != null && user != null;
  bool get idVerified => user?['id_status'] == 'verified';
  bool get isFemale => user?['gender'] == 'female';
  bool get profileComplete => user?['profile_complete'] == true;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('token');
    final cached = p.getString('user');
    if (cached != null) user = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    if (api.token != null) {
      try {
        await refreshMe();
      } on ApiException catch (e) {
        // Token no longer valid (expired or account suspended): sign out. Network errors keep the cached login.
        if (e.status == 401 || e.status == 403) await logout();
      }
    }
  }

  Future<void> login(String token, Json u) async {
    api.token = token;
    user = u;
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token);
    await p.setString('user', jsonEncode(u));
    notifyListeners();
  }

  Future<void> refreshMe() async {
    user = await api.get('/me');
    final p = await SharedPreferences.getInstance();
    await p.setString('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    notifyListeners();
  }
}

final AppState app = AppState();
