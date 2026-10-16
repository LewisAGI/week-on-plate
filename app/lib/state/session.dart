import 'package:flutter/foundation.dart';

import '../api/api.dart';

class Session extends ChangeNotifier {
  Session({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;
  Map<String, dynamic>? user;
  String? error;
  bool ready = false;
  bool busy = false;

  bool get signedIn => user != null;
  bool get isCreator => user?['role'] == 'creator';
  Map<String, dynamic> get household =>
      (user?['household'] as Map<String, dynamic>?) ?? {'adults': 2, 'under18s': 0};

  Future<void> boot() async {
    await api.restore();
    if (api.token != null) {
      try {
        final me = await api.me();
        user = me['user'] as Map<String, dynamic>?;
      } catch (_) {
        user = null;
        api.token = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.login(email, password);
      user = data['user'] as Map<String, dynamic>?;
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    final me = await api.me();
    user = me['user'] as Map<String, dynamic>?;
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
