import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free US NHTSA vPIC VIN decoder — no API key required.
/// https://vpic.nhtsa.dot.gov/api/
class NhtsaVinClient {
  NhtsaVinClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';
  static const _timeout = Duration(seconds: 12);

  Future<Map<String, String>> decodeVinValues(String vin, {int? modelYear}) async {
    final yearParam = modelYear != null ? '&modelyear=$modelYear' : '';
    final uri = Uri.parse('$_base/DecodeVinValues/${Uri.encodeComponent(vin)}?format=json$yearParam');
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return {};

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['Results'];
    if (results is! List || results.isEmpty) return {};

    final row = results.first as Map<String, dynamic>;
    if ('${row['ErrorCode']}' != '0') return {};

    return row.map((key, value) => MapEntry('$key', _clean('${value ?? ''}')));
  }

  Future<Map<String, String>> decodeWmi(String wmi) async {
    final uri = Uri.parse('$_base/DecodeWMI/${Uri.encodeComponent(wmi)}?format=json');
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return {};

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['Results'];
    if (results is! List || results.isEmpty) return {};

    final row = results.first as Map<String, dynamic>;
    return row.map((key, value) => MapEntry('$key', _clean('${value ?? ''}')));
  }

  String _clean(String value) {
    final v = value.trim();
    if (v.isEmpty || v == 'Not Applicable' || v == 'NULL' || v == '0') return '';
    return v;
  }
}
