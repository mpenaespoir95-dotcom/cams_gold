import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/gold_price_service.dart';
import '../../shared/widgets/app_widgets.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({
    super.key,
    required this.store,
    this.onFormVisibilityChanged,
  });

  final AppStore store;
  final ValueChanged<bool>? onFormVisibilityChanged;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with WidgetsBindingObserver {
  static const _goldApiKey = String.fromEnvironment('GOLDAPI_KEY');

  final _sellerController = TextEditingController(text: 'Moussa Diakité');
  final _grossWeight = TextEditingController();
  final _nonGoldWeight = TextEditingController(text: '0');
  final _karatController = TextEditingController(text: '22');
  final _manualReferencePrice = TextEditingController();
  final _goldPricePerOunce = TextEditingController();
  final _usdToXafRate = TextEditingController();
  final _search = TextEditingController();
  final _manualDescription = TextEditingController();
  final _manualAmount = TextEditingController();
  final _manualInitialPayment = TextEditingController(text: '0');
  final _manualGrossWeight = TextEditingController();
  final _manualNonGoldWeight = TextEditingController(text: '0');
  final _manualKarat = TextEditingController();
  final _origin = TextEditingController();
  final _notes = TextEditingController();
  final _initialPayment = TextEditingController(text: '0');
  late final GoldPriceService _goldPriceService = GoldPriceService(
    apiKey: _goldApiKey,
  );
  final _exchangeRateService = ExchangeRateService();
  final _imagePicker = ImagePicker();
  Timer? _refreshTimer;
  String _seller = 'Moussa Diakité';
  String? _paymentAccount;
  String _category = 'Or brut';
  final _categories = ['Or brut', 'Or fondu', 'Bijoux', 'Taux Poubelle'];
  GoldPriceQuote? _goldQuote;
  ExchangeRateSnapshot? _exchangeRates;
  String? _marketError;
  bool _isLoadingMarket = false;
  bool _rateWasEnteredManually = false;
  bool _showingForm = false;
  String _purchaseFilter = 'Tous';
  double get _grossValue => _number(_grossWeight.text);
  double get _nonGoldValue => _number(_nonGoldWeight.text);
  double get _netWeight => _grossValue - _nonGoldValue;
  int? get _karatValue => goldKaratValue(_karatController.text);
  String get _karatLabel => '${_karatController.text.trim()}K';
  double get _purityPercent => (_karatValue ?? 0) / 24 * 100;
  double? get _categoryDeduction => switch (_category) {
    'Or brut' => 4500,
    'Or fondu' => 3500,
    'Bijoux' => 7000,
    _ => null,
  };
  double? get _effectiveGoldPricePerOunce {
    if (_goldPricePerOunce.text.trim().isNotEmpty) {
      final manual = _number(_goldPricePerOunce.text);
      return manual.isFinite && manual > 30 ? manual : null;
    }
    return _goldQuote?.pricePerTroyOunceUsd;
  }

  double? get _effectiveUsdToXafRate {
    if (_usdToXafRate.text.trim().isNotEmpty) {
      final manual = _number(_usdToXafRate.text);
      return manual.isFinite && manual > 0 ? manual : null;
    }
    return _exchangeRates?.rate('USD', 'XAF');
  }

  double? get _referencePricePerGram {
    final pricePerOunce = _effectiveGoldPricePerOunce;
    final rate = _effectiveUsdToXafRate;
    if (pricePerOunce == null ||
        rate == null ||
        !pricePerOunce.isFinite ||
        !rate.isFinite ||
        pricePerOunce <= 30 ||
        rate <= 0) {
      return null;
    }
    return (pricePerOunce - 30) * rate / 31.103477;
  }

  double? get _finalPricePerGram {
    final manualPrice = _number(_manualReferencePrice.text);
    if (_manualReferencePrice.text.trim().isNotEmpty) {
      return manualPrice.isFinite && manualPrice > 0 ? manualPrice : null;
    }
    final referencePrice = _referencePricePerGram;
    final karat = _karatValue;
    final deduction = _categoryDeduction;
    if (referencePrice == null || karat == null || deduction == null) {
      return null;
    }
    final pricePerOunce = _effectiveGoldPricePerOunce;
    final rate = _effectiveUsdToXafRate;
    if (pricePerOunce == null || rate == null) return null;
    try {
      return calculateCrudeGoldPricePerKaratGramXaf(
        pricePerTroyOunceUsd: pricePerOunce,
        usdToXafRate: rate,
        karat: karat,
        deductionXafPer24KGram: deduction,
      );
    } on ArgumentError {
      return null;
    }
  }

  double? get _finalAmount {
    final unitPrice = _finalPricePerGram;
    if (unitPrice == null || _netWeight <= 0) return null;
    return _netWeight * unitPrice;
  }

  List<Contact> get _suppliers => widget.store.contacts
      .where(
        (contact) =>
            contact.roles.any((role) => role.contains('Fournisseur d’or')),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_suppliers.any((contact) => contact.name == _seller) &&
        _suppliers.isNotEmpty) {
      _seller = _suppliers.first.name;
      _sellerController.text = _seller;
    }
    _refreshMarketPrice();
    _refreshTimer = Timer.periodic(
      GoldPriceService.refreshInterval,
      (_) => _refreshMarketPrice(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _sellerController.dispose();
    _grossWeight.dispose();
    _nonGoldWeight.dispose();
    _karatController.dispose();
    _manualReferencePrice.dispose();
    _goldPricePerOunce.dispose();
    _usdToXafRate.dispose();
    _search.dispose();
    _manualDescription.dispose();
    _manualAmount.dispose();
    _manualInitialPayment.dispose();
    _manualGrossWeight.dispose();
    _manualNonGoldWeight.dispose();
    _manualKarat.dispose();
    _origin.dispose();
    _notes.dispose();
    _initialPayment.dispose();
    _goldPriceService.close();
    _exchangeRateService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshMarketPrice();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.bankBalances.keys.toList();
    _paymentAccount ??= accounts.contains('Caisse (espèces)')
        ? 'Caisse (espèces)'
        : accounts.firstOrNull;
    return _showingForm ? _buildNewPurchase() : _buildHistory();
  }

  Widget _buildNewPurchase() {
    final suppliers = _suppliers;
    final accounts = widget.store.bankBalances.keys.toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeading(
                "Comptoir d’achat d’or Congo",
                icon: Icons.balance_outlined,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _setShowingForm(false),
              icon: const Icon(Icons.close),
              label: const Text('Fermer le formulaire'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Achat direct d’or brut d’orpaillage, fondu et bijoux avec "
          'tarification conforme au Congo-Brazzaville.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SectionHeading(
          "Saisie du Bordereau d'Achat",
          icon: Icons.edit_note,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            final cardWidth = isWide
                ? (constraints.maxWidth - 28) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _purchaseSection(
                    title: '1. Vendeur / partenaire',
                    icon: Icons.person_outline,
                    child: _sellerSection(suppliers),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _purchaseSection(
                    title: '2. Type d’or & titre carat',
                    icon: Icons.diamond_outlined,
                    child: _goldDetailsSection(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _purchaseSection(
                    title: '3. Tarification & règlement',
                    icon: Icons.payments_outlined,
                    trailing: IconButton(
                      tooltip: _marketError ?? 'Actualiser le cours de l’or',
                      onPressed: _isLoadingMarket ? null : _refreshMarketPrice,
                      icon: _isLoadingMarket
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                    child: _paymentSection(accounts),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Notes ou observation'),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: fieldDecoration(
                  'Ex. état du lot, référence du reçu, remarques…',
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Valider l’achat et générer le reçu',
                icon: Icons.check_circle_outline,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setShowingForm(bool showing) {
    setState(() => _showingForm = showing);
    widget.onFormVisibilityChanged?.call(showing);
  }

  Widget _purchaseSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.gold, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.forest,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const Divider(height: 22),
        child,
      ],
    ),
  );

  Widget _sellerSection(List<Contact> suppliers) {
    final selectedSupplier = suppliers
        .where((contact) => contact.name == _seller)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Nom du vendeur / orpailleur *'),
        TextField(
          controller: _sellerController,
          decoration: fieldDecoration(
            'Ex. Mamadou Diallo ou Coopérative Kakamoeaka',
          ),
          onChanged: (value) => setState(() => _seller = value.trim()),
        ),
        if (suppliers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const FieldLabel('Sélection rapide partenaire'),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: suppliers.take(3).map((contact) {
              final selected = contact.name == _seller;
              return ActionChip(
                label: Text(contact.name),
                onPressed: () => setState(() {
                  _seller = contact.name;
                  _sellerController.text = contact.name;
                }),
                backgroundColor: selected ? AppTheme.gold : AppTheme.paper,
                side: BorderSide(
                  color: selected ? AppTheme.gold : AppTheme.border,
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.forest,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final phone = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Téléphone'),
                InputDecorator(
                  decoration: fieldDecoration('+242 06…'),
                  child: Text(
                    selectedSupplier?.phone.isNotEmpty == true
                        ? selectedSupplier!.phone
                        : '+242 06…',
                    style: TextStyle(
                      color: selectedSupplier?.phone.isNotEmpty == true
                          ? AppTheme.forest
                          : AppTheme.muted,
                    ),
                  ),
                ),
              ],
            );
            final origin = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Origine / site'),
                TextField(
                  controller: _origin,
                  decoration: fieldDecoration('Ex. Mayoko (Niari)'),
                ),
              ],
            );
            if (constraints.maxWidth < 360) {
              return Column(
                children: [phone, const SizedBox(height: 12), origin],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: phone),
                const SizedBox(width: 10),
                Expanded(child: origin),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _goldDetailsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FieldLabel('Catégorie d’or'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _categories.map((value) {
          final selected = value == _category;
          return ChoiceChip(
            label: Text(_categoryLabel(value)),
            selected: selected,
            onSelected: (_) => setState(() => _category = value),
            selectedColor: AppTheme.gold,
            side: BorderSide(color: selected ? AppTheme.gold : AppTheme.border),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.forest,
              fontSize: 12,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      const FieldLabel('Titre (carat)'),
      DropdownButtonFormField<String>(
        initialValue: _karatController.text,
        decoration: fieldDecoration('Choisir le titre'),
        items: List.generate(24, (index) {
          final karat = 24 - index;
          final purity = _format(karat / 24 * 100);
          return DropdownMenuItem(
            value: '$karat',
            child: Text('${karat}K – $purity%'),
          );
        }),
        onChanged: (value) {
          if (value != null) {
            _karatController.text = value;
            setState(() {});
          }
        },
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Poids brut (g)'),
                _numberField(
                  controller: _grossWeight,
                  hint: '0,00',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Tare (g)'),
                _numberField(
                  controller: _nonGoldWeight,
                  hint: '0,00',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _paymentSection(List<String> accounts) =>
      _buildPriceEstimate(accounts);

  Widget _buildPriceEstimate(List<String> accounts) {
    final reference = _referencePricePerGram;
    final appliedPrice = _finalPricePerGram;
    final total = _finalAmount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.forest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _priceLine(
            'Prix formule',
            reference == null ? 'À calculer' : '${money(reference)} FCFA / g',
          ),
          const SizedBox(height: 8),
          Material(
            color: AppTheme.forest,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.white24,
                colorScheme: Theme.of(
                  context,
                ).colorScheme.copyWith(onSurface: Colors.white),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white70,
                iconColor: Colors.white70,
                title: const Text(
                  'Modifier le cours de référence',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Prix de l’once troy (USD)',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _goldPricePerOunce,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldDecoration('USD / once troy'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Taux USD/XAF (à renseigner)',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _usdToXafRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldDecoration('Ex. 600'),
                    onChanged: (_) {
                      _rateWasEnteredManually = true;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Prix appliqué au gramme (Modifiable)',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _manualReferencePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDecoration(
              appliedPrice == null ? 'FCFA / g' : _format(appliedPrice),
            ).copyWith(suffixText: 'FCFA/g'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mode de Paiement',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            initialValue: _paymentAccount,
            decoration: fieldDecoration('Choisir un compte'),
            items: accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account,
                    child: Text(
                      account == 'Caisse (espèces)'
                          ? 'Espèces Caisse (FCFA)'
                          : account,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _paymentAccount = value),
          ),
          const SizedBox(height: 12),
          const Text(
            'Montant Versé Immédiatement',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 5),
          _numberField(
            controller: _initialPayment,
            hint: '0',
            onChanged: (_) => setState(() {}),
          ),
          const Divider(color: Colors.white24, height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total de l’achat :',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                total != null
                    ? '${money(total)} FCFA'
                    : _netWeight <= 0
                    ? '0 FCFA'
                    : 'À calculer',
                style: const TextStyle(
                  color: AppTheme.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final query = _search.text.trim().toLowerCase();
    final purchases = widget.store.purchases.where((purchase) {
      final date = _date(purchase.purchasedAt).toLowerCase();
      final searchable = [
        purchase.description,
        purchase.reference ?? '',
        purchase.supplier ?? '',
        purchase.goldCategory,
        purchase.karat ?? '',
        date,
        purchase.purchasedAt.toIso8601String(),
        ...purchase.payments.map(
          (payment) => '${payment.method} ${payment.account ?? ''}',
        ),
      ].join(' ').toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) return false;
      return switch (_purchaseFilter) {
        'Traités (Soldés)' =>
          !purchase.isCancelled && purchase.remainingAmount <= 0,
        'En Avance' =>
          !purchase.isCancelled &&
              purchase.paidAmount > 0 &&
              purchase.remainingAmount > 0,
        'Non Traités' =>
          !purchase.isCancelled &&
              purchase.paidAmount <= 0 &&
              purchase.remainingAmount > 0,
        _ => true,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeading(
                "Comptoir d’achat d’or Congo",
                icon: Icons.balance_outlined,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _setShowingForm(true),
              icon: const Icon(Icons.add),
              label: const Text("Nouvel Achat d'Or"),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.white,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Autres actions',
              onSelected: (action) {
                if (action == 'manual') _addManualPurchase();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'manual',
                  child: Text('Ajouter un achat manuellement'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Achat direct d’or brut d’orpaillage, fondu et bijoux avec "
          'tarification conforme Congo-Brazzaville.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        AppPanel(
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _search,
                    decoration:
                        fieldDecoration(
                          'Rechercher par client, N° bordereau, origine ou mode de paiement…',
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
                  );
                  final filters = Wrap(
                    spacing: 4,
                    children:
                        [
                          'Tous',
                          'Traités (Soldés)',
                          'En Avance',
                          'Non Traités',
                        ].map((filter) {
                          final selected = _purchaseFilter == filter;
                          return ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _purchaseFilter = filter),
                            selectedColor: AppTheme.gold,
                            side: BorderSide(
                              color: selected ? AppTheme.gold : AppTheme.border,
                            ),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppTheme.forest,
                              fontSize: 11,
                            ),
                          );
                        }).toList(),
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 8), filters],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      filters,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (purchases.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      widget.store.purchases.isEmpty
                          ? 'Aucun achat enregistré.'
                          : 'Aucun achat correspondant.',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      AppTheme.paper.withValues(alpha: 0.75),
                    ),
                    headingTextStyle: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    dataTextStyle: const TextStyle(
                      color: AppTheme.forest,
                      fontSize: 11,
                    ),
                    horizontalMargin: 10,
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('DATE & CODE')),
                      DataColumn(label: Text('VENDEUR & ORIGINE')),
                      DataColumn(label: Text('TYPE & CARAT')),
                      DataColumn(label: Text('POIDS NET')),
                      DataColumn(label: Text('PRIX / G')),
                      DataColumn(label: Text('TOTAL ACHAT')),
                      DataColumn(label: Text('RÈGLEMENT / CAISSE')),
                      DataColumn(label: Text('STATUT')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: purchases.map(_purchaseDataRow).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _purchaseDataRow(PurchaseRecord purchase) {
    final netWeight = purchase.netWeightGrams;
    final unitPrice = netWeight != null && netWeight > 0
        ? purchase.amount / netWeight
        : purchase.referencePricePerGram;
    final payment = purchase.payments.lastOrNull;
    final settled = !purchase.isCancelled && purchase.remainingAmount <= 0;
    final statusColor = purchase.isCancelled
        ? AppTheme.red
        : settled
        ? AppTheme.green
        : AppTheme.gold;
    final statusLabel = purchase.isCancelled
        ? 'Annulé'
        : settled
        ? 'Traité'
        : purchase.paidAmount > 0
        ? 'En avance'
        : 'Non traité';

    return DataRow(
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchase.reference ?? 'Ancienne référence',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(_dateTime(purchase.purchasedAt)),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchase.supplier ?? purchase.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(purchase.description),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(purchase.goldCategory),
              Text(
                purchase.karat ?? '—',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(netWeight == null ? '—' : '${_format(netWeight)} g')),
        DataCell(Text(unitPrice == null ? '—' : '${money(unitPrice)} FCFA')),
        DataCell(
          Text(
            '${money(purchase.amount)} FCFA',
            style: const TextStyle(
              color: AppTheme.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(payment?.method ?? 'Aucun paiement'),
              Text(
                purchase.remainingAmount <= 0
                    ? 'Payé intégralement'
                    : 'Dû : ${money(purchase.remainingAmount)} FCFA',
                style: TextStyle(
                  color: purchase.remainingAmount > 0
                      ? AppTheme.red
                      : AppTheme.green,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            children: [
              Icon(
                settled ? Icons.check_circle_outline : Icons.error_outline,
                size: 15,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(color: statusColor)),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Voir les détails',
                onPressed: () => _showPurchaseDetails(purchase),
                icon: const Icon(Icons.visibility_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Imprimer le reçu',
                onPressed: () => _printReceipt(purchase),
                icon: const Icon(Icons.print_outlined, size: 18),
              ),
              if (!purchase.isCancelled && purchase.remainingAmount > 0)
                TextButton(
                  onPressed: () => _addPayment(purchase),
                  child: const Text('Régler'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String category) => switch (category) {
    'Or brut' => 'Or Brut (-4500)',
    'Or fondu' => 'Or Fondu (-3500)',
    'Bijoux' => 'Bijoux (-7000)',
    _ => category,
  };

  Future<void> _addManualPurchase() async {
    _manualDescription.clear();
    _manualAmount.clear();
    _manualInitialPayment.text = '0';
    _manualGrossWeight.clear();
    _manualNonGoldWeight.text = '0';
    _manualKarat.clear();
    final suppliers = _suppliers;
    final accounts = widget.store.bankBalances.keys.toList();
    var supplier = suppliers.any((contact) => contact.name == _seller)
        ? _seller
        : suppliers.firstOrNull?.name;
    var account = accounts.contains('Caisse (espèces)')
        ? 'Caisse (espèces)'
        : accounts.firstOrNull;
    var category = 'Or brut';

    try {
      final entry =
          await showDialog<
            (
              String,
              double,
              double,
              String?,
              String?,
              double?,
              double?,
              String?,
              String,
            )
          >(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Ajouter un achat au carnet'),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _manualDescription,
                          decoration: fieldDecoration('Désignation / note'),
                        ),
                        const SizedBox(height: 12),
                        if (suppliers.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: supplier,
                            decoration: fieldDecoration('Fournisseur'),
                            items: suppliers
                                .map(
                                  (contact) => DropdownMenuItem(
                                    value: contact.name,
                                    child: Text(contact.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => supplier = value),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _manualAmount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: fieldDecoration(
                            'Prix d’achat total (FCFA)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _manualInitialPayment,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: fieldDecoration(
                            'Montant déjà payé / avance (FCFA)',
                          ),
                        ),
                        if (accounts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: account,
                            decoration: fieldDecoration('Compte débité'),
                            items: accounts
                                .map(
                                  (name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(
                                      '$name · ${money(widget.store.bankBalances[name]!)} FCFA',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => account = value),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _manualGrossWeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: fieldDecoration(
                            'Poids brut (g), facultatif',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _manualNonGoldWeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: fieldDecoration('Poids non aurifère (g)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _manualKarat,
                          keyboardType: TextInputType.number,
                          decoration: fieldDecoration(
                            'Carat, facultatif',
                          ).copyWith(suffixText: 'K'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: fieldDecoration('Catégorie'),
                          items: _categories
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => category = value ?? category,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final total = _number(_manualAmount.text);
                      final paid = _number(_manualInitialPayment.text);
                      final grossText = _manualGrossWeight.text.trim();
                      final karatText = _manualKarat.text.trim();
                      final hasWeight = grossText.isNotEmpty;
                      final hasKarat = karatText.isNotEmpty;
                      final gross = _number(grossText);
                      final nonGold = _number(_manualNonGoldWeight.text);
                      final isWeightValid =
                          hasWeight == hasKarat &&
                          (!hasWeight ||
                              (gross > 0 &&
                                  nonGold >= 0 &&
                                  nonGold < gross &&
                                  isValidGoldKarat(karatText)));
                      if (_manualDescription.text.trim().isEmpty ||
                          total <= 0 ||
                          paid < 0 ||
                          paid > total ||
                          (paid > 0 &&
                              (account == null ||
                                  (widget.store.bankBalances[account] ?? 0) <
                                      paid)) ||
                          !isWeightValid) {
                        _message(
                          'Vérifiez la désignation, le prix, l’avance, le compte et les éventuels poids/carat.',
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, (
                        _manualDescription.text.trim(),
                        total,
                        paid,
                        supplier,
                        account,
                        hasWeight ? gross : null,
                        hasWeight ? nonGold : null,
                        hasKarat ? '${goldKaratValue(karatText)}K' : null,
                        category,
                      ));
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          );
      if (entry == null) return;
      final paid = entry.$3;
      final weight = entry.$6;
      final selectedKarat = entry.$8;
      widget.store.addPurchase(
        entry.$1,
        entry.$2,
        paymentAccount: paid > 0 ? entry.$5 : null,
        initialPaymentAmount: paid,
        reference: _nextReference,
        supplier: entry.$4,
        grossWeightGrams: weight,
        nonGoldWeightGrams: entry.$7,
        karat: selectedKarat,
        goldCategory: entry.$9,
        purityPercent: selectedKarat == null
            ? null
            : goldKaratValue(selectedKarat)! / 24 * 100,
      );
      if (mounted) {
        setState(() {});
        _message('Achat ajouté au carnet.');
      }
    } on ArgumentError catch (error) {
      _message(error.message?.toString() ?? 'Achat manuel invalide.');
    }
  }

  // ignore: unused_element
  Widget _buildSuppliers() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Gestion des fournisseurs',
                icon: Icons.people_outline,
              ),
              const SizedBox(height: 8),
              Text(
                'Coordonnées issues du carnet de contacts et activité '
                'calculée à partir des achats enregistrés.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (_suppliers.isEmpty)
                const Text('Aucun fournisseur d’or dans les contacts.')
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 22,
                    headingRowColor: WidgetStateProperty.all(AppTheme.paper),
                    columns: const [
                      DataColumn(label: Text('Fournisseur')),
                      DataColumn(label: Text('Coordonnées')),
                      DataColumn(label: Text('Achats'), numeric: true),
                      DataColumn(label: Text('Payé (FCFA)'), numeric: true),
                      DataColumn(label: Text('Dû (FCFA)'), numeric: true),
                    ],
                    rows: _suppliers.map((supplier) {
                      final purchases = widget.store.purchases
                          .where(
                            (purchase) =>
                                purchase.supplier == supplier.name &&
                                !purchase.isCancelled,
                          )
                          .toList();
                      final paid = purchases.fold<double>(
                        0,
                        (total, purchase) => total + purchase.paidAmount,
                      );
                      final due = purchases.fold<double>(
                        0,
                        (total, purchase) => total + purchase.remainingAmount,
                      );
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircleAvatar(
                                  radius: 17,
                                  backgroundColor: AppTheme.paper,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: AppTheme.forest,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Text(supplier.name),
                              ],
                            ),
                          ),
                          DataCell(Text('${supplier.phone}\n${supplier.city}')),
                          DataCell(Text('${purchases.length}')),
                          DataCell(Text(money(paid))),
                          DataCell(Text(money(due))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildStatistics() {
    final active = widget.store.purchases
        .where((purchase) => !purchase.isCancelled)
        .toList();
    final weight = active.fold<double>(
      0,
      (total, purchase) => total + (purchase.netWeightGrams ?? 0),
    );
    final spent = active.fold<double>(
      0,
      (total, purchase) => total + purchase.amount,
    );
    final paid = active.fold<double>(
      0,
      (total, purchase) => total + purchase.paidAmount,
    );
    final averagePrice = weight == 0 ? 0.0 : spent / weight;
    final fineGold = active.fold<double>(
      0,
      (total, purchase) => total + purchase.fineGoldWeightGrams,
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Statistiques des achats',
                icon: Icons.query_stats,
              ),
              const SizedBox(height: 14),
              _statLine('Achats actifs', '${active.length}'),
              _statLine('Poids net acheté', '${_format(weight)} g'),
              _statLine('Or fin estimé', '${_format(fineGold)} g'),
              _statLine('Dépenses engagées', '${money(spent)} FCFA'),
              _statLine('Paiements effectués', '${money(paid)} FCFA'),
              _statLine(
                'Prix moyen par gramme net',
                '${money(averagePrice)} FCFA/g',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Future<void> _showPurchaseDetails(PurchaseRecord purchase) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(purchase.reference ?? 'Fiche détaillée'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailLine(
                    'Fournisseur',
                    purchase.supplier ?? 'Non renseigné',
                  ),
                  _detailLine('Date', _dateTime(purchase.purchasedAt)),
                  _detailLine('Poids brut', _grams(purchase.grossWeightGrams)),
                  _detailLine('Poids net', _grams(purchase.netWeightGrams)),
                  _detailLine('Carat', purchase.karat ?? 'Non renseigné'),
                  _detailLine(
                    'Pureté estimée',
                    purchase.purityPercent == null
                        ? 'Non renseignée'
                        : '${_format(purchase.purityPercent!)} %',
                  ),
                  _detailLine(
                    'Or fin estimé',
                    '${_format(purchase.fineGoldWeightGrams)} g',
                  ),
                  _detailLine(
                    'Prix de référence / g',
                    purchase.referencePricePerGram == null
                        ? 'Non renseigné'
                        : '${money(purchase.referencePricePerGram!)} FCFA',
                  ),
                  if (purchase.goldPricePerTroyOunceUsd != null)
                    _detailLine(
                      'Cours de l’once à l’achat',
                      '${_format(purchase.goldPricePerTroyOunceUsd!)} USD',
                    ),
                  _detailLine(
                    purchase.goldPricePerTroyOunceUsd == null
                        ? 'Décote'
                        : 'Déduction fixe',
                    purchase.goldPricePerTroyOunceUsd == null
                        ? purchase.discountPercent == null
                              ? 'Non renseignée'
                              : '${_format(purchase.discountPercent!)} %'
                        : '4 500 FCFA / 24K',
                  ),
                  _detailLine(
                    'Montant total',
                    '${money(purchase.amount)} FCFA',
                  ),
                  _detailLine(
                    'Déjà payé',
                    '${money(purchase.paidAmount)} FCFA',
                  ),
                  _detailLine(
                    'Reste à payer',
                    '${money(purchase.remainingAmount)} FCFA',
                  ),
                  if (purchase.usdToXafRate != null)
                    _detailLine(
                      'Taux USD/XAF à l’achat',
                      '${_format(purchase.usdToXafRate!)}'
                          '${purchase.rateObservedAt == null ? '' : ' · ${_dateTime(purchase.rateObservedAt!)}'}',
                    ),
                  const Divider(),
                  const Text(
                    'Paiements',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (purchase.payments.isEmpty)
                    const Text('Aucun paiement enregistré.')
                  else
                    ...purchase.payments.map(
                      (payment) => Text(
                        '${_dateTime(payment.paidAt)} · ${payment.method} · '
                        '${money(payment.amount)} FCFA'
                        '${payment.note.isEmpty ? '' : ' · ${payment.note}'}',
                      ),
                    ),
                  const Divider(),
                  const Text(
                    'Analyses et photos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (purchase.photos.isEmpty)
                    const Text(
                      'Aucune photo jointe.',
                      style: TextStyle(color: AppTheme.muted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: purchase.photos
                          .map(
                            (photo) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                photo,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (!purchase.isCancelled)
                    TextButton.icon(
                      onPressed: () async {
                        await _addPhotos(purchase);
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Ajouter des photos'),
                    ),
                  if (purchase.isCancelled) ...[
                    const Divider(),
                    Text(
                      'Annulé le ${_dateTime(purchase.cancelledAt!)}'
                      ' · ${purchase.cancellationReason}',
                      style: const TextStyle(color: AppTheme.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
            TextButton.icon(
              onPressed: () => _printReceipt(purchase),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Réimprimer le reçu'),
            ),
            if (!purchase.isCancelled && purchase.remainingAmount > 0)
              FilledButton.tonal(
                onPressed: () => _addPayment(purchase),
                child: const Text('Ajouter un paiement'),
              ),
            if (!purchase.isCancelled)
              TextButton(
                onPressed: () => _cancelPurchase(purchase),
                child: const Text('Annuler l’achat'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhotos(PurchaseRecord purchase) async {
    final selected = await _imagePicker.pickMultiImage();
    if (selected.isEmpty) return;
    final photoBytes = <Uint8List>[];
    for (final photo in selected) {
      photoBytes.add(await photo.readAsBytes());
    }
    widget.store.addPurchasePhotos(purchase, photoBytes);
    if (mounted) setState(() {});
  }

  Future<void> _addPayment(PurchaseRecord purchase) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var method = 'Espèces';
    final accounts = widget.store.bankBalances.keys.toList();
    var paymentAccount = accounts.contains('Caisse (espèces)')
        ? 'Caisse (espèces)'
        : accounts.firstOrNull;
    try {
      final payment = await showDialog<PurchasePayment>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Enregistrer un paiement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Solde restant : ${money(purchase.remainingAmount)} FCFA'),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: fieldDecoration('Montant en FCFA'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: fieldDecoration('Mode de paiement'),
                  items: ['Espèces', 'Virement', 'Mobile money', 'Autre']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? method),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: paymentAccount,
                  decoration: fieldDecoration('Compte débité'),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account,
                          child: Text(
                            '$account · ${money(widget.store.bankBalances[account]!)} FCFA',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => paymentAccount = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: fieldDecoration('Note (facultatif)'),
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
                  final amount = _number(amountController.text);
                  if (amount <= 0 || amount > purchase.remainingAmount) {
                    _message(
                      'Le paiement doit être positif et ne pas dépasser le solde.',
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    PurchasePayment(
                      amount: amount,
                      paidAt: DateTime.now(),
                      method: method,
                      note: noteController.text.trim(),
                      account: paymentAccount,
                    ),
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
      if (payment != null) {
        widget.store.addPurchasePayment(purchase, payment);
        if (mounted) setState(() {});
      }
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _cancelPurchase(PurchaseRecord purchase) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Annuler cet achat ?'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: fieldDecoration('Motif obligatoire'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  _message('Saisissez le motif de l’annulation.');
                  return;
                }
                Navigator.pop(dialogContext, reasonController.text.trim());
              },
              child: const Text('Confirmer l’annulation'),
            ),
          ],
        ),
      );
      if (reason != null) {
        widget.store.cancelPurchase(purchase, reason);
        if (mounted) {
          Navigator.of(context).pop();
          setState(() {});
          _message('Achat annulé. L’opération reste dans l’historique.');
        }
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _printReceipt(PurchaseRecord purchase) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "COMPTOIR D'OR",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'REÇU D’ACHAT · ${purchase.reference ?? 'Ancienne référence'}',
            ),
            pw.Divider(),
            _receiptLine('Date', _dateTime(purchase.purchasedAt)),
            _receiptLine('Fournisseur', purchase.supplier ?? 'Non renseigné'),
            _receiptLine('Poids brut', _grams(purchase.grossWeightGrams)),
            _receiptLine('Poids net', _grams(purchase.netWeightGrams)),
            _receiptLine('Carat', purchase.karat ?? 'Non renseigné'),
            if (purchase.goldPricePerTroyOunceUsd != null)
              _receiptLine(
                'Cours de l’once utilisé',
                '${_format(purchase.goldPricePerTroyOunceUsd!)} USD',
              ),
            if (purchase.goldPricePerTroyOunceUsd != null)
              _receiptLine('Déduction fixe', '4 500 FCFA / 24K'),
            _receiptLine('Montant total', '${money(purchase.amount)} FCFA'),
            _receiptLine('Montant payé', '${money(purchase.paidAmount)} FCFA'),
            _receiptLine(
              'Reste à payer',
              '${money(purchase.remainingAmount)} FCFA',
            ),
            if (purchase.usdToXafRate != null)
              _receiptLine(
                'Taux USD/XAF utilisé',
                _format(purchase.usdToXafRate!),
              ),
            if (purchase.isCancelled)
              _receiptLine('ANNULÉ', '${purchase.cancellationReason}'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Document généré à partir du registre des achats.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => document.save(),
        name:
            'recu-${purchase.reference ?? purchase.purchasedAt.millisecondsSinceEpoch}.pdf',
      );
    } catch (error) {
      if (mounted) _message('Impossible d’imprimer le reçu : $error');
    }
  }

  bool get _canSave =>
      _seller.trim().isNotEmpty &&
      _karatValue != null &&
      _grossValue.isFinite &&
      _nonGoldValue.isFinite &&
      (_manualReferencePrice.text.trim().isNotEmpty
          ? _number(_manualReferencePrice.text) > 0
          : _categoryDeduction != null &&
                (_effectiveGoldPricePerOunce ?? 0) > 30 &&
                (_effectiveUsdToXafRate ?? 0) > 0) &&
      _grossValue > 0 &&
      _nonGoldValue >= 0 &&
      _nonGoldValue < _grossValue &&
      _finalAmount != null &&
      _finalAmount!.isFinite &&
      _finalAmount! > 0 &&
      _number(_initialPayment.text).isFinite &&
      _number(_initialPayment.text) >= 0 &&
      _number(_initialPayment.text) <= _finalAmount! &&
      (_number(_initialPayment.text) == 0 ||
          (_paymentAccount != null &&
              (widget.store.bankBalances[_paymentAccount] ?? 0) >=
                  _number(_initialPayment.text)));

  String get _nextReference {
    final year = DateTime.now().year;
    final count = widget.store.purchases
        .where(
          (purchase) => purchase.reference?.startsWith('ACH-$year-') == true,
        )
        .length;
    return 'ACH-$year-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<void> _refreshMarketPrice() async {
    if (_isLoadingMarket) return;
    setState(() {
      _isLoadingMarket = true;
      _marketError = null;
    });
    GoldPriceQuote? goldQuote;
    ExchangeRateSnapshot? exchangeRates;
    String? goldError;
    String? exchangeError;
    try {
      goldQuote = await _goldPriceService.fetchGoldUsd();
    } catch (error) {
      goldError = error.toString();
    }
    try {
      exchangeRates = await _exchangeRateService.fetchRates();
    } catch (error) {
      exchangeError = error.toString();
    }
    if (!mounted) return;
    setState(() {
      if (goldQuote != null) {
        _goldQuote = goldQuote;
        if (_goldPricePerOunce.text.isEmpty) {
          _goldPricePerOunce.text = _format(goldQuote.pricePerTroyOunceUsd);
        }
      }
      if (exchangeRates != null) {
        _exchangeRates = exchangeRates;
        final rate = exchangeRates.rate('USD', 'XAF');
        if (_usdToXafRate.text.isEmpty && rate != null) {
          _usdToXafRate.text = _format(rate);
        }
      }
      final errors = [
        if (goldError != null) 'GoldAPI : $goldError',
        if (exchangeError != null) 'taux USD/XAF : $exchangeError',
      ];
      _marketError = errors.isEmpty ? null : errors.join(' · ');
      _isLoadingMarket = false;
    });
  }

  void _save() {
    if (!_canSave) {
      _message('Vérifiez le fournisseur, les poids, le cours et le taux.');
      return;
    }
    final referencePrice = _referencePricePerGram ?? _finalPricePerGram!;
    final amount = _finalAmount!;
    final rate = _effectiveUsdToXafRate;
    final goldPricePerOunce = _effectiveGoldPricePerOunce;
    final purchaseReference = _nextReference;
    final initialPayment = _number(_initialPayment.text);
    final account = initialPayment > 0 ? _paymentAccount : null;
    final description = [
      _seller,
      if (_origin.text.trim().isNotEmpty) 'Origine : ${_origin.text.trim()}',
      '${_format(_netWeight)} g',
      _karatLabel,
      '${money(amount)} FCFA',
      _category,
      if (_notes.text.trim().isNotEmpty) 'Note : ${_notes.text.trim()}',
    ].join(' · ');
    try {
      widget.store.addPurchase(
        description,
        amount,
        paymentAccount: account,
        initialPaymentAmount: initialPayment,
        reference: purchaseReference,
        supplier: _seller,
        grossWeightGrams: _grossValue,
        nonGoldWeightGrams: _nonGoldValue,
        karat: _karatLabel,
        goldCategory: _category,
        purityPercent: _purityPercent,
        referencePricePerGram: referencePrice,
        discountPercent: null,
        goldPricePerTroyOunceUsd: goldPricePerOunce,
        usdToXafRate: rate,
        rateObservedAt: rate == null
            ? null
            : _rateWasEnteredManually
            ? DateTime.now()
            : _exchangeRates?.updatedAt,
      );
    } on ArgumentError catch (error) {
      _message(error.message.toString());
      return;
    }
    _grossWeight.clear();
    _nonGoldWeight.text = '0';
    _manualReferencePrice.clear();
    _origin.clear();
    _notes.clear();
    _initialPayment.text = '0';
    setState(() {});
    _message('Achat enregistré sous la référence $purchaseReference.');
  }

  Widget _numberField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: fieldDecoration(hint),
    onChanged: onChanged,
  );

  Widget _priceLine(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: Colors.white70)),
      ),
      Text(value, style: const TextStyle(color: Colors.white)),
    ],
  );

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.muted)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static double _number(String value) =>
      double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  static String _format(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  static String _grams(double? value) =>
      value == null ? 'Non renseigné' : '${_format(value)} g';

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  static String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static pw.Widget _receiptLine(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}
