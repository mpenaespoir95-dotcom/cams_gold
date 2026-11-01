import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cams_gold/app/app.dart';
import 'package:cams_gold/core/app_store.dart';
import 'package:cams_gold/screens/appointments/appointments_screen.dart';
import 'package:cams_gold/screens/cash/cash_screen.dart';
import 'package:cams_gold/screens/contacts/contacts_screen.dart';
import 'package:cams_gold/screens/purchases/purchases_screen.dart';
import 'package:cams_gold/screens/shell/app_shell.dart';
import 'package:cams_gold/screens/stock/stock_screen.dart';
import 'package:cams_gold/services/gold_price_service.dart';
import 'package:cams_gold/shared/widgets/app_widgets.dart';

void main() {
  test(
    'crude gold price applies the agreed ounce, rate, and karat formula',
    () {
      final quote = GoldPriceQuote(
        pricePerTroyOunceUsd: 2000,
        updatedAt: DateTime(2026, 10, 27),
        previousCloseUsd: null,
        changePercent: null,
      );
      final t = (2000 - 30) * 600 / 31.103477;

      expect(
        quote.crudeGoldPricePerKaratGramXaf(usdToXafRate: 600, karat: 22),
        closeTo((t - 4500 / 24) * 22 / 24, 0.000001),
      );
      expect(
        calculateCrudeGoldPricePerKaratGramXaf(
          pricePerTroyOunceUsd: 2000,
          usdToXafRate: 600,
          karat: 22,
          deductionXafPer24KGram: 3500,
        ),
        closeTo((t - 3500 / 24) * 22 / 24, 0.000001),
      );
      expect(
        () => quote.crudeGoldPricePerKaratGramXaf(usdToXafRate: 0, karat: 22),
        throwsArgumentError,
      );
    },
  );

  test('cash transfers and expenses update account balances safely', () {
    final store = AppStore();
    final totalBefore = store.totalTreasury;
    final cashBefore = store.bankBalances['Caisse (espèces)']!;
    final ecobankBefore = store.bankBalances['Ecobank']!;

    store.transferFunds(
      fromAccount: 'Caisse (espèces)',
      toAccount: 'Ecobank',
      amount: 100000,
      label: 'Dépôt à la banque',
    );
    expect(store.bankBalances['Caisse (espèces)'], cashBefore - 100000);
    expect(store.bankBalances['Ecobank'], ecobankBefore + 100000);
    expect(store.totalTreasury, totalBefore);

    store.addExpense(
      account: 'Caisse (espèces)',
      amount: 25000,
      description: 'Fournitures',
    );
    expect(store.bankBalances['Caisse (espèces)'], cashBefore - 125000);
    expect(store.operations.first.title, 'Dépense · Fournitures');
    expect(
      () => store.transferFunds(
        fromAccount: 'Caisse (espèces)',
        toAccount: 'Ecobank',
        amount: cashBefore,
        label: 'Solde insuffisant',
      ),
      throwsArgumentError,
    );
  });

  test('cash-funded purchase debits and cancellation refunds its account', () {
    final store = AppStore();
    final initialCash = store.bankBalances['Caisse (espèces)']!;
    store.addPurchase(
      'Fournisseur · 1 g · 24K',
      1000,
      paymentAccount: 'Caisse (espèces)',
    );
    final purchase = store.purchases.first;
    expect(store.bankBalances['Caisse (espèces)'], initialCash - 1000);
    expect(purchase.paidAmount, 1000);
    expect(purchase.remainingAmount, 0);

    store.cancelPurchase(purchase, 'Erreur de saisie');
    expect(store.bankBalances['Caisse (espèces)'], initialCash);
  });

  test('purchase records retain the USD/XAF rate used at purchase time', () {
    final store = AppStore();
    final rateObservedAt = DateTime(2026, 10, 25, 7, 20);
    store.addPurchase(
      'Moussa Diakité · 2 g · 24K · 89 000 FCFA',
      89000,
      goldPricePerTroyOunceUsd: 2000,
      usdToXafRate: 601.25,
      rateObservedAt: rateObservedAt,
    );

    final purchase = store.purchases.first;
    expect(purchase.description, contains('Moussa Diakité'));
    expect(purchase.amount, 89000);
    expect(purchase.goldPricePerTroyOunceUsd, 2000);
    expect(purchase.usdToXafRate, 601.25);
    expect(purchase.rateObservedAt, rateObservedAt);
  });

  test(
    'purchase payments, remaining balance, and cancellation are tracked',
    () {
      final store = AppStore();
      store.addPurchase(
        'Moussa Diakité · 24,5 g · 22K · 245 000 FCFA',
        245000,
        supplier: 'Moussa Diakité',
        grossWeightGrams: 25,
        nonGoldWeightGrams: 0.5,
        karat: '22K',
        purityPercent: 22 / 24 * 100,
      );
      final purchase = store.purchases.first;

      expect(purchase.netWeightGrams, 24.5);
      expect(purchase.fineGoldWeightGrams, closeTo(22.4583, 0.0001));
      expect(purchase.remainingAmount, 245000);

      store.addPurchasePayment(
        purchase,
        PurchasePayment(
          amount: 100000,
          paidAt: DateTime(2026, 10, 25),
          method: 'Espèces',
        ),
      );
      expect(purchase.paidAmount, 100000);
      expect(purchase.remainingAmount, 145000);
      expect(
        () => store.addPurchasePayment(
          purchase,
          PurchasePayment(
            amount: 150000,
            paidAt: DateTime(2026, 10, 25),
            method: 'Virement',
          ),
        ),
        throwsArgumentError,
      );

      store.cancelPurchase(purchase, 'Erreur de saisie');
      expect(purchase.isCancelled, isTrue);
      expect(purchase.cancellationReason, 'Erreur de saisie');
      expect(store.purchases, contains(purchase));
    },
  );

  test('gold stock combines purchases, sales, and traced corrections', () {
    final store = AppStore();
    expect(store.stockWeightForKarat('24K'), 2);
    expect(store.stockWeightForKarat('22K'), 124.6);

    store.addSale('Client · 1 g · 24K', 1000, weightGrams: 1, karat: '24K');
    expect(store.stockWeightForKarat('24K'), 1);

    store.adjustGoldStock(
      karat: '24K',
      weightGrams: 0.5,
      reason: 'Inventaire physique',
    );
    expect(store.stockWeightForKarat('24K'), 1.5);
    expect(store.stockMovements, hasLength(2));
    expect(
      () => store.adjustGoldStock(
        karat: '24K',
        weightGrams: -2,
        reason: 'Correction excessive',
      ),
      throwsArgumentError,
    );
  });

  test('manually entered carat is saved and included in stock', () {
    final store = AppStore();
    store.addPurchase(
      'Fournisseur · 2 g · 20K',
      50000,
      grossWeightGrams: 2,
      nonGoldWeightGrams: 0,
      karat: '20K',
      purityPercent: 20 / 24 * 100,
    );

    expect(store.purchases.first.karat, '20K');
    expect(store.stockWeightForKarat('20K'), 2);
    expect(isValidGoldKarat('20K'), isTrue);
    expect(isValidGoldKarat('25K'), isFalse);
    expect(isValidGoldKarat('0K'), isFalse);
  });

  testWidgets('stock page presents inventory and movements in French', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StockScreen(store: AppStore())),
      ),
    );

    expect(find.text('Gestion du stock'), findsOneWidget);
    expect(find.text('Résumé du stock d’or'), findsOneWidget);
    expect(find.text('POIDS NET DISPONIBLE'), findsOneWidget);
    expect(find.text('OR FIN ESTIMÉ'), findsOneWidget);
    expect(find.text('Mettre à jour le stock'), findsOneWidget);
    expect(find.text('RÉSERVE · STOCK D’OR'), findsOneWidget);
    expect(find.text('OR 24K (G)'), findsOneWidget);
    expect(find.text('ÉQUIVALENT OR 999‰'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Caisse · stock de devises'), findsOneWidget);
    expect(find.text('SOLDE USD'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Détail par catégorie et carat'), findsOneWidget);
    expect(find.text('Catégorie'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Mouvements de stock'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('purchase module shows the calculated purchase workflow', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PurchasesScreen(store: store)),
      ),
    );

    expect(find.text("Comptoir d’achat d’or Congo"), findsOneWidget);
    expect(find.text("Nouvel Achat d'Or"), findsOneWidget);
    expect(find.text('DATE & CODE'), findsOneWidget);
    await tester.tap(find.text("Nouvel Achat d'Or"));
    await tester.pumpAndSettle();
    expect(find.text("Saisie du Bordereau d'Achat"), findsOneWidget);
    expect(find.text('POIDS BRUT (G)'), findsOneWidget);
    expect(
      find.text('Cours indisponible. Saisissez l’once et le taux USD/XAF.'),
      findsNothing,
    );
    expect(find.text('Poids net (g)'), findsNothing);
    expect(find.text('Pureté estimée'), findsNothing);
    expect(find.text('Or fin estimé'), findsNothing);
    expect(find.text('Prix formule'), findsOneWidget);
    expect(find.text('Prix appliqué au gramme (Modifiable)'), findsOneWidget);
    expect(find.text('Mode de Paiement'), findsOneWidget);
    expect(find.text('Montant Versé Immédiatement'), findsOneWidget);
    expect(find.text('Total de l’achat :'), findsOneWidget);
    expect(find.text('ESTIMATION DU MONTANT'), findsNothing);
    expect(find.text('Reste à payer'), findsNothing);
    expect(tester.takeException(), isNull);

    final bijouxChip = find.widgetWithText(ChoiceChip, 'Bijoux (-7000)');
    await tester.ensureVisible(bijouxChip);
    await tester.pumpAndSettle();
    await tester.tap(bijouxChip);
    await tester.pump();
    expect(find.text('Prix appliqué au gramme (Modifiable)'), findsOneWidget);
    expect(find.text('Déduction catégorie'), findsNothing);
    expect(find.text('Prix de la décote négociée (%)'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cash module exposes gold purchases, transfers, and expenses', (
    tester,
  ) async {
    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CashScreen(store: store)),
      ),
    );

    expect(find.text('Caisse'), findsOneWidget);
    expect(find.text('Achat'), findsOneWidget);
    expect(find.text('Virements'), findsOneWidget);
    expect(find.text('Dépenses'), findsOneWidget);
    expect(find.text('DATE & CODE'), findsOneWidget);
    await tester.tap(find.text("Nouvel Achat d'Or"));
    await tester.pumpAndSettle();
    expect(find.text("Saisie du Bordereau d'Achat"), findsOneWidget);
    expect(find.text('Caisse'), findsNothing);
    await tester.tap(find.text('Fermer le formulaire'));
    await tester.pumpAndSettle();
    expect(find.text('Caisse'), findsOneWidget);

    await tester.tap(find.text('Dépenses'));
    await tester.pumpAndSettle();
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '12500');
    await tester.enterText(textFields.at(1), 'Fournitures');
    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pumpAndSettle();

    expect(store.bankBalances['Caisse (espèces)'], 6284500 - 12500);
    expect(store.operations.first.title, 'Dépense · Fournitures');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'purchase estimate uses net weight, ounce price, and exchange rate',
    (tester) async {
      final store = AppStore();
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PurchasesScreen(store: store)),
        ),
      );
      await tester.tap(find.text("Nouvel Achat d'Or"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier le cours de référence'));
      await tester.pumpAndSettle();

      final grossWeightField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '0,00',
      );
      await tester.enterText(grossWeightField.first, '25');
      await tester.enterText(grossWeightField.last, '0.5');
      final caratField = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.initialValue == '22',
      );
      await tester.tap(caratField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('20K – 83,33%').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'USD / once troy',
        ),
        '2000',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'Ex. 600',
        ),
        '600',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.decoration?.hintText == '0',
        ),
        '1000',
      );
      await tester.pump();

      expect(find.text('Prix de l’once troy (USD)'), findsOneWidget);
      expect(find.text('Taux USD/XAF (à renseigner)'), findsOneWidget);

      final expectedPrice = (2000 - 30) * 600 / 31.103477;
      final expectedTotal = (expectedPrice - 4500 / 24) * 20 / 24 * 24.5;
      expect(find.text('Prix formule'), findsOneWidget);
      expect(find.text('${money(expectedPrice)} FCFA / g'), findsOneWidget);
      expect(find.text('Prix appliqué au gramme (Modifiable)'), findsOneWidget);
      expect(find.text('${money(expectedTotal)} FCFA'), findsOneWidget);

      final saveButton = find.text('Valider l’achat et générer le reçu');
      await tester.scrollUntilVisible(
        saveButton,
        500,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pump();
      final purchase = store.purchases.first;
      expect(purchase.amount, closeTo(expectedTotal, 0.001));
      expect(purchase.goldPricePerTroyOunceUsd, 2000);
      expect(purchase.usdToXafRate, 600);
      expect(purchase.karat, '20K');
      expect(purchase.purityPercent, closeTo(20 / 24 * 100, 0.001));
      expect(purchase.referencePricePerGram, closeTo(expectedPrice, 0.001));
      expect(purchase.paidAmount, 1000);
      expect(purchase.remainingAmount, closeTo(expectedTotal - 1000, 0.001));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('manual purchase entries support an advance payment', (
    tester,
  ) async {
    final store = AppStore();
    final openingBalance = store.bankBalances['Caisse (espèces)']!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PurchasesScreen(store: store)),
      ),
    );

    await tester.tap(find.byTooltip('Autres actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un achat manuellement'));
    await tester.pumpAndSettle();

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), 'Achat manuel de bijou');
    await tester.enterText(dialogFields.at(1), '120000');
    await tester.enterText(dialogFields.at(2), '40000');
    await tester.enterText(dialogFields.at(3), '2.5');
    await tester.enterText(dialogFields.at(5), '22');
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(store.purchases.first.description, 'Achat manuel de bijou');
    expect(store.purchases.first.amount, 120000);
    expect(store.purchases.first.paidAmount, 40000);
    expect(store.purchases.first.remainingAmount, 80000);
    expect(store.purchases.first.payments.single.method, 'Avance');
    expect(store.bankBalances['Caisse (espèces)'], openingBalance - 40000);
    expect(store.stockWeightForKarat('22K'), 127.1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cash shows recorded bank deposits', (tester) async {
    final store = AppStore()
      ..addMovement('Ecobank', 25000, true, 'Versement recettes');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CashScreen(store: store)),
      ),
    );

    await tester.tap(find.text('Versements'));
    await tester.pumpAndSettle();

    expect(find.text('Versements enregistrés'), findsOneWidget);
    expect(find.text('Versement recettes'), findsOneWidget);
    expect(find.textContaining('+ 25 000 FCFA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Login screen renders with logo and form fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CamsGoldApp());
    expect(find.text('Connexion'), findsWidgets);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Connexion'), findsOneWidget);
  });

  testWidgets('Desktop home renders dashboard and navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1152, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore()..signIn('Administrateur');
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(store: store, onSignOut: () {}),
      ),
    );

    expect(find.text('Bonjour Administrateur,'), findsOneWidget);
    expect(find.text('Accès rapide'), findsOneWidget);
    expect(find.text('Dernières opérations'), findsOneWidget);
    expect(find.text('Cours de référence'), findsOneWidget);
    expect(find.text('Bénéfice total'), findsOneWidget);
    expect(find.text('Caisse'), findsWidgets);
    expect(find.text('6 284 500 FCFA'), findsOneWidget);
    expect(find.text('Stock de devises'), findsOneWidget);
    expect(find.text('Opérations non traitées'), findsOneWidget);
    expect(find.text('Rendez-vous fixés'), findsOneWidget);
    expect(find.text('Al Noor Gold Trading'), findsWidgets);
    expect(find.byTooltip('Marquer comme traitée'), findsNWidgets(3));
    expect(find.text('Non traitée'), findsNWidgets(3));
    expect(find.text('Traitée'), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('SMS'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Marquer comme traitée').first);
    await tester.pump();
    expect(find.byTooltip('Marquer comme traitée'), findsNWidgets(2));
    expect(find.text('Non traitée'), findsNWidgets(2));
    expect(find.text('Traitée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile home keeps compact navigation and dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore()..signIn('Aminata');
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(store: store, onSignOut: () {}),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Bonjour Aminata,'), findsOneWidget);
    expect(find.text('Accès rapide'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SMS').last);
    await tester.pumpAndSettle();

    expect(find.text('Nouveau message'), findsOneWidget);
    expect(find.text('Écrire un message…'), findsOneWidget);
    expect(
      find.textContaining('Rédigez votre message ci-dessous'),
      findsOneWidget,
    );
    expect(find.text('Ouvrir l’application SMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contacts screen shows a searchable client table', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1152, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactsScreen(store: store)),
      ),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('N°'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Ville'), findsOneWidget);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Action'), findsNothing);
    expect(find.text('RDV'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(6));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Clients'));
    await tester.pump();

    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(4));
    expect(find.text('Jean-Paul Mbarga'), findsOneWidget);
    expect(find.text('Moussa Diakité'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Appointments screen lists and removes fixed appointments', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1152, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppointmentsScreen(store: store)),
      ),
    );

    expect(find.text('Rendez-vous fixés'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Moussa Diakité'), findsOneWidget);
    expect(find.text('Awa Traoré Bijouterie'), findsOneWidget);
    expect(find.text('Al Noor Gold Trading'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer le rendez-vous').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Moussa Diakité'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
