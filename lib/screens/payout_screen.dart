import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/wallet_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

enum _Step { form, review, success }

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _account = TextEditingController(text: '+254 ');
  String _method = 'M-Pesa';
  bool _busy = false;
  _Step _step = _Step.form;
  String? _reference;

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  void _toReview() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = _Step.review);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final amount = double.tryParse(_amount.text) ?? 0;
    final ctrl = context.read<WalletController>();
    final result = await ctrl.requestPayout(
      amount: amount,
      method: _method,
      destination: _account.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result) {
      setState(() {
        _step = _Step.success;
        _reference = 'WS${DateTime.now().millisecondsSinceEpoch}';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'Payout failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>().wallet;
    final money = NumberFormat.currency(
      symbol: '${wallet?.currency ?? 'KES'} ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: _step == _Step.success
          ? null
          : AppBar(
              title: Text(
                  _step == _Step.form ? 'Request payout' : 'Confirm payout'),
              leading: _step == _Step.review
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _step = _Step.form),
                    )
                  : null,
            ),
      body: SafeArea(
        child: switch (_step) {
          _Step.form => _buildForm(wallet, money),
          _Step.review => _buildReview(money),
          _Step.success => _buildSuccess(),
        },
      ),
    );
  }

  Widget _buildForm(dynamic wallet, NumberFormat money) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Available: ${money.format(wallet?.balance ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            WsTextField(
              controller: _amount,
              label: 'Amount',
              hint: 'e.g. 2000',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                if ((wallet?.balance ?? 0) < n) return 'Exceeds balance';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text('Method',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Row(
              children: [
                for (final m in ['M-Pesa', 'Airtel Money', 'Bank'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            WsTextField(
              controller: _account,
              label: _method == 'Bank' ? 'Bank account' : 'Phone number',
              icon: _method == 'Bank'
                  ? Icons.account_balance_outlined
                  : Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().length < 6) ? 'Required' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _toReview,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(NumberFormat money) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final amount = double.tryParse(_amount.text) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor),
            ),
            child: Column(
              children: [
                Text('You are sending',
                    style: TextStyle(color: subtext, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  money.format(amount),
                  style: t.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _reviewRow('Method', _method, subtext),
                _reviewRow('To', _account.text.trim(), subtext),
                _reviewRow('Fee', money.format(0), subtext),
                const Divider(height: 24),
                _reviewRow('Total', money.format(amount), subtext,
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Confirm payout'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _step = _Step.form),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, Color sub,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: sub)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Payout submitted',
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your payout is being processed and should arrive shortly.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium,
            ),
            if (_reference != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: t.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.dividerColor),
                ),
                child: Text('Ref: $_reference',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
