import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/wallet_controller.dart';
import '../theme/app_theme.dart';

class EarningsStatementScreen extends StatelessWidget {
  const EarningsStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final wallet = context.watch<WalletController>();
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final money =
        NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    final balance = wallet.wallet?.balance ?? 0;
    final pending = wallet.wallet?.pending ?? 0;
    final lifetime = wallet.wallet?.lifetimeEarnings ?? 0;
    final txns = wallet.transactions;
    final earningTxns =
        txns.where((t) => t.type.name == 'earning').toList();
    final payoutTxns =
        txns.where((t) => t.type.name == 'payout').toList();
    final totalEarned =
        earningTxns.fold<double>(0, (s, t) => s + t.amount);
    final totalPaidOut =
        payoutTxns.fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('PDF export coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            monthLabel,
            style:
                t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _Row(label: 'Available balance', value: money.format(balance)),
          _Row(label: 'Pending', value: money.format(pending)),
          _Row(label: 'Lifetime earnings', value: money.format(lifetime)),
          const Divider(height: 32),
          _Row(
            label: 'Earned this period',
            value: money.format(totalEarned),
            color: AppColors.success,
          ),
          _Row(
            label: 'Paid out this period',
            value: money.format(totalPaidOut),
            color: AppColors.danger,
          ),
          _Row(
            label: 'Tasks completed',
            value: '${earningTxns.length}',
          ),
          const Divider(height: 32),
          Text('Recent transactions',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (txns.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text('No transactions yet', style: TextStyle(color: subtext)),
              ),
            )
          else
            ...txns.take(10).map((tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.reference ?? tx.type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${tx.isDebit ? '-' : '+'}${money.format(tx.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              tx.isDebit ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Row({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: subtext))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
