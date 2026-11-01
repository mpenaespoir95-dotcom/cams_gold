import 'package:flutter/material.dart';

class ModuleHomeScreen extends StatelessWidget {
  const ModuleHomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  static const _modules = [
    _Module('Accueil', Icons.home_outlined, 0),
    _Module('Caisse', Icons.account_balance_wallet_outlined, 1),
    _Module('Vente', Icons.shopping_bag_outlined, 2),
    _Module('Stock Devise', Icons.currency_exchange_outlined, 3),
    _Module('Partenaires', Icons.handshake_outlined, 4),
    _Module('Banques', Icons.account_balance_outlined, 5),
    _Module('Gestion Stock', Icons.inventory_2_outlined, 10),
    _Module('Rapports', Icons.bar_chart_outlined, 9),
    _Module('RDV/SMS', Icons.event_note_outlined, 7),
    _Module('Clients/Fournisseurs', Icons.people_outline, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const minimumTileWidth = 140.0;
        const maximumTileWidth = 240.0;
        const maximumColumns = 4;
        final horizontalPadding = constraints.maxWidth >= 650 ? 30.0 : 18.0;
        final availableWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, double.infinity)
            .toDouble();
        final contentWidth = availableWidth.clamp(
          0.0,
          maximumTileWidth * maximumColumns + spacing * (maximumColumns - 1),
        );
        final columns =
            ((contentWidth + spacing) / (minimumTileWidth + spacing))
                .floor()
                .clamp(1, maximumColumns);
        final tileWidth = (contentWidth - spacing * (columns - 1)) / columns;
        final tileHeight = tileWidth.clamp(92.0, 112.0).toDouble();

        return Container(
          color: const Color(0xFFE7E8E9),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              24,
            ),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final module in _modules)
                      SizedBox(
                        width: tileWidth,
                        child: _ModuleTile(
                          module: module,
                          height: tileHeight,
                          onTap: () => _openModule(context, module),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openModule(BuildContext context, _Module module) {
    if (module.destination != 7) {
      onNavigate(module.destination);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Rendez-vous'),
              onTap: () {
                Navigator.pop(context);
                onNavigate(7);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS'),
              onTap: () {
                Navigator.pop(context);
                onNavigate(8);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.height,
    required this.onTap,
  });

  final _Module module;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(15));
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE1A3), Color(0xFFFFD27A)],
          ),
          border: Border.all(color: const Color(0xFFE7AD35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(module.icon, size: 27, color: const Color(0xFF17140D)),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    module.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF17140D),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Module {
  const _Module(this.label, this.icon, this.destination);

  final String label;
  final IconData icon;
  final int destination;
}
