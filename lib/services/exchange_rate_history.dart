import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'exchange_rate_service.dart';

class ExchangeRateHistoryPoint {
  const ExchangeRateHistoryPoint({
    required this.observedAt,
    required this.usdRates,
  });

  final DateTime observedAt;
  final Map<String, double> usdRates;

  double? rate(String from, String to) {
    final fromRate = usdRates[from];
    final toRate = usdRates[to];
    if (fromRate == null || toRate == null || fromRate <= 0) return null;
    return toRate / fromRate;
  }

  Map<String, Object> toJson() => {
    'observedAt': observedAt.toIso8601String(),
    'usdRates': usdRates,
  };

  static ExchangeRateHistoryPoint fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['observedAt'] is! String ||
        value['usdRates'] is! Map<String, dynamic>) {
      throw const FormatException('Point d’historique de taux invalide.');
    }
    final observedAt = DateTime.tryParse(value['observedAt'] as String);
    final rates = <String, double>{};
    for (final entry in (value['usdRates'] as Map<String, dynamic>).entries) {
      if (entry.value is! num || (entry.value as num) <= 0) {
        throw const FormatException('Valeur de taux historique invalide.');
      }
      rates[entry.key] = (entry.value as num).toDouble();
    }
    if (observedAt == null || rates.isEmpty) {
      throw const FormatException('Point d’historique de taux incomplet.');
    }
    return ExchangeRateHistoryPoint(
      observedAt: observedAt,
      usdRates: Map.unmodifiable(rates),
    );
  }
}

class ExchangeRateHistory {
  static const _storageKey = 'exchange_rate_history_v1';

  Future<List<ExchangeRateHistoryPoint>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Historique des taux invalide.');
    }
    final points = decoded
        .map(ExchangeRateHistoryPoint.fromJson)
        .toList(growable: true);
    points.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return points;
  }

  Future<List<ExchangeRateHistoryPoint>> record(
    ExchangeRateSnapshot snapshot, {
    DateTime? observedAt,
  }) async {
    final now = observedAt ?? DateTime.now();
    final points = (await load()).toList();
    if (points.isNotEmpty &&
        now.difference(points.last.observedAt) < const Duration(minutes: 50)) {
      return points;
    }
    points.add(
      ExchangeRateHistoryPoint(observedAt: now, usdRates: snapshot.usdRates),
    );
    final cutoff = now.subtract(const Duration(days: 365));
    final hourlyCutoff = now.subtract(const Duration(hours: 24));
    final olderByDay = <String, ExchangeRateHistoryPoint>{};
    final recent = <ExchangeRateHistoryPoint>[];
    for (final point in points.where(
      (point) => point.observedAt.isAfter(cutoff),
    )) {
      if (point.observedAt.isAfter(hourlyCutoff)) {
        recent.add(point);
      } else {
        final time = point.observedAt;
        final day = '${time.year}-${time.month}-${time.day}';
        olderByDay[day] = point;
      }
    }
    final compacted = [...olderByDay.values, ...recent]
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(compacted.map((point) => point.toJson()).toList()),
    );
    return compacted;
  }
}
