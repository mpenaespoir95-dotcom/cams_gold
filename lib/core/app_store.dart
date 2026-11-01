import 'package:flutter/foundation.dart';

int? goldKaratValue(String karat) {
  final normalized = karat.trim().toUpperCase();
  final value = int.tryParse(
    normalized.endsWith('K')
        ? normalized.substring(0, normalized.length - 1)
        : normalized,
  );
  return value != null && value >= 1 && value <= 24 ? value : null;
}

bool isValidGoldKarat(String karat) => goldKaratValue(karat) != null;

const goldStockCategories = ['Or brut', 'Bijoux', 'Or fondu', 'Non catégorisé'];

class Contact {
  Contact({
    required this.name,
    required this.phone,
    required this.city,
    required this.roles,
    this.reference = '',
    this.email = '',
    this.notes = '',
    this.appointment,
  });

  String reference;
  final String name;
  final String phone;
  final String city;
  final String email;
  final String notes;
  final Set<String> roles;
  String? appointment;
}

class LedgerEntry {
  LedgerEntry({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    this.isIncome = false,
    this.isProcessed = false,
    this.isTransfer = false,
    this.isDeposit = false,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final bool isIncome;
  final bool isTransfer;
  final bool isDeposit;
  bool isProcessed;
}

class PurchaseRecord {
  PurchaseRecord({
    required this.description,
    required this.amount,
    required this.purchasedAt,
    this.reference,
    this.supplier,
    this.grossWeightGrams,
    this.nonGoldWeightGrams,
    this.karat,
    this.goldCategory = 'Non catégorisé',
    this.purityPercent,
    this.referencePricePerGram,
    this.discountPercent,
    this.goldPricePerTroyOunceUsd,
    this.usdToXafRate,
    this.rateObservedAt,
    List<PurchasePayment>? payments,
    List<Uint8List>? photos,
    this.cancelledAt,
    this.cancellationReason,
  }) : payments = payments ?? [],
       photos = photos ?? [];

  final String description;
  final double amount;
  final DateTime purchasedAt;
  final String? reference;
  final String? supplier;
  final double? grossWeightGrams;
  final double? nonGoldWeightGrams;
  final String? karat;
  final String goldCategory;
  final double? purityPercent;
  final double? referencePricePerGram;
  final double? discountPercent;
  final double? goldPricePerTroyOunceUsd;
  final double? usdToXafRate;
  final DateTime? rateObservedAt;
  final List<PurchasePayment> payments;
  final List<Uint8List> photos;
  DateTime? cancelledAt;
  String? cancellationReason;

  double? get netWeightGrams {
    final gross = grossWeightGrams;
    final nonGold = nonGoldWeightGrams;
    if (gross == null || nonGold == null) return null;
    return gross - nonGold;
  }

  double get fineGoldWeightGrams =>
      (netWeightGrams ?? 0) * (purityPercent ?? 0) / 100;

  double get paidAmount =>
      payments.fold(0, (total, payment) => total + payment.amount);

  double get remainingAmount => (amount - paidAmount).clamp(0, amount);

  bool get isCancelled => cancelledAt != null;
}

class PurchasePayment {
  PurchasePayment({
    required this.amount,
    required this.paidAt,
    required this.method,
    this.note = '',
    this.account,
  });

  final double amount;
  final DateTime paidAt;
  final String method;
  final String note;
  final String? account;
}

class GoldStockMovement {
  GoldStockMovement({
    required this.label,
    required this.karat,
    required this.weightGrams,
    required this.date,
    required this.type,
    this.category = 'Non catégorisé',
    this.reason,
  });

  final String label;
  final String karat;
  final double weightGrams;
  final DateTime date;
  final String type;
  final String category;
  final String? reason;
}

class CurrencyStockMovement {
  CurrencyStockMovement({
    required this.currency,
    required this.amount,
    required this.type,
    required this.label,
    required this.date,
  });

  final String currency;
  final double amount;
  final String type;
  final String label;
  final DateTime date;
}

class AppStore extends ChangeNotifier {
  String userName = 'Aminata';
  bool isSignedIn = false;

  final List<Contact> contacts = [
    Contact(
      reference: 'CLI-00001',
      name: 'Moussa Diakité',
      phone: '+223 76 41 08 92',
      city: 'Bamako',
      roles: {'Fournisseur d’or'},
      appointment: '20 oct. · 10h30',
    ),
    Contact(
      reference: 'CLI-00002',
      name: 'Awa Traoré Bijouterie',
      phone: '+225 07 58 33 14',
      city: 'Abidjan',
      roles: {'Client d’or', 'Fournisseur d’or'},
      appointment: '19 oct. · 15h00',
    ),
    Contact(
      reference: 'CLI-00003',
      name: 'Al Noor Gold Trading',
      phone: '+971 4 226 8814',
      city: 'Dubaï',
      roles: {'Client d’or'},
      appointment: '24 oct. · 09h00',
    ),
    Contact(
      reference: 'CLI-00004',
      name: 'Jean-Paul Mbarga',
      phone: '+237 6 77 21 45 09',
      city: 'Douala',
      roles: {'Client d’échange'},
    ),
    Contact(
      reference: 'CLI-00005',
      name: 'Li Wei Import-Export',
      phone: '+86 20 8371 5562',
      city: 'Guangzhou',
      roles: {'Fournisseur d’échange', 'Client d’échange'},
    ),
    Contact(
      reference: 'CLI-00006',
      name: 'Seydou Coulibaly',
      phone: '+226 70 12 88 31',
      city: 'Ouagadougou',
      roles: {'Fournisseur d’or'},
    ),
  ];

  final Map<String, double> bankBalances = {
    'Ecobank': 38412750,
    'UBA': 21908400,
    'Orabank': 9645100,
    'Caisse (espèces)': 6284500,
  };

  final List<LedgerEntry> operations = [
    LedgerEntry(
      title: 'Achat 2 g · 24K',
      subtitle: 'Moussa Diakité',
      amount: 89000,
      date: '18 oct. 2026',
    ),
    LedgerEntry(
      title: 'Échange CNY · Chine',
      subtitle: 'Li Wei Import-Export',
      amount: 4156450,
      date: '18 oct. 2026',
      isIncome: true,
    ),
    LedgerEntry(
      title: 'Achat 38,2 g · 18K',
      subtitle: 'Awa Traoré Bijouterie',
      amount: 1235000,
      date: '17 oct. 2026',
    ),
  ];

  final List<String> partnerships = [];
  final List<String> exchanges = [
    '48 500 CNY · Chine · Li Wei Import-Export',
    '6 250 000 XAF · Cameroun · Jean-Paul Mbarga',
    '73 200 AED · Dubaï · Al Noor Gold Trading',
  ];
  final List<String> sales = [
    'Al Noor Gold Trading · 512,3 g · bénéfice 2 371 698 FCFA',
  ];
  final List<PurchaseRecord> purchases = [
    PurchaseRecord(
      description: '18 oct. · Moussa Diakité · 2 g · 24K · 89 000 FCFA',
      amount: 89000,
      purchasedAt: DateTime(2026, 10, 18),
      supplier: 'Moussa Diakité',
      grossWeightGrams: 2,
      nonGoldWeightGrams: 0,
      karat: '24K',
      purityPercent: 100,
    ),
    PurchaseRecord(
      description: '18 oct. · Moussa Diakité · 124,6 g · 22K · 4 700 000 FCFA',
      amount: 4700000,
      purchasedAt: DateTime(2026, 10, 18),
      supplier: 'Moussa Diakité',
      grossWeightGrams: 124.6,
      nonGoldWeightGrams: 0,
      karat: '22K',
      purityPercent: 22 / 24 * 100,
    ),
  ];
  final List<GoldStockMovement> stockMovements = [];
  final Map<String, double> currencyBalances = {
    'USD': 0,
    'EUR': 0,
    'XAF': 0,
    'XOF': 0,
    'AED': 0,
    'CNY': 0,
  };
  final List<CurrencyStockMovement> currencyStockMovements = [];

  double get totalTreasury =>
      bankBalances.values.fold(0, (total, balance) => total + balance);

  double get totalProfit {
    return sales.fold<double>(0, (total, sale) {
      final match = RegExp(r'bénéfice\s+([0-9\s]+)\s+FCFA').firstMatch(sale);
      if (match == null) return total;

      final digits = match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return total;

      return total + double.parse(digits);
    });
  }

  List<LedgerEntry> get unprocessedOperations =>
      operations.where((operation) => !operation.isProcessed).toList();

  List<Contact> get contactsWithAppointments =>
      contacts.where((contact) => contact.appointment != null).toList();

  void signIn(String name) {
    userName = name.trim().isEmpty ? 'Aminata' : name.trim().split(' ').first;
    isSignedIn = true;
    notifyListeners();
  }

  void signOut() {
    isSignedIn = false;
    notifyListeners();
  }

  void addContact(Contact contact) {
    contact.reference = _nextContactReference();
    contacts.insert(0, contact);
    notifyListeners();
  }

  String _nextContactReference() {
    final lastNumber = contacts.fold<int>(0, (current, contact) {
      final match = RegExp(r'^CLI-(\d+)$').firstMatch(contact.reference);
      final number = int.tryParse(match?.group(1) ?? '');
      return number == null || number < current ? current : number;
    });
    final nextNumber = lastNumber + 1;
    return 'CLI-${nextNumber.toString().padLeft(5, '0')}';
  }

  void saveAppointment(Contact contact, String appointment) {
    contact.appointment = appointment;
    notifyListeners();
  }

  void removeAppointment(Contact contact) {
    contact.appointment = null;
    notifyListeners();
  }

  void markOperationProcessed(LedgerEntry operation) {
    if (operation.isProcessed) return;
    operation.isProcessed = true;
    notifyListeners();
  }

  void addBank(String bank, double openingBalance) {
    bankBalances[bank] = openingBalance;
    notifyListeners();
  }

  void addPurchase(
    String description,
    double price, {
    String? paymentAccount,
    double? initialPaymentAmount,
    String? reference,
    String? supplier,
    double? grossWeightGrams,
    double? nonGoldWeightGrams,
    String? karat,
    String goldCategory = 'Non catégorisé',
    double? purityPercent,
    double? referencePricePerGram,
    double? discountPercent,
    double? goldPricePerTroyOunceUsd,
    double? usdToXafRate,
    DateTime? rateObservedAt,
  }) {
    if (!price.isFinite || price <= 0) {
      throw ArgumentError('Le montant de l’achat doit être positif.');
    }
    final paidAmount =
        initialPaymentAmount ?? (paymentAccount == null ? 0 : price);
    if (!paidAmount.isFinite || paidAmount < 0 || paidAmount > price) {
      throw ArgumentError(
        'Le paiement initial doit être compris entre zéro et le montant de l’achat.',
      );
    }
    if (paidAmount > 0 && paymentAccount == null) {
      throw ArgumentError('Choisissez un compte pour le paiement initial.');
    }
    if (paymentAccount != null &&
        paidAmount > 0 &&
        (!bankBalances.containsKey(paymentAccount) ||
            bankBalances[paymentAccount]! < paidAmount)) {
      throw ArgumentError('Le solde du compte de paiement est insuffisant.');
    }
    if (goldPricePerTroyOunceUsd != null &&
        (!goldPricePerTroyOunceUsd.isFinite || goldPricePerTroyOunceUsd <= 0)) {
      throw ArgumentError('Le cours de l’once doit être positif.');
    }
    final purchasedAt = DateTime.now();
    purchases.insert(
      0,
      PurchaseRecord(
        description: description,
        amount: price,
        purchasedAt: purchasedAt,
        reference: reference ?? _nextPurchaseReference(purchasedAt.year),
        supplier: supplier,
        grossWeightGrams: grossWeightGrams,
        nonGoldWeightGrams: nonGoldWeightGrams,
        karat: karat,
        goldCategory: goldCategory,
        purityPercent: purityPercent,
        referencePricePerGram: referencePricePerGram,
        discountPercent: discountPercent,
        goldPricePerTroyOunceUsd: goldPricePerTroyOunceUsd,
        usdToXafRate: usdToXafRate,
        rateObservedAt: rateObservedAt,
        payments: paidAmount == 0
            ? null
            : [
                PurchasePayment(
                  amount: paidAmount,
                  paidAt: purchasedAt,
                  method: paidAmount == price ? 'Paiement immédiat' : 'Avance',
                  account: paymentAccount,
                ),
              ],
      ),
    );
    if (paymentAccount != null && paidAmount > 0) {
      bankBalances[paymentAccount] = bankBalances[paymentAccount]! - paidAmount;
    }
    operations.insert(
      0,
      LedgerEntry(
        title: 'Nouvel achat d’or',
        subtitle: description,
        amount: price,
        date: 'Aujourd’hui',
      ),
    );
    notifyListeners();
  }

  void addPurchasePayment(PurchaseRecord purchase, PurchasePayment payment) {
    if (!purchases.contains(purchase) || purchase.isCancelled) {
      throw ArgumentError('Cet achat ne peut pas recevoir de paiement.');
    }
    if (!payment.amount.isFinite ||
        payment.amount <= 0 ||
        payment.amount > purchase.remainingAmount) {
      throw ArgumentError('Le montant du paiement est invalide.');
    }
    if (payment.account != null &&
        (!bankBalances.containsKey(payment.account) ||
            bankBalances[payment.account]! < payment.amount)) {
      throw ArgumentError('Le solde du compte de paiement est insuffisant.');
    }
    purchase.payments.add(payment);
    if (payment.account != null) {
      bankBalances[payment.account!] =
          bankBalances[payment.account]! - payment.amount;
    }
    notifyListeners();
  }

  void addPurchasePhotos(PurchaseRecord purchase, Iterable<Uint8List> photos) {
    if (!purchases.contains(purchase) || purchase.isCancelled) {
      throw ArgumentError('Impossible de joindre des photos à cet achat.');
    }
    purchase.photos.addAll(photos);
    notifyListeners();
  }

  void cancelPurchase(PurchaseRecord purchase, String reason) {
    if (!purchases.contains(purchase) || purchase.isCancelled) {
      throw ArgumentError('Cet achat est déjà annulé ou introuvable.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Le motif d’annulation est obligatoire.');
    }
    final purchaseWeight = purchase.netWeightGrams;
    final karat = purchase.karat;
    if (purchaseWeight != null &&
        karat != null &&
        stockWeightForKarat(karat, category: purchase.goldCategory) -
                purchaseWeight <
            0) {
      throw ArgumentError(
        'Impossible d’annuler cet achat : une partie du stock a déjà été vendue.',
      );
    }
    purchase
      ..cancelledAt = DateTime.now()
      ..cancellationReason = reason.trim();
    for (final payment in purchase.payments) {
      final account = payment.account;
      if (account == null) continue;
      bankBalances[account] = (bankBalances[account] ?? 0) + payment.amount;
      operations.insert(
        0,
        LedgerEntry(
          title: 'Remboursement d’achat annulé',
          subtitle: '${purchase.reference ?? purchase.description} · $account',
          amount: payment.amount,
          date: 'Aujourd’hui',
          isIncome: true,
        ),
      );
    }
    notifyListeners();
  }

  double stockWeightForKarat(String karat, {String? category}) {
    final purchased = purchases
        .where(
          (purchase) =>
              !purchase.isCancelled &&
              purchase.karat == karat &&
              (category == null || purchase.goldCategory == category),
        )
        .fold<double>(
          0,
          (total, purchase) => total + (purchase.netWeightGrams ?? 0),
        );
    final moved = stockMovements
        .where(
          (movement) =>
              movement.karat == karat &&
              (category == null || movement.category == category),
        )
        .fold<double>(0, (total, movement) => total + movement.weightGrams);
    return purchased + moved;
  }

  void adjustGoldStock({
    required String karat,
    String category = 'Non catégorisé',
    required double weightGrams,
    required String reason,
  }) {
    if (!isValidGoldKarat(karat)) {
      throw ArgumentError('Le carat sélectionné n’est pas valide.');
    }
    if (!weightGrams.isFinite || weightGrams == 0) {
      throw ArgumentError('La correction doit avoir un poids non nul.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Le motif de correction est obligatoire.');
    }
    if (stockWeightForKarat(karat, category: category) + weightGrams < 0) {
      throw ArgumentError('La correction ne peut pas rendre le stock négatif.');
    }
    stockMovements.insert(
      0,
      GoldStockMovement(
        label: 'Correction de stock',
        karat: karat,
        weightGrams: weightGrams,
        date: DateTime.now(),
        type: 'Correction',
        category: category,
        reason: reason.trim(),
      ),
    );
    notifyListeners();
  }

  String _nextPurchaseReference(int year) {
    final count = purchases
        .where(
          (purchase) => purchase.reference?.startsWith('ACH-$year-') == true,
        )
        .length;
    return 'ACH-$year-${(count + 1).toString().padLeft(4, '0')}';
  }

  void addSale(
    String description,
    double profit, {
    double? weightGrams,
    String? karat,
    String? category,
  }) {
    if (weightGrams != null || karat != null) {
      if (weightGrams == null ||
          karat == null ||
          !weightGrams.isFinite ||
          weightGrams <= 0) {
        throw ArgumentError('Le poids et le carat de la vente sont requis.');
      }
      if (stockWeightForKarat(karat) < weightGrams) {
        throw ArgumentError(
          'Le stock disponible est insuffisant pour cette vente.',
        );
      }
      if (category != null &&
          stockWeightForKarat(karat, category: category) < weightGrams) {
        throw ArgumentError(
          'Le stock disponible est insuffisant pour $karat en $category.',
        );
      }
      stockMovements.insert(
        0,
        GoldStockMovement(
          label: description,
          karat: karat,
          weightGrams: -weightGrams,
          date: DateTime.now(),
          type: 'Vente',
          category: category ?? 'Non catégorisé',
        ),
      );
    }
    sales.insert(0, description);
    operations.insert(
      0,
      LedgerEntry(
        title: 'Vente à Dubaï',
        subtitle: description,
        amount: profit,
        date: 'Aujourd’hui',
        isIncome: true,
      ),
    );
    notifyListeners();
  }

  void addExchange(
    String description, {
    String? receivedCurrency,
    double? receivedAmount,
    String? deliveredCurrency,
    double? deliveredAmount,
  }) {
    final hasCurrencyMovement =
        receivedCurrency != null ||
        receivedAmount != null ||
        deliveredCurrency != null ||
        deliveredAmount != null;
    if (hasCurrencyMovement) {
      if (receivedCurrency == null ||
          deliveredCurrency == null ||
          receivedAmount == null ||
          deliveredAmount == null ||
          receivedCurrency == deliveredCurrency ||
          !receivedAmount.isFinite ||
          receivedAmount <= 0 ||
          !deliveredAmount.isFinite ||
          deliveredAmount <= 0) {
        throw ArgumentError(
          'Vérifiez les devises et les montants de l’échange.',
        );
      }
      final available = currencyBalances[deliveredCurrency] ?? 0;
      if (available < deliveredAmount) {
        throw ArgumentError(
          'Stock insuffisant en $deliveredCurrency : '
          '${available.toStringAsFixed(2)} disponible(s).',
        );
      }
      final date = DateTime.now();
      currencyBalances[receivedCurrency] =
          (currencyBalances[receivedCurrency] ?? 0) + receivedAmount;
      currencyBalances[deliveredCurrency] = available - deliveredAmount;
      currencyStockMovements
        ..insert(
          0,
          CurrencyStockMovement(
            currency: receivedCurrency,
            amount: receivedAmount,
            type: 'Change reçu',
            label: description,
            date: date,
          ),
        )
        ..insert(
          0,
          CurrencyStockMovement(
            currency: deliveredCurrency,
            amount: -deliveredAmount,
            type: 'Change remis',
            label: description,
            date: date,
          ),
        );
    }
    exchanges.insert(0, description);
    operations.insert(
      0,
      LedgerEntry(
        title: 'Nouvel échange',
        subtitle: description,
        amount: 0,
        date: 'Aujourd’hui',
        isIncome: true,
      ),
    );
    notifyListeners();
  }

  void adjustCurrencyStock({
    required String currency,
    required double amount,
    required bool isAddition,
    required String reason,
  }) {
    if (currency.trim().isEmpty) {
      throw ArgumentError('Sélectionnez une devise.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Le montant doit être supérieur à zéro.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Le motif est obligatoire.');
    }
    final current = currencyBalances[currency] ?? 0;
    final delta = isAddition ? amount : -amount;
    if (current + delta < 0) {
      throw ArgumentError('Le stock de $currency ne peut pas être négatif.');
    }
    currencyBalances[currency] = current + delta;
    currencyStockMovements.insert(
      0,
      CurrencyStockMovement(
        currency: currency,
        amount: delta,
        type: 'Ajustement',
        label: reason.trim(),
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void replacePartnerships(Iterable<String> descriptions) {
    partnerships
      ..clear()
      ..addAll(descriptions);
    notifyListeners();
  }

  void addMovement(String bank, double amount, bool deposit, String label) {
    bankBalances[bank] =
        (bankBalances[bank] ?? 0) + (deposit ? amount : -amount);
    operations.insert(
      0,
      LedgerEntry(
        title: label,
        subtitle: bank,
        amount: amount,
        date: 'Aujourd’hui',
        isIncome: deposit,
        isDeposit: deposit,
      ),
    );
    notifyListeners();
  }

  void transferFunds({
    required String fromAccount,
    required String toAccount,
    required double amount,
    required String label,
  }) {
    if (!bankBalances.containsKey(fromAccount) ||
        !bankBalances.containsKey(toAccount)) {
      throw ArgumentError('Le compte sélectionné est introuvable.');
    }
    if (fromAccount == toAccount) {
      throw ArgumentError(
        'Les comptes source et destination doivent différer.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Le montant du virement doit être positif.');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError('Le libellé du virement est obligatoire.');
    }
    if (bankBalances[fromAccount]! < amount) {
      throw ArgumentError('Le solde du compte source est insuffisant.');
    }

    bankBalances[fromAccount] = bankBalances[fromAccount]! - amount;
    bankBalances[toAccount] = bankBalances[toAccount]! + amount;
    operations.insert(
      0,
      LedgerEntry(
        title: 'Virement · ${label.trim()}',
        subtitle: '$fromAccount → $toAccount',
        amount: amount,
        date: 'Aujourd’hui',
        isTransfer: true,
      ),
    );
    notifyListeners();
  }

  void addExpense({
    required String account,
    required double amount,
    required String description,
  }) {
    if (!bankBalances.containsKey(account)) {
      throw ArgumentError('Le compte sélectionné est introuvable.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Le montant de la dépense doit être positif.');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('Le libellé de la dépense est obligatoire.');
    }
    if (bankBalances[account]! < amount) {
      throw ArgumentError('Le solde du compte est insuffisant.');
    }

    bankBalances[account] = bankBalances[account]! - amount;
    operations.insert(
      0,
      LedgerEntry(
        title: 'Dépense · ${description.trim()}',
        subtitle: account,
        amount: amount,
        date: 'Aujourd’hui',
      ),
    );
    notifyListeners();
  }
}
