import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/wallet_controller.dart';
import '../models/wallet.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'earnings_statement_screen.dart';
import 'payout_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String _txFilter = 'all'; // all, credit, debit, payout

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletController>().load();
    });
  }

  List<WalletTransaction> _filtered(List<WalletTransaction> all) {
    switch (_txFilter) {
      case 'credit':
        return all.where((t) => !t.isDebit).toList();
      case 'debit':
        return all.where((t) => t.isDebit).toList();
      case 'payout':
        return all.where((t) => t.type == TxnType.payout).toList();
      default:
        return all;
    }
  }

  Widget _filterChip(String label, String value) {
    final active = _txFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      onSelected: (_) => setState(() => _txFilter = value),
    );
  }

  void _showDetail(BuildContext context, WalletTransaction tx) {
    final money = NumberFormat.currency(
      symbol: '${tx.currency} ',
      decimalDigits: 0,
    );
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Transaction details',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailRow('Type', tx.type.label, subtext),
            _detailRow('Status', tx.status.label, subtext),
            _detailRow(
              'Amount',
              '${tx.isDebit ? '-' : '+'}${money.format(tx.amount)}',
              subtext,
            ),
            if (tx.reference != null)
              _detailRow('Reference', tx.reference!, subtext),
            if (tx.note != null)
              _detailRow('Note', tx.note!, subtext),
            _detailRow(
              'Date',
              DateFormat('MMM d, yyyy HH:mm').format(tx.createdAt),
              subtext,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color subtext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: subtext)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WalletController>();
    final wallet = ctrl.wallet;
    final money = NumberFormat.currency(
      symbol: '${wallet?.currency ?? 'KES'} ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () => context.read<WalletController>().load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDeep, AppColors.primarySoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money.format(wallet?.balance ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _InlineStat(
                        label: 'Pending',
                        value: money.format(wallet?.pending ?? 0),
                      ),
                      const SizedBox(width: 24),
                      _InlineStat(
                        label: 'Lifetime',
                        value: money.format(wallet?.lifetimeEarnings ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PayoutScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Withdraw'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const EarningsStatementScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Statement'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Recent transactions'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _filterChip('All', 'all'),
                _filterChip('Credits', 'credit'),
                _filterChip('Debits', 'debit'),
                _filterChip('Payouts', 'payout'),
              ],
            ),
            const SizedBox(height: 12),
            if (ctrl.loading && ctrl.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (ctrl.transactions.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                message: 'Complete your first task to see earnings here.',
              )
            else
              ..._filtered(ctrl.transactions).map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TxTile(
                    tx: tx,
                    onTap: () => _showDetail(context, tx),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTransaction tx;
  final VoidCallback? onTap;
  const _TxTile({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final money = NumberFormat.currency(
      symbol: '${tx.currency} ',
      decimalDigits: 0,
    );
    final sign = tx.isDebit ? '-' : '+';
    final color = tx.isDebit ? AppColors.danger : AppColors.success;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.isDebit
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.reference ?? tx.note ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${money.format(tx.amount)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d').format(tx.createdAt),
                style: TextStyle(color: subtext, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
