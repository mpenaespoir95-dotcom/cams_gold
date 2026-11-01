import 'package:cams_gold/core/app_store.dart';
import 'package:cams_gold/screens/reports/reports_screen.dart';
import 'package:cams_gold/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows activity totals, account balances, and print action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReportsScreen(store: AppStore())),
      ),
    );

    expect(find.text('Rapports'), findsOneWidget);
    expect(find.text('Trésorerie totale'), findsOneWidget);
    expect(find.text('Entrées enregistrées'), findsOneWidget);
    expect(find.text('Détail des opérations'), findsOneWidget);
    expect(find.text('Imprimer le rapport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps internal transfers out of report income and expenses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();
    store.transferFunds(
      fromAccount: 'Ecobank',
      toAccount: 'UBA',
      amount: 1000,
      label: 'Transfert interne',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReportsScreen(store: store)),
      ),
    );

    expect(store.operations.first.isTransfer, isTrue);
    expect(
      find.textContaining(
        'Virements exclus des totaux d’entrées et de sorties',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 virement (hors entrées/sorties)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the reports module from desktop navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1152, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(store: AppStore(), onSignOut: () {}),
      ),
    );

    await tester.tap(find.text('Rapports'));
    await tester.pumpAndSettle();

    expect(find.text('Rapport d’activité'), findsOneWidget);
    expect(find.text('Imprimer le rapport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
