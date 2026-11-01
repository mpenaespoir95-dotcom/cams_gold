import 'package:flutter/material.dart';

import '../../core/app_store.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../purchases/purchases_screen.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  bool _isPurchaseFormOpen = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          if (!_isPurchaseFormOpen) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: PageHeading(
                eyebrow: 'Trésorerie · Opérations',
                title: 'Caisse',
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.balance_outlined), text: 'Achat'),
                Tab(icon: Icon(Icons.swap_horiz), text: 'Virements'),
                Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Dépenses'),
                Tab(icon: Icon(Icons.south_west), text: 'Versements'),
              ],
            ),
          ],
          Expanded(
            child: TabBarView(
              children: [
                PurchasesScreen(
                  store: widget.store,
                  onFormVisibilityChanged: (isOpen) {
                    setState(() => _isPurchaseFormOpen = isOpen);
                  },
                ),
                _CashMovementForm(store: widget.store, isTransfer: true),
                _CashMovementForm(store: widget.store, isTransfer: false),
                _CashDeposits(store: widget.store),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashDeposits extends StatelessWidget {
  const _CashDeposits({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final deposits = store.operations
        .where((operation) => operation.isDeposit)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Versements enregistrés',
                icon: Icons.south_west,
              ),
              const SizedBox(height: 8),
              if (deposits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Aucun versement enregistré.'),
                )
              else
                ...deposits.map(
                  (deposit) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.green,
                    ),
                    title: Text(deposit.title),
                    subtitle: Text('${deposit.subtitle} · ${deposit.date}'),
                    trailing: Text(
                      '+ ${money(deposit.amount)} FCFA',
                      style: const TextStyle(
                        color: AppTheme.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashMovementForm extends StatefulWidget {
  const _CashMovementForm({required this.store, required this.isTransfer});

  final AppStore store;
  final bool isTransfer;

  @override
  State<_CashMovementForm> createState() => _CashMovementFormState();
}

class _CashMovementFormState extends State<_CashMovementForm> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _account;
  String? _destination;

  double get _amountValue =>
      double.tryParse(
        _amount.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
      ) ??
      0;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.bankBalances.keys.toList();
    if (!accounts.contains(_account)) {
      _account = accounts.contains('Caisse (espèces)')
          ? 'Caisse (espèces)'
          : accounts.firstOrNull;
    }
    if (widget.isTransfer &&
        (!accounts.contains(_destination) || _destination == _account)) {
      _destination = accounts
          .where((account) => account != _account)
          .firstOrNull;
    }
    final balance = widget.store.bankBalances[_account] ?? 0;
    final isTransfer = widget.isTransfer;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                isTransfer ? 'Nouveau virement' : 'Nouvelle dépense',
                icon: isTransfer
                    ? Icons.swap_horiz
                    : Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Compte source'),
              DropdownButtonFormField<String>(
                initialValue: _account,
                decoration: fieldDecoration('Choisir un compte'),
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
                onChanged: (value) => setState(() {
                  _account = value;
                  if (_destination == value) {
                    _destination = accounts
                        .where((account) => account != value)
                        .firstOrNull;
                  }
                }),
              ),
              if (isTransfer) ...[
                const SizedBox(height: 14),
                const FieldLabel('Compte destinataire'),
                DropdownButtonFormField<String>(
                  initialValue: _destination,
                  decoration: fieldDecoration('Choisir un compte'),
                  items: accounts
                      .where((account) => account != _account)
                      .map(
                        (account) => DropdownMenuItem(
                          value: account,
                          child: Text(
                            '$account · ${money(widget.store.bankBalances[account]!)} FCFA',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _destination = value),
                ),
              ],
              const SizedBox(height: 14),
              const FieldLabel('Montant (FCFA)'),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: fieldDecoration('0'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              FieldLabel(
                isTransfer ? 'Motif du virement' : 'Motif de la dépense',
              ),
              TextField(
                controller: _description,
                decoration: fieldDecoration(
                  isTransfer
                      ? 'Ex. transfert de trésorerie'
                      : 'Ex. fournitures',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isTransfer
                    ? 'Solde après virement : ${money(balance - _amountValue)} FCFA'
                    : 'Solde après dépense : ${money(balance - _amountValue)} FCFA',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: isTransfer
                    ? 'Enregistrer le virement'
                    : 'Enregistrer la dépense',
                icon: isTransfer
                    ? Icons.swap_horiz
                    : Icons.check_circle_outline,
                onPressed: _save,
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
                isTransfer ? 'Virements récents' : 'Dépenses récentes',
                icon: Icons.history,
              ),
              const SizedBox(height: 8),
              ...widget.store.operations
                  .where(
                    (entry) => isTransfer
                        ? entry.title.startsWith('Virement · ')
                        : entry.title.startsWith('Dépense · '),
                  )
                  .take(10)
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.title),
                      subtitle: Text('${entry.subtitle} · ${entry.date}'),
                      trailing: Text(
                        '${money(entry.amount)} FCFA',
                        style: TextStyle(
                          color: isTransfer ? AppTheme.forest : AppTheme.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              if (!widget.store.operations.any(
                (entry) => isTransfer
                    ? entry.title.startsWith('Virement · ')
                    : entry.title.startsWith('Dépense · '),
              ))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Aucune opération enregistrée.'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _save() {
    final account = _account;
    final description = _description.text.trim();
    if (account == null || _amountValue <= 0 || description.isEmpty) {
      _message('Renseignez le compte, un montant positif et un motif.');
      return;
    }
    try {
      if (widget.isTransfer) {
        final destination = _destination;
        if (destination == null) {
          _message('Choisissez un compte destinataire différent.');
          return;
        }
        widget.store.transferFunds(
          fromAccount: account,
          toAccount: destination,
          amount: _amountValue,
          label: description,
        );
      } else {
        widget.store.addExpense(
          account: account,
          amount: _amountValue,
          description: description,
        );
      }
    } on ArgumentError catch (error) {
      _message(error.message.toString());
      return;
    }
    _amount.clear();
    _description.clear();
    setState(() {});
    _message(
      widget.isTransfer ? 'Virement enregistré.' : 'Dépense enregistrée.',
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
