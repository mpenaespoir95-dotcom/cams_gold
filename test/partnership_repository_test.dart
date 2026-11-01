import 'dart:typed_data';
import 'dart:io';
import 'package:cams_gold/models/partnership_models.dart';
import 'package:cams_gold/services/partnership_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ffi.sqfliteFfiInit);

  test(
    'persists structured partners, contributions, and assays in SQLite',
    () async {
      final databasePath = p.join(
        Directory.systemTemp.path,
        'cams_gold_partnership_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      var repository = PartnershipRepository(
        factory: ffi.databaseFactoryFfi,
        databasePath: databasePath,
      );

      final saved = await repository.createPartnership(_partnership());
      await repository.close();
      repository = PartnershipRepository(
        factory: ffi.databaseFactoryFfi,
        databasePath: databasePath,
      );
      final loaded = await repository.loadPartnerships();

      expect(saved.reference, startsWith('PTN-'));
      expect(loaded, hasLength(1));
      expect(loaded.single.scenario, PartnershipScenario.financialGold);
      expect(loaded.single.status, PartnershipStatus.draft);
      expect(loaded.single.members, hasLength(2));
      expect(loaded.single.members.last.phone, '+223 70 00 00 00');
      expect(loaded.single.members.last.city, 'Bamako');
      expect(loaded.single.members.last.email, 'partenaire@example.com');
      expect(loaded.single.validatedFinancialContributionsXaf, 500000);
      expect(loaded.single.members.first.profitSharePercent, 65);
      expect(
        loaded.single.financialContributionPercent(loaded.single.members.first),
        100,
      );
      expect(
        loaded.single.financialContributionPercent(loaded.single.members.last),
        0,
      );
      expect(
        loaded.single.members.first.validatedFinancialContributionXaf,
        500000,
      );
      expect(loaded.single.validatedFineGoldWeightGrams, 8.1);
      expect(loaded.single.provisionalFineGoldWeightGrams, 0.8);
      expect(loaded.single.analysisBefore?.fineGoldWeightGrams, 90);
      expect(loaded.single.meltWeightDifferenceGrams, 1);
      expect(await repository.loadPartners(), hasLength(1));
      expect(PartnershipScenario.values, hasLength(8));

      await repository.close();
      await File(databasePath).delete();
    },
  );

  test('rejects contractual profit shares above one hundred percent', () async {
    final repository = PartnershipRepository(
      factory: ffi.databaseFactoryFfi,
      databasePath: ffi.inMemoryDatabasePath,
    );
    await expectLater(
      repository.createPartnership(_partnership(partnerProfitShare: 45)),
      throwsArgumentError,
    );
    await repository.close();
  });

  test(
    'tracks repayments without allowing the outstanding balance below zero',
    () async {
      final repository = PartnershipRepository(
        factory: ffi.databaseFactoryFfi,
        databasePath: ffi.inMemoryDatabasePath,
      );
      final partner = await repository.createPartner(
        Partner(
          id: null,
          name: 'Partenaire de test',
          phone: '+223 70 00 00 00',
          city: 'Bamako',
          email: 'test@example.com',
          createdAt: DateTime(2026, 10, 28),
        ),
      );
      final created = await repository.createLoan(
        PartnershipLoan(
          id: null,
          reference: '',
          partnerId: partner.id,
          partnerName: partner.name,
          direction: PartnershipLoanDirection.companyBorrows,
          principalXaf: 100000,
          dueAt: DateTime(2026, 12, 31),
          note: 'Avance temporaire',
          createdAt: DateTime(2026, 10, 28),
          createdBy: 'Aminata',
          repayments: const [],
          evidenceBytes: Uint8List.fromList([1, 2, 3]),
          evidenceName: 'contrat.jpg',
        ),
      );

      expect(created.reference, startsWith('EMP-'));
      expect(created.partnerId, partner.id);
      expect(created.partnerName, 'Partenaire de test');
      expect(created.evidenceName, 'contrat.jpg');
      expect(created.evidenceBytes, Uint8List.fromList([1, 2, 3]));
      final partiallyRepaid = await repository.addLoanRepayment(
        loanId: created.id!,
        amountXaf: 40000,
        note: 'Premier versement',
        createdBy: 'Aminata',
        evidenceBytes: Uint8List.fromList([4, 5, 6]),
        evidenceName: 'virement.jpg',
      );
      expect(partiallyRepaid.repaidXaf, 40000);
      expect(partiallyRepaid.remainingXaf, 60000);
      expect(partiallyRepaid.repayments.single.evidenceName, 'virement.jpg');
      expect(
        partiallyRepaid.repayments.single.evidenceBytes,
        Uint8List.fromList([4, 5, 6]),
      );

      final settled = await repository.addLoanRepayment(
        loanId: created.id!,
        amountXaf: 60000,
        note: '',
        createdBy: 'Aminata',
      );
      expect(settled.remainingXaf, 0);
      await expectLater(
        repository.addLoanRepayment(
          loanId: created.id!,
          amountXaf: 1,
          note: '',
          createdBy: 'Aminata',
        ),
        throwsArgumentError,
      );
      await repository.close();
    },
  );

  test(
    'upgrades existing loan records without losing movement history',
    () async {
      final databasePath = p.join(
        Directory.systemTemp.path,
        'cams_gold_partnership_upgrade_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final oldDatabase = await ffi.databaseFactoryFfi.openDatabase(
        databasePath,
        options: sqflite.OpenDatabaseOptions(
          version: 2,
          onCreate: (database, version) async {
            await database.execute('''
            CREATE TABLE partners (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              phone TEXT NOT NULL DEFAULT '',
              city TEXT NOT NULL DEFAULT '',
              email TEXT NOT NULL DEFAULT '',
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL
            )
          ''');
            await database.execute('''
            CREATE TABLE partnership_loans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              reference TEXT NOT NULL UNIQUE,
              partner_name TEXT NOT NULL,
              direction TEXT NOT NULL,
              principal_xaf INTEGER NOT NULL,
              due_at TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              created_by TEXT NOT NULL
            )
          ''');
            await database.execute('''
            CREATE TABLE partnership_loan_repayments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              loan_id INTEGER NOT NULL,
              amount_xaf INTEGER NOT NULL,
              paid_at TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_by TEXT NOT NULL
            )
          ''');
            await database.insert('partners', {
              'name': 'Partenaire historique',
              'phone': '',
              'city': '',
              'email': '',
              'created_at': DateTime(2026, 10, 28).toIso8601String(),
            });
            await database.insert('partnership_loans', {
              'reference': 'EMP-2026-000001',
              'partner_name': 'Partenaire historique',
              'direction': PartnershipLoanDirection.companyBorrows.name,
              'principal_xaf': 75000,
              'due_at': DateTime(2026, 12, 31).toIso8601String(),
              'note': '',
              'created_at': DateTime(2026, 10, 28).toIso8601String(),
              'created_by': 'Aminata',
            });
            await database.insert('partnership_loan_repayments', {
              'loan_id': 1,
              'amount_xaf': 25000,
              'paid_at': DateTime(2026, 10, 29).toIso8601String(),
              'note': 'Versement historique',
              'created_by': 'Aminata',
            });
          },
        ),
      );
      await oldDatabase.close();

      final repository = PartnershipRepository(
        factory: ffi.databaseFactoryFfi,
        databasePath: databasePath,
      );
      final loans = await repository.loadLoans();

      expect(loans, hasLength(1));
      expect(loans.single.partnerName, 'Partenaire historique');
      expect(loans.single.partnerId, isNull);
      expect(loans.single.repaidXaf, 25000);
      expect(loans.single.remainingXaf, 50000);
      expect(loans.single.evidenceBytes, isNull);
      expect((await repository.loadPartners()).single.type, 'Investisseur');
      await repository.close();
      await File(databasePath).delete();
    },
  );
}

Partnership _partnership({double partnerProfitShare = 35}) => Partnership(
  id: null,
  reference: '',
  scenario: PartnershipScenario.financialGold,
  status: PartnershipStatus.draft,
  remunerationMethod: RemunerationMethod.contractualProfitShares,
  note: 'Accord de test',
  createdAt: DateTime(2026, 10, 24),
  members: [
    PartnershipMember(
      name: 'Notre entreprise',
      role: 'Entreprise',
      isCompany: true,
      profitSharePercent: 65,
      contributions: const [
        PartnershipContribution(
          kind: ContributionKind.financial,
          amountXaf: 500000,
          isValidated: true,
        ),
      ],
    ),
    PartnershipMember(
      name: 'Partenaire de test',
      role: 'Fournisseur d’or',
      phone: '+223 70 00 00 00',
      city: 'Bamako',
      email: 'partenaire@example.com',
      profitSharePercent: partnerProfitShare,
      contributions: [
        PartnershipContribution(
          kind: ContributionKind.metal,
          grossWeightGrams: 10,
          netWeightGrams: 9,
          purityPercent: 90,
          purityIsProvisional: false,
          purityAnalyzedAt: DateTime(2026, 10, 24),
          isValidated: true,
        ),
        PartnershipContribution(
          kind: ContributionKind.metal,
          grossWeightGrams: 1.2,
          netWeightGrams: 1,
          purityPercent: 80,
          purityIsProvisional: true,
          isValidated: true,
        ),
      ],
    ),
  ],
  analysisBefore: GoldAnalysis(
    netWeightGrams: 100,
    purityPercent: 90,
    isProvisional: false,
    analyzedAt: DateTime(2026, 10, 24),
  ),
  analysisAfter: const GoldAnalysis(
    netWeightGrams: 99,
    purityPercent: 91,
    isProvisional: true,
  ),
);
