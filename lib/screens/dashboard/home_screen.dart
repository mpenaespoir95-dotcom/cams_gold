import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/gold_price_service.dart';
import '../../shared/widgets/app_widgets.dart';

const _ink = Color(0xFF17313D);
const _muted = Color(0xFF71828B);
const _gold = Color(0xFFE5AC32);
const _green = Color(0xFF16A477);
const _blue = Color(0xFF438BDD);
const _purple = Color(0xFF8969D6);
const _red = Color(0xFFED786E);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.onNavigate});

  final AppStore store;
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _goldPriceService = GoldPriceService();
  final _exchangeRateService = ExchangeRateService();
  GoldPriceQuote? _goldQuote;
  ExchangeRateSnapshot? _exchangeRates;
  ExchangeRateSnapshot? _previousExchangeRates;
  Timer? _refreshTimer;
  bool _isRefreshingRates = false;
  String? _ratesError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRates();
    _refreshTimer = Timer.periodic(
      GoldPriceService.refreshInterval,
      (_) => _refreshRates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _goldPriceService.close();
    _exchangeRateService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRates();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final mainColumn = _buildMainColumn(context);
        final content = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mainColumn),
                  const SizedBox(width: 18),
                  SizedBox(width: 238, child: _buildRightColumn(context)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  mainColumn,
                  const SizedBox(height: 18),
                  _buildRightColumn(context),
                ],
              );

        return Container(
          color: const Color(0xFFFAF8F3),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 18,
              18,
              wide ? 28 : 18,
              26,
            ),
            child: content,
          ),
        );
      },
    );
  }
  Widget _buildMainColumn(BuildContext context) {
    final cashBalance = widget.store.bankBalances['Caisse (espèces)'] ?? 0;
    final exchangeTotal = _totalFor('échange');
    final recentOperations = widget.store.operations.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bonjour ${widget.store.userName},',
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Bienvenue sur votre espace Comptoir d’Or',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 590
                ? 4
                : constraints.maxWidth >= 360
                ? 2
                : 1;
            final gap = 12.0;
            final width =
                (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                _StatCard(
                  width: width,
                  title: 'Caisse',
                  value: '${money(cashBalance)} FCFA',
                  subtitle: 'solde en espèces',
                  icon: Icons.account_balance_wallet_outlined,
                  color: _gold,
                  background: const Color(0xFFFFF9EA),
                ),
                _StatCard(
                  width: width,
                  title: 'Bénéfice total',
                  value: '${money(widget.store.totalProfit)} FCFA',
                  subtitle: 'bénéfices enregistrés',
                  icon: Icons.flight_takeoff,
                  color: _blue,
                  background: const Color(0xFFF0F6FD),
                ),
                _StatCard(
                  width: width,
                  title: 'Stock de devises',
                  value: '${money(exchangeTotal)} FCFA',
                  subtitle:
                      '${widget.store.exchanges.length} opérations de change',
                  icon: Icons.swap_horiz,
                  color: _green,
                  background: const Color(0xFFF0F8F3),
                ),
                _StatCard(
                  width: width,
                  title: 'Partenariats',
                  value: '${widget.store.partnerships.length}',
                  subtitle: 'partenaires actifs',
                  icon: Icons.handshake_outlined,
                  color: _purple,
                  background: const Color(0xFFF6F2FC),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _ActivityPanel(store: widget.store),
        const SizedBox(height: 12),
        _QuickAccess(onNavigate: widget.onNavigate),
        const SizedBox(height: 12),
        _UnprocessedOperations(
          operations: widget.store.unprocessedOperations,
          onMarkProcessed: widget.store.markOperationProcessed,
        ),
        const SizedBox(height: 12),
        _RecentOperations(
          operations: recentOperations,
          onSeeAll: () => widget.onNavigate(1),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_weekday(now.weekday)} ${now.day} ${_month(now.month)} ${now.year}';
    return Column(
      children: [
        _DateCard(date: date),
        const SizedBox(height: 12),
        _RatesCard(
          usdToXaf: _exchangeRates?.rate('USD', 'XAF'),
          eurToXaf: _exchangeRates?.rate('EUR', 'XAF'),
          gold24kToXaf: _goldPriceInXaf(24),
          gold18kToXaf: _goldPriceInXaf(18),
          usdChange: _rateChange('USD', 'XAF'),
          eurChange: _rateChange('EUR', 'XAF'),
          goldChange: _goldQuote?.changePercent,
          isRefreshing: _isRefreshingRates,
          error: _ratesError,
          updatedAt: _goldQuote?.updatedAt,
          onRefresh: _refreshRates,
        ),
        const SizedBox(height: 12),
        _AppointmentsCard(
          contacts: widget.store.contactsWithAppointments,
          onSeeAll: () => widget.onNavigate(7),
        ),
        const SizedBox(height: 12),
        _SupportCard(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contactez-nous au +237 6 00 00 00 00.'),
            ),
          ),
        ),
      ],
    );
  }

  double _totalFor(String keyword) => widget.store.operations
      .where((operation) => operation.title.toLowerCase().contains(keyword))
      .fold(0, (total, operation) => total + operation.amount);

  double? _goldPriceInXaf(int karat) {
    final usdToXaf = _exchangeRates?.rate('USD', 'XAF');
    final quote = _goldQuote;
    if (usdToXaf == null || quote == null) return null;
    return quote.pricePerKaratGramUsd(karat) * usdToXaf;
  }

  double? _rateChange(String from, String to) {
    final previous = _previousExchangeRates?.rate(from, to);
    final current = _exchangeRates?.rate(from, to);
    if (previous == null || current == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  Future<void> _refreshRates() async {
    if (_isRefreshingRates) return;
    if (mounted) {
      setState(() {
        _isRefreshingRates = true;
        _ratesError = null;
      });
    }

    GoldPriceQuote? goldQuote;
    ExchangeRateSnapshot? rates;
    String? goldError;
    String? exchangeError;
    try {
      goldQuote = await _goldPriceService.fetchGoldUsd();
    } catch (error) {
      goldError = error.toString();
    }
    try {
      rates = await _exchangeRateService.fetchRates();
    } catch (error) {
      exchangeError = error.toString();
    }

    if (!mounted) return;
    setState(() {
      if (rates != null) {
        _previousExchangeRates = _exchangeRates;
        _exchangeRates = rates;
      }
      if (goldQuote != null) _goldQuote = goldQuote;
      final errors = [
        if (goldError != null) 'Or : $goldError',
        if (exchangeError != null) 'Devises : $exchangeError',
      ];
      _ratesError = errors.isEmpty ? null : errors.join(' · ');
      _isRefreshingRates = false;
    });
  }

  static String _formatChange(double? change) {
    if (change == null) return '—';
    return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2).replaceAll('.', ',')}%';
  }

  static String _formatXaf(double? value) =>
      value == null ? '—' : '${money(value)} XAF';

  String _weekday(int day) => const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ][day - 1];

  String _month(int month) => const [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ][month - 1];
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAECEF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08313C45),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.operations.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    return _DashboardPanel(
      title: 'Activité récente',
      icon: Icons.bar_chart,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 450;
          return Row(
            children: [
              SizedBox(
                width: compact ? 132 : 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Montant des opérations',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${money(total)} FCFA',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${store.operations.length} opérations enregistrées',
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: SizedBox(
                  height: 92,
                  child: CustomPaint(
                    painter: _ActivityChartPainter(),
                    child: const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 0),
                        child: Text(
                          '08h        10h        12h        14h        16h        18h        20h',
                          style: TextStyle(color: _muted, fontSize: 8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 18;
    final grid = Paint()
      ..color = const Color(0xFFEFF1F2)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = row * chartHeight / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final points = <Offset>[
      Offset(0, chartHeight * .83),
      Offset(size.width * .12, chartHeight * .65),
      Offset(size.width * .22, chartHeight * .72),
      Offset(size.width * .34, chartHeight * .46),
      Offset(size.width * .45, chartHeight * .58),
      Offset(size.width * .57, chartHeight * .32),
      Offset(size.width * .68, chartHeight * .44),
      Offset(size.width * .79, chartHeight * .20),
      Offset(size.width * .90, chartHeight * .28),
      Offset(size.width, chartHeight * .10),
    ];
    final curve = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middleX = (previous.dx + current.dx) / 2;
      curve.cubicTo(
        middleX,
        previous.dy,
        middleX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final fill = Path.from(curve)
      ..lineTo(size.width, chartHeight)
      ..lineTo(0, chartHeight)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x66E5AC32), Color(0x08E5AC32)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & Size(size.width, chartHeight)),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(points.last, 4, Paint()..color = _gold);
    canvas.drawCircle(points.last, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Caisse', Icons.inventory_2_outlined, _gold, Color(0xFFFFF9EA), 1),
      ('Stock Or', Icons.flight_takeoff, _blue, Color(0xFFF0F6FD), 2),
      ('Devise', Icons.swap_horiz, _green, Color(0xFFF0F8F3), 3),
      ('Partenariats', Icons.handshake_outlined, _purple, Color(0xFFF6F2FC), 4),
      (
        'Banques & versements',
        Icons.account_balance_outlined,
        _blue,
        Color(0xFFF0F6FD),
        5,
      ),
      (
        'Clients & fournisseurs',
        Icons.people_outline,
        _red,
        Color(0xFFFFF3F1),
        6,
      ),
      ('SMS', Icons.sms_outlined, _green, Color(0xFFF0F8F3), 7),
    ];
    return _DashboardPanel(
      title: 'Accès rapide',
      icon: Icons.bolt,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 520 ? 3 : 2;
          final gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: 10,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _QuickAccessTile(
                    label: item.$1,
                    icon: item.$2,
                    color: item.$3,
                    background: item.$4,
                    onTap: () => onNavigate(item.$5),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Icon(icon, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, color: color, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnprocessedOperations extends StatelessWidget {
  const _UnprocessedOperations({
    required this.operations,
    required this.onMarkProcessed,
  });

  final List<LedgerEntry> operations;
  final ValueChanged<LedgerEntry> onMarkProcessed;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Opérations non traitées',
      icon: Icons.pending_actions_outlined,
      trailing: Text(
        '${operations.length}',
        style: TextStyle(
          color: operations.isNotEmpty ? _red : _green,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
      child: operations.isEmpty
          ? const Text(
              'Aucune opération en attente.',
              style: TextStyle(color: _muted, fontSize: 11),
            )
          : Column(
              children: [
                for (final operation in operations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      operation.isIncome ? Icons.south_west : Icons.north_east,
                      color: operation.isIncome ? _green : _gold,
                    ),
                    title: Text(
                      operation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${operation.subtitle} · ${operation.date}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                    trailing: IconButton(
                      tooltip: 'Marquer comme traitée',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onMarkProcessed(operation),
                      icon: const Icon(Icons.check_circle_outline, color: _red),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentOperations extends StatelessWidget {
  const _RecentOperations({required this.operations, required this.onSeeAll});

  final List<LedgerEntry> operations;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Dernières opérations',
      icon: Icons.schedule,
      trailing: TextButton(
        onPressed: onSeeAll,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Voir tout',
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      ),
      child: Column(
        children: [
          const _OperationRow(
            date: 'Date',
            type: 'Type',
            detail: 'Détail',
            amount: 'Montant',
            status: 'Statut',
            header: true,
          ),
          for (final operation in operations)
            _OperationRow(
              date: operation.date,
              type: operation.title,
              detail: operation.subtitle,
              amount:
                  '${operation.isIncome ? '+' : '−'} ${money(operation.amount)} FCFA',
              status: '',
              income: operation.isIncome,
              isProcessed: operation.isProcessed,
            ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.date,
    required this.type,
    required this.detail,
    required this.amount,
    required this.status,
    this.header = false,
    this.income = false,
    this.isProcessed = false,
  });

  final String date;
  final String type;
  final String detail;
  final String amount;
  final String status;
  final bool header;
  final bool income;
  final bool isProcessed;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? _muted : _ink,
      fontSize: header ? 8 : 9,
      fontWeight: header || income ? FontWeight.w700 : FontWeight.w500,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 25),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF7F8F9) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Color(0xFFF0F1F2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 520)
            Expanded(
              flex: 4,
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          Expanded(
            flex: 4,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: header
                  ? style
                  : style.copyWith(color: income ? _green : AppTheme.red),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: header
                  ? Text(status, style: style)
                  : Text(
                      isProcessed ? 'Traitée' : 'Non traitée',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: isProcessed ? _green : _red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return _SideCard(
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: _ink, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$date\n${TimeOfDay.now().format(context)}',
              style: const TextStyle(
                color: _ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard({required this.contacts, required this.onSeeAll});

  final List<Contact> contacts;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Rendez-vous fixés',
      icon: Icons.event_available_outlined,
      trailing: TextButton(
        onPressed: onSeeAll,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Voir tout',
          style: TextStyle(color: _muted, fontSize: 9),
        ),
      ),
      child: contacts.isEmpty
          ? const Text(
              'Aucun rendez-vous fixé.',
              style: TextStyle(color: _muted, fontSize: 10),
            )
          : Column(
              children: [
                for (final contact in contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: _gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${contact.appointment} · ${contact.city}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({
    required this.usdToXaf,
    required this.eurToXaf,
    required this.gold24kToXaf,
    required this.gold18kToXaf,
    required this.usdChange,
    required this.eurChange,
    required this.goldChange,
    required this.isRefreshing,
    required this.error,
    required this.updatedAt,
    required this.onRefresh,
  });

  final double? usdToXaf;
  final double? eurToXaf;
  final double? gold24kToXaf;
  final double? gold18kToXaf;
  final double? usdChange;
  final double? eurChange;
  final double? goldChange;
  final bool isRefreshing;
  final String? error;
  final DateTime? updatedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _SideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: _ink, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cours de référence',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser les cours',
                onPressed: isRefreshing ? null : onRefresh,
                visualDensity: VisualDensity.compact,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.refresh,
                        color: _ink.withValues(alpha: .8),
                        size: 15,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 26),
            child: Text(
              'Taux indicatifs',
              style: TextStyle(color: _muted, fontSize: 8),
            ),
          ),
          const SizedBox(height: 11),
          _RateRow(
            flag: '🇺🇸',
            title: '1 USD',
            value: _HomeScreenState._formatXaf(usdToXaf),
            change: _HomeScreenState._formatChange(usdChange),
            changePercent: usdChange,
          ),
          const Divider(height: 13, color: Color(0xFFECEFF1)),
          _RateRow(
            flag: '🇪🇺',
            title: '1 EUR',
            value: _HomeScreenState._formatXaf(eurToXaf),
            change: _HomeScreenState._formatChange(eurChange),
            changePercent: eurChange,
          ),
          const Divider(height: 13, color: Color(0xFFECEFF1)),
          _RateRow(
            flag: '🟡',
            title: '24K',
            value: gold24kToXaf == null ? '—' : '${money(gold24kToXaf!)} XAF/g',
            change: _HomeScreenState._formatChange(goldChange),
            changePercent: goldChange,
          ),
          const SizedBox(height: 10),
          _RateRow(
            flag: '⚪',
            title: '18K',
            value: gold18kToXaf == null ? '—' : '${money(gold18kToXaf!)} XAF/g',
            change: _HomeScreenState._formatChange(goldChange),
            changePercent: goldChange,
          ),
          if (isRefreshing || updatedAt != null || error != null) ...[
            const SizedBox(height: 8),
            Text(
              error ??
                  (isRefreshing
                      ? 'Actualisation en cours…'
                      : 'Cours de l’or mis à jour à '
                            '${updatedAt!.hour.toString().padLeft(2, '0')}:'
                            '${updatedAt!.minute.toString().padLeft(2, '0')}'),
              style: TextStyle(
                color: error == null ? _muted : _red,
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.flag,
    required this.title,
    required this.value,
    required this.change,
    required this.changePercent,
  });

  final String flag;
  final String title;
  final String value;
  final String change;
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 25,
          child: Text(flag, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _muted, fontSize: 9)),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${changePercent == null
              ? ''
              : changePercent! >= 0
              ? '▲ '
              : '▼ '}$change',
          style: TextStyle(
            color: changePercent == null
                ? _muted
                : changePercent! >= 0
                ? _green
                : _red,
            fontWeight: FontWeight.w700,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF3E1B9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 11,
                backgroundColor: _gold,
                child: Icon(Icons.call, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Besoin d’assistance ?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Notre équipe est à votre écoute',
                      style: TextStyle(color: _muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 33,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.call, size: 13),
              label: const Text(
                'Nous contacter',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAECEF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08313C45),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
