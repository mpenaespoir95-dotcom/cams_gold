import 'package:cams_gold/core/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assigns unique references and keeps profile details on contacts', () {
    final store = AppStore();
    final first = Contact(
      name: 'Partenaire local',
      phone: '+242 05 339 61 58',
      city: 'Bamako',
      email: 'contact@partenaire.com',
      notes: 'À rappeler',
      roles: {'Partenaire'},
    );
    final second = Contact(
      name: 'Partenaire local',
      phone: '',
      city: '',
      roles: {'Client d’or'},
    );

    store
      ..addContact(first)
      ..addContact(second);

    expect(first.reference, 'CLI-00007');
    expect(second.reference, 'CLI-00008');
    expect(first.email, 'contact@partenaire.com');
    expect(first.notes, 'À rappeler');
  });

  test(
    'tracks gold stock by category and prevents overselling that category',
    () {
      final store = AppStore()
        ..addPurchase(
          'Bijou reçu',
          50000,
          grossWeightGrams: 5,
          nonGoldWeightGrams: 0,
          karat: '18K',
          goldCategory: 'Bijoux',
          purityPercent: 75,
        );

      expect(store.stockWeightForKarat('18K'), 5);
      expect(store.stockWeightForKarat('18K', category: 'Bijoux'), 5);
      expect(store.stockWeightForKarat('18K', category: 'Or brut'), 0);

      store.addSale(
        'Vente bijou',
        1000,
        weightGrams: 2,
        karat: '18K',
        category: 'Bijoux',
      );
      expect(store.stockWeightForKarat('18K', category: 'Bijoux'), 3);
      expect(
        () => store.addSale(
          'Vente bijou trop importante',
          1000,
          weightGrams: 4,
          karat: '18K',
          category: 'Bijoux',
        ),
        throwsArgumentError,
      );
    },
  );

  test('tracks currency exchanges and refuses an exchange without stock', () {
    final store = AppStore();
    store.adjustCurrencyStock(
      currency: 'USD',
      amount: 100,
      isAddition: true,
      reason: 'Stock initial',
    );

    store.addExchange(
      'Échange client',
      receivedCurrency: 'EUR',
      receivedAmount: 50,
      deliveredCurrency: 'USD',
      deliveredAmount: 60,
    );

    expect(store.currencyBalances['EUR'], 50);
    expect(store.currencyBalances['USD'], 40);
    expect(store.currencyStockMovements, hasLength(3));
    expect(
      () => store.addExchange(
        'Échange sans stock',
        receivedCurrency: 'EUR',
        receivedAmount: 1,
        deliveredCurrency: 'USD',
        deliveredAmount: 50,
      ),
      throwsArgumentError,
    );
    expect(store.currencyBalances['USD'], 40);
  });

  test('records an initial purchase advance against the selected account', () {
    final store = AppStore();
    final startingBalance = store.bankBalances['Caisse (espèces)']!;

    store.addPurchase(
      'Achat manuel',
      120000,
      paymentAccount: 'Caisse (espèces)',
      initialPaymentAmount: 40000,
    );

    expect(store.purchases.first.paidAmount, 40000);
    expect(store.purchases.first.remainingAmount, 80000);
    expect(store.purchases.first.payments.single.method, 'Avance');
    expect(store.bankBalances['Caisse (espèces)'], startingBalance - 40000);
  });

  test('marks bank deposits for display in the cash deposit register', () {
    final store = AppStore()
      ..addMovement('Ecobank', 25000, true, 'Versement recettes');

    expect(store.operations.first.isDeposit, isTrue);
    expect(store.operations.first.isIncome, isTrue);

    store.addMovement('Ecobank', 5000, false, 'Retrait de caisse');
    expect(store.operations.first.isDeposit, isFalse);
  });
}
