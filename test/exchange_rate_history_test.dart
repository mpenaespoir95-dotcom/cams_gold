import 'package:cams_gold/services/exchange_rate_history.dart';
import 'package:cams_gold/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists observations and skips repeated hourly checks', () async {
    final history = ExchangeRateHistory();
    final firstTime = DateTime(2026, 10, 1, 10);
    final snapshot = _snapshot(600);

    final first = await history.record(snapshot, observedAt: firstTime);
    final repeated = await history.record(
      _snapshot(601),
      observedAt: firstTime.add(const Duration(minutes: 30)),
    );
    final later = await history.record(
      _snapshot(602),
      observedAt: firstTime.add(const Duration(hours: 1)),
    );
    final loaded = await history.load();

    expect(first, hasLength(1));
    expect(repeated, hasLength(1));
    expect(later, hasLength(2));
    expect(loaded.last.rate('USD', 'XAF'), 602);
  });

  test(
    'keeps hourly recent points and compacts older observations by day',
    () async {
      final history = ExchangeRateHistory();
      final now = DateTime(2026, 10, 19, 12);

      await history.record(
        _snapshot(580),
        observedAt: now.subtract(const Duration(days: 3)),
      );
      await history.record(
        _snapshot(581),
        observedAt: now.subtract(const Duration(days: 3, hours: -1)),
      );
      await history.record(
        _snapshot(600),
        observedAt: now.subtract(const Duration(hours: 2)),
      );
      final points = await history.record(_snapshot(601), observedAt: now);

      expect(points, hasLength(3));
      expect(
        points.map((point) => point.observedAt),
        orderedEquals([
          now.subtract(const Duration(days: 3, hours: -1)),
          now.subtract(const Duration(hours: 2)),
          now,
        ]),
      );
    },
  );
}

ExchangeRateSnapshot _snapshot(double xafRate) => ExchangeRateSnapshot(
  usdRates: {'USD': 1, 'XAF': xafRate, 'EUR': 0.9},
  updatedAt: DateTime(2026, 10, 19),
);
