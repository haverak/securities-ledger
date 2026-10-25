
import 'dart:convert';

import 'package:http/http.dart' as http;

class Deal {
  final int id;
  final String securityName;
  final int quantity;
  final String price;
  final DateTime dealDate;
  final int dealTypeId;
  final int dealPlaceId;
  final int currencyId;

  Deal({
    required this.id,
    required this.securityName,
    required this.quantity,
    required this.price,
    required this.dealDate,
    required this.dealTypeId,
    required this.dealPlaceId,
    required this.currencyId,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id'] as int,
      securityName: json['security_name'] as String,
      quantity: json['quantity'] as int,
      price: json['price'].toString(),
      dealDate: DateTime.parse(json['deal_date'] as String),
      dealTypeId: json['deal_type_id'] as int,
      dealPlaceId: json['deal_place_id'] as int,
      currencyId: json['currency_id'] as int,
    );
  }
}


class ReferenceItem {
  final int id;
  final String name;
  final String? code;

  const ReferenceItem({
    required this.id,
    required this.name,
    this.code,
  });

  factory ReferenceItem.fromJson(Map<String, dynamic> json) {
    return ReferenceItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
    );
  }
}


class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  Future<List<Deal>> getDeals() async {
    final response = await http
        .get(Uri.parse('$baseUrl/deals'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Ошибка сервера: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;

    return data
        .map((item) => Deal.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferenceItem>> getReferences(String path) async {
    if (!['deal-types', 'deal-places', 'currencies'].contains(path)) {
      throw ArgumentError('Неизвестный справочник');
    }

    final response = await http
        .get(Uri.parse('$baseUrl/$path'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки справочника: ${response.statusCode}');
    }

    final items = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return items
        .map((item) => ReferenceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDeal({
    required String securityName,
    required int quantity,
    required String price,
    required DateTime date,
    required int typeId,
    required int placeId,
    required int currencyId,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/deals'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'security_name': securityName,
        'quantity': quantity,
        'price': price,
        'deal_date': date.toIso8601String(),
        'deal_type_id': typeId,
        'deal_place_id': placeId,
        'currency_id': currencyId,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw Exception(
        'Ошибка сохранения (${response.statusCode}): '
            '${utf8.decode(response.bodyBytes)}',
      );
    }
  }

  Future<void> updateDeal({
    required int id,
    required String securityName,
    required int quantity,
    required String price,
    required DateTime date,
    required int typeId,
    required int placeId,
    required int currencyId,
  }) async {
    final response = await http
        .put(
      Uri.parse('$baseUrl/deals/$id'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'security_name': securityName,
        'quantity': quantity,
        'price': price,
        'deal_date': date.toIso8601String(),
        'deal_type_id': typeId,
        'deal_place_id': placeId,
        'currency_id': currencyId,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Не удалось изменить сделку: ${response.statusCode}');
    }
  }

  Future<void> deleteDeal(int id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/deals/$id'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 204) {
      throw Exception('Не удалось удалить сделку: ${response.statusCode}');
    }
  }

  Future<void> createReference(
      String path, {
        required String name,
        String? code,
      }) async {
    _checkReferencePath(path);

    final body = path == 'currencies'
        ? {'name': name.trim(), 'code': (code ?? '').trim().toUpperCase()}
        : {'name': name.trim()};

    await _sendReference(
      'POST',
      '$baseUrl/$path',
      body,
      201,
    );
  }

  Future<void> updateReference(
      String path,
      int id, {
        required String name,
        String? code,
      }) async {
    _checkReferencePath(path);

    final body = path == 'currencies'
        ? {'name': name.trim(), 'code': (code ?? '').trim().toUpperCase()}
        : {'name': name.trim()};

    await _sendReference(
      'PUT',
      '$baseUrl/$path/$id',
      body,
      200,
    );
  }

  Future<void> deleteReference(String path, int id) async {
    _checkReferencePath(path);

    final response = await http
        .delete(Uri.parse('$baseUrl/$path/$id'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 204) return;

    if (response.statusCode == 409) {
      throw Exception('Запись используется в сделках. Удаление запрещено.');
    }

    throw Exception(
      'Ошибка удаления (${response.statusCode}): '
          '${utf8.decode(response.bodyBytes)}',
    );
  }

  void _checkReferencePath(String path) {
    if (!['deal-types', 'deal-places', 'currencies'].contains(path)) {
      throw ArgumentError('Неизвестный справочник');
    }
  }

  Future<void> _sendReference(
      String method,
      String url,
      Map<String, String> body,
      int expectedStatus,
      ) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode(body);

    final response = await http.Client().send(request).timeout(
      const Duration(seconds: 10),
    );
    final result = await http.Response.fromStream(response);

    if (result.statusCode != expectedStatus) {
      throw Exception(
        'Ошибка ${result.statusCode}: '
            '${utf8.decode(result.bodyBytes)}',
      );
    }
  }

}
