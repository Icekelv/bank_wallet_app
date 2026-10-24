import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/auth_screen.dart';
import 'screens/bank/bank_shell.dart';
import 'screens/wallet/wallet_shell.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const MonoApp()));
  state.init();
}

class MonoApp extends StatelessWidget {
  const MonoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final wallet = s.isWallet;
    SystemChrome.setSystemUIOverlayStyle(wallet ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);

    Widget home;
    if (!s.ready) {
      home = const _Splash();
    } else if (!s.signedIn && s.startupError != null) {
      home = _Offline(message: s.startupError!);
    } else if (!s.signedIn) {
      home = const AuthScreen();
    } else if (wallet) {
      home = const WalletShell(key: ValueKey('wallet'));
    } else {
      home = const BankShell(key: ValueKey('bank'));
    }

    return MaterialApp(
      title: s.config.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(wallet),
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: home),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.show_chart_rounded, color: p.bg, size: 28),
            ),
            const SizedBox(height: 24),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  final String message;
  const _Offline({required this.message});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: p.muted),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<AppState>().retryStartup(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
