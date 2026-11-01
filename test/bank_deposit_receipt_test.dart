import 'package:cams_gold/core/app_store.dart';
import 'package:cams_gold/screens/banks/banks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saving a deposit offers a printable receipt', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    final startingBalance = store.bankBalances['Ecobank']!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BanksScreen(store: store)),
      ),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Détail'), findsOneWidget);
    expect(find.text('Montant'), findsOneWidget);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(3));

    await tester.enterText(find.byType(TextField).at(0), '25000');
    await tester.enterText(find.byType(TextField).at(1), 'Versement test');
    await tester.tap(find.text('Enregistrer le versement'));
    await tester.pumpAndSettle();

    expect(store.bankBalances['Ecobank'], startingBalance + 25000);
    expect(find.text('Versement enregistré'), findsOneWidget);
    expect(find.text('Imprimer la fiche'), findsOneWidget);
    expect(find.textContaining('25 000 FCFA'), findsWidgets);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(4));

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'Versement test');
    await tester.pumpAndSettle();

    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(1));
    expect(find.text('Versement test'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
