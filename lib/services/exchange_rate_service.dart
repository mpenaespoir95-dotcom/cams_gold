import 'dart:convert';

import 'package:http/http.dart' as http;

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({required this.usdRates, required this.updatedAt});

  final Map<String, double> usdRates;
  final DateTime updatedAt;

  double? rate(String from, String to) {
    final fromRate = usdRates[from];
    final toRate = usdRates[to];
    if (fromRate == null || toRate == null || fromRate <= 0) return null;
    return toRate / fromRate;
  }

  double? parallelRate(String from, String to, double premiumPercent) {
    final officialRate = rate(from, to);
    if (officialRate == null ||
        !premiumPercent.isFinite ||
        premiumPercent < 0) {
      return null;
    }
    return officialRate * (1 + premiumPercent / 100);
  }
}

class ExchangeRateService {
  ExchangeRateService({
    http.Client? client,
    String apiKey = const String.fromEnvironment('EXCHANGE_RATE_API_KEY'),
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey.trim();

  final http.Client _client;
  final String _apiKey;

  Future<ExchangeRateSnapshot> fetchRates() async {
    final uri = _apiKey.isEmpty
        ? Uri.https('open.er-api.com', '/v6/latest/USD')
        : Uri.https('v6.exchangerate-api.com', '/v6/$_apiKey/latest/USD');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Le fournisseur de taux a répondu ${response.statusCode}.',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['result'] != 'success' ||
        payload['rates'] is! Map<String, dynamic>) {
      throw const FormatException('Réponse de taux invalide.');
    }

    final rates = <String, double>{'USD': 1};
    for (final entry in (payload['rates'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      if (value is num && value > 0) {
        rates[entry.key] = value.toDouble();
      }
    }

    final updateTimestamp = payload['time_last_update_unix'];
    final updatedAt = updateTimestamp is num && updateTimestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            updateTimestamp.toInt() * 1000,
            isUtc: true,
          )
        : null;
    if (updatedAt == null || !rates.containsKey('XAF')) {
      throw const FormatException(
        'La réponse ne contient pas les taux requis.',
      );
    }

    return ExchangeRateSnapshot(
      usdRates: Map.unmodifiable(rates),
      updatedAt: updatedAt.toLocal(),
    );
  }

  void close() => _client.close();
}
