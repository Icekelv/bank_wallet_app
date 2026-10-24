import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../state.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Full-screen transfer, opened from the home "Send" button.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: const TransferForm(popOnSuccess: true),
    );
  }
}

/// The Payments tab: transfer form plus recent transfers.
class TransferView extends StatelessWidget {
  const TransferView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TransferForm(showHeader: true, showRecent: true);
  }
}

class TransferForm extends StatefulWidget {
  final bool popOnSuccess;
  final bool showHeader;
  final bool showRecent;
  const TransferForm({super.key, this.popOnSuccess = false, this.showHeader = false, this.showRecent = false});

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _form = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _recipientName;
  String? _lookupError;
  bool _looking = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _recipient.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onRecipientChanged(String v) {
    _debounce?.cancel();
    setState(() {
      _recipientName = null;
      _lookupError = null;
    });
    final q = v.trim();
    final looksComplete = q.contains('@') ? RegExp(r'^\S+@\S+\.\S+$').hasMatch(q) : q.length == 10;
    if (!looksComplete) return;
    _debounce = Timer(const Duration(milliseconds: 500), () => _lookup(q));
  }

  Future<void> _lookup(String q) async {
    setState(() => _looking = true);
    try {
      final name = await context.read<AppState>().lookupAccount(q);
      if (mounted && _recipient.text.trim() == q) setState(() => _recipientName = name);
    } catch (e) {
      if (mounted && _recipient.text.trim() == q) setState(() => _lookupError = e.toString());
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AppState>();
    final amount = double.parse(_amount.text.replaceAll(',', ''));
    final who = _recipientName ?? _recipient.text.trim();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('You are sending', style: TextStyle(color: p.muted)),
                const SizedBox(height: 4),
                Text(money(s.currency, amount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text('to $who', style: const TextStyle(fontSize: 16)),
                if (_note.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('“${_note.text.trim()}”', style: TextStyle(color: p.muted)),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm and send')),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;

    final res = await runBusy(context, () => s.transfer(_recipient.text.trim(), amount, _note.text.trim()));
    if (res == null || !mounted) return;
    showMessage('Sent ${money(s.currency, amount)} to ${res['recipient']}');
    _recipient.clear();
    _amount.clear();
    _note.clear();
    setState(() => _recipientName = null);
    if (widget.popOnSuccess && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final balance = s.user?.balance ?? 0;
    final transfers = s.recentCash.where((t) => t.type == 'transfer_out' || t.type == 'transfer_in').take(8).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (widget.showHeader) ...[
          const Text('Payments', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          Text('Send money to anyone with an account.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 20),
        ],
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _recipient,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Account number or email',
                  suffixIcon: _looking
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : _recipientName != null
                          ? Icon(Icons.check_circle_rounded, color: p.up)
                          : null,
                ),
                onChanged: _onRecipientChanged,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter who you are sending to' : null,
              ),
              if (_recipientName != null || _lookupError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 8),
                  child: Text(
                    _recipientName ?? _lookupError!,
                    style: TextStyle(color: _recipientName != null ? p.ink : p.down, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${s.currency} ',
                  helperText: 'Available: ${money(s.currency, balance)}',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Enter an amount';
                  if (n > balance) return 'More than your balance';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _send, child: const Text('Continue')),
            ],
          ),
        ),
        if (widget.showRecent) ...[
          const SizedBox(height: 28),
          Panel(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
                const SectionHeader('Recent transfers'),
                if (transfers.isEmpty)
                  const EmptyNote(icon: Icons.swap_horiz_rounded, text: 'Transfers you send and receive show up here.')
                else
                  ...transfers.map(TxTile.new),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
