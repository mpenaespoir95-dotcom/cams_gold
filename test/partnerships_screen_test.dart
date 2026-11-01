import 'package:cams_gold/core/app_store.dart';
import 'package:cams_gold/screens/partnerships/partnerships_screen.dart';
import 'package:cams_gold/services/partnership_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ffi.sqfliteFfiInit);

  testWidgets('shows partner records without a new partnership form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnershipsScreen(
            store: store,
            repository: PartnershipRepository(
              factory: ffi.databaseFactoryFfi,
              databasePath: ffi.inMemoryDatabasePath,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partenariats'), findsOneWidget);
    expect(find.text('Participant 1'), findsNothing);
    expect(find.text('FONDS PROPRES VALIDÉS'), findsNothing);
    expect(find.text('FONDS CONFIÉS VALIDÉS'), findsNothing);
    expect(find.text('Nouveau partenariat'), findsNothing);
    expect(find.text('Enregistrer en brouillon'), findsNothing);
    expect(find.text('Partenaires'), findsOneWidget);
    expect(find.text('Emprunts et remboursements'), findsOneWidget);
    expect(find.textContaining('Ibrahim Sangaré'), findsNothing);

    expect(tester.takeException(), isNull);
  });

}
