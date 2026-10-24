double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class AppConfig {
  final String mode; // 'bank' or 'wallet'
  final String appName;
  final String bankName;
  final String walletName;
  final String currency;
  final bool signupEnabled;
  final String depositInstructions;

  const AppConfig({
    required this.mode,
    required this.appName,
    required this.bankName,
    required this.walletName,
    required this.currency,
    required this.signupEnabled,
    required this.depositInstructions,
  });

  bool get isWallet => mode == 'wallet';

  static const AppConfig fallback = AppConfig(
    mode: 'bank',
    appName: 'mono',
    bankName: 'mono',
    walletName: 'mono wallet',
    currency: '\$',
    signupEnabled: true,
    depositInstructions: '',
  );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        mode: j['mode'] == 'wallet' ? 'wallet' : 'bank',
        appName: (j['app_name'] ?? 'mono').toString(),
        bankName: (j['bank_name'] ?? 'mono').toString(),
        walletName: (j['wallet_name'] ?? 'mono wallet').toString(),
        currency: (j['currency_symbol'] ?? '\$').toString(),
        signupEnabled: j['signup_enabled'] == true,
        depositInstructions: (j['deposit_instructions'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'app_name': appName,
        'bank_name': bankName,
        'wallet_name': walletName,
        'currency_symbol': currency,
        'signup_enabled': signupEnabled,
        'deposit_instructions': depositInstructions,
      };
}

class User {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String accountNumber;
  final double balance;
  final String cardLast4;
  final String cardExpiry;
  final bool cardFrozen;
  final String mode;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.accountNumber,
    required this.balance,
    required this.cardLast4,
    required this.cardExpiry,
    required this.cardFrozen,
    required this.mode,
  });

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] as num).toInt(),
        fullName: (j['full_name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        accountNumber: (j['account_number'] ?? '').toString(),
        balance: _d(j['balance']),
        cardLast4: (j['card_last4'] ?? '0000').toString(),
        cardExpiry: (j['card_expiry'] ?? '').toString(),
        cardFrozen: j['card_frozen'] == true,
        mode: (j['mode'] ?? 'bank').toString(),
      );
}

class Txn {
  final int id;
  final String type;
  final String direction;
  final double amount;
  final String asset;
  final double? assetAmount;
  final double? price;
  final String? counterparty;
  final String description;
  final DateTime createdAt;

  const Txn({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.asset,
    required this.assetAmount,
    required this.price,
    required this.counterparty,
    required this.description,
    required this.createdAt,
  });

  bool get isIn => direction == 'in';
  bool get isCrypto => const ['buy', 'sell', 'crypto_in', 'crypto_out'].contains(type);

  /// Effect on the cash balance (buying crypto spends cash, selling adds it).
  bool get cashIncreases {
    if (type == 'buy') return false;
    if (type == 'sell') return true;
    return isIn;
  }

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: (j['id'] as num).toInt(),
        type: (j['type'] ?? '').toString(),
        direction: (j['direction'] ?? 'out').toString(),
        amount: _d(j['amount']),
        asset: (j['asset'] ?? 'USD').toString(),
        assetAmount: j['asset_amount'] == null ? null : _d(j['asset_amount']),
        price: j['price'] == null ? null : _d(j['price']),
        counterparty: j['counterparty']?.toString(),
        description: (j['description'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class PricePoint {
  final DateTime time;
  final double price;
  const PricePoint(this.time, this.price);
}

class Asset {
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final double high24h;
  final double low24h;
  final List<PricePoint> history;
  final double amount;
  final double avgCost;
  final double value;

  const Asset({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.high24h,
    required this.low24h,
    required this.history,
    required this.amount,
    required this.avgCost,
    required this.value,
  });

  bool get held => amount > 0;

  /// Profit or loss on the coins held, against the average buy price.
  double get pnl => held && avgCost > 0 ? (price - avgCost) * amount : 0;

  List<double> pricesSince(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    final pts = history.where((p) => p.time.isAfter(cutoff)).map((p) => p.price).toList();
    if (pts.length < 2) return history.map((p) => p.price).toList();
    return pts;
  }

  factory Asset.fromJson(Map<String, dynamic> j) {
    final raw = (j['history'] as List?) ?? const [];
    final hist = <PricePoint>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        hist.add(PricePoint(
          DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt() * 1000),
          _d(p[1]),
        ));
      }
    }
    return Asset(
      symbol: (j['symbol'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      price: _d(j['price']),
      change24h: _d(j['change_24h']),
      high24h: _d(j['high_24h']),
      low24h: _d(j['low_24h']),
      history: hist,
      amount: _d(j['amount']),
      avgCost: _d(j['avg_cost']),
      value: _d(j['value']),
    );
  }
}

class CryptoData {
  final List<Asset> assets;
  final double cash;
  final double cryptoTotal;
  final double total;

  const CryptoData({
    required this.assets,
    required this.cash,
    required this.cryptoTotal,
    required this.total,
  });

  List<Asset> get holdings => assets.where((a) => a.held).toList();

  /// Today's move of the crypto part, weighted by each coin's value.
  double get dayChangeAmount {
    double sum = 0;
    for (final a in holdings) {
      final before = a.value / (1 + a.change24h / 100);
      sum += a.value - before;
    }
    return sum;
  }

  double get dayChangePercent {
    final before = cryptoTotal - dayChangeAmount;
    if (before <= 0) return 0;
    return dayChangeAmount / before * 100;
  }

  /// Portfolio value over time using today's holdings (cash included).
  List<double> portfolioSeries(Duration window) {
    final held = holdings;
    if (held.isEmpty) return [cash, cash];
    const n = 40;
    final series = List<double>.filled(n, cash);
    for (final a in held) {
      final prices = a.pricesSince(window);
      if (prices.isEmpty) continue;
      for (var i = 0; i < n; i++) {
        final idx = prices.length == 1 ? 0 : (i * (prices.length - 1) / (n - 1)).round();
        series[i] += prices[idx] * a.amount;
      }
    }
    return series;
  }

  factory CryptoData.fromJson(Map<String, dynamic> j) => CryptoData(
        assets: ((j['assets'] as List?) ?? const [])
            .map((e) => Asset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        cash: _d(j['cash']),
        cryptoTotal: _d(j['crypto_total']),
        total: _d(j['total']),
      );
}

class DaySpend {
  final String label;
  final double amount;
  const DaySpend(this.label, this.amount);
}

class BankSummary {
  final List<DaySpend> week;
  final double weekTotal;
  final double monthIn;
  final double monthOut;

  const BankSummary({
    required this.week,
    required this.weekTotal,
    required this.monthIn,
    required this.monthOut,
  });

  factory BankSummary.fromJson(Map<String, dynamic> j) => BankSummary(
        week: ((j['week'] as List?) ?? const [])
            .map((e) => DaySpend((e['label'] ?? '').toString(), _d(e['amount'])))
            .toList(),
        weekTotal: _d(j['week_total']),
        monthIn: _d(j['month_in']),
        monthOut: _d(j['month_out']),
      );
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}
