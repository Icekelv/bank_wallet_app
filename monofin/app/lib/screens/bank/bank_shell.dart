import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../format.dart';
import '../../state.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../shared.dart';
import 'transfer.dart';

class BankShell extends StatefulWidget {
  const BankShell({super.key});

  @override
  State<BankShell> createState() => _BankShellState();
}

class _BankShellState extends State<BankShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            BankHome(onOpenTab: (i) => setState(() => _tab = i)),
            const BankCards(),
            const TransferView(),
            const ProfileView(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          NavItem(Icons.home_outlined, 'Home'),
          NavItem(Icons.credit_card_rounded, 'Cards'),
          NavItem(Icons.swap_horiz_rounded, 'Payments'),
          NavItem(Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }
}

// ---------------- Home ----------------

class BankHome extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  const BankHome({super.key, required this.onOpenTab});

  @override
  State<BankHome> createState() => _BankHomeState();
}

class _BankHomeState extends State<BankHome> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final u = s.user!;
    final summary = s.bankSummary;
    final acct = u.accountNumber.length >= 4 ? u.accountNumber.substring(u.accountNumber.length - 4) : u.accountNumber;

    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: p.border,
                child: Text(u.initials, style: TextStyle(fontWeight: FontWeight.w600, color: p.ink, fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting(), style: TextStyle(fontSize: 13, color: p.muted)),
                    Text(u.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Balance card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: p.heroBg, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Total balance', style: TextStyle(fontSize: 13, color: p.heroMuted)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF3A3A38)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Acct •••• $acct', style: const TextStyle(fontSize: 12, color: Color(0xFFD6D6D1))),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: BigAmount(value: u.balance, color: p.heroInk, dim: const Color(0xFF8A8A85), hidden: _hidden)),
                    IconButton(
                      tooltip: _hidden ? 'Show balance' : 'Hide balance',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: p.heroMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: money(s.currency, summary?.monthIn ?? 0, signed: true), style: TextStyle(color: p.heroUp)),
                    TextSpan(text: ' in this month', style: TextStyle(color: p.heroMuted)),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.north_east_rounded,
                  label: 'Send',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferScreen())),
                ),
              ),
              Expanded(child: QuickAction(icon: Icons.south_west_rounded, label: 'Request', onTap: () => showReceiveSheet(context))),
              Expanded(child: QuickAction(icon: Icons.add_rounded, label: 'Top up', onTap: () => showDepositSheet(context))),
              Expanded(
                child: QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'History',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TransactionsScreen(scope: 'cash', title: 'History')),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Panel(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                SectionHeader(
                  'Recent activity',
                  action: 'See all',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TransactionsScreen(scope: 'cash', title: 'History')),
                  ),
                ),
                if (s.recentCash.isEmpty)
                  const EmptyNote(icon: Icons.receipt_long_outlined, text: 'No activity yet. Top up to get started.')
                else
                  ...s.recentCash.take(6).map(TxTile.new),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Cards ----------------

class BankCards extends StatelessWidget {
  const BankCards({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final u = s.user!;
    final summary = s.bankSummary;

    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const SizedBox(height: 4),
          const Center(child: Text('My card', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          const SizedBox(height: 20),
          _CardFace(name: u.fullName, last4: u.cardLast4, expiry: u.cardExpiry, frozen: u.cardFrozen, brand: s.config.bankName),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  icon: u.cardFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  label: u.cardFrozen ? 'Unfreeze' : 'Freeze',
                  onTap: () async {
                    final ok = await runBusy(context, () => s.setCardFrozen(!u.cardFrozen).then((_) => true));
                    if (ok == true) showMessage(u.cardFrozen ? 'Card unfrozen' : 'Card frozen');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardButton(
                  icon: Icons.visibility_outlined,
                  label: 'Details',
                  onTap: () => showReceiveSheet(context, title: 'Account details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CardButton(
                  icon: Icons.add_rounded,
                  label: 'Top up',
                  onTap: () => showDepositSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spent in the last 7 days', style: TextStyle(fontSize: 13, color: p.muted)),
                const SizedBox(height: 4),
                Text(
                  money(s.currency, summary?.weekTotal ?? 0),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6),
                ),
                const SizedBox(height: 18),
                if (summary == null)
                  const SizedBox(height: 110, child: Center(child: CircularProgressIndicator()))
                else
                  WeekBars(summary.week),
                const SizedBox(height: 20),
                _MonthRow(label: 'Money in this month', value: summary?.monthIn ?? 0, total: (summary?.monthIn ?? 0) + (summary?.monthOut ?? 0)),
                const SizedBox(height: 12),
                _MonthRow(label: 'Money out this month', value: summary?.monthOut ?? 0, total: (summary?.monthIn ?? 0) + (summary?.monthOut ?? 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final String name;
  final String last4;
  final String expiry;
  final bool frozen;
  final String brand;
  const _CardFace({required this.name, required this.last4, required this.expiry, required this.frozen, required this.brand});

  @override
  Widget build(BuildContext context) {
    const ring = Color(0xFF2C2C2A);
    return Semantics(
      label: 'Debit card ending $last4, expires $expiry${frozen ? ', frozen' : ''}',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.66,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: const Color(0xFF161616),
              child: Stack(
                children: [
                  Positioned(right: -60, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring)))),
                  Positioned(right: -10, top: -10, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring)))),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(brand, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            const Icon(Icons.contactless_outlined, color: Color(0xFFBDBDB8), size: 26),
                          ],
                        ),
                        const Spacer(),
                        Container(width: 40, height: 30, decoration: BoxDecoration(color: const Color(0xFF3A3A37), borderRadius: BorderRadius.circular(6))),
                        const Spacer(),
                        Text('••••  ••••  ••••  $last4', style: const TextStyle(color: Colors.white, fontSize: 17, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text('${name.toUpperCase()} · $expiry',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFA3A39E), fontSize: 12)),
                            ),
                            const Text('DEBIT', style: TextStyle(color: Color(0xFFD6D6D1), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (frozen)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xB3161616),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.ac_unit_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Frozen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CardButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: p.ink),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  const _MonthRow({required this.label, required this.value, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cur = context.select<AppState, String>((s) => s.currency);
    final frac = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(money(cur, value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: p.surfaceAlt, color: p.ink),
        ),
      ],
    );
  }
}
