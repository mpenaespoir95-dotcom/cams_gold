import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final transferCount = store.operations
        .where((entry) => entry.isTransfer)
        .length;
    final income = store.operations
        .where((entry) => entry.isIncome && !entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final expenses = store.operations
        .where((entry) => !entry.isIncome && !entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final transfers = store.operations
        .where((entry) => entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(eyebrow: 'Gestion · Synthèse', title: 'Rapports'),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Rapport d’activité',
                icon: Icons.summarize_outlined,
              ),
              const SizedBox(height: 6),
              Text(
                'Synthèse des opérations, des registres et de la trésorerie.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 600 ? 3 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: width,
                        child: _ReportMetric(
                          label: 'Trésorerie totale',
                          value: '${money(store.totalTreasury)} FCFA',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _ReportMetric(
                          label: 'Entrées enregistrées',
                          value: '${money(income)} FCFA',
                          icon: Icons.south_west,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _ReportMetric(
                          label: 'Sorties enregistrées',
                          value: '${money(expenses)} FCFA',
                          icon: Icons.north_east,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Virements exclus des totaux d’entrées et de sorties : '
                '${money(transfers)} FCFA.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${store.operations.length} opérations · '
                '${store.purchases.length} achats · '
                '${store.sales.length} ventes · '
                '${store.exchanges.length} échanges · '
                '$transferCount ${transferCount == 1 ? 'virement' : 'virements'} '
                '(hors entrées/sorties)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Imprimer le rapport',
                icon: Icons.print_outlined,
                onPressed: () => _printReport(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                'Détail des opérations',
                icon: Icons.receipt_long_outlined,
                trailing: Text(
                  '${store.operations.length} entrées',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (store.operations.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Aucune opération enregistrée.'),
                )
              else
                ...store.operations.map(
                  (entry) => _OperationLine(entry: entry),
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
                'Soldes par compte',
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 8),
              ...store.bankBalances.entries.map(
                (account) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text(account.key)),
                      Text(
                        '${money(account.value)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _printReport(BuildContext context) async {
    final issuedAt = DateTime.now();
    final income = store.operations
        .where((entry) => entry.isIncome && !entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final expenses = store.operations
        .where((entry) => !entry.isIncome && !entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final transfers = store.operations
        .where((entry) => entry.isTransfer)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Text(
            "COMPTOIR D'OR · RAPPORT",
            style: pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Rapport d’activité',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Édité le ${_dateTime(issuedAt)}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'SYNTHÈSE FINANCIÈRE',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown700,
            ),
          ),
          pw.SizedBox(height: 8),
          _pdfSummaryTable(income, expenses, transfers),
          pw.SizedBox(height: 18),
          pw.Text(
            'TRÉSORERIE PAR COMPTE',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown700,
            ),
          ),
          pw.SizedBox(height: 8),
          _pdfTable(
            ['Compte', 'Solde'],
            [
              for (final entry in store.bankBalances.entries)
                [entry.key, '${money(entry.value)} FCFA'],
              ['Total trésorerie', '${money(store.totalTreasury)} FCFA'],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'REGISTRES',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown700,
            ),
          ),
          pw.SizedBox(height: 8),
          _pdfTable(
            ['Registre', 'Nombre d’entrées'],
            [
              ['Opérations', '${store.operations.length}'],
              ['Achats', '${store.purchases.length}'],
              ['Ventes', '${store.sales.length}'],
              ['Échanges', '${store.exchanges.length}'],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'DÉTAIL DES OPÉRATIONS',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.brown700,
            ),
          ),
          pw.SizedBox(height: 8),
          if (store.operations.isEmpty)
            pw.Text('Aucune opération enregistrée.')
          else
            _pdfTable(
              ['Date', 'Type', 'Détail', 'Montant'],
              [
                for (final entry in store.operations)
                  [
                    entry.date,
                    entry.title,
                    entry.subtitle,
                    '${money(entry.amount)} FCFA',
                  ],
              ],
            ),
          pw.SizedBox(height: 12),
          _pdfRegisterSection(
            'ACHATS',
            store.purchases.map(_purchaseReportEntry).toList(),
          ),
          _pdfRegisterSection('VENTES', store.sales),
          _pdfRegisterSection('ÉCHANGES', store.exchanges),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => document.save(),
        name: 'rapport-activite-${_fileDate(issuedAt)}.pdf',
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’imprimer le rapport : $error')),
        );
      }
    }
  }

  pw.Widget _pdfSummaryTable(
    double income,
    double expenses,
    double transfers,
  ) => _pdfTable(
    ['Indicateur', 'Montant'],
    [
      ['Entrées enregistrées', '${money(income)} FCFA'],
      ['Sorties enregistrées', '${money(expenses)} FCFA'],
      ['Virements (hors entrées/sorties)', '${money(transfers)} FCFA'],
      ['Trésorerie totale', '${money(store.totalTreasury)} FCFA'],
    ],
  );

  pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );
  }

  pw.Widget _pdfRegisterSection(String title, List<String> entries) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$title (${entries.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (entries.isEmpty)
            pw.Text('Aucune entrée')
          else
            ...entries.map(
              (entry) => pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  '• $entry',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _purchaseReportEntry(PurchaseRecord purchase) {
    final rate = purchase.usdToXafRate;
    final rateText = rate == null
        ? 'taux USD/XAF non disponible'
        : '1 USD = ${_formatRate(rate)} XAF'
              '${purchase.rateObservedAt == null ? '' : ' (relevé le ${_dateTime(purchase.rateObservedAt!)})'}';
    return '${purchase.description} · $rateText';
  }

  static String _formatRate(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static String _fileDate(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationLine extends StatelessWidget {
  const _OperationLine({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(
            entry.isIncome ? Icons.south_west : Icons.north_east,
            color: entry.isIncome ? AppTheme.green : AppTheme.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.date} · ${entry.subtitle}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${money(entry.amount)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
