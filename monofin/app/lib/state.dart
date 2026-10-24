import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'push.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String text) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// App-wide state: configuration (which app to show), session and data.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final Api api = Api();
  final Push push = Push();

  bool ready = false;
  AppConfig config = AppConfig.fallback;
  User? user;

  BankSummary? bankSummary;
  List<Txn> recentCash = [];
  CryptoData? crypto;
  List<Txn> recentCrypto = [];
  List<AppNotification> notifications = [];

  Timer? _priceTimer;

  String get currency => config.currency;
  bool get isWallet => config.isWallet;
  bool get signedIn => user != null;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('token');
    final cached = prefs.getString('config');
    if (cached != null) {
      try {
        config = AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      } catch (_) {}
    }

    await push.init(onMessage: _onPushMessage, onToken: _sendPushToken);

    await refreshConfig();
    await _restoreSession();
    ready = true;
    notifyListeners();
  }

  /// Set when a saved session could not be checked (e.g. no internet).
  String? startupError;

  Future<void> _restoreSession() async {
    startupError = null;
    if (api.token == null) return;
    try {
      await refreshUser();
      _afterSignIn();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await _clearSession();
      } else {
        startupError = e.message;
      }
    }
  }

  Future<void> retryStartup() async {
    await refreshConfig();
    await _restoreSession();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ready) {
      refreshConfig();
      if (signedIn) refreshAll();
    }
  }

  // ---------- configuration / mode ----------

  Future<void> refreshConfig() async {
    try {
      final data = await api.get('app_config');
      final next = AppConfig.fromJson(data);
      final modeChanged = next.mode != config.mode;
      config = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('config', jsonEncode(next.toJson()));
      if (modeChanged) {
        // Close any open screens of the old app before showing the new one.
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
        if (signedIn) refreshAll();
        _syncPriceTimer();
      }
      notifyListeners();
    } on ApiException {
      // Offline: keep the last known configuration.
    }
  }

  // ---------- session ----------

  Future<void> login(String email, String password) async {
    final data = await api.post('login', {'email': email, 'password': password});
    await _startSession(data);
  }

  Future<void> register(String name, String email, String phone, String password) async {
    final data = await api.post('register', {
      'full_name': name,
      'email': email,
      'phone': phone,
      'password': password,
    });
    await _startSession(data);
  }

  Future<void> _startSession(Map<String, dynamic> data) async {
    api.token = data['token'].toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    user = User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await refreshConfig();
    _afterSignIn();
    notifyListeners();
  }

  void _afterSignIn() {
    push.registerDevice();
    refreshAll();
    _syncPriceTimer();
  }

  Future<void> logout() async {
    try {
      await api.post('logout', {'fcm_token': push.token ?? ''});
    } catch (_) {}
    await _clearSession();
    await refreshConfig();
  }

  Future<void> _clearSession() async {
    api.token = null;
    user = null;
    bankSummary = null;
    crypto = null;
    recentCash = [];
    recentCrypto = [];
    notifications = [];
    _priceTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await _clearSession();
        showMessage(e.message);
      }
    }
  }

  // ---------- data ----------

  Future<void> refreshUser() async {
    final data = await api.get('me');
    user = User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    notifyListeners();
  }

  Future<void> refreshAll() => _guard(() async {
        await refreshUser();
        if (isWallet) {
          await Future.wait([loadCrypto(), loadCryptoTxns()]);
        } else {
          await Future.wait([loadBankSummary(), loadCashTxns()]);
        }
      });

  Future<void> loadBankSummary() async {
    final data = await api.get('bank_summary');
    bankSummary = BankSummary.fromJson(data);
    notifyListeners();
  }

  Future<void> loadCashTxns() async {
    recentCash = await fetchTransactions(scope: 'cash', limit: 20);
    notifyListeners();
  }

  Future<void> loadCryptoTxns() async {
    recentCrypto = await fetchTransactions(scope: 'crypto', limit: 20);
    notifyListeners();
  }

  Future<List<Txn>> fetchTransactions({String scope = 'all', int limit = 50}) async {
    final data = await api.get('transactions', {'scope': scope, 'limit': '$limit'});
    return ((data['transactions'] as List?) ?? const [])
        .map((e) => Txn.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> loadCrypto() async {
    final data = await api.get('crypto_assets');
    crypto = CryptoData.fromJson(data);
    notifyListeners();
  }

  Future<void> loadNotifications() => _guard(() async {
        final data = await api.get('notifications');
        notifications = ((data['notifications'] as List?) ?? const [])
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      });

  void _syncPriceTimer() {
    _priceTimer?.cancel();
    if (isWallet && signedIn) {
      _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) => _guard(loadCrypto));
    }
  }

  // ---------- actions (throw ApiException with a readable message) ----------

  Future<String> lookupAccount(String query) async {
    final data = await api.get('lookup_account', {'q': query});
    return data['name'].toString();
  }

  Future<Map<String, dynamic>> transfer(String recipient, double amount, String note) async {
    final data = await api.post('transfer', {'recipient': recipient, 'amount': amount, 'note': note});
    await refreshAll();
    return data;
  }

  Future<void> setCardFrozen(bool frozen) async {
    await api.post('card_toggle', {'frozen': frozen ? 1 : 0});
    await refreshUser();
  }

  Future<Map<String, dynamic>> trade(String side, String symbol, {double? amount, bool all = false}) async {
    final data = await api.post('crypto_trade', {
      'side': side,
      'symbol': symbol,
      if (amount != null) 'amount': amount,
      if (all) 'all': 1,
    });
    await refreshAll();
    return data;
  }

  Future<Map<String, dynamic>> sendCrypto(String symbol, double quantity, String recipient) async {
    final data = await api.post('crypto_send', {'symbol': symbol, 'quantity': quantity, 'recipient': recipient});
    await refreshAll();
    return data;
  }

  // ---------- push ----------

  Future<void> _sendPushToken(String token) async {
    if (!signedIn) return;
    try {
      await api.post('fcm_token', {'token': token});
    } catch (_) {}
  }

  void _onPushMessage(Map<String, dynamic> data, String? title, String? body, bool openedFromTray) {
    final type = data['type']?.toString() ?? '';
    if (type == 'config') {
      refreshConfig();
      return;
    }
    if (signedIn) {
      refreshAll();
      loadNotifications();
    }
    if (!openedFromTray && title != null) {
      showMessage(body == null || body.isEmpty ? title : '$title · $body');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _priceTimer?.cancel();
    super.dispose();
  }
}
