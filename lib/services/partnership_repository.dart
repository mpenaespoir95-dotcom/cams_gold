import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' as ffi_web;

import '../models/partnership_models.dart';

class PartnershipRepository {
  PartnershipRepository({sqflite.DatabaseFactory? factory, this.databasePath})
    : _providedFactory = factory;

  final sqflite.DatabaseFactory? _providedFactory;
  final String? databasePath;
  sqflite.Database? _database;

  Future<List<Partnership>> loadPartnerships() async {
    final database = await _openDatabase();
    final rows = await database.query(
      'partnerships',
      orderBy: 'created_at DESC, id DESC',
    );
    final partnerships = <Partnership>[];
    for (final row in rows) {
      partnerships.add(await _readPartnership(database, row));
    }
    return partnerships;
  }

  Future<List<Partner>> loadPartners() async {
    final database = await _openDatabase();
    final rows = await database.query(
      'partners',
      where: 'is_active = 1',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(_partnerFromRow).toList();
  }

  Future<Partner> createPartner(Partner partner) async {
    final name = partner.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Le nom du partenaire est obligatoire.');
    }
    final database = await _openDatabase();
    final id = await database.insert('partners', {
      'name': name,
      'phone': partner.phone.trim(),
      'city': partner.city.trim(),
      'email': partner.email.trim(),
      'type': partner.type.trim(),
      'is_active': 1,
      'created_at': partner.createdAt.toIso8601String(),
    });
    final rows = await database.query(
      'partners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return _partnerFromRow(rows.single);
  }

  Future<List<PartnershipLoan>> loadLoans() async {
    final database = await _openDatabase();
    final rows = await database.query(
      'partnership_loans',
      orderBy: 'created_at DESC, id DESC',
    );
    final loans = <PartnershipLoan>[];
    for (final row in rows) {
      loans.add(await _readLoan(database, row));
    }
    return loans;
  }

  Future<PartnershipLoan> createLoan(PartnershipLoan loan) async {
    _validateLoan(loan);
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final partnerRows = loan.partnerId == null
          ? const <Map<String, Object?>>[]
          : await transaction.query(
              'partners',
              columns: ['name'],
              where: 'id = ? AND is_active = 1',
              whereArgs: [loan.partnerId],
              limit: 1,
            );
      if (partnerRows.isEmpty) {
        throw ArgumentError('Sélectionnez une fiche partenaire active.');
      }
      final id = await transaction.insert('partnership_loans', {
        'reference': 'PENDING',
        'partner_id': loan.partnerId,
        'partner_name': partnerRows.single['name']! as String,
        'direction': loan.direction.name,
        'principal_xaf': loan.principalXaf,
        'due_at': loan.dueAt.toIso8601String(),
        'note': loan.note.trim(),
        'created_at': loan.createdAt.toIso8601String(),
        'created_by': loan.createdBy.trim(),
        'evidence_bytes': loan.evidenceBytes,
        'evidence_name': loan.evidenceName,
      });
      final reference =
          'EMP-${loan.createdAt.year}-${id.toString().padLeft(6, '0')}';
      await transaction.update(
        'partnership_loans',
        {'reference': reference},
        where: 'id = ?',
        whereArgs: [id],
      );
      final rows = await transaction.query(
        'partnership_loans',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return _readLoan(transaction, rows.single);
    });
  }

  Future<PartnershipLoan> addLoanRepayment({
    required int loanId,
    required int amountXaf,
    required String note,
    required String createdBy,
    Uint8List? evidenceBytes,
    String? evidenceName,
  }) async {
    if (amountXaf <= 0) {
      throw ArgumentError('Le remboursement doit être supérieur à zéro.');
    }
    if (createdBy.trim().isEmpty) {
      throw ArgumentError('L’auteur du remboursement est obligatoire.');
    }
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final loanRows = await transaction.query(
        'partnership_loans',
        where: 'id = ?',
        whereArgs: [loanId],
        limit: 1,
      );
      if (loanRows.isEmpty) {
        throw ArgumentError('Cet emprunt est introuvable.');
      }
      final repaymentRows = await transaction.query(
        'partnership_loan_repayments',
        columns: ['amount_xaf'],
        where: 'loan_id = ?',
        whereArgs: [loanId],
      );
      final paid = repaymentRows.fold<int>(
        0,
        (total, row) => total + (row['amount_xaf']! as int),
      );
      final principal = loanRows.single['principal_xaf']! as int;
      if (amountXaf > principal - paid) {
        throw ArgumentError('Le remboursement dépasse le solde restant dû.');
      }
      await transaction.insert('partnership_loan_repayments', {
        'loan_id': loanId,
        'amount_xaf': amountXaf,
        'paid_at': DateTime.now().toIso8601String(),
        'note': note.trim(),
        'created_by': createdBy.trim(),
        'evidence_bytes': evidenceBytes,
        'evidence_name': evidenceName?.trim(),
      });
      return _readLoan(transaction, loanRows.single);
    });
  }

  Future<Partnership> createPartnership(Partnership partnership) async {
    _validate(partnership);
    final database = await _openDatabase();
    return database.transaction((transaction) async {
      final createdAt = partnership.createdAt.toIso8601String();
      final id = await transaction.insert('partnerships', {
        'reference': 'PENDING',
        'scenario': partnership.scenario.name,
        'status': partnership.status.name,
        'remuneration_method': partnership.remunerationMethod.name,
        'remuneration_value': partnership.remunerationValue,
        'note': partnership.note.trim(),
        'created_at': createdAt,
        'before_net_weight': partnership.analysisBefore?.netWeightGrams,
        'before_purity': partnership.analysisBefore?.purityPercent,
        'before_provisional': _boolToInt(
          partnership.analysisBefore?.isProvisional,
        ),
        'before_analyzed_at': partnership.analysisBefore?.analyzedAt
            ?.toIso8601String(),
        'after_net_weight': partnership.analysisAfter?.netWeightGrams,
        'after_purity': partnership.analysisAfter?.purityPercent,
        'after_provisional': _boolToInt(
          partnership.analysisAfter?.isProvisional,
        ),
        'after_analyzed_at': partnership.analysisAfter?.analyzedAt
            ?.toIso8601String(),
      });
      final reference =
          'PTN-${partnership.createdAt.year}-'
          '${id.toString().padLeft(6, '0')}';
      await transaction.update(
        'partnerships',
        {'reference': reference},
        where: 'id = ?',
        whereArgs: [id],
      );

      for (final member in partnership.members) {
        final partnerId = member.isCompany
            ? null
            : await _getOrCreatePartner(transaction, member);
        final memberId = await transaction.insert('partnership_members', {
          'partnership_id': id,
          'partner_id': partnerId,
          'display_name': member.name.trim(),
          'role': member.role.trim(),
          'profit_share_percent': member.profitSharePercent,
          'is_company': _boolToInt(member.isCompany),
        });
        for (final contribution in member.contributions) {
          await transaction.insert('partnership_contributions', {
            'member_id': memberId,
            'kind': contribution.kind.name,
            'is_validated': _boolToInt(contribution.isValidated),
            'amount_xaf': contribution.amountXaf,
            'gross_weight_grams': contribution.grossWeightGrams,
            'net_weight_grams': contribution.netWeightGrams,
            'purity_percent': contribution.purityPercent,
            'purity_is_provisional': _boolToInt(
              contribution.purityIsProvisional,
            ),
            'purity_analyzed_at': contribution.purityAnalyzedAt
                ?.toIso8601String(),
            'service_description': contribution.serviceDescription?.trim(),
          });
        }
      }
      return _readPartnership(
        transaction,
        (await transaction.query(
          'partnerships',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        )).single,
      );
    });
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Future<sqflite.Database> _openDatabase() async {
    final existing = _database;
    if (existing != null) return existing;
    final factory = _providedFactory ?? await _defaultFactory();
    final path = await _resolveDatabasePath();
    final database = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 4,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createLoanSchema(database);
          } else if (oldVersion < 3) {
            await _upgradeLoanEvidenceSchema(database);
          }
          if (oldVersion < 4) await _upgradePartnerTypeSchema(database);
        },
      ),
    );
    _database = database;
    return database;
  }

  Future<String> _resolveDatabasePath() async {
    final providedPath = databasePath;
    if (providedPath != null) return providedPath;
    if (kIsWeb) return 'cams_gold_partnerships.db';
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, 'cams_gold_partnerships.db');
  }

  Future<sqflite.DatabaseFactory> _defaultFactory() async {
    if (kIsWeb) return ffi_web.databaseFactoryFfiWeb;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      ffi.sqfliteFfiInit();
      return ffi.databaseFactoryFfi;
    }
    return sqflite.databaseFactorySqflitePlugin;
  }

  Future<void> _createSchema(sqflite.Database database, int version) async {
    await database.execute('''
      CREATE TABLE partners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        phone TEXT NOT NULL DEFAULT '',
        city TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'Investisseur',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE partnerships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL UNIQUE,
        scenario TEXT NOT NULL,
        status TEXT NOT NULL,
        remuneration_method TEXT NOT NULL,
        remuneration_value REAL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        before_net_weight REAL,
        before_purity REAL,
        before_provisional INTEGER,
        before_analyzed_at TEXT,
        after_net_weight REAL,
        after_purity REAL,
        after_provisional INTEGER,
        after_analyzed_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE partnership_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        partnership_id INTEGER NOT NULL REFERENCES partnerships(id)
          ON DELETE CASCADE,
        partner_id INTEGER REFERENCES partners(id),
        display_name TEXT NOT NULL,
        role TEXT NOT NULL,
        profit_share_percent REAL,
        is_company INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE partnership_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES partnership_members(id)
          ON DELETE CASCADE,
        kind TEXT NOT NULL,
        is_validated INTEGER NOT NULL DEFAULT 0,
        amount_xaf INTEGER,
        gross_weight_grams REAL,
        net_weight_grams REAL,
        purity_percent REAL,
        purity_is_provisional INTEGER NOT NULL DEFAULT 1,
        purity_analyzed_at TEXT,
        service_description TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX partnerships_created_at_idx '
      'ON partnerships(created_at)',
    );
    await database.execute(
      'CREATE INDEX partnership_members_partnership_idx '
      'ON partnership_members(partnership_id)',
    );
    await _createLoanSchema(database);
  }

  Future<void> _createLoanSchema(sqflite.DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE partnership_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL UNIQUE,
        partner_id INTEGER REFERENCES partners(id),
        partner_name TEXT NOT NULL,
        direction TEXT NOT NULL,
        principal_xaf INTEGER NOT NULL,
        due_at TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        evidence_bytes BLOB,
        evidence_name TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE partnership_loan_repayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL REFERENCES partnership_loans(id)
          ON DELETE CASCADE,
        amount_xaf INTEGER NOT NULL,
        paid_at TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_by TEXT NOT NULL,
        evidence_bytes BLOB,
        evidence_name TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX partnership_loan_repayments_loan_idx '
      'ON partnership_loan_repayments(loan_id)',
    );
  }

  Future<void> _upgradeLoanEvidenceSchema(
    sqflite.DatabaseExecutor database,
  ) async {
    await database.execute(
      'ALTER TABLE partnership_loans ADD COLUMN partner_id INTEGER '
      'REFERENCES partners(id)',
    );
    await database.execute(
      'ALTER TABLE partnership_loans ADD COLUMN evidence_bytes BLOB',
    );
    await database.execute(
      'ALTER TABLE partnership_loans ADD COLUMN evidence_name TEXT',
    );
    await database.execute(
      'ALTER TABLE partnership_loan_repayments ADD COLUMN evidence_bytes BLOB',
    );
    await database.execute(
      'ALTER TABLE partnership_loan_repayments ADD COLUMN evidence_name TEXT',
    );
  }

  Future<void> _upgradePartnerTypeSchema(
    sqflite.DatabaseExecutor database,
  ) async {
    await database.execute(
      "ALTER TABLE partners ADD COLUMN type TEXT NOT NULL DEFAULT 'Investisseur'",
    );
  }

  Future<int> _getOrCreatePartner(
    sqflite.Transaction transaction,
    PartnershipMember member,
  ) async {
    final name = member.name.trim();
    final matches = await transaction.query(
      'partners',
      columns: ['id', 'phone', 'city', 'email'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (matches.isNotEmpty) {
      final existing = matches.single;
      final id = existing['id']! as int;
      await transaction.update(
        'partners',
        {
          'phone': member.phone.trim().isEmpty
              ? existing['phone']
              : member.phone.trim(),
          'city': member.city.trim().isEmpty
              ? existing['city']
              : member.city.trim(),
          'email': member.email.trim().isEmpty
              ? existing['email']
              : member.email.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    return transaction.insert('partners', {
      'name': name,
      'phone': member.phone.trim(),
      'city': member.city.trim(),
      'email': member.email.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Partnership> _readPartnership(
    sqflite.DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as int;
    final memberRows = await executor.query(
      'partnership_members',
      where: 'partnership_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    final members = <PartnershipMember>[];
    for (final memberRow in memberRows) {
      final memberId = memberRow['id']! as int;
      final partnerId = memberRow['partner_id'] as int?;
      final partnerRows = partnerId == null
          ? const <Map<String, Object?>>[]
          : await executor.query(
              'partners',
              columns: ['phone', 'city', 'email'],
              where: 'id = ?',
              whereArgs: [partnerId],
              limit: 1,
            );
      final partner = partnerRows.isEmpty ? null : partnerRows.single;
      final contributionRows = await executor.query(
        'partnership_contributions',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'id',
      );
      members.add(
        PartnershipMember(
          partnerId: partnerId,
          name: memberRow['display_name']! as String,
          role: memberRow['role']! as String,
          phone: partner?['phone'] as String? ?? '',
          city: partner?['city'] as String? ?? '',
          email: partner?['email'] as String? ?? '',
          profitSharePercent: memberRow['profit_share_percent'] as double?,
          isCompany: _intToBool(memberRow['is_company']),
          contributions: contributionRows
              .map(_contributionFromRow)
              .toList(growable: false),
        ),
      );
    }
    return Partnership(
      id: id,
      reference: row['reference']! as String,
      scenario: PartnershipScenario.values.byName(row['scenario']! as String),
      status: PartnershipStatus.values.byName(row['status']! as String),
      remunerationMethod: RemunerationMethod.values.byName(
        row['remuneration_method']! as String,
      ),
      remunerationValue: row['remuneration_value'] as double?,
      note: row['note']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      members: members,
      analysisBefore: _analysisFromRow(row, 'before'),
      analysisAfter: _analysisFromRow(row, 'after'),
    );
  }

  Future<PartnershipLoan> _readLoan(
    sqflite.DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as int;
    final repaymentRows = await executor.query(
      'partnership_loan_repayments',
      where: 'loan_id = ?',
      whereArgs: [id],
      orderBy: 'paid_at, id',
    );
    return PartnershipLoan(
      id: id,
      reference: row['reference']! as String,
      partnerName: row['partner_name']! as String,
      partnerId: row['partner_id'] as int?,
      direction: PartnershipLoanDirection.values.byName(
        row['direction']! as String,
      ),
      principalXaf: row['principal_xaf']! as int,
      dueAt: DateTime.parse(row['due_at']! as String),
      note: row['note']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      createdBy: row['created_by']! as String,
      evidenceBytes: row['evidence_bytes'] as Uint8List?,
      evidenceName: row['evidence_name'] as String?,
      repayments: repaymentRows
          .map(
            (repayment) => PartnershipRepayment(
              amountXaf: repayment['amount_xaf']! as int,
              paidAt: DateTime.parse(repayment['paid_at']! as String),
              note: repayment['note']! as String,
              createdBy: repayment['created_by']! as String,
              evidenceBytes: repayment['evidence_bytes'] as Uint8List?,
              evidenceName: repayment['evidence_name'] as String?,
            ),
          )
          .toList(growable: false),
    );
  }

  Partner _partnerFromRow(Map<String, Object?> row) => Partner(
    id: row['id']! as int,
    name: row['name']! as String,
    phone: row['phone']! as String,
    city: row['city']! as String,
    email: row['email']! as String,
    isActive: _intToBool(row['is_active']),
    type: row['type'] as String? ?? 'Investisseur',
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  PartnershipContribution _contributionFromRow(Map<String, Object?> row) =>
      PartnershipContribution(
        kind: ContributionKind.values.byName(row['kind']! as String),
        isValidated: _intToBool(row['is_validated']),
        amountXaf: row['amount_xaf'] as int?,
        grossWeightGrams: row['gross_weight_grams'] as double?,
        netWeightGrams: row['net_weight_grams'] as double?,
        purityPercent: row['purity_percent'] as double?,
        purityIsProvisional: _intToBool(row['purity_is_provisional']),
        purityAnalyzedAt: row['purity_analyzed_at'] == null
            ? null
            : DateTime.parse(row['purity_analyzed_at']! as String),
        serviceDescription: row['service_description'] as String?,
      );

  GoldAnalysis? _analysisFromRow(Map<String, Object?> row, String prefix) {
    final weight = row['${prefix}_net_weight'] as double?;
    final purity = row['${prefix}_purity'] as double?;
    if (weight == null || purity == null) return null;
    final analyzedAt = row['${prefix}_analyzed_at'] as String?;
    return GoldAnalysis(
      netWeightGrams: weight,
      purityPercent: purity,
      isProvisional: _intToBool(row['${prefix}_provisional']),
      analyzedAt: analyzedAt == null ? null : DateTime.parse(analyzedAt),
    );
  }

  void _validate(Partnership partnership) {
    if (partnership.members.isEmpty) {
      throw ArgumentError('Ajoutez au moins un participant.');
    }
    if (partnership.remunerationValue != null &&
        (!partnership.remunerationValue!.isFinite ||
            partnership.remunerationValue! < 0)) {
      throw ArgumentError('La rémunération doit être positive ou nulle.');
    }
    if (partnership.remunerationValue != null &&
        partnership.remunerationMethod != RemunerationMethod.fixedCommission &&
        partnership.remunerationValue! > 100) {
      throw ArgumentError(
        'Un taux de rémunération en pourcentage doit être compris entre 0 et 100 %.',
      );
    }
    var totalProfitShare = 0.0;
    final partnerNames = <String>{};
    for (final member in partnership.members) {
      if (member.name.trim().isEmpty || member.role.trim().isEmpty) {
        throw ArgumentError('Chaque participant doit avoir un nom et un rôle.');
      }
      if (!member.isCompany &&
          !partnerNames.add(member.name.trim().toLowerCase())) {
        throw ArgumentError(
          'Un partenaire ne peut apparaître qu’une fois dans le partenariat.',
        );
      }
      final profitShare = member.profitSharePercent;
      if (profitShare != null) {
        if (!profitShare.isFinite || profitShare < 0 || profitShare > 100) {
          throw ArgumentError(
            'Les parts de bénéfice doivent être entre 0 et 100 %.',
          );
        }
        totalProfitShare += profitShare;
      }
      for (final contribution in member.contributions) {
        _validateContribution(contribution);
      }
    }
    if (totalProfitShare > 100.000001) {
      throw ArgumentError(
        'La somme des parts contractuelles ne peut dépasser 100 %.',
      );
    }
    _validateAnalysis(partnership.analysisBefore);
    _validateAnalysis(partnership.analysisAfter);
  }

  void _validateLoan(PartnershipLoan loan) {
    if (loan.partnerId == null) {
      throw ArgumentError('Le prêt doit être associé à une fiche partenaire.');
    }
    if (loan.partnerName.trim().isEmpty) {
      throw ArgumentError('Le nom du partenaire est obligatoire.');
    }
    if (loan.principalXaf <= 0) {
      throw ArgumentError('Le montant du prêt doit être supérieur à zéro.');
    }
    if (loan.createdBy.trim().isEmpty) {
      throw ArgumentError('L’auteur de l’enregistrement est obligatoire.');
    }
  }

  void _validateContribution(PartnershipContribution contribution) {
    switch (contribution.kind) {
      case ContributionKind.financial:
        final amount = contribution.amountXaf;
        if (amount == null || amount <= 0) {
          throw ArgumentError(
            'Un apport financier doit être supérieur à zéro.',
          );
        }
      case ContributionKind.metal:
        final gross = contribution.grossWeightGrams;
        final net = contribution.netWeightGrams;
        final purity = contribution.purityPercent;
        if (gross == null ||
            net == null ||
            purity == null ||
            !gross.isFinite ||
            !net.isFinite ||
            !purity.isFinite ||
            gross <= 0 ||
            net <= 0 ||
            net > gross ||
            purity < 0 ||
            purity > 100 ||
            (!contribution.purityIsProvisional &&
                contribution.purityAnalyzedAt == null)) {
          throw ArgumentError(
            'Vérifiez le poids brut, le poids net et le titre de l’apport en métal.',
          );
        }
      case ContributionKind.service:
        if (contribution.serviceDescription?.trim().isNotEmpty != true) {
          throw ArgumentError('Décrivez la prestation apportée.');
        }
    }
  }

  void _validateAnalysis(GoldAnalysis? analysis) {
    if (analysis == null) return;
    if (!analysis.netWeightGrams.isFinite ||
        analysis.netWeightGrams <= 0 ||
        !analysis.purityPercent.isFinite ||
        analysis.purityPercent < 0 ||
        analysis.purityPercent > 100 ||
        (!analysis.isProvisional && analysis.analyzedAt == null)) {
      throw ArgumentError(
        'Une analyse doit avoir un poids net positif et un titre de 0 à 100 %.',
      );
    }
  }

  static int? _boolToInt(bool? value) => value == null ? null : (value ? 1 : 0);

  static bool _intToBool(Object? value) => value == 1;
}
