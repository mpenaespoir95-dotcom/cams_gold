import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/gold_price_service.dart';
import '../../shared/widgets/app_widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with WidgetsBindingObserver {
  final _weight = TextEditingController();
  final _gramPrice = TextEditingController();
  final _rate = TextEditingController();
  final _cost = TextEditingController();
  final _travel = TextEditingController();
  final _customs = TextEditingController();
  final _goldPriceService = GoldPriceService();
  final _exchangeRateService = ExchangeRateService();
  Timer? _refreshTimer;
  static const _standardKarats = ['24K', '22K', '21K', '18K', '14K', '9K'];
  String _buyer = 'Al Noor Gold Trading';
  String _karat = '24K';
  String _category = 'Non catégorisé';
  GoldPriceQuote? _goldQuote;
  ExchangeRateSnapshot? _exchangeRates;
  String? _marketError;
  bool _isLoadingMarket = false;
  bool _manualGoldPrice = false;
  bool _manualExchangeRate = false;

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

  double _number(TextEditingController controller) =>
      double.tryParse(
        controller.text.replaceAll(',', '.').replaceAll(' ', ''),
      ) ??
      0;

  double get _weightValue => _number(_weight);
  double get _revenue => _weightValue * _number(_gramPrice) * _number(_rate);
  double get _costValue => _number(_cost);
  double get _charges => _number(_travel) + _number(_customs);
  double get _profit => _revenue - _costValue - _charges;
  double get _availableCategoryWeight =>
      widget.store.stockWeightForKarat(_karat, category: _category);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshMarketPrices();
    _refreshTimer = Timer.periodic(
      GoldPriceService.refreshInterval,
      (_) => _refreshMarketPrices(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _weight.dispose();
    _gramPrice.dispose();
    _rate.dispose();
    _cost.dispose();
    _travel.dispose();
    _customs.dispose();
    _goldPriceService.close();
    _exchangeRateService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshMarketPrices();
  }

  @override
  Widget build(BuildContext context) {
    final buyers = widget.store.contacts
        .where((contact) => contact.roles.contains('Client d’or'))
        .map((contact) => contact.name)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(eyebrow: 'Comptoir · Ventes', title: 'Stock d’or'),
        AppPanel(
          padding: 0,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: SectionHeading(
                            'Nouvelle vente en dollars',
                            icon: Icons.flight_takeoff_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualiser le cours de l’or',
                          onPressed: _isLoadingMarket
                              ? null
                              : _refreshMarketPrices,
                          icon: _isLoadingMarket
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    Text(
                      _marketStatus,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _marketError == null
                            ? AppTheme.muted
                            : AppTheme.red,
                      ),
                    ),
                    if (_manualGoldPrice || _manualExchangeRate)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _useMarketPrices,
                          child: const Text('Reprendre les cours automatiques'),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const FieldLabel('Acheteur à Dubaï'),
                    DropdownButtonFormField<String>(
                      initialValue: buyers.contains(_buyer)
                          ? _buyer
                          : (buyers.isEmpty ? null : buyers.first),
                      decoration: fieldDecoration('Choisir un acheteur'),
                      items: buyers
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _buyer = value ?? _buyer),
                    ),
                    const SizedBox(height: 14),
                    _NumberField(
                      label: 'Poids vendu (g)',
                      controller: _weight,
                      hint: '0,00',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Pureté de l’or vendu'),
                    DropdownButtonFormField<String>(
                      initialValue: _karat,
                      decoration: fieldDecoration('Carats'),
                      items: _karats
                          .map(
                            (karat) => DropdownMenuItem(
                              value: karat,
                              child: Text(karat),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _karat = value;
                          if (!_manualGoldPrice && _goldQuote != null) {
                            _gramPrice.text = _format(
                              _goldQuote!.pricePerKaratGramUsd(
                                goldKaratValue(_karat)!,
                              ),
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Catégorie de stock à déduire'),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: fieldDecoration('Catégorie'),
                      items: goldStockCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(
                                '$category · ${_format(widget.store.stockWeightForKarat(_karat, category: category))} g',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Disponible pour cette catégorie : '
                      '${_format(_availableCategoryWeight)} g',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Prix du gramme (USD)',
                            controller: _gramPrice,
                            hint: _goldQuote == null
                                ? 'Cours non chargé'
                                : _format(
                                    _goldQuote!.pricePerKaratGramUsd(
                                      goldKaratValue(_karat)!,
                                    ),
                                  ),
                            onChanged: (_) => setState(() {
                              _manualGoldPrice = true;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberField(
                            label: 'Taux (1 USD en FCFA)',
                            controller: _rate,
                            hint: _exchangeRates == null
                                ? 'Taux non chargé'
                                : _format(
                                    _exchangeRates!.rate('USD', 'XAF') ?? 0,
                                  ),
                            onChanged: (_) => setState(() {
                              _manualExchangeRate = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _NumberField(
                      label: 'Coût d’achat de l’or (FCFA)',
                      controller: _cost,
                      hint: '0',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Charges (FCFA)'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: fieldDecoration('Billet d’avion'),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _travel,
                            keyboardType: TextInputType.number,
                            decoration: fieldDecoration('0'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: fieldDecoration(
                              'Frais douane / export',
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _customs,
                            keyboardType: TextInputType.number,
                            decoration: fieldDecoration('0'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppTheme.forest,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryLine(
                      'Montant de la vente',
                      '${money(_revenue)} FCFA',
                    ),
                    _SummaryLine(
                      'Coût d’achat + charges',
                      '${money(_costValue + _charges)} FCFA',
                    ),
                    const Divider(color: Color(0x335D7469), height: 24),
                    const Text(
                      'BÉNÉFICE EN FCFA',
                      style: TextStyle(color: Color(0xFFAEB7AE), fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${money(_profit)} FCFA',
                      style: TextStyle(
                        color: _profit >= 0
                            ? const Color(0xFFF4D99F)
                            : const Color(0xFFFF806A),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'Enregistrer la vente',
                      onPressed: _save,
                    ),
                  ],
                ),
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
                'Ventes réalisées',
                icon: Icons.flight_outlined,
              ),
              const SizedBox(height: 8),
              ...widget.store.sales.map(
                (sale) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.gold,
                  ),
                  title: Text(sale),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _marketStatus {
    if (_isLoadingMarket && _goldQuote == null) {
      return 'Récupération du cours de l’or et du taux USD/XAF…';
    }
    if (_marketError != null) {
      return 'Actualisation incomplète : $_marketError. Les champs restent modifiables.';
    }
    final quote = _goldQuote;
    final rate = _exchangeRates?.rate('USD', 'XAF');
    if (quote == null || rate == null) {
      return 'Configurez GoldAPI et le taux USD/XAF pour les prix automatiques.';
    }
    final variation = quote.changePercent;
    return 'GoldAPI · XAU/USD ${_format(quote.pricePerTroyOunceUsd)} USD/oz · '
        'cours du gramme ${_format(quote.pricePerGramUsd)} USD/g · '
        '${variation == null ? '' : 'variation ${variation >= 0 ? '+' : ''}${_format(variation)} % · '}'
        '1 USD = ${_format(rate)} XAF · ${_dateTime(quote.updatedAt)}';
  }

  Future<void> _refreshMarketPrices() async {
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
        if (!_manualGoldPrice) {
          _gramPrice.text = _format(
            goldQuote.pricePerKaratGramUsd(goldKaratValue(_karat)!),
          );
        }
      }
      if (exchangeRates != null) {
        _exchangeRates = exchangeRates;
        if (!_manualExchangeRate) {
          final usdToXaf = exchangeRates.rate('USD', 'XAF');
          if (usdToXaf != null) _rate.text = _format(usdToXaf);
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

  void _useMarketPrices() {
    final quote = _goldQuote;
    final usdToXaf = _exchangeRates?.rate('USD', 'XAF');
    if (quote == null || usdToXaf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les cours GoldAPI et USD/XAF ne sont pas disponibles.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _manualGoldPrice = false;
      _manualExchangeRate = false;
      _gramPrice.text = _format(
        quote.pricePerKaratGramUsd(goldKaratValue(_karat)!),
      );
      _rate.text = _format(usdToXaf);
    });
  }

  void _save() {
    if (_weightValue <= 0 || _revenue <= 0 || _costValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indiquez un poids, un prix et le coût d’achat de l’or.',
          ),
        ),
      );
      return;
    }
    final availableWeight = widget.store.stockWeightForKarat(_karat);
    if (_weightValue > availableWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock insuffisant en $_karat : '
            '${_format(availableWeight)} g disponibles.',
          ),
        ),
      );
      return;
    }
    if (_weightValue > _availableCategoryWeight) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock insuffisant en $_karat · $_category : '
            '${_format(_availableCategoryWeight)} g disponibles.',
          ),
        ),
      );
      return;
    }
    widget.store.addSale(
      '$_buyer · ${_weight.text} g · $_karat · ${money(_revenue)} FCFA',
      _profit,
      weightGrams: _weightValue,
      karat: _karat,
      category: _category,
    );
    _weight.clear();
    _cost.clear();
    _travel.clear();
    _customs.clear();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vente enregistrée.')));
  }

  static String _format(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint = '0',
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDecoration(hint),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.title, this.amount);

  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFAEB7AE))),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
