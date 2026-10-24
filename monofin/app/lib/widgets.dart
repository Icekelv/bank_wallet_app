import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'format.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

// ---------------- containers ----------------

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: dark ? Border.all(color: p.border) : null,
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: p.muted, minimumSize: const Size(44, 44)),
            child: Text(action!, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

/// Round outlined icon button (44px+ target).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const CircleIconButton({super.key, required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: p.ink)),
        ),
      ),
    );
  }
}

/// Square-ish quick action with a label under it.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.border),
                ),
                child: Icon(icon, size: 22, color: p.ink),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "$24,580" with ".42" dimmed.
class BigAmount extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final Color dim;
  final bool hidden;
  const BigAmount({super.key, required this.value, required this.color, required this.dim, this.size = 40, this.hidden = false});

  @override
  Widget build(BuildContext context) {
    final cur = context.select<AppState, String>((s) => s.currency);
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: -size * 0.03,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (hidden) return Text('$cur ••••••', style: style);
    final (whole, cents) = moneyParts(cur, value);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(TextSpan(text: whole, style: style, children: [TextSpan(text: cents, style: style.copyWith(color: dim))])),
    );
  }
}

class ChangePill extends StatelessWidget {
  final double percentValue;
  const ChangePill(this.percentValue, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final up = percentValue >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: up ? p.upBg : p.downBg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '${up ? '▲' : '▼'} ${percentValue.abs().toStringAsFixed(2)}%',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: up ? p.up : p.down),
      ),
    );
  }
}

class AssetIcon extends StatelessWidget {
  final String symbol;
  final double size;
  final bool highlight;
  const AssetIcon(this.symbol, {super.key, this.size = 40, this.highlight = false});

  static String glyph(String symbol) {
    switch (symbol) {
      case 'BTC':
        return '₿';
      case 'ETH':
        return 'Ξ';
      case 'USDC':
      case 'USDT':
        return '\$';
      default:
        return symbol.isEmpty ? '?' : symbol.substring(0, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: highlight ? p.ink : p.surfaceAlt),
        child: Text(
          glyph(symbol),
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: highlight ? p.bg : p.ink),
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyNote({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: p.muted, size: 28),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

// ---------------- transactions ----------------

IconData txIcon(Txn t) {
  switch (t.type) {
    case 'deposit':
      return Icons.south_west_rounded;
    case 'withdrawal':
      return Icons.account_balance_outlined;
    case 'transfer_in':
      return Icons.call_received_rounded;
    case 'transfer_out':
      return Icons.call_made_rounded;
    case 'buy':
      return Icons.add_rounded;
    case 'sell':
      return Icons.remove_rounded;
    case 'crypto_in':
      return Icons.download_rounded;
    case 'crypto_out':
      return Icons.upload_rounded;
    default:
      return Icons.swap_horiz_rounded;
  }
}

String txTitle(Txn t) {
  switch (t.type) {
    case 'deposit':
      return t.description.isNotEmpty ? t.description : 'Deposit';
    case 'withdrawal':
      return t.description.isNotEmpty ? t.description : 'Withdrawal';
    case 'transfer_in':
      return 'From ${t.counterparty ?? 'transfer'}';
    case 'transfer_out':
      return 'To ${t.counterparty ?? 'transfer'}';
    case 'buy':
      return 'Bought ${t.asset}';
    case 'sell':
      return 'Sold ${t.asset}';
    case 'crypto_in':
      return 'Received ${t.asset}';
    case 'crypto_out':
      return 'Sent ${t.asset}';
    default:
      return t.description;
  }
}

class TxTile extends StatelessWidget {
  final Txn tx;
  const TxTile(this.tx, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cur = context.select<AppState, String>((s) => s.currency);
    final cryptoMove = tx.type == 'crypto_in' || tx.type == 'crypto_out';
    final positive = cryptoMove ? tx.isIn : tx.cashIncreases;
    final main = cryptoMove
        ? '${tx.isIn ? '+' : '−'}${coin(tx.assetAmount ?? 0)} ${tx.asset}'
        : money(cur, positive ? tx.amount : -tx.amount, signed: true);
    final sub = tx.isCrypto && tx.assetAmount != null && !cryptoMove
        ? '${coin(tx.assetAmount!)} ${tx.asset}'
        : friendlyDate(tx.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(14)),
            child: Icon(txIcon(tx), size: 18, color: p.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txTitle(tx), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(tx.isCrypto && !cryptoMove ? friendlyDate(tx.createdAt) : sub, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(main, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: positive ? p.up : p.ink)),
              if (tx.isCrypto && !cryptoMove) ...[
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- charts ----------------

class LineChart extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color color;
  final bool fill;
  final String semanticLabel;
  const LineChart({super.key, required this.values, required this.color, this.height = 140, this.fill = true, this.semanticLabel = 'Price chart'});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(values, color, fill, p.border, p.bg)),
      ),
    );
  }
}

class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const Sparkline({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ExcludeSemantics(
      child: SizedBox(width: 56, height: 24, child: CustomPaint(painter: _LinePainter(values, color, false, null, p.bg, dot: false, stroke: 1.6))),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool fill;
  final Color? baseline;
  final Color bg;
  final bool dot;
  final double stroke;
  _LinePainter(this.values, this.color, this.fill, this.baseline, this.bg, {this.dot = true, this.stroke = 2});

  @override
  void paint(Canvas canvas, Size size) {
    var data = values;
    if (data.isEmpty) data = [0, 0];
    if (data.length == 1) data = [data.first, data.first];
    final lo = data.reduce(math.min);
    final hi = data.reduce(math.max);
    final span = hi - lo;
    final pad = dot ? 6.0 : 2.0;
    double y(double v) => span == 0 ? size.height / 2 : pad + (1 - (v - lo) / span) * (size.height - pad * 2);
    double x(int i) => i * (size.width - (dot ? pad : 0)) / (data.length - 1);

    final path = Path()..moveTo(x(0), y(data[0]));
    for (var i = 1; i < data.length; i++) {
      path.lineTo(x(i), y(data[i]));
    }

    if (baseline != null) {
      final dash = Paint()
        ..color = baseline!
        ..strokeWidth = 1;
      for (double dx = 0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, size.height - 0.5), Offset(dx + 3, size.height - 0.5), dash);
      }
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(x(data.length - 1), size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withAlpha(14));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (dot) {
      final end = Offset(x(data.length - 1), y(data.last));
      canvas.drawCircle(end, 4.5, Paint()..color = bg);
      canvas.drawCircle(
        end,
        4.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values || old.color != color;
}

/// Weekly bars, highest day in solid ink.
class WeekBars extends StatelessWidget {
  final List<DaySpend> days;
  const WeekBars(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final max = days.isEmpty ? 0.0 : days.map((d) => d.amount).reduce(math.max);
    final cur = context.select<AppState, String>((s) => s.currency);
    final topIndex = max > 0 ? days.indexWhere((d) => d.amount == max) : -1;
    return Semantics(
      label: 'Spending over the last 7 days. Highest: ${max > 0 ? money(cur, max) : 'none'}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: max > 0 ? math.max(8.0, 80.0 * days[i].amount / max) : 8.0,
                        decoration: BoxDecoration(
                          color: i == topIndex ? p.ink : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        days[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          color: i == topIndex ? p.ink : p.muted,
                          fontWeight: i == topIndex ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 1H / 6H / 1D / 2D selector.
class RangeTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  static const labels = ['1H', '6H', '1D', '2D'];
  static const windows = [Duration(hours: 1), Duration(hours: 6), Duration(days: 1), Duration(days: 2)];
  const RangeTabs({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.border), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == selected ? p.ink : null, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                        color: i == selected ? p.bg : p.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- sheets shared by both apps ----------------

Future<void> showDepositSheet(BuildContext context) {
  final s = context.read<AppState>();
  final user = s.user;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final p = Palette.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add money', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(
                s.config.depositInstructions.isEmpty ? 'Contact support to fund your account.' : s.config.depositInstructions,
                style: TextStyle(color: p.muted, height: 1.5),
              ),
              if (user != null) ...[
                const SizedBox(height: 16),
                CopyRow(label: 'Account number', value: user.accountNumber),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showReceiveSheet(BuildContext context, {String title = 'Receive money'}) {
  final user = context.read<AppState>().user;
  if (user == null) return Future.value();
  return showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final p = Palette.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Share either of these with the sender.', style: TextStyle(color: p.muted)),
              const SizedBox(height: 16),
              CopyRow(label: 'Name', value: user.fullName),
              CopyRow(label: 'Account number', value: user.accountNumber),
              CopyRow(label: 'Email', value: user.email),
            ],
          ),
        ),
      );
    },
  );
}

class CopyRow extends StatelessWidget {
  final String label;
  final String value;
  const CopyRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            icon: Icon(Icons.copy_rounded, size: 20, color: p.ink),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showMessage('$label copied');
            },
          ),
        ],
      ),
    );
  }
}

/// Runs an async action with a spinner and turns errors into a snackbar.
Future<T?> runBusy<T>(BuildContext context, Future<T> Function() action) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  try {
    final r = await action();
    return r;
  } catch (e) {
    showMessage(e.toString());
    return null;
  } finally {
    navigatorKey.currentState?.pop();
  }
}
