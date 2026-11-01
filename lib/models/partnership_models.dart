import 'dart:typed_data';

enum PartnershipScenario {
  financialPurchase,
  financialGold,
  businessIntroducer,
  meltingAndTransformation,
  consignment,
  financingAndManagement,
  repayableAdvance,
  operationalService,
}

extension PartnershipScenarioLabel on PartnershipScenario {
  String get label => switch (this) {
    PartnershipScenario.financialPurchase => 'Financement d’un achat',
    PartnershipScenario.financialGold => 'Financement contre apport en or',
    PartnershipScenario.businessIntroducer => 'Apporteur d’affaires',
    PartnershipScenario.meltingAndTransformation => 'Fonte et transformation',
    PartnershipScenario.consignment => 'Consignation',
    PartnershipScenario.financingAndManagement => 'Financement et gestion',
    PartnershipScenario.repayableAdvance => 'Avance remboursable ou prêt',
    PartnershipScenario.operationalService => 'Partenaire opérationnel',
  };
}

enum PartnershipStatus {
  draft,
  pendingVerification,
  pendingContractApproval,
  contractApproved,
  contributionsCommitted,
  analysis,
  transactionInProgress,
  paymentPending,
  partiallySettled,
  settled,
  disputed,
  suspended,
  rejected,
  cancelled,
  closed,
}

extension PartnershipStatusLabel on PartnershipStatus {
  String get label => switch (this) {
    PartnershipStatus.draft => 'Brouillon',
    PartnershipStatus.pendingVerification => 'En attente de vérification',
    PartnershipStatus.pendingContractApproval =>
      'En attente de validation du contrat',
    PartnershipStatus.contractApproved => 'Contrat validé',
    PartnershipStatus.contributionsCommitted => 'Apports engagés',
    PartnershipStatus.analysis => 'Contrôle et analyse',
    PartnershipStatus.transactionInProgress => 'Opération en cours',
    PartnershipStatus.paymentPending => 'Paiement en attente',
    PartnershipStatus.partiallySettled => 'Règlement partiel',
    PartnershipStatus.settled => 'Réglé',
    PartnershipStatus.disputed => 'Contesté',
    PartnershipStatus.suspended => 'Suspendu',
    PartnershipStatus.rejected => 'Refusé',
    PartnershipStatus.cancelled => 'Annulé',
    PartnershipStatus.closed => 'Clôturé',
  };
}

enum ContributionKind { financial, metal, service }

extension ContributionKindLabel on ContributionKind {
  String get label => switch (this) {
    ContributionKind.financial => 'Apport financier',
    ContributionKind.metal => 'Apport en métal',
    ContributionKind.service => 'Prestation',
  };
}

enum RemunerationMethod {
  contractualProfitShares,
  financialContributionRatio,
  fixedCommission,
  saleAmountCommission,
  netProfitCommission,
  managementFeeAndRemainder,
}

enum PartnershipLoanDirection { companyBorrows, companyLends }

extension PartnershipLoanDirectionLabel on PartnershipLoanDirection {
  String get label => switch (this) {
    PartnershipLoanDirection.companyBorrows => 'L’entreprise emprunte',
    PartnershipLoanDirection.companyLends => 'L’entreprise prête',
  };
}

extension RemunerationMethodLabel on RemunerationMethod {
  String get label => switch (this) {
    RemunerationMethod.contractualProfitShares =>
      'Pourcentages définis au contrat',
    RemunerationMethod.financialContributionRatio =>
      'Répartition selon les apports financiers',
    RemunerationMethod.fixedCommission => 'Commission fixe',
    RemunerationMethod.saleAmountCommission =>
      'Commission sur le montant de vente',
    RemunerationMethod.netProfitCommission => 'Commission sur le bénéfice net',
    RemunerationMethod.managementFeeAndRemainder =>
      'Rémunération de gestion et partage du solde',
  };
}

class PartnershipLoan {
  const PartnershipLoan({
    required this.id,
    required this.reference,
    required this.partnerName,
    required this.direction,
    required this.principalXaf,
    required this.dueAt,
    required this.note,
    required this.createdAt,
    required this.createdBy,
    required this.repayments,
    this.partnerId,
    this.evidenceBytes,
    this.evidenceName,
  });

  final int? id;
  final int? partnerId;
  final String reference;
  final String partnerName;
  final PartnershipLoanDirection direction;
  final int principalXaf;
  final DateTime dueAt;
  final String note;
  final DateTime createdAt;
  final String createdBy;
  final List<PartnershipRepayment> repayments;
  final Uint8List? evidenceBytes;
  final String? evidenceName;

  int get repaidXaf =>
      repayments.fold(0, (total, repayment) => total + repayment.amountXaf);

  int get remainingXaf => principalXaf - repaidXaf;
}

class PartnershipRepayment {
  const PartnershipRepayment({
    required this.amountXaf,
    required this.paidAt,
    required this.note,
    required this.createdBy,
    this.evidenceBytes,
    this.evidenceName,
  });

  final int amountXaf;
  final DateTime paidAt;
  final String note;
  final String createdBy;
  final Uint8List? evidenceBytes;
  final String? evidenceName;
}

class Partner {
  const Partner({
    required this.id,
    required this.name,
    required this.createdAt,
    this.phone = '',
    this.city = '',
    this.email = '',
    this.isActive = true,
    this.type = 'Investisseur',
  });

  final int? id;
  final String name;
  final String phone;
  final String city;
  final String email;
  final DateTime createdAt;
  final bool isActive;
  final String type;
}

class GoldAnalysis {
  const GoldAnalysis({
    required this.netWeightGrams,
    required this.purityPercent,
    required this.isProvisional,
    this.analyzedAt,
  });

  final double netWeightGrams;
  final double purityPercent;
  final bool isProvisional;
  final DateTime? analyzedAt;

  double get fineGoldWeightGrams => netWeightGrams * purityPercent / 100;
}

class PartnershipContribution {
  const PartnershipContribution({
    required this.kind,
    required this.isValidated,
    this.amountXaf,
    this.grossWeightGrams,
    this.netWeightGrams,
    this.purityPercent,
    this.purityIsProvisional = true,
    this.purityAnalyzedAt,
    this.serviceDescription,
  });

  final ContributionKind kind;
  final bool isValidated;
  final int? amountXaf;
  final double? grossWeightGrams;
  final double? netWeightGrams;
  final double? purityPercent;
  final bool purityIsProvisional;
  final DateTime? purityAnalyzedAt;
  final String? serviceDescription;

  double get fineGoldWeightGrams =>
      (netWeightGrams ?? 0) * (purityPercent ?? 0) / 100;
}

class PartnershipMember {
  const PartnershipMember({
    required this.name,
    required this.role,
    required this.profitSharePercent,
    required this.contributions,
    this.partnerId,
    this.phone = '',
    this.city = '',
    this.email = '',
    this.isCompany = false,
  });

  final int? partnerId;
  final String name;
  final String role;
  final String phone;
  final String city;
  final String email;
  final double? profitSharePercent;
  final bool isCompany;
  final List<PartnershipContribution> contributions;

  double get validatedFinancialContributionXaf => contributions
      .where(
        (contribution) =>
            contribution.kind == ContributionKind.financial &&
            contribution.isValidated,
      )
      .fold(
        0.0,
        (total, contribution) =>
            total + (contribution.amountXaf?.toDouble() ?? 0),
      );

  double get validatedMetalWeightGrams => contributions
      .where(
        (contribution) =>
            contribution.kind == ContributionKind.metal &&
            contribution.isValidated,
      )
      .fold(
        0,
        (total, contribution) => total + (contribution.netWeightGrams ?? 0),
      );
}

class Partnership {
  const Partnership({
    required this.id,
    required this.reference,
    required this.scenario,
    required this.status,
    required this.remunerationMethod,
    required this.note,
    required this.createdAt,
    required this.members,
    this.remunerationValue,
    this.analysisBefore,
    this.analysisAfter,
  });

  final int? id;
  final String reference;
  final PartnershipScenario scenario;
  final PartnershipStatus status;
  final RemunerationMethod remunerationMethod;
  final double? remunerationValue;
  final String note;
  final DateTime createdAt;
  final List<PartnershipMember> members;
  final GoldAnalysis? analysisBefore;
  final GoldAnalysis? analysisAfter;

  double get validatedFinancialContributionsXaf => members.fold(
    0,
    (total, member) => total + member.validatedFinancialContributionXaf,
  );

  double? financialContributionPercent(PartnershipMember member) {
    final total = validatedFinancialContributionsXaf;
    if (total <= 0) return null;
    return member.validatedFinancialContributionXaf / total * 100;
  }

  double get validatedFineGoldWeightGrams => members
      .expand((member) => member.contributions)
      .where(
        (contribution) =>
            contribution.kind == ContributionKind.metal &&
            contribution.isValidated &&
            !contribution.purityIsProvisional,
      )
      .fold(
        0,
        (total, contribution) => total + contribution.fineGoldWeightGrams,
      );

  double get provisionalFineGoldWeightGrams => members
      .expand((member) => member.contributions)
      .where(
        (contribution) =>
            contribution.kind == ContributionKind.metal &&
            contribution.isValidated &&
            contribution.purityIsProvisional,
      )
      .fold(
        0,
        (total, contribution) => total + contribution.fineGoldWeightGrams,
      );

  double? get meltWeightDifferenceGrams {
    final before = analysisBefore;
    final after = analysisAfter;
    if (before == null || after == null) return null;
    return before.netWeightGrams - after.netWeightGrams;
  }
}
