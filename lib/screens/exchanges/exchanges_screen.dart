import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../services/exchange_rate_history.dart';
import '../../services/exchange_rate_service.dart';
import '../../shared/widgets/app_widgets.dart';
import 'rate_history_chart.dart';

class ExchangesScreen extends StatefulWidget {
  const ExchangesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExchangesScreen> createState() => _ExchangesScreenState();
}

class _ExchangesScreenState extends State<ExchangesScreen>
    with WidgetsBindingObserver {
  static const _currencies = ['USD', 'EUR', 'XAF', 'XOF', 'AED', 'CNY'];
  static const _ratePairs = [('USD', 'XAF'), ('EUR', 'XAF'), ('USD', 'EUR')];
  static const _periods = {
    '24 heures': Duration(hours: 24),
    '7 jours': Duration(days: 7),
    '30 jours': Duration(days: 30),
    '1 an': Duration(days: 365),
  };

  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _fees = TextEditingController(text: '0');
  final _premium = TextEditingController(text: '0');
  final _rateService = ExchangeRateService();
  final _rateHistory = ExchangeRateHistory();
  String _fromCurrency = 'USD';
  String _toCurrency = 'XAF';
  String _chartFromCurrency = 'USD';
  String _chartToCurrency = 'XAF';
  String _selectedPeriod = '24 heures';
  String _contact = '';
  ExchangeRateSnapshot? _snapshot;
  List<ExchangeRateHistoryPoint> _historyPoints = const [];
  late final Future<void> _historyReady;
  String? _historyError;
  Timer? _refreshTimer;
  String? _ratesError;
  bool _isRefreshing = false;
  bool _automaticRate = true;
  bool _useParallelRate = false;

  double get _amountValue => _number(_amount.text);
  double get _rateValue => _number(_rate.text);
  double get _feePercent => _number(_fees.text);
  double get _grossAmount => _amountValue * _rateValue;
  double get _feeAmount => _grossAmount * _feePercent / 100;
  double get _netAmount => _grossAmount - _feeAmount;
  double get _premiumPercent => _number(_premium.text);
  bool get _hasValidPremium {
    final value = double.tryParse(
      _premium.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    return value != null && value.isFinite && value >= 0;
  }
  double? get _parallelRate =>
      _hasValidPremium
          ? _snapshot?.parallelRate(
              _fromCurrency,
              _toCurrency,
              _premiumPercent,
            )
          : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historyReady = _loadRateHistory();
    _refreshRates();
    _refreshTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _refreshRates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _rateService.close();
    _amount.dispose();
    _rate.dispose();
    _fees.dispose();
    _premium.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRates();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.store.contacts
        .where(
          (contact) => contact.roles.any((role) => role.contains('échange')),
        )
        .map((contact) => contact.name)
        .toList();
    final selectedContact = contacts.contains(_contact)
        ? _contact
        : (contacts.isEmpty ? null : contacts.first);
    final cashAvailable = widget.store.bankBalances['Caisse (espèces)'] ?? 0;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.swap_horiz), text: 'Échange'),
              Tab(icon: Icon(Icons.show_chart), text: 'Graphique'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const PageHeading(
                      eyebrow: 'Comptoir · Devises',
                      title: 'Échanges',
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 720
                            ? (constraints.maxWidth - 20) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final pair in _ratePairs)
                              SizedBox(
                                width: cardWidth,
                                child: _buildRateCard(pair.$1, pair.$2),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: SectionHeading(
                                  'Nouvelle opération',
                                  icon: Icons.swap_horiz,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Actualiser les taux',
                                onPressed: _isRefreshing ? null : _refreshRates,
                                icon: _isRefreshing
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
                            _rateStatus,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _ratesError == null
                                      ? AppTheme.muted
                                      : AppTheme.red,
                                ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openRateProvider,
                              child: const Text(
                                'Taux d\'échange fournis par exchangerate',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const FieldLabel('Client de change'),
                          DropdownButtonFormField<String>(
                            initialValue: selectedContact,
                            decoration: fieldDecoration(
                              'Sélectionner un client',
                            ),
                            items: contacts
                                .map(
                                  (name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _contact = value ?? _contact),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _currencyDropdown('Vous recevez', true),
                              ),
                              IconButton(
                                tooltip: 'Inverser les devises',
                                onPressed: _swapCurrencies,
                                icon: const Icon(
                                  Icons.swap_vert,
                                  color: AppTheme.gold,
                                ),
                              ),
                              Expanded(
                                child: _currencyDropdown(
                                  'Vous remettez',
                                  false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  label: 'Montant reçu · $_fromCurrency',
                                  controller: _amount,
                                  hint: '0',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _numberField(
                                  label:
                                      'Taux appliqué · 1 $_fromCurrency = $_toCurrency',
                                  controller: _rate,
                                  hint: _snapshot == null
                                      ? 'En attente du taux'
                                      : '0',
                                  readOnly: _automaticRate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            label: 'Prime du taux parallèle (%)',
                            controller: _premium,
                            hint: '0',
                            onChanged: (_) {
                              setState(() {
                                if (_useParallelRate) _applyParallelRate();
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _parallelRate == null
                                ? 'Taux parallèle indisponible : vérifiez le taux officiel et la prime.'
                                : 'Taux parallèle = taux officiel × '
                                    '(1 + prime / 100) · '
                                    '${_formatRate(_snapshot!.rate(_fromCurrency, _toCurrency)!)} × '
                                    '(1 + ${_formatRate(_premiumPercent)} / 100) = '
                                    '${_formatRate(_parallelRate!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _useParallelRate,
                            title: const Text(
                              'Appliquer le taux parallèle calculé',
                            ),
                            onChanged: _parallelRate == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _useParallelRate = value;
                                      if (value) {
                                        _automaticRate = false;
                                        _applyParallelRate();
                                      } else {
                                        _automaticRate = true;
                                        _applyMarketRate();
                                      }
                                    });
                                  },
                          ),
                          Row(
                            children: [
                              const Expanded(child: Text('Taux automatique')),
                              Switch(
                                value: _automaticRate,
                                onChanged: (value) {
                                  setState(() {
                                    _automaticRate = value;
                                    _useParallelRate = false;
                                    if (value) _applyMarketRate();
                                  });
                                },
                              ),
                              if (!_automaticRate)
                                TextButton(
                                  onPressed: _snapshot == null
                                      ? null
                                      : () => setState(() {
                                          _automaticRate = true;
                                          _applyMarketRate();
                                        }),
                                  child: const Text('Taux du marché'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _numberField(
                            label: 'Frais (%)',
                            controller: _fees,
                            hint: '0',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.forest,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Montant net remis au client',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${money(_netAmount)} $_toCurrency',
                                  style: const TextStyle(
                                    color: Color(0xFF00D6A0),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Frais : ${money(_feeAmount)} $_toCurrency',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.paper,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Disponibilité en caisse (XAF) :',
                                  ),
                                ),
                                Text(
                                  '${money(cashAvailable)} XAF',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Stock disponible remis au client : '
                            '${_formatRate(widget.store.currencyBalances[_toCurrency] ?? 0)} $_toCurrency'
                            ' · après opération : '
                            '${_formatRate((widget.store.currencyBalances[_toCurrency] ?? 0) - _netAmount)} $_toCurrency',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Le stock physique doit être initialisé ou ajusté '
                            'dans Gestion du stock avant tout échange.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Valider le change',
                              onPressed: (_netAmount > 0 &&
                                      (widget.store.currencyBalances[_toCurrency] ??
                                              0) >=
                                          _netAmount)
                                  ? _save
                                  : null,
                              icon: Icons.check,
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
                            'Registre des échanges',
                            icon: Icons.receipt_long_outlined,
                          ),
                          const SizedBox(height: 8),
                          ...widget.store.exchanges.map(
                            (entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.swap_horiz,
                                color: AppTheme.gold,
                              ),
                              title: Text(entry),
                              subtitle: const Text('En cours'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildChartTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    final currentRate = _snapshot?.rate(_chartFromCurrency, _chartToCurrency);
    final period = _periods[_selectedPeriod]!;
    final cutoff = DateTime.now().subtract(period);
    final visiblePoints = _historyPoints
        .where((point) => point.observedAt.isAfter(cutoff))
        .toList();
    final firstRate = visiblePoints.isEmpty
        ? null
        : visiblePoints.first.rate(_chartFromCurrency, _chartToCurrency);
    final lastRate = visiblePoints.isEmpty
        ? currentRate
        : visiblePoints.last.rate(_chartFromCurrency, _chartToCurrency);
    final changePercent =
        firstRate == null || lastRate == null || firstRate == 0
        ? null
        : (lastRate - firstRate) / firstRate * 100;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const PageHeading(
          eyebrow: 'Marché des devises',
          title: 'Évolution des taux',
        ),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _chartCurrencyDropdown('De', true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: AppTheme.gold),
                  ),
                  Expanded(child: _chartCurrencyDropdown('Vers', false)),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: _periods.keys
                    .map(
                      (period) =>
                          ButtonSegment(value: period, label: Text(period)),
                    )
                    .toList(),
                selected: {_selectedPeriod},
                onSelectionChanged: (selection) =>
                    setState(() => _selectedPeriod = selection.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              if (_historyError != null)
                Text(
                  'Historique local indisponible : $_historyError',
                  style: const TextStyle(color: AppTheme.red),
                )
              else if (_historyPoints.isEmpty)
                const Text(
                  'Le graphique se remplira au fil des relevés, à partir de '
                  'l’activation du suivi sur cet appareil.',
                )
              else
                Text(
                  'Relevés conservés sur cet appareil. La source gratuite '
                  'publie ses cours une fois par jour : les variations horaires '
                  'ne sont donc pas disponibles avec cette source.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              if (currentRate != null)
                Text(
                  'Taux actuel : 1 $_chartFromCurrency = '
                  '${_formatRate(currentRate)} $_chartToCurrency'
                  '${changePercent == null ? '' : ' · ${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)} % sur la période'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 8),
              RateHistoryChart(
                points: _historyPoints,
                fromCurrency: _chartFromCurrency,
                toCurrency: _chartToCurrency,
                period: period,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartCurrencyDropdown(String label, bool isFrom) {
    final selected = isFrom ? _chartFromCurrency : _chartToCurrency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: fieldDecoration(''),
          items: _currencies
              .map(
                (currency) =>
                    DropdownMenuItem(value: currency, child: Text(currency)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              if (isFrom) {
                _chartFromCurrency = value;
              } else {
                _chartToCurrency = value;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildRateCard(String from, String to) {
    final rate = _snapshot?.rate(from, to);
    return AppPanel(
      padding: 14,
      child: Row(
        children: [
          Text(from, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, size: 17, color: AppTheme.gold),
          ),
          Text(to, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            rate == null ? '—' : _formatRate(rate),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _currencyDropdown(String label, bool isFrom) {
    final selected = isFrom ? _fromCurrency : _toCurrency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: fieldDecoration(''),
          items: _currencies
              .map(
                (currency) =>
                    DropdownMenuItem(value: currency, child: Text(currency)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              if (isFrom) {
                _fromCurrency = value;
              } else {
                _toCurrency = value;
              }
              if (_useParallelRate) {
                _applyParallelRate();
              } else if (_automaticRate) {
                _applyMarketRate();
              }
            });
          },
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDecoration(hint),
          onChanged: onChanged ??
              (_) => setState(() {
                if (identical(controller, _rate)) {
                  _useParallelRate = false;
                }
              }),
        ),
      ],
    );
  }

  String get _rateStatus {
    if (_isRefreshing && _snapshot == null) return 'Récupération des taux…';
    if (_ratesError != null && _snapshot == null) {
      return 'Taux indisponibles : $_ratesError. Saisissez un taux manuel.';
    }
    if (_snapshot == null) return 'Taux de référence non disponibles.';
    final date = _snapshot!.updatedAt;
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    if (_ratesError != null) {
      return 'Actualisation impossible : $_ratesError. '
          'Dernier taux reçu le $formatted conservé.';
    }
    return 'Taux fournisseur mis à jour le $formatted · vérification chaque heure '
        '(les cours sont publiés une fois par jour).';
  }

  Future<void> _refreshRates() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _ratesError = null;
    });
    try {
      final snapshot = await _rateService.fetchRates();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (_useParallelRate) {
          _applyParallelRate();
        } else if (_automaticRate) {
          _applyMarketRate();
        }
      });
      try {
        await _historyReady;
        final points = await _rateHistory.record(snapshot);
        if (mounted) {
          setState(() {
            _historyPoints = points;
            _historyError = null;
          });
        }
      } catch (error) {
        if (mounted) setState(() => _historyError = error.toString());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _ratesError = error.toString());
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadRateHistory() async {
    try {
      final points = await _rateHistory.load();
      if (mounted) setState(() => _historyPoints = points);
    } catch (error) {
      if (mounted) setState(() => _historyError = error.toString());
    }
  }

  void _applyMarketRate() {
    final rate = _snapshot?.rate(_fromCurrency, _toCurrency);
    _rate.text = rate == null ? '' : _formatRate(rate);
  }

  void _applyParallelRate() {
    final rate = _parallelRate;
    _rate.text = rate == null ? '' : _formatRate(rate);
  }

  void _swapCurrencies() {
    setState(() {
      final oldFrom = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = oldFrom;
      if (_useParallelRate) {
        _applyParallelRate();
      } else if (_automaticRate) {
        _applyMarketRate();
      }
    });
  }

  Future<void> _openRateProvider() async {
    final opened = await launchUrl(
      Uri.https('www.exchangerate-api.com'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir le site du fournisseur.'),
        ),
      );
    }
  }

  void _save() {
    if (_amountValue <= 0 ||
        _rateValue <= 0 ||
        _feePercent < 0 ||
        _feePercent > 100 ||
        !_hasValidPremium ||
        (_useParallelRate && _parallelRate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Renseignez un montant, un taux positif, une prime positive ou nulle et des frais entre 0 et 100 %.',
          ),
        ),
      );
      return;
    }
    final contacts = widget.store.contacts
        .where(
          (contact) => contact.roles.any((role) => role.contains('échange')),
        )
        .map((contact) => contact.name)
        .toList();
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ajoutez d’abord un client de change dans les contacts.',
          ),
        ),
      );
      return;
    }
    final contact = contacts.contains(_contact) ? _contact : contacts.first;
    try {
      widget.store.addExchange(
        '$contact · ${money(_amountValue)} $_fromCurrency → '
        '${money(_netAmount)} $_toCurrency · taux ${_formatRate(_rateValue)} · '
        'frais ${_formatRate(_feePercent)} %'
        '${_useParallelRate ? ' · prime ${_formatRate(_premiumPercent)} %' : ''}'
        '${_snapshot == null ? '' : ' · référence ${_dateTime(_snapshot!.updatedAt)}'}',
        receivedCurrency: _fromCurrency,
        receivedAmount: _amountValue,
        deliveredCurrency: _toCurrency,
        deliveredAmount: _netAmount,
      );
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
      return;
    }
    _amount.clear();
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Change enregistré.')));
  }

  static double _number(String text) =>
      double.tryParse(text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

  static String _formatRate(double value) {
    if (value == 0) return '0';
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',');
  }

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
