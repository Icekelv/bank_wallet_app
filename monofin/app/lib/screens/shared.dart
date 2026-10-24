import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadNotifications();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: s.notifications.isEmpty ? 1 : s.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (s.notifications.isEmpty) {
                    return const EmptyNote(icon: Icons.notifications_none_rounded, text: 'No notifications yet.');
                  }
                  final n = s.notifications[i];
                  return Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                            Text(friendlyDate(n.createdAt), style: TextStyle(fontSize: 12, color: p.muted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(n.body, style: TextStyle(color: p.muted, height: 1.4)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  final String scope; // all | cash | crypto
  final String title;
  const TransactionsScreen({super.key, this.scope = 'all', this.title = 'Activity'});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Txn>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AppState>().fetchTransactions(scope: widget.scope, limit: 200);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items == null) {
      body = ListView(children: [EmptyNote(icon: Icons.error_outline_rounded, text: _error!)]);
    } else if (_items!.isEmpty) {
      body = ListView(children: const [EmptyNote(icon: Icons.receipt_long_outlined, text: 'No transactions yet.')]);
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [Panel(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Column(children: _items!.map(TxTile.new).toList()))],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

/// Profile tab used by both apps.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final u = s.user;
    if (u == null) return const SizedBox.shrink();

    Widget tile(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
          minVerticalPadding: 14,
          leading: Icon(icon, color: color ?? p.ink),
          title: Text(label, style: TextStyle(color: color ?? p.ink, fontWeight: FontWeight.w500)),
          trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: p.surfaceAlt,
              child: Text(u.initials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.ink)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(u.email, style: TextStyle(color: p.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              CopyRow(label: 'Account number', value: u.accountNumber),
              if (u.phone.isNotEmpty) CopyRow(label: 'Phone', value: u.phone),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              tile(Icons.notifications_none_rounded, 'Notifications', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }),
              tile(Icons.receipt_long_outlined, 'All activity', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsScreen()));
              }),
              tile(Icons.add_card_rounded, 'Add money', () => showDepositSheet(context)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: tile(Icons.logout_rounded, 'Sign out', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                ],
              ),
            );
            if (ok == true) await s.logout();
          }, color: p.down),
        ),
        const SizedBox(height: 24),
        Center(child: Text(s.config.appName, style: TextStyle(color: p.muted, fontSize: 12))),
      ],
    );
  }
}

/// Bottom navigation used by both shells.
class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class BottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Widget? center; // optional raised button in the middle
  const BottomNav({super.key, required this.items, required this.index, required this.onTap, this.center});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cells = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (center != null && i == items.length ~/ 2) cells.add(Expanded(child: Center(child: center!)));
      final on = i == index;
      cells.add(Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: items[i].label,
          child: InkWell(
            onTap: () => onTap(i),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].icon, size: 22, color: on ? p.ink : p.muted),
                    const SizedBox(height: 4),
                    Text(
                      items[i].label,
                      style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.ink : p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF121213) : p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: 68, child: Row(children: cells)),
      ),
    );
  }
}
