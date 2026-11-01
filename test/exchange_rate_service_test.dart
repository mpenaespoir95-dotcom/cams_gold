import 'package:cams_gold/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses a configured API key endpoint', () async {
    final service = ExchangeRateService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.host, 'v6.exchangerate-api.com');
        expect(request.url.path, '/v6/test-key/latest/USD');
        return http.Response('''
          {
            "result": "success",
            "time_last_update_unix": 1792368152,
            "rates": {"USD": 1, "XAF": 584.3}
          }
          ''', 200);
      }),
    );

    final snapshot = await service.fetchRates();

    expect(snapshot.rate('USD', 'XAF'), 584.3);
    service.close();
  });

  test('parses provider rates and calculates cross-currency rates', () async {
    final service = ExchangeRateService(
      client: MockClient((request) async {
        expect(request.url.host, 'open.er-api.com');
        return http.Response('''
          {
            "result": "success",
            "time_last_update_unix": 1792368152,
            "rates": {"USD": 1, "EUR": 0.89, "XAF": 584.3, "CNY": 6.69}
          }
          ''', 200);
      }),
    );

    final snapshot = await service.fetchRates();

    expect(snapshot.rate('USD', 'XAF'), 584.3);
    expect(snapshot.rate('EUR', 'XAF'), closeTo(656.5168, 0.0001));
    expect(snapshot.rate('CNY', 'EUR'), closeTo(0.89 / 6.69, 0.000001));
    expect(
      snapshot.parallelRate('USD', 'XAF', 10),
      closeTo(642.73, 0.000001),
    );
    expect(snapshot.parallelRate('USD', 'XAF', -1), isNull);
    expect(snapshot.parallelRate('USD', 'XAF', double.nan), isNull);
    expect(snapshot.rate('USD', 'AED'), isNull);
    expect(snapshot.updatedAt.isUtc, isFalse);
    service.close();
  });

  test('surfaces provider and malformed-response errors', () async {
    final failedRequest = ExchangeRateService(
      client: MockClient((_) async => http.Response('Too many requests', 429)),
    );
    await expectLater(failedRequest.fetchRates(), throwsException);
    failedRequest.close();

    final malformedRequest = ExchangeRateService(
      client: MockClient((_) async => http.Response('{"result":"error"}', 200)),
    );
    await expectLater(malformedRequest.fetchRates(), throwsFormatException);
    malformedRequest.close();
  });
}
