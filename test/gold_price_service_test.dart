import 'package:cams_gold/services/gold_price_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests XAU/USD and calculates karat gram prices', () async {
    final service = GoldPriceService(
      apiKey: 'test-gold-key',
      client: MockClient((request) async {
        expect(request.url.host, 'www.goldapi.io');
        expect(request.url.path, '/api/price/XAU/USD');
        expect(request.headers['x-access-token'], 'test-gold-key');
        expect(request.headers['Accept'], 'application/json');
        return http.Response('''
          {
            "timestamp": 1792486990,
            "metal": "XAU",
            "currency": "USD",
            "price": 4300.0,
            "prev_close_price": 4290.0,
            "change_percent": 0.23
          }
          ''', 200);
      }),
    );

    final quote = await service.fetchGoldUsd();

    expect(quote.pricePerGramUsd, closeTo(4300 / troyOunceInGrams, 0.0001));
    expect(
      quote.pricePerKaratGramUsd(18),
      closeTo(4300 / troyOunceInGrams * 0.75, 0.0001),
    );
    expect(quote.previousCloseUsd, 4290);
    expect(quote.changePercent, 0.23);
    service.close();
  });

  test('reports missing API key and invalid response', () async {
    final missingKey = GoldPriceService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(missingKey.fetchGoldUsd(), throwsStateError);
    missingKey.close();

    final invalidResponse = GoldPriceService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('{"price": 0}', 200)),
    );
    await expectLater(invalidResponse.fetchGoldUsd(), throwsFormatException);
    invalidResponse.close();
  });
}
