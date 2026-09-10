import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const defaultApiBase = 'https://week-on-plate.lewismgodfrey.workers.dev';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? base})
      : base = (base == null || base.isEmpty)
            ? const String.fromEnvironment('API_BASE', defaultValue: defaultApiBase)
            : base;

  final String base;
  String? token;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('wop_token');
  }

  Future<void> _store(String? value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('wop_token');
    } else {
      await prefs.setString('wop_token', value);
    }
  }

  Map<String, String> _headers() {
    final h = <String, String>{'content-type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      h['authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('$base$path');
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response res = switch (method) {
      'GET' => await http.get(uri, headers: _headers()),
      'POST' => await http.post(uri, headers: _headers(), body: encoded),
      'PUT' => await http.put(uri, headers: _headers(), body: encoded),
      'PATCH' => await http.patch(uri, headers: _headers(), body: encoded),
      'DELETE' => await http.delete(uri, headers: _headers()),
      _ => throw ApiException('Unsupported method'),
    };
    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from the server.');
    }
    if (res.statusCode >= 400) {
      throw ApiException(decoded['message'] as String? ?? 'Request failed.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> health() => _send('GET', '/api/health');

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    await _store(data['token'] as String?);
    return data;
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout');
    } finally {
      await _store(null);
    }
  }

  Future<Map<String, dynamic>> me() => _send('GET', '/api/auth/me');

  Future<Map<String, dynamic>> household() => _send('GET', '/api/household');

  Future<Map<String, dynamic>> saveHousehold(int adults, int under18s) =>
      _send('PUT', '/api/household', body: {'adults': adults, 'under18s': under18s});

  Future<Map<String, dynamic>> recipes({String scope = 'browse'}) =>
      _send('GET', '/api/recipes?scope=$scope');

  Future<Map<String, dynamic>> recipe(String id) => _send('GET', '/api/recipes/$id');

  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> body) =>
      _send('POST', '/api/recipes', body: body);

  Future<Map<String, dynamic>> publishRecipe(String id) =>
      _send('POST', '/api/recipes/$id/publish');

  Future<Map<String, dynamic>> saveRecipe(String id) =>
      _send('POST', '/api/recipes/$id/save');

  Future<Map<String, dynamic>> unsaveRecipe(String id) =>
      _send('DELETE', '/api/recipes/$id/save');

  Future<Map<String, dynamic>> week({String? start}) =>
      _send('GET', start == null ? '/api/week' : '/api/week?start=$start');

  Future<Map<String, dynamic>> addToWeek({
    required String date,
    required String slot,
    required String recipeId,
  }) =>
      _send('PUT', '/api/week/slots', body: {
        'date': date,
        'slot': slot,
        'recipe_id': recipeId,
      });

  Future<Map<String, dynamic>> removeSlot(String id) =>
      _send('DELETE', '/api/week/slots/$id');

  Future<Map<String, dynamic>> markCooked(String id) =>
      _send('POST', '/api/week/slots/$id/cooked');

  Future<Map<String, dynamic>> shopping({String? start}) =>
      _send('GET', start == null ? '/api/shopping' : '/api/shopping?start=$start');

  Future<Map<String, dynamic>> cupboard() => _send('GET', '/api/cupboard');

  Future<Map<String, dynamic>> coldStart(List<String> names) =>
      _send('POST', '/api/cupboard/cold-start', body: {'names': names});

  Future<Map<String, dynamic>> patchCupboard(String id, Map<String, dynamic> body) =>
      _send('PATCH', '/api/cupboard/$id', body: body);

  Future<Map<String, dynamic>> adjustCupboard(List<Map<String, dynamic>> suggestions) =>
      _send('POST', '/api/cupboard/adjust', body: {'suggestions': suggestions});

  Future<Map<String, dynamic>> extractImport(String text) =>
      _send('POST', '/api/import/extract', body: {'text': text});

  Future<Map<String, dynamic>> confirmImport(Map<String, dynamic> draft, {bool publish = true}) =>
      _send('POST', '/api/import/confirm', body: {'draft': draft, 'publish': publish});

  Future<Map<String, dynamic>> packs() => _send('GET', '/api/packs');

  Future<Map<String, dynamic>> createPack(Map<String, dynamic> body) =>
      _send('POST', '/api/packs', body: body);

  Future<Map<String, dynamic>> purchasePack(String id) =>
      _send('POST', '/api/packs/$id/purchase');
}
