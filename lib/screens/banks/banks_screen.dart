import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  final _search = TextEditingController();
  String? _bank;
  bool _deposit = true;

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    _search.dispose();
    super.dispose();
  }

  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(' ', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.bankBalances.keys.toList();
    final query = _search.text.trim().toLowerCase();
    final operations = widget.store.operations.where((entry) {
      final searchable = '${entry.title} ${entry.subtitle} ${entry.date}'
          .toLowerCase();
      return query.isEmpty || searchable.contains(query);
    }).toList();
    _bank ??= accounts.isEmpty ? null : accounts.first;
    final balance = widget.store.bankBalances[_bank] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        PageHeading(
          eyebrow: 'Trésorerie · Banques',
          title: 'Banques & versements',
        ),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRÉSORERIE TOTALE',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${money(widget.store.totalTreasury)} FCFA',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...accounts.map(
          (account) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _bank = account),
              borderRadius: BorderRadius.circular(18),
              child: AppPanel(
                padding: 16,
                child: Row(
                  children: [
                    Icon(
                      account == 'Caisse (espèces)'
                          ? Icons.payments_outlined
                          : Icons.account_balance_outlined,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${money(widget.store.bankBalances[account]!)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_bank == account) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.gold,
                        size: 19,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _addBank,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une banque'),
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading('Nouveau mouvement', icon: Icons.swap_vert),
              const SizedBox(height: 14),
              const FieldLabel('Compte'),
              DropdownButtonFormField<String>(
                initialValue: _bank,
                decoration: fieldDecoration('Choisir un compte'),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account,
                        child: Text(account),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _bank = value),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Type'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Versement'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Retrait'),
                    icon: Icon(Icons.north_east),
                  ),
                ],
                selected: {_deposit},
                onSelectionChanged: (value) =>
                    setState(() => _deposit = value.first),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Montant (FCFA)'),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('0'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Libellé'),
              TextField(
                controller: _label,
                decoration: fieldDecoration('Ex. dépôt recettes vente Dubaï'),
              ),
              const SizedBox(height: 14),
              Text(
                'Nouveau solde $_bank : ${money(balance + (_deposit ? _amountValue : -_amountValue))} FCFA',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _deposit
                    ? 'Enregistrer le versement'
                    : 'Enregistrer le retrait',
                onPressed: _saveMovement,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Mouvements récents',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                decoration:
                    fieldDecoration(
                      'Rechercher un client, un compte ou une opération',
                    ).copyWith(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer la recherche',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 38,
                  dataRowMinHeight: 42,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Détail')),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Text('Montant', textAlign: TextAlign.right),
                      ),
                    ),
                  ],
                  rows: [
                    for (final entry in operations)
                      DataRow(
                        cells: [
                          DataCell(Text(entry.date)),
                          DataCell(Text(entry.title)),
                          DataCell(Text(entry.subtitle)),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${entry.isIncome ? '+' : '−'} ${money(entry.amount)} FCFA',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: entry.isIncome
                                      ? AppTheme.green
                                      : AppTheme.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (operations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Aucune opération correspondante.'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addBank() async {
    final name = TextEditingController();
    final balance = TextEditingController();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: fieldDecoration('Nom de la banque'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balance,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration('Solde initial (FCFA)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(balance.text.replaceAll(' ', ''));
              if (name.text.trim().isNotEmpty &&
                  parsed != null &&
                  parsed >= 0) {
                Navigator.pop(dialogContext, (name.text.trim(), parsed));
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (result != null) {
      if (widget.store.bankBalances.containsKey(result.$1)) {
        _message('Ce compte existe déjà.');
      } else {
        widget.store.addBank(result.$1, result.$2);
        setState(() => _bank = result.$1);
        _message('Compte bancaire ajouté.');
      }
    }
    name.dispose();
    balance.dispose();
  }

  void _saveMovement() {
    final selectedBank = _bank;
    if (selectedBank == null ||
        _amountValue <= 0 ||
        _label.text.trim().isEmpty) {
      _message('Renseignez le compte, un montant positif et le libellé.');
      return;
    }
    if (!_deposit &&
        _amountValue > (widget.store.bankBalances[selectedBank] ?? 0)) {
      _message('Le retrait dépasse le solde disponible.');
      return;
    }
    final previousBalance = widget.store.bankBalances[selectedBank] ?? 0;
    final amount = _amountValue;
    final label = _label.text.trim();
    final isDeposit = _deposit;
    widget.store.addMovement(selectedBank, amount, isDeposit, label);
    _amount.clear();
    _label.clear();
    setState(() {});
    if (isDeposit) {
      _showDepositReceipt(
        _DepositReceipt(
          account: selectedBank,
          label: label,
          amount: amount,
          previousBalance: previousBalance,
          newBalance: previousBalance + amount,
          issuedAt: DateTime.now(),
        ),
      );
    } else {
      _message('Retrait enregistré.');
    }
  }

  Future<void> _showDepositReceipt(_DepositReceipt receipt) async {
    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Versement enregistré'),
        content: Text(
          'Le versement de ${money(receipt.amount)} FCFA sur '
          '${receipt.account} a bien été enregistré.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimer la fiche'),
          ),
        ],
      ),
    );
    if (shouldPrint == true && mounted) {
      await _printDepositReceipt(receipt);
    }
  }

  Future<void> _printDepositReceipt(_DepositReceipt receipt) async {
    try {
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "COMPTOIR D'OR",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('REÇU DE VERSEMENT'),
              pw.Divider(height: 28),
              _receiptLine('Date', _receiptDate(receipt.issuedAt)),
              _receiptLine('Compte crédité', receipt.account),
              _receiptLine('Libellé', receipt.label),
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                ),
                child: pw.Text(
                  'MONTANT VERSÉ : ${money(receipt.amount)} FCFA',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              _receiptLine(
                'Solde avant versement',
                '${money(receipt.previousBalance)} FCFA',
              ),
              _receiptLine(
                'Solde après versement',
                '${money(receipt.newBalance)} FCFA',
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 28),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Signature du déposant'),
                  pw.Text('Cachet et signature'),
                ],
              ),
            ],
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => document.save(),
        name: 'recu-versement-${receipt.issuedAt.millisecondsSinceEpoch}.pdf',
      );
    } catch (error) {
      if (mounted) {
        _message('Impossible de générer ou imprimer la fiche : $error');
      }
    }
  }

  pw.Widget _receiptLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _receiptDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DepositReceipt {
  const _DepositReceipt({
    required this.account,
    required this.label,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    required this.issuedAt,
  });

  final String account;
  final String label;
  final double amount;
  final double previousBalance;
  final double newBalance;
  final DateTime issuedAt;
}
