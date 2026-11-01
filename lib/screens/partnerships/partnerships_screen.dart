import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../models/partnership_models.dart';
import '../../services/partnership_repository.dart';
import '../../shared/widgets/app_widgets.dart';

class PartnershipsScreen extends StatefulWidget {
  const PartnershipsScreen({super.key, required this.store, this.repository});
  final AppStore store;
  final PartnershipRepository? repository;
  @override
  State<PartnershipsScreen> createState() => _PartnershipsScreenState();
}

class _PartnershipsScreenState extends State<PartnershipsScreen> {
  final _search = TextEditingController();
  final _loanAmount = TextEditingController();
  final _loanNote = TextEditingController();
  late final PartnershipRepository _repository =
      widget.repository ?? PartnershipRepository();
  final _imagePicker = ImagePicker();
  List<Partnership> _partnerships = const [];
  List<Partner> _partners = const [];
  List<PartnershipLoan> _loans = const [];
  int? _selectedLoanPartnerId;
  int? _viewedPartnerId;
  int _partnerTabIndex = 0;
  Uint8List? _loanEvidenceBytes;
  String? _loanEvidenceName;
  PartnershipLoanDirection _loanDirection =
      PartnershipLoanDirection.companyBorrows;
  DateTime? _loanDueAt;
  PartnershipStatus? _statusFilter;
  bool _isLoading = true;
  bool _isSavingLoan = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _loadPartnerships();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    _loanAmount.dispose();
    _loanNote.dispose();
    unawaited(_repository.close());
    super.dispose();
  }

  List<Partnership> get _visiblePartnerships {
    final query = _search.text.trim().toLowerCase();
    return _partnerships
        .where((partnership) {
          if (_statusFilter != null && partnership.status != _statusFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return partnership.reference.toLowerCase().contains(query) ||
              partnership.scenario.label.toLowerCase().contains(query) ||
              partnership.status.label.toLowerCase().contains(query) ||
              partnership.note.toLowerCase().contains(query) ||
              partnership.members.any(
                (member) =>
                    member.name.toLowerCase().contains(query) ||
                    member.role.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
  }

  void _refresh([String? _]) {
    if (mounted) setState(() {});
  }

  Future<void> _loadPartnerships() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final partnerships = await _repository.loadPartnerships();
      final loans = await _repository.loadLoans();
      final partners = await _repository.loadPartners();
      final allPartners =
          [
            ...partners,
            ..._partners.where(
              (existing) =>
                  !partners.any((partner) => partner.id == existing.id),
            ),
          ]..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
      if (!mounted) return;
      widget.store.replacePartnerships(partnerships.map(_summary));
      setState(() {
        _partnerships = partnerships;
        _partners = allPartners;
        _loans = loans;
        if (!_partners.any((partner) => partner.id == _viewedPartnerId)) {
          _viewedPartnerId = _partners.firstOrNull?.id;
        }
        if (!_partners.any((partner) => partner.id == _selectedLoanPartnerId)) {
          _selectedLoanPartnerId = _partners.firstOrNull?.id;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(
          eyebrow: 'Comptoir · Partenaires',
          title: 'Partenariats',
        ),
        _buildPartnerWorkspace(context),
        const SizedBox(height: 16),
        _buildLoanRegister(context),
        const SizedBox(height: 16),
        _buildRegister(context),
      ],
    );
  }

  Widget _buildPartnerWorkspace(BuildContext context) {
    final selected =
        _partners
            .where((partner) => partner.id == _viewedPartnerId)
            .firstOrNull ??
        _partners.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final directory = _buildPartnerDirectory(context);
        final details = selected == null
            ? AppPanel(
                child: SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      _partners.isEmpty
                          ? 'Créez une fiche partenaire pour commencer.'
                          : 'Sélectionnez un partenaire pour consulter son dossier.',
                    ),
                  ),
                ),
              )
            : _buildPartnerDetails(context, selected);
        if (!wide) {
          return Column(
            children: [directory, const SizedBox(height: 12), details],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 270, child: directory),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }

  Widget _buildPartnerDirectory(BuildContext context) => AppPanel(
    padding: 14,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'Partenaires',
          icon: Icons.people_outline,
          trailing: IconButton(
            tooltip: 'Créer une fiche partenaire',
            onPressed: _createPartner,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ),
        const SizedBox(height: 8),
        if (_partners.isEmpty)
          const Text('Aucun partenaire enregistré.')
        else
          for (final partner in _partners)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color:
                    (_viewedPartnerId ?? _partners.firstOrNull?.id) ==
                        partner.id
                    ? AppTheme.gold.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _viewedPartnerId = partner.id;
                    _partnerTabIndex = 0;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.forest.withValues(
                            alpha: 0.08,
                          ),
                          foregroundColor: AppTheme.forest,
                          child: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partner.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                partner.type,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    ),
  );

  Widget _buildPartnerDetails(BuildContext context, Partner partner) {
    final partnerLoans = _loans
        .where((loan) => loan.partnerId == partner.id)
        .toList(growable: false);
    final entrustedAmount = _partnerships
        .expand((partnership) => partnership.members)
        .where((member) => !member.isCompany && member.partnerId == partner.id)
        .fold<double>(
          0,
          (sum, member) => sum + member.validatedFinancialContributionXaf,
        );
    final loanAmount = partnerLoans.fold<int>(
      0,
      (sum, loan) =>
          sum +
          (loan.direction == PartnershipLoanDirection.companyBorrows
              ? loan.remainingXaf
              : 0),
    );
    final repaidAmount = partnerLoans.fold<int>(
      0,
      (sum, loan) => sum + loan.repaidXaf,
    );
    final tabs = [
      'Résumé',
      'Apports',
      'Emprunts',
      'Mouvements',
      'Pièces jointes',
    ];
    return AppPanel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.forest.withValues(alpha: 0.08),
                foregroundColor: AppTheme.forest,
                child: const Icon(Icons.person_outline, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${partner.type}  ·  '
                      '${[partner.phone, partner.city].where((value) => value.isNotEmpty).join('  ·  ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var index = 0; index < tabs.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(tabs[index]),
                      selected: _partnerTabIndex == index,
                      selectedColor: AppTheme.gold.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: _partnerTabIndex == index
                            ? AppTheme.forest
                            : AppTheme.muted,
                        fontWeight: _partnerTabIndex == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: _partnerTabIndex == index
                            ? AppTheme.gold
                            : AppTheme.border,
                      ),
                      onSelected: (_) =>
                          setState(() => _partnerTabIndex = index),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_partnerTabIndex == 0) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                final width =
                    (constraints.maxWidth - 8 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: width,
                      child: _PartnerMetric(
                        label: 'Apports',
                        value: '${money(entrustedAmount)} FCFA',
                        color: AppTheme.green,
                        icon: Icons.savings_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _PartnerMetric(
                        label: 'Dettes',
                        value: '${money(loanAmount.toDouble())} FCFA',
                        color: AppTheme.forest,
                        icon: Icons.account_balance_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _PartnerMetric(
                        label: 'Remboursements',
                        value: '${money(repaidAmount.toDouble())} FCFA',
                        color: const Color(0xFFB36B13),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _PartnerMetric(
                        label: 'Solde dû',
                        value: '${money(loanAmount.toDouble())} FCFA',
                        color: AppTheme.gold,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _buildPartnerMovements(partner),
          ] else if (_partnerTabIndex == 1) ...[
            _buildPartnerContributions(partner),
          ] else if (_partnerTabIndex == 2) ...[
            if (partnerLoans.isEmpty)
              const Text('Aucun emprunt ou prêt enregistré pour ce partenaire.')
            else
              ...partnerLoans.map(_buildLoanCard),
          ] else if (_partnerTabIndex == 3) ...[
            _buildPartnerMovements(partner),
          ] else ...[
            _buildPartnerEvidence(partner),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerMovements(Partner partner) {
    final contributions = _partnerships
        .where(
          (partnership) => partnership.members.any(
            (member) => !member.isCompany && member.partnerId == partner.id,
          ),
        )
        .toList(growable: false);
    final loans = _loans
        .where((loan) => loan.partnerId == partner.id)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Derniers mouvements', icon: Icons.swap_vert),
        const SizedBox(height: 8),
        if (contributions.isEmpty && loans.isEmpty)
          const Text('Aucun mouvement enregistré.')
        else ...[
          for (final partnership in contributions)
            _PartnerMovementLine(
              date: _date(partnership.createdAt),
              label: 'Apport · ${partnership.reference}',
              amount:
                  '${money(partnership.members.where((member) => !member.isCompany && member.partnerId == partner.id).fold<double>(0, (total, member) => total + member.validatedFinancialContributionXaf))} FCFA',
              color: AppTheme.green,
            ),
          for (final loan in loans)
            _PartnerMovementLine(
              date: _date(loan.createdAt),
              label: loan.direction == PartnershipLoanDirection.companyBorrows
                  ? 'Emprunt'
                  : 'Prêt accordé',
              amount: '${money(loan.principalXaf.toDouble())} FCFA',
              color: AppTheme.forest,
            ),
          for (final loan in loans)
            for (final repayment in loan.repayments)
              _PartnerMovementLine(
                date: _date(repayment.paidAt),
                label: loan.direction == PartnershipLoanDirection.companyBorrows
                    ? 'Remboursement'
                    : 'Remboursement reçu',
                amount: '${money(repayment.amountXaf.toDouble())} FCFA',
                color: const Color(0xFFB36B13),
              ),
        ],
      ],
    );
  }

  Widget _buildPartnerContributions(Partner partner) {
    final rows = <Widget>[];
    for (final partnership in _partnerships) {
      for (final member in partnership.members.where(
        (member) => !member.isCompany && member.partnerId == partner.id,
      )) {
        for (final contribution in member.contributions) {
          rows.add(
            _PartnerMovementLine(
              date: _date(partnership.createdAt),
              label: switch (contribution.kind) {
                ContributionKind.financial => 'Apport financier',
                ContributionKind.metal => 'Apport en or',
                ContributionKind.service => 'Prestation',
              },
              amount: contribution.kind == ContributionKind.financial
                  ? '${money((contribution.amountXaf ?? 0).toDouble())} FCFA'
                  : contribution.kind == ContributionKind.metal
                  ? '${_weight(contribution.netWeightGrams ?? 0)} g d’or'
                  : contribution.serviceDescription ?? 'Prestation',
              color: contribution.isValidated ? AppTheme.green : AppTheme.muted,
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          'Apports enregistrés',
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Text('Aucun apport enregistré.') else ...rows,
      ],
    );
  }

  Widget _buildPartnerEvidence(Partner partner) {
    final loans = _loans.where((loan) => loan.partnerId == partner.id);
    final evidenceRows = <Widget>[];
    for (final loan in loans) {
      if (loan.evidenceBytes != null) {
        evidenceRows.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined, color: AppTheme.forest),
            title: Text(loan.evidenceName ?? 'Justificatif du prêt'),
            subtitle: Text(loan.reference),
            trailing: IconButton(
              tooltip: 'Afficher la pièce jointe',
              onPressed: () => _showEvidence(
                loan.evidenceBytes!,
                loan.evidenceName ?? 'Justificatif du prêt',
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
          ),
        );
      }
      for (final repayment in loan.repayments) {
        if (repayment.evidenceBytes != null) {
          evidenceRows.add(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined, color: AppTheme.forest),
              title: Text(
                repayment.evidenceName ?? 'Justificatif du remboursement',
              ),
              subtitle: Text('${loan.reference} · ${_date(repayment.paidAt)}'),
              trailing: IconButton(
                tooltip: 'Afficher la pièce jointe',
                onPressed: () => _showEvidence(
                  repayment.evidenceBytes!,
                  repayment.evidenceName ?? 'Justificatif du remboursement',
                ),
                icon: const Icon(Icons.visibility_outlined),
              ),
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Pièces jointes', icon: Icons.attach_file),
        if (evidenceRows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Aucune pièce justificative associée.'),
          )
        else
          ...evidenceRows,
      ],
    );
  }

  Future<void> _createPartner() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final city = TextEditingController();
    final email = TextEditingController();
    var type = 'Investisseur';
    try {
      final draft = await showDialog<Partner>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
            title: Row(
              children: [
                const Expanded(child: Text('Nouvelle fiche partenaire')),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Builder(
                builder: (context) {
                  final narrow = MediaQuery.sizeOf(context).width < 760;
                  final generalInfo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        'Informations générales',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: fieldDecoration('Nom du partenaire *'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        decoration: fieldDecoration('Type de partenaire'),
                        items:
                            const [
                                  'Investisseur',
                                  'Prêteur',
                                  'Partenaire commercial',
                                  'Prestataire',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => type = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: fieldDecoration('Téléphone'),
                      ),
                    ],
                  );
                  final contactInfo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        'Coordonnées et informations complémentaires',
                        icon: Icons.contact_mail_outlined,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: city,
                        decoration: fieldDecoration('Adresse / ville'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: fieldDecoration('Adresse e-mail'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Text(
                          'Les apports, emprunts et pièces justificatives '
                          'seront ajoutés au dossier du partenaire après '
                          'la création de sa fiche.',
                          style: TextStyle(color: AppTheme.forest),
                        ),
                      ),
                    ],
                  );
                  if (narrow) {
                    return Column(
                      children: [
                        generalInfo,
                        const SizedBox(height: 18),
                        contactInfo,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: generalInfo),
                      const SizedBox(width: 14),
                      Expanded(child: contactInfo),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.forest,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    Partner(
                      id: null,
                      name: name.text.trim(),
                      type: type,
                      phone: phone.text.trim(),
                      city: city.text.trim(),
                      email: email.text.trim(),
                      createdAt: DateTime.now(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
      if (draft == null) return;
      final partner = await _repository.createPartner(draft);
      if (!mounted) return;
      setState(() {
        _partners = [..._partners, partner]
          ..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
        _selectedLoanPartnerId = partner.id;
        _viewedPartnerId = partner.id;
        _partnerTabIndex = 0;
      });
      _message('Fiche partenaire créée.');
    } catch (error) {
      if (mounted) _message('Impossible de créer la fiche partenaire : $error');
    } finally {
      name.dispose();
      phone.dispose();
      city.dispose();
      email.dispose();
    }
  }

  Future<void> _pickLoanEvidence() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _loanEvidenceBytes = bytes;
        _loanEvidenceName = image.name;
      });
    } catch (error) {
      if (mounted) {
        _message('Impossible de joindre la pièce justificative : $error');
      }
    }
  }

  Future<void> _showEvidence(Uint8List bytes, String name) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanRegister(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            'Emprunts et remboursements',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 6),
          Text(
            'Les emprunts sont des dettes à rembourser ; les prêts accordés '
            'sont des créances. Les mouvements ne modifient pas la caisse.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _selectedLoanPartnerId,
            isExpanded: true,
            decoration: fieldDecoration('Fiche partenaire'),
            items: _partners
                .where((partner) => partner.id != null)
                .map(
                  (partner) => DropdownMenuItem(
                    value: partner.id!,
                    child: Text(partner.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _selectedLoanPartnerId = value;
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<PartnershipLoanDirection>(
            initialValue: _loanDirection,
            isExpanded: true,
            decoration: fieldDecoration('Sens du prêt'),
            items: PartnershipLoanDirection.values
                .map(
                  (direction) => DropdownMenuItem(
                    value: direction,
                    child: Text(direction.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _loanDirection = value);
            },
          ),
          const SizedBox(height: 10),
          _NumberField(
            label: 'Montant du principal (FCFA entiers)',
            controller: _loanAmount,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _chooseLoanDueDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _loanDueAt == null
                  ? 'Choisir l’échéance'
                  : 'Échéance : ${_date(_loanDueAt!)}',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _loanNote,
            minLines: 2,
            maxLines: 3,
            decoration: fieldDecoration('Note ou conditions du prêt'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickLoanEvidence,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _loanEvidenceName ?? 'Joindre une photo du justificatif',
            ),
          ),
          if (_loanEvidenceBytes != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _loanEvidenceBytes = null;
                  _loanEvidenceName = null;
                }),
                child: const Text('Retirer la pièce jointe'),
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _isSavingLoan ? 'Enregistrement…' : 'Enregistrer le prêt',
            icon: Icons.save_outlined,
            onPressed: _isSavingLoan || _partners.isEmpty ? null : _saveLoan,
          ),
          const Divider(height: 28),
          if (_loans.isEmpty)
            const Text('Aucun prêt ou remboursement enregistré.')
          else
            ..._loans.map(_buildLoanCard),
        ],
      ),
    );
  }

  Widget _buildLoanCard(PartnershipLoan loan) {
    final today = DateTime.now();
    final isOverdue =
        loan.remainingXaf > 0 &&
        DateTime(
          loan.dueAt.year,
          loan.dueAt.month,
          loan.dueAt.day,
        ).isBefore(DateTime(today.year, today.month, today.day));
    final balanceLabel =
        loan.direction == PartnershipLoanDirection.companyBorrows
        ? 'Dette restante'
        : 'Créance restante';
    final repaymentLabel =
        loan.direction == PartnershipLoanDirection.companyBorrows
        ? 'Remboursement versé'
        : 'Remboursement reçu';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${loan.reference} · ${loan.partnerName}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${loan.direction.label} · échéance ${_date(loan.dueAt)}'
            '${isOverdue ? ' · EN RETARD' : ''}',
            style: TextStyle(color: isOverdue ? AppTheme.red : null),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Principal : ${money(loan.principalXaf.toDouble())} FCFA'),
              Text('Remboursé : ${money(loan.repaidXaf.toDouble())} FCFA'),
              Text(
                '$balanceLabel : ${money(loan.remainingXaf.toDouble())} FCFA',
              ),
            ],
          ),
          if (loan.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(loan.note),
          ],
          if (loan.evidenceBytes != null)
            TextButton.icon(
              onPressed: () => _showEvidence(
                loan.evidenceBytes!,
                loan.evidenceName ?? 'Justificatif du prêt',
              ),
              icon: const Icon(Icons.image_outlined),
              label: Text(loan.evidenceName ?? 'Voir le justificatif'),
            ),
          Text(
            'Saisi par ${loan.createdBy} · ${_date(loan.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (loan.repayments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final repayment in loan.repayments)
              Text(
                '$repaymentLabel ${money(repayment.amountXaf.toDouble())} FCFA · '
                '${_date(repayment.paidAt)} · ${repayment.createdBy}'
                '${repayment.note.isEmpty ? '' : ' · ${repayment.note}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            for (final repayment in loan.repayments.where(
              (repayment) => repayment.evidenceBytes != null,
            ))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showEvidence(
                    repayment.evidenceBytes!,
                    repayment.evidenceName ?? 'Justificatif du remboursement',
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    'Justificatif du remboursement · '
                    '${_date(repayment.paidAt)}',
                  ),
                ),
              ),
          ],
          if (loan.remainingXaf > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _recordLoanRepayment(loan),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Enregistrer un remboursement'),
              ),
            )
          else
            const Text('Prêt soldé.'),
        ],
      ),
    );
  }

  Future<void> _chooseLoanDueDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _loanDueAt ?? today,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 30),
    );
    if (selected != null) setState(() => _loanDueAt = selected);
  }

  Future<void> _saveLoan() async {
    final partner = _partners
        .where((entry) => entry.id == _selectedLoanPartnerId)
        .firstOrNull;
    double? principal;
    try {
      principal = _parseOptional(_loanAmount, 'Montant du prêt');
    } on FormatException catch (error) {
      _message(error.message);
      return;
    }
    final dueAt = _loanDueAt;
    if (partner == null ||
        principal == null ||
        principal <= 0 ||
        principal % 1 != 0 ||
        dueAt == null) {
      _message(
        'Choisissez une fiche partenaire, un principal entier positif et une échéance.',
      );
      return;
    }
    setState(() => _isSavingLoan = true);
    try {
      final loan = await _repository.createLoan(
        PartnershipLoan(
          id: null,
          reference: '',
          partnerId: partner.id,
          partnerName: partner.name,
          direction: _loanDirection,
          principalXaf: principal.toInt(),
          dueAt: dueAt,
          note: _loanNote.text.trim(),
          createdAt: DateTime.now(),
          createdBy: widget.store.userName,
          repayments: const [],
          evidenceBytes: _loanEvidenceBytes,
          evidenceName: _loanEvidenceName,
        ),
      );
      if (!mounted) return;
      setState(() {
        _loans = [loan, ..._loans];
        _isSavingLoan = false;
      });
      _loanAmount.clear();
      _loanNote.clear();
      _loanEvidenceBytes = null;
      _loanEvidenceName = null;
      setState(() => _loanDueAt = null);
      _message('${loan.reference} enregistré.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingLoan = false);
      _message('Impossible d’enregistrer le prêt : $error');
    }
  }

  Future<void> _recordLoanRepayment(PartnershipLoan loan) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    Uint8List? evidenceBytes;
    String? evidenceName;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Remboursement · ${loan.reference}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Partenaire : ${loan.partnerName}\n'
                  'Solde restant : ${money(loan.remainingXaf.toDouble())} FCFA',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration(
                    'Montant remboursé (FCFA entiers)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: fieldDecoration('Note du mouvement'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final image = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        maxHeight: 1600,
                        imageQuality: 80,
                      );
                      if (image == null) return;
                      evidenceBytes = await image.readAsBytes();
                      evidenceName = image.name;
                      setDialogState(() {});
                    } catch (error) {
                      if (mounted) {
                        _message(
                          'Impossible de joindre la pièce justificative : $error',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    evidenceName ?? 'Joindre une photo du justificatif',
                  ),
                ),
                if (evidenceBytes != null)
                  TextButton(
                    onPressed: () => setDialogState(() {
                      evidenceBytes = null;
                      evidenceName = null;
                    }),
                    child: const Text('Retirer la pièce jointe'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      amount.dispose();
      note.dispose();
      return;
    }
    final value = double.tryParse(
      amount.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (value == null || !value.isFinite || value <= 0 || value % 1 != 0) {
      _message('Saisissez un montant entier positif.');
      amount.dispose();
      note.dispose();
      return;
    }
    try {
      final updated = await _repository.addLoanRepayment(
        loanId: loan.id!,
        amountXaf: value.toInt(),
        note: note.text,
        createdBy: widget.store.userName,
        evidenceBytes: evidenceBytes,
        evidenceName: evidenceName,
      );
      if (!mounted) return;
      setState(() {
        _loans = _loans
            .map((entry) => entry.id == updated.id ? updated : entry)
            .toList(growable: false);
      });
      _message('Remboursement enregistré.');
    } catch (error) {
      if (mounted) {
        _message('Impossible d’enregistrer le remboursement : $error');
      }
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Widget _buildRegister(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            'Registre des partenariats',
            icon: Icons.receipt_long_outlined,
            trailing: IconButton(
              tooltip: 'Actualiser le registre',
              onPressed: _loadPartnerships,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            decoration: fieldDecoration(
              'Rechercher par référence, partenaire, scénario…',
            ).copyWith(prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<PartnershipStatus?>(
            initialValue: _statusFilter,
            isExpanded: true,
            decoration: fieldDecoration('Filtrer par statut'),
            items: [
              const DropdownMenuItem<PartnershipStatus?>(
                value: null,
                child: Text('Tous les statuts'),
              ),
              ...PartnershipStatus.values.map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les partenariats ou les prêts : $_loadError',
              style: const TextStyle(color: AppTheme.red),
            ),
            TextButton(
              onPressed: _loadPartnerships,
              child: const Text('Réessayer'),
            ),
          ],
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_visiblePartnerships.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('Aucun partenariat ne correspond à la recherche.'),
              ),
            )
          else
            ..._visiblePartnerships.map(_buildPartnershipCard),
        ],
      ),
    );
  }

  Widget _buildPartnershipCard(Partnership partnership) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${partnership.reference} · ${partnership.scenario.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusBadge(status: partnership.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            partnership.members
                .map((member) {
                  final financialPercent = partnership
                      .financialContributionPercent(member);
                  final profitShare = member.profitSharePercent;
                  return '${member.name} (${member.role})'
                      '${financialPercent == null ? '' : ' · contribution ${financialPercent.toStringAsFixed(1)} %'}'
                      '${profitShare == null ? '' : ' · bénéfice au contrat ${profitShare.toStringAsFixed(1)} %'}';
                })
                .join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final member in partnership.members.where(
            (member) =>
                !member.isCompany &&
                (member.phone.isNotEmpty ||
                    member.email.isNotEmpty ||
                    member.city.isNotEmpty),
          ))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${member.name} · '
                '${[member.phone, member.city, member.email].where((value) => value.isNotEmpty).join(' · ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (partnership.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(partnership.note),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              Text(
                'Apports financiers confirmés : '
                '${money(partnership.validatedFinancialContributionsXaf)} FCFA',
              ),
              Text(
                'Or fin confirmé : '
                '${_weight(partnership.validatedFineGoldWeightGrams)} g',
              ),
              Text(
                'Or fin provisoire : '
                '${_weight(partnership.provisionalFineGoldWeightGrams)} g',
              ),
              Text('Rémunération : ${partnership.remunerationMethod.label}'),
              if (partnership.analysisBefore != null &&
                  partnership.analysisAfter != null)
                Text(
                  'Écart de poids à justifier : '
                  '${_weight(partnership.meltWeightDifferenceGrams!.abs())} g'
                  '${partnership.meltWeightDifferenceGrams! < 0 ? ' (augmentation)' : ''}',
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Statut : ${partnership.status.label} · '
            '${_date(partnership.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  double? _parseOptional(TextEditingController controller, String label) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    final value = _read(controller);
    if (value == null || !value.isFinite) {
      throw FormatException('$label doit être un nombre valide.');
    }
    if (value < 0) throw FormatException('$label ne peut pas être négatif.');
    return value;
  }

  static double? _read(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(' ', '').replaceAll(',', '.'));

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String _summary(Partnership partnership) =>
      '${partnership.reference} · ${partnership.scenario.label} · '
      '${partnership.status.label}';

  static String _weight(double value) =>
      value.toStringAsFixed(3).replaceAll('.', ',');

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

class _PartnerMetric extends StatelessWidget {
  const _PartnerMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PartnerMovementLine extends StatelessWidget {
  const _PartnerMovementLine({
    required this.date,
    required this.label,
    required this.amount,
    required this.color,
  });

  final String date;
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(date, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          textAlign: TextAlign.end,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: fieldDecoration('0'),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PartnershipStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.gold.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.label,
      style: const TextStyle(
        color: AppTheme.forest,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
