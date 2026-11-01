import 'package:cams_gold/screens/exchanges/rate_history_chart.dart';
import 'package:cams_gold/services/exchange_rate_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a chart from persisted exchange-rate observations', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RateHistoryChart(
              points: [
                _point(now.subtract(const Duration(hours: 2)), 600),
                _point(now.subtract(const Duration(hours: 1)), 602),
              ],
              fromCurrency: 'USD',
              toCurrency: 'XAF',
              period: const Duration(hours: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RateHistoryChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ExchangeRateHistoryPoint _point(DateTime time, double xafRate) =>
    ExchangeRateHistoryPoint(
      observedAt: time,
      usdRates: {'USD': 1, 'XAF': xafRate},
    );
