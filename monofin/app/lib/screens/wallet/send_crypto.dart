import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../models.dart';
import '../../state.dart';
import '../../theme.dart';

Future<void> showSendCryptoSheet(BuildContext context) {
  final held = context.read<AppState>().crypto?.holdings ?? const <Asset>[];
  if (held.isEmpty) {
    showMessage('You have no crypto to send yet.');
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SendCryptoSheet(holdings: held),
  );
}

class _SendCryptoSheet extends StatefulWidget {
  final List<Asset> holdings;
  const _SendCryptoSheet({required this.holdings});

  @override
  State<_SendCryptoSheet> createState() => _SendCryptoSheetState();
}

class _SendCryptoSheetState extends State<_SendCryptoSheet> {
  final _qty = TextEditingController();
  final _to = TextEditingController();
  late Asset _asset = widget.holdings.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = double.tryParse(_qty.text.replaceAll(',', ''));
    if (q == null || q <= 0) {
      setState(() => _error = 'Enter a quantity');
      return;
    }
    if (q > _asset.amount + 0.00000001) {
      setState(() => _error = 'You hold ${coin(_asset.amount)} ${_asset.symbol}');
      return;
    }
    if (_to.text.trim().isEmpty) {
      setState(() => _error = 'Enter the recipient’s email or account number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = context.read<AppState>();
    try {
      final r = await s.sendCrypto(_asset.symbol, q, _to.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage('Sent ${coin(q)} ${_asset.symbol} to ${r['recipient']}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Send crypto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Sends instantly to another user of this app.', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.holdings)
                    ChoiceChip(
                      label: Text(a.symbol),
                      selected: a.symbol == _asset.symbol,
                      onSelected: (_) => setState(() => _asset = a),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('You hold ${coin(_asset.amount)} ${_asset.symbol}', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: _asset.symbol,
                  suffixIcon: TextButton(
                    onPressed: () => setState(() => _qty.text = coin(_asset.amount)),
                    child: const Text('Max'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _to,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Recipient email or account number'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: p.down, fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted))
                    : const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
