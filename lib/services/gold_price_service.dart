import 'dart:convert';

import 'package:http/http.dart' as http;

const troyOunceInGrams = 31.1034768;

class GoldPriceQuote {
  const GoldPriceQuote({
    required this.pricePerTroyOunceUsd,
    required this.updatedAt,
    required this.previousCloseUsd,
    required this.changePercent,
  });

  final double pricePerTroyOunceUsd;
  final DateTime updatedAt;
  final double? previousCloseUsd;
  final double? changePercent;

  double get pricePerGramUsd => pricePerTroyOunceUsd / troyOunceInGrams;

  double pricePerKaratGramUsd(int karat) {
    if (karat < 1 || karat > 24) {
      throw ArgumentError('Le carat doit être compris entre 1 et 24.');
    }
    return pricePerGramUsd * karat / 24;
  }

  double crudeGoldPricePerKaratGramXaf({
    required double usdToXafRate,
    required int karat,
    double deductionXafPer24KGram = 4500,
  }) => calculateCrudeGoldPricePerKaratGramXaf(
    pricePerTroyOunceUsd: pricePerTroyOunceUsd,
    usdToXafRate: usdToXafRate,
    karat: karat,
    deductionXafPer24KGram: deductionXafPer24KGram,
  );
}

double calculateCrudeGoldPricePerKaratGramXaf({
  required double pricePerTroyOunceUsd,
  required double usdToXafRate,
  required int karat,
  double deductionXafPer24KGram = 4500,
}) {
  if (!pricePerTroyOunceUsd.isFinite || pricePerTroyOunceUsd <= 30) {
    throw ArgumentError('Le cours de l’once doit dépasser 30 USD.');
  }
  if (!usdToXafRate.isFinite || usdToXafRate <= 0) {
    throw ArgumentError('Le taux USD/XAF doit être positif.');
  }
  if (karat < 1 || karat > 24) {
    throw ArgumentError('Le carat doit être compris entre 1 et 24.');
  }
  if (!deductionXafPer24KGram.isFinite || deductionXafPer24KGram < 0) {
    throw ArgumentError(
      'La déduction par gramme 24K ne peut pas être négative.',
    );
  }
  final pricePerFineGram =
      (pricePerTroyOunceUsd - 30) * usdToXafRate / 31.103477;
  return (pricePerFineGram - deductionXafPer24KGram / 24) * karat / 24;
}

class GoldPriceService {
  static const refreshInterval = Duration(hours: 1);

  GoldPriceService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = (apiKey ?? const String.fromEnvironment('GOLDAPI_KEY')).trim();

  final http.Client _client;
  final String _apiKey;

  Future<GoldPriceQuote> fetchGoldUsd() async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Clé GoldAPI absente. Lancez Flutter avec '
        '--dart-define=GOLDAPI_KEY=VOTRE_CLE.',
      );
    }

    final response = await _client
        .get(
          Uri.https('www.goldapi.io', '/api/price/XAU/USD'),
          headers: {'x-access-token': _apiKey, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'GoldAPI a répondu HTTP ${response.statusCode}. '
        'Vérifiez votre clé, votre quota et l’endpoint.',
      );
    }

    final payload = jsonDecode(response.body);

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Réponse GoldAPI invalide.');
    }

    final price = payload['price'];
    final timestamp = payload['timestamp'];

    if (payload['metal'] != 'XAU' ||
        payload['currency'] != 'USD' ||
        price is! num ||
        price <= 0) {
      throw const FormatException('Le cours XAU/USD reçu est invalide.');
    }

    final dateValue = payload['datetime'];

    final updatedAt = timestamp is num && timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            timestamp.toInt() * 1000,
            isUtc: true,
          ).toLocal()
        : dateValue is String
        ? DateTime.tryParse(dateValue)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return GoldPriceQuote(
      pricePerTroyOunceUsd: price.toDouble(),
      updatedAt: updatedAt,
      previousCloseUsd: _toDouble(payload['prev_close_price']),
      changePercent: _toDouble(payload['change_percent']),
    );
  }

  void close() => _client.close();

  static double? _toDouble(Object? value) =>
      value is num ? value.toDouble() : null;
}
