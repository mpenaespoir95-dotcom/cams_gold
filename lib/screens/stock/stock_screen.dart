import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Widget _buildCurrencyStock() {
    final currencies = widget.store.currencyBalances.keys.toList()..sort();
    final movements = [...widget.store.currencyStockMovements]
      ..sort((first, second) => second.date.compareTo(first.date));
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeading(
                  'Caisse · stock de devises',
                  icon: Icons.currency_exchange_outlined,
                ),
              ),
          FilledButton.icon(
                onPressed: _showCurrencyCorrection,
                icon: const Icon(Icons.tune),
            label: const Text('Ajuster le stock'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Soldes physiques suivis séparément des comptes bancaires et de la caisse.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (currencies.isEmpty)
            const Text('Aucune devise configurée.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850 ? 4 : 2;
                final spacing = 8.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final currency in currencies)
                      _StockBalanceField(
                        width: width,
                        label: 'Solde $currency',
                        value: _format(
                          widget.store.currencyBalances[currency]!,
                        ),
                        suffix: currency,
                      ),
                  ],
                );
              },
            ),
          const Divider(height: 24),
          const Text(
            'Mouvements récents',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Aucun mouvement de devise enregistré.'),
            )
          else
            ...movements
                .take(10)
                .map(
                  (movement) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${movement.type} · ${movement.currency} · '
                      '${movement.amount > 0 ? '+' : ''}${_format(movement.amount)}',
                    ),
                    subtitle: Text(
                      '${_dateTime(movement.date)} · ${movement.label}',
                    ),
                    trailing: Text(movement.currency),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showCurrencyCorrection() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final currencies = widget.store.currencyBalances.keys.toList()..sort();
    var selectedCurrency = currencies.contains('USD')
        ? 'USD'
        : currencies.first;
    var isAddition = true;
    try {
      final adjustment = await showDialog<(String, double, bool, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Ajuster le stock de devises'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCurrency,
                    decoration: fieldDecoration('Devise'),
                    items: currencies
                        .map(
                          (currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => selectedCurrency = value ?? selectedCurrency,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Ajouter'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Retirer'),
                        icon: Icon(Icons.remove),
                      ),
                    ],
                    selected: {isAddition},
                    onSelectionChanged: (selection) =>
                        setDialogState(() => isAddition = selection.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldDecoration('Quantité'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: fieldDecoration('Motif obligatoire'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = _number(amountController.text);
                  final reason = reasonController.text.trim();
                  if (amount <= 0 || reason.isEmpty) {
                    _showMessage(
                      'Saisissez une quantité positive et un motif.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    selectedCurrency,
                    amount,
                    isAddition,
                    reason,
                  ));
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
      if (adjustment == null) return;
      widget.store.adjustCurrencyStock(
        currency: adjustment.$1,
        amount: adjustment.$2,
        isAddition: adjustment.$3,
        reason: adjustment.$4,
      );
      if (mounted) setState(() {});
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? 'Ajustement invalide.');
    } finally {
      amountController.dispose();
      reasonController.dispose();
    }
  }

  static const _standardKarats = ['24K', '22K', '21K', '18K', '14K', '9K'];

  List<String> get _karats =>
      {
        ..._standardKarats,
        ...widget.store.purchases
            .where((purchase) => !purchase.isCancelled)
            .map((purchase) => purchase.karat)
            .whereType<String>()
            .where(isValidGoldKarat),
        ...widget.store.stockMovements
            .map((movement) => movement.karat)
            .where(isValidGoldKarat),
      }.toList()..sort(
        (first, second) =>
            goldKaratValue(second)!.compareTo(goldKaratValue(first)!),
      );

  @override
  Widget build(BuildContext context) {
    final stockByKarat = {
      for (final karat in _karats)
        karat: widget.store.stockWeightForKarat(karat),
    };
    final totalWeight = stockByKarat.values.fold<double>(
      0,
      (total, weight) => total + weight,
    );
    final fineGold = _fineGoldStock;
    final movements = _stockHistory..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(
          eyebrow: 'Comptoir · Inventaire',
          title: 'Gestion du stock',
        ),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionHeading(
                      'Résumé du stock d’or',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showStockCorrection,
                    icon: const Icon(Icons.tune),
                    label: const Text('Mettre à jour le stock'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _ReferenceSectionLabel('Réserve · stock d’or'),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 850 ? 4 : 2;
                  const gap = 8.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final karat in _karats)
                        _StockBalanceField(
                          width: width,
                          label: 'Or $karat (g)',
                          value: _format(stockByKarat[karat]!),
                        ),
                      _StockBalanceField(
                        width: width,
                        label: 'Poids net disponible',
                        value: _format(totalWeight),
                        suffix: 'g',
                      ),
                      _StockBalanceField(
                        width: width,
                        label: 'Or fin estimé',
                        value: _format(fineGold),
                        suffix: 'g',
                      ),
                      _StockBalanceField(
                        width: width,
                        label: 'Équivalent Or 999‰',
                        value: _format(fineGold / 0.999),
                        suffix: 'g',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Les soldes sont calculés depuis les achats, les ventes et les corrections enregistrées.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _buildCurrencyStock(),
        const SizedBox(height: 16),
        _buildCategoryBreakdown(),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                'Mouvements de stock',
                icon: Icons.swap_vert_circle_outlined,
                trailing: Text(
                  '${movements.length} mouvements',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (movements.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text('Aucun mouvement de stock enregistré.'),
                )
              else
                ...movements.map(_movementTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          'Détail par catégorie et carat',
          icon: Icons.warehouse_outlined,
        ),
        const SizedBox(height: 8),
        if (widget.store.purchases.isEmpty &&
            widget.store.stockMovements.isEmpty)
          const Text('Aucun stock d’or enregistré.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.paper),
              columns: const [
                DataColumn(label: Text('Catégorie')),
                DataColumn(label: Text('Carat')),
                DataColumn(label: Text('Poids disponible'), numeric: true),
                DataColumn(label: Text('Or fin estimé'), numeric: true),
                DataColumn(label: Text('État')),
              ],
              rows: [
                for (final category in goldStockCategories)
                  for (final karat in _karats)
                    if (widget.store.stockWeightForKarat(
                          karat,
                          category: category,
                        ) !=
                        0)
                      DataRow(
                        cells: [
                          DataCell(Text(category)),
                          DataCell(Text(karat)),
                          DataCell(
                            Text(
                              '${_format(widget.store.stockWeightForKarat(karat, category: category))} g',
                            ),
                          ),
                          DataCell(
                            Text(
                              '${_format(widget.store.stockWeightForKarat(karat, category: category) * _purity(karat))} g',
                            ),
                          ),
                          DataCell(
                            Text(
                              widget.store.stockWeightForKarat(
                                        karat,
                                        category: category,
                                      ) <=
                                      0
                                  ? 'Indisponible'
                                  : 'Disponible',
                              style: TextStyle(
                                color:
                                    widget.store.stockWeightForKarat(
                                          karat,
                                          category: category,
                                        ) <=
                                        0
                                    ? AppTheme.muted
                                    : AppTheme.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
      ],
    ),
  );

  List<_StockHistoryRow> get _stockHistory {
    final rows = <_StockHistoryRow>[
      for (final purchase in widget.store.purchases.where(
        (purchase) => !purchase.isCancelled && purchase.netWeightGrams != null,
      ))
        _StockHistoryRow(
          date: purchase.purchasedAt,
          type: 'Achat',
          label:
              '${purchase.reference ?? 'Achat'} · ${purchase.supplier ?? purchase.description}',
          karat: purchase.karat ?? '—',
          category: purchase.goldCategory,
          weight: purchase.netWeightGrams!,
        ),
      for (final movement in widget.store.stockMovements)
        _StockHistoryRow(
          date: movement.date,
          type: movement.type,
          label: movement.label,
          karat: movement.karat,
          category: movement.category,
          weight: movement.weightGrams,
          reason: movement.reason,
        ),
    ];
    return rows;
  }

  double get _fineGoldStock {
    final purchases = widget.store.purchases
        .where((purchase) => !purchase.isCancelled)
        .fold<double>(
          0,
          (total, purchase) => total + purchase.fineGoldWeightGrams,
        );
    final movements = widget.store.stockMovements.fold<double>(
      0,
      (total, movement) =>
          total + movement.weightGrams * _purity(movement.karat),
    );
    return purchases + movements;
  }

  Widget _movementTile(_StockHistoryRow movement) {
    final incoming = movement.weight > 0;
    final amount = '${incoming ? '+' : ''}${_format(movement.weight)} g';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (incoming ? AppTheme.green : AppTheme.gold)
                .withValues(alpha: 0.12),
            child: Icon(
              incoming ? Icons.south_west : Icons.north_east,
              color: incoming ? AppTheme.green : AppTheme.gold,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${movement.type} · ${movement.category} · ${movement.karat}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_dateTime(movement.date)} · ${movement.label}'
                  '${movement.reason == null ? '' : ' · Motif : ${movement.reason}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: incoming ? AppTheme.green : AppTheme.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStockCorrection() async {
    final weightController = TextEditingController();
    final reasonController = TextEditingController();
    final karats = _karats;
    final categories = goldStockCategories
        .where((category) => category != 'Non catégorisé')
        .toList();
    var selectedKarat = '24K';
    var selectedCategory = 'Or brut';
    var isAddition = true;
    try {
      final correction = await showDialog<(String, String, double, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Corriger le stock'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedKarat,
                    decoration: fieldDecoration('Carat'),
                    items: karats
                        .map(
                          (karat) => DropdownMenuItem(
                            value: karat,
                            child: Text(karat),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => selectedKarat = value ?? selectedKarat,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: fieldDecoration('Catégorie'),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => selectedCategory = value ?? selectedCategory,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Ajouter'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Retirer'),
                        icon: Icon(Icons.remove),
                      ),
                    ],
                    selected: {isAddition},
                    onSelectionChanged: (selection) =>
                        setDialogState(() => isAddition = selection.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldDecoration('Poids en grammes'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: fieldDecoration('Motif obligatoire'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final weight = _number(weightController.text);
                  final reason = reasonController.text.trim();
                  if (weight <= 0 || reason.isEmpty) {
                    _showMessage('Saisissez un poids positif et un motif.');
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    selectedKarat,
                    selectedCategory,
                    isAddition ? weight : -weight,
                    reason,
                  ));
                },
                child: const Text('Enregistrer la correction'),
              ),
            ],
          ),
        ),
      );
      if (correction == null) return;
      widget.store.adjustGoldStock(
        karat: correction.$1,
        category: correction.$2,
        weightGrams: correction.$3,
        reason: correction.$4,
      );
      if (mounted) setState(() {});
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? 'Correction invalide.');
    } finally {
      weightController.dispose();
      reasonController.dispose();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static double _purity(String karat) => goldKaratValue(karat)! / 24;

  static double _number(String value) =>
      double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  static String _format(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _StockHistoryRow {
  const _StockHistoryRow({
    required this.date,
    required this.type,
    required this.label,
    required this.karat,
    required this.category,
    required this.weight,
    this.reason,
  });

  final DateTime date;
  final String type;
  final String label;
  final String karat;
  final String category;
  final double weight;
  final String? reason;
}

class _ReferenceSectionLabel extends StatelessWidget {
  const _ReferenceSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: AppTheme.forest,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    ),
  );
}

class _StockBalanceField extends StatelessWidget {
  const _StockBalanceField({
    required this.width,
    required this.label,
    required this.value,
    this.suffix,
  });

  final double width;
  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.paper,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.forest,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix!,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
