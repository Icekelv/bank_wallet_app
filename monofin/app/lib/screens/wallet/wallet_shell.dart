import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../models.dart';
import '../../state.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../shared.dart';
import 'asset_detail.dart';
import 'send_crypto.dart';

class WalletShell extends StatefulWidget {
  const WalletShell({super.key});

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int _tab = 0;

  void _openTradePicker() {
    final s = context.read<AppState>();
    final assets = s.crypto?.assets ?? const <Asset>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text('Trade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (assets.isEmpty) const EmptyNote(icon: Icons.hourglass_empty_rounded, text: 'Loading markets…'),
              for (final a in assets)
                AssetRow(
                  asset: a,
                  onTap: () {
                    Navigator.pop(ctx);
                    openAsset(context, a.symbol);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            Portfolio(onBrowse: () => setState(() => _tab = 1)),
            const Markets(),
            const WalletTab(),
            const ProfileView(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          NavItem(Icons.donut_large_rounded, 'Portfolio'),
          NavItem(Icons.show_chart_rounded, 'Markets'),
          NavItem(Icons.account_balance_wallet_outlined, 'Wallet'),
          NavItem(Icons.person_outline_rounded, 'Account'),
        ],
        center: Semantics(
          button: true,
          label: 'Trade',
          child: Material(
            color: p.ink,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openTradePicker,
              child: SizedBox(width: 52, height: 52, child: Icon(Icons.swap_vert_rounded, color: p.bg)),
            ),
          ),
        ),
      ),
    );
  }
}

void openAsset(BuildContext context, String symbol) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssetDetail(symbol: symbol)));
}

/// One coin in a list: icon, name, sparkline, value.
class AssetRow extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;
  final bool showHolding;
  const AssetRow({super.key, required this.asset, required this.onTap, this.showHolding = false});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cur = context.select<AppState, String>((s) => s.currency);
    final up = asset.change24h >= 0;
    final flat = asset.change24h == 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AssetIcon(asset.symbol, highlight: asset.symbol == 'BTC'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    showHolding ? '${coin(asset.amount)} ${asset.symbol}' : asset.symbol,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
            ),
            Sparkline(values: asset.pricesSince(const Duration(days: 1)), color: flat ? p.muted : (up ? p.up : p.down)),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(cur, showHolding ? asset.value : asset.price),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(percent(asset.change24h), style: TextStyle(fontSize: 12, color: flat ? p.muted : (up ? p.up : p.down))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Portfolio ----------------

class Portfolio extends StatefulWidget {
  final VoidCallback onBrowse;
  const Portfolio({super.key, required this.onBrowse});

  @override
  State<Portfolio> createState() => _PortfolioState();
}

class _PortfolioState extends State<Portfolio> {
  int _range = 2;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final c = s.crypto;

    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.show_chart_rounded, size: 18, color: p.bg),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Portfolio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              CircleIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Total value', style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 6),
          BigAmount(value: c?.total ?? s.user?.balance ?? 0, color: p.ink, dim: const Color(0xFF6A6A66), size: 42),
          const SizedBox(height: 10),
          if (c != null)
            Row(
              children: [
                ChangePill(c.dayChangePercent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${money(s.currency, c.dayChangeAmount, signed: true)} today',
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          if (c == null)
            const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()))
          else
            LineChart(
              values: c.portfolioSeries(RangeTabs.windows[_range]),
              color: p.ink,
              fill: false,
              semanticLabel: 'Portfolio value over the selected period',
            ),
          const SizedBox(height: 16),
          RangeTabs(selected: _range, onChanged: (i) => setState(() => _range = i)),
          const SizedBox(height: 24),
          SectionHeader('Holdings', action: 'Markets', onAction: widget.onBrowse),
          if (c != null) ...[
            for (final a in c.holdings) AssetRow(asset: a, showHolding: true, onTap: () => openAsset(context, a.symbol)),
            _CashRow(cash: c.cash),
            if (c.holdings.isEmpty)
              EmptyNote(
                icon: Icons.add_chart_rounded,
                text: 'You don’t own any crypto yet.',
                action: OutlinedButton(onPressed: widget.onBrowse, child: const Text('Browse markets')),
              ),
          ],
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final double cash;
  const _CashRow({required this.cash});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cur = context.select<AppState, String>((s) => s.currency);
    return InkWell(
      onTap: () => showDepositSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.surfaceAlt),
              child: Icon(Icons.payments_outlined, size: 18, color: p.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Available to trade', style: TextStyle(fontSize: 12, color: p.muted)),
                ],
              ),
            ),
            Text(money(cur, cash), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Markets ----------------

class Markets extends StatelessWidget {
  const Markets({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.crypto;
    final p = Palette.of(context);
    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text('Markets', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text('Prices update every minute.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          if (c == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            for (final a in c.assets) AssetRow(asset: a, onTap: () => openAsset(context, a.symbol)),
        ],
      ),
    );
  }
}

// ---------------- Wallet tab ----------------

class WalletTab extends StatelessWidget {
  const WalletTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final c = s.crypto;

    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(child: QuickAction(icon: icon, label: label, onTap: onTap));

    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text('Wallet', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cash balance', style: TextStyle(fontSize: 13, color: p.muted)),
                const SizedBox(height: 6),
                BigAmount(value: s.user?.balance ?? 0, color: p.ink, dim: const Color(0xFF6A6A66), size: 34),
                const SizedBox(height: 4),
                Text('Crypto: ${money(s.currency, c?.cryptoTotal ?? 0)}', style: TextStyle(fontSize: 13, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              action(Icons.add_rounded, 'Add cash', () => showDepositSheet(context)),
              action(Icons.north_east_rounded, 'Send', () => showSendCryptoSheet(context)),
              action(Icons.south_west_rounded, 'Receive', () => showReceiveSheet(context, title: 'Receive crypto')),
              action(
                Icons.receipt_long_outlined,
                'History',
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsScreen(title: 'History'))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            'Recent trades',
            action: 'See all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransactionsScreen(scope: 'crypto', title: 'Trades')),
            ),
          ),
          if (s.recentCrypto.isEmpty)
            const EmptyNote(icon: Icons.swap_vert_rounded, text: 'Your buys, sells and transfers show up here.')
          else
            ...s.recentCrypto.take(8).map(TxTile.new),
        ],
      ),
    );
  }
}
