import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../appointments/appointments_screen.dart';
import '../banks/banks_screen.dart';
import '../cash/cash_screen.dart';
import '../contacts/contacts_screen.dart';
import '../dashboard/home_screen.dart';
import '../dashboard/module_home_screen.dart';
import '../exchanges/exchanges_screen.dart';
import '../partnerships/partnerships_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/sales_screen.dart';
import '../sms/sms_screen.dart';
import '../stock/stock_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, required this.onSignOut});

  final AppStore store;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selected = 11;

  static const _destinations = [
    _Destination('Accueil', Icons.dashboard_outlined),
    _Destination('Caisse', Icons.balance_outlined),
    _Destination('Ventes Dubaï', Icons.flight_takeoff_outlined),
    _Destination('Échanges', Icons.swap_horiz),
    _Destination('Partenariats', Icons.handshake_outlined),
    _Destination('Banques & versements', Icons.account_balance_outlined),
    _Destination('Clients & fournisseurs', Icons.people_outline),
    _Destination('Rendez-vous', Icons.event_available_outlined),
    _Destination('SMS', Icons.sms_outlined),
    _Destination('Rapports', Icons.summarize_outlined),
    _Destination('Gestion du stock', Icons.inventory_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1080) {
              return _buildDesktopShell(context);
            }
            return _buildMobileShell(context);
          },
        );
      },
    );
  }

  Widget _buildMobileShell(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: AppTheme.forest,
              foregroundColor: AppTheme.gold,
              child: Text(widget.store.userName.characters.first.toUpperCase()),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            if (_selected != 11) _buildModulesBackButton(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(key: ValueKey(_selected), child: _page()),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (index) => _select([0, 1, 2, 6, 7][index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.balance_outlined),
            label: 'Caisse',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            label: 'Dubaï',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            label: 'RDV',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopShell(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F3),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildDesktopHeader(),
            Expanded(
              child: Column(
                children: [
                  if (_selected != 11) _buildModulesBackButton(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_selected),
                        child: _page(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextButton.icon(
          onPressed: () => _select(11),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Retour aux modules'),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      color: AppTheme.forest,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _select(11),
            child: SizedBox(
              width: 330,
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 49,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'lib/assets/images/cams_gold.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Comptoir d'Or",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'OR · DEVISES · PARTENAIRES',
                          style: TextStyle(
                            color: Color(0xFFF2BD45),
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText:
                          'Rechercher une opération, un client, un numéro...',
                      hintStyle: const TextStyle(
                        color: Color(0xFFB9C4C6),
                        fontSize: 11,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .12),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: .14),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: .14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(
            height: 25,
            child: VerticalDivider(color: Colors.white38, width: 22),
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFF1C756),
            foregroundColor: AppTheme.forest,
            child: Text(widget.store.userName.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 9),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bienvenue',
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
              Text(
                widget.store.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white70,
            size: 18,
          ),
        ],
      ),
    );
  }

  int get _bottomIndex => switch (_selected) {
    1 => 1,
    2 => 2,
    6 => 3,
    7 => 4,
    _ => 0,
  };

  Widget _page() => switch (_selected) {
    1 => CashScreen(store: widget.store),
    2 => SalesScreen(store: widget.store),
    3 => ExchangesScreen(store: widget.store),
    4 => PartnershipsScreen(store: widget.store),
    5 => BanksScreen(store: widget.store),
    6 => ContactsScreen(store: widget.store),
    7 => AppointmentsScreen(store: widget.store),
    8 => SmsScreen(store: widget.store),
    9 => ReportsScreen(store: widget.store),
    10 => StockScreen(store: widget.store),
    11 => ModuleHomeScreen(onNavigate: _select),
    _ => HomeScreen(store: widget.store, onNavigate: _select),
  };

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 30, 20, 24),
            child: BrandMark(),
          ),
          ...List.generate(_destinations.length, (index) {
            final item = _destinations[index];
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: _selected == index,
              selectedTileColor: AppTheme.gold.withValues(alpha: 0.18),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _select(index);
              },
            );
          }),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: widget.onSignOut,
          ),
        ],
      ),
    );
  }

  void _select(int index) => setState(() => _selected = index);
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}
