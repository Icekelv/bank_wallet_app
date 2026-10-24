import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../models.dart';
import '../../state.dart';
import '../../theme.dart';
import '../../widgets.dart';

class AssetDetail extends StatefulWidget {
  final String symbol;
  const AssetDetail({super.key, required this.symbol});

  @override
  State<AssetDetail> createState() => _AssetDetailState();
}

class _AssetDetailState extends State<AssetDetail> {
  int _range = 2;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    Asset? a;
    for (final x in s.crypto?.assets ?? const <Asset>[]) {
      if (x.symbol == widget.symbol) a = x;
    }
    if (a == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final asset = a;
    final prices = asset.pricesSince(RangeTabs.windows[_range]);
    final rangeChange = prices.length > 1 && prices.first > 0 ? (prices.last - prices.first) / prices.first * 100 : asset.change24h;
    final up = rangeChange >= 0;

    Widget stat(String label, String value) => Expanded(
          child: Panel(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon(asset.symbol, size: 28, highlight: true),
            const SizedBox(width: 8),
            Text(asset.name),
            const SizedBox(width: 6),
            Text(asset.symbol, style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: s.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            BigAmount(value: asset.price, color: p.ink, dim: const Color(0xFF6A6A66)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChangePill(rangeChange),
                const SizedBox(width: 8),
                Text('${RangeTabs.labels[_range]} · 24h ${percent(asset.change24h)}', style: TextStyle(fontSize: 13, color: p.muted)),
              ],
            ),
            const SizedBox(height: 24),
            LineChart(
              values: prices,
              color: p.ink,
              height: 200,
              semanticLabel: '${asset.name} price, ${up ? 'up' : 'down'} ${rangeChange.abs().toStringAsFixed(2)} percent over ${RangeTabs.labels[_range]}',
            ),
            const SizedBox(height: 16),
            RangeTabs(selected: _range, onChanged: (i) => setState(() => _range = i)),
            const SizedBox(height: 20),
            Row(children: [
              stat('Your balance', '${coin(asset.amount)} ${asset.symbol}'),
              const SizedBox(width: 10),
              stat('Value', money(s.currency, asset.value)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              stat('Avg. buy price', asset.avgCost > 0 && asset.held ? money(s.currency, asset.avgCost) : '—'),
              const SizedBox(width: 10),
              stat('Profit / loss', asset.held ? money(s.currency, asset.pnl, signed: true) : '—'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              stat('24h high', money(s.currency, asset.high24h)),
              const SizedBox(width: 10),
              stat('24h low', money(s.currency, asset.low24h)),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: asset.held ? () => showTradeSheet(context, asset, 'sell') : null,
                  child: const Text('Sell'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => showTradeSheet(context, asset, 'buy'),
                  child: Text('Buy ${asset.symbol}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showTradeSheet(BuildContext context, Asset asset, String side) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TradeSheet(asset: asset, side: side),
  );
}

class _TradeSheet extends StatefulWidget {
  final Asset asset;
  final String side;
  const _TradeSheet({required this.asset, required this.side});

  @override
  State<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<_TradeSheet> {
  final _amount = TextEditingController();
  bool _all = false;
  bool _busy = false;
  String? _error;

  bool get _buy => widget.side == 'buy';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double _availableFrom(AppState s) => _buy ? (s.user?.balance ?? 0) : widget.asset.value;

  void _fill(double fraction) {
    final v = _availableFrom(context.read<AppState>()) * fraction;
    setState(() {
      _all = !_buy && fraction == 1;
      _amount.text = (v * 100).floorToDouble() / 100 == 0 ? '' : ((v * 100).floorToDouble() / 100).toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final s = context.read<AppState>();
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (!_all && (amount == null || amount <= 0)) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (!_all && amount! > _availableFrom(s) + 0.001) {
      setState(() => _error = _buy ? 'More than your cash balance' : 'More than you hold');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await s.trade(widget.side, widget.asset.symbol, amount: _all ? null : amount, all: _all);
      if (!mounted) return;
      Navigator.of(context).pop();
      final qty = (r['quantity'] as num).toDouble();
      final value = (r['value'] as num).toDouble();
      showMessage('${_buy ? 'Bought' : 'Sold'} ${coin(qty)} ${widget.asset.symbol} for ${money(s.currency, value)}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final qty = widget.asset.price > 0 ? (_all ? widget.asset.amount : amount / widget.asset.price) : 0.0;

    Widget chip(String label, double f) => Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: _busy ? null : () => _fill(f),
            child: Text(label),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${_buy ? 'Buy' : 'Sell'} ${widget.asset.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '1 ${widget.asset.symbol} = ${money(s.currency, widget.asset.price)} · '
                '${_buy ? 'Cash' : 'Holding'}: ${money(s.currency, _availableFrom(s))}',
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  prefixText: '${s.currency} ',
                  hintText: '0.00',
                  helperText: amount > 0 || _all ? '≈ ${coin(double.parse(qty.toStringAsFixed(8)))} ${widget.asset.symbol}' : ' ',
                ),
                onChanged: (_) => setState(() {
                  _all = false;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(children: [chip('25%', 0.25), const SizedBox(width: 8), chip('50%', 0.5), const SizedBox(width: 8), chip('Max', 1)]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: p.down, fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted))
                    : Text(_buy ? 'Buy now' : 'Sell now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
