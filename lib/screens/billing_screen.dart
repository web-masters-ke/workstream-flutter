import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class _BillingWallet {
  final double total;
  final double reserved;
  final double available;
  final String currency;

  const _BillingWallet({
    required this.total,
    required this.reserved,
    required this.available,
    this.currency = 'KES',
  });

  factory _BillingWallet.fromJson(Map<String, dynamic> j) {
    final bal = _d(j['balance'] ?? j['total']);
    final reserved = _d(j['reservedBalance'] ?? j['reserved'] ?? j['pending']);
    return _BillingWallet(
      total: bal,
      reserved: reserved,
      available: _d(j['available'] ?? (bal - reserved)),
      currency: 'KES', // Always KES for East Africa market
    );
  }

  factory _BillingWallet.empty() =>
      const _BillingWallet(total: 0, reserved: 0, available: 0);

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _BillingTx {
  final String id;
  final String type; // TOPUP, DEBIT, PAYOUT, EARNING, etc.
  final String status; // COMPLETED, PENDING, FAILED
  final double amount;
  final String currency;
  final String? description;
  final String? reference;
  final DateTime createdAt;

  _BillingTx({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    this.currency = 'KES',
    this.description,
    this.reference,
    required this.createdAt,
  });

  bool get isCredit =>
      type.toUpperCase() == 'TOPUP' ||
      type.toUpperCase() == 'EARNING' ||
      type.toUpperCase() == 'BONUS' ||
      type.toUpperCase() == 'REFUND';

  factory _BillingTx.fromJson(Map<String, dynamic> j) => _BillingTx(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'DEBIT',
        status: j['status']?.toString() ?? 'PENDING',
        amount: _d(j['amount']),
        currency: j['currency']?.toString() ?? 'KES',
        description: j['description']?.toString() ?? j['note']?.toString(),
        reference: j['reference']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _Plan {
  final String id;
  final String name;
  final double price;
  final List<String> features;
  final bool isCurrent;

  const _Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    this.isCurrent = false,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  _BillingWallet _wallet = _BillingWallet.empty();
  List<_BillingTx> _transactions = [];
  bool _loading = true;
  String? _error;
  String _txFilter = 'all';
  bool _autoRecharge = false;
  final _autoThresholdCtrl = TextEditingController(text: '500');
  final _autoAmountCtrl = TextEditingController(text: '2000');

  // Hardcoded plans
  final List<_Plan> _plans = const [
    _Plan(
      id: 'free',
      name: 'Free',
      price: 0,
      features: ['5 agents', 'Basic tasks', 'Community support'],
    ),
    _Plan(
      id: 'starter',
      name: 'Starter',
      price: 2999,
      features: ['20 agents', 'Task management', 'Email support'],
      isCurrent: true,
    ),
    _Plan(
      id: 'growth',
      name: 'Growth',
      price: 7999,
      features: ['100 agents', 'Advanced analytics', 'Priority support'],
    ),
    _Plan(
      id: 'enterprise',
      name: 'Enterprise',
      price: 24999,
      features: [
        'Unlimited agents',
        'API access & webhooks',
        'Dedicated manager'
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoThresholdCtrl.dispose();
    _autoAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final walletResp = await ApiService.instance.get('/wallet');
      final walletData = unwrap<dynamic>(walletResp);
      if (walletData is Map<String, dynamic>) {
        _wallet = _BillingWallet.fromJson(walletData);
      }
    } catch (e) {
      _error = cleanError(e);
    }

    try {
      final txResp =
          await ApiService.instance.get('/wallet/transactions');
      final txData = unwrap<dynamic>(txResp);
      List<dynamic> list;
      if (txData is List) {
        list = txData;
      } else if (txData is Map && txData['items'] is List) {
        list = txData['items'] as List;
      } else {
        list = [];
      }
      _transactions = list
          .whereType<Map<String, dynamic>>()
          .map(_BillingTx.fromJson)
          .toList();
    } catch (_) {
      _transactions = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  List<_BillingTx> get _filtered {
    switch (_txFilter) {
      case 'topups':
        return _transactions
            .where((t) => t.type.toUpperCase() == 'TOPUP')
            .toList();
      case 'debits':
        return _transactions.where((t) => !t.isCredit).toList();
      case 'payouts':
        return _transactions
            .where((t) => t.type.toUpperCase() == 'PAYOUT')
            .toList();
      default:
        return _transactions;
    }
  }

  void _showTopUpSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TopUpSheet(
        currency: _wallet.currency,
        onComplete: _load,
      ),
    );
  }

  Future<void> _saveAutoRecharge() async {
    try {
      await ApiService.instance.patch('/wallet/auto-recharge', body: {
        'enabled': _autoRecharge,
        'threshold': double.tryParse(_autoThresholdCtrl.text) ?? 500,
        'amount': double.tryParse(_autoAmountCtrl.text) ?? 2000,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-recharge settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${cleanError(e)}')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESS':
        return AppColors.success;
      case 'FAILED':
        return AppColors.danger;
      default:
        return AppColors.warn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final money = NumberFormat.currency(
      symbol: '${_wallet.currency} ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Subscriptions'),
        actions: [
          TextButton.icon(
            onPressed: _showTopUpSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Top up'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // ── Loading indicator ──
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        color: AppColors.primary,
                        minHeight: 2,
                      ),
                    ),

                  // ── Error banner ──
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),

                  // ── Balance cards ──
                  _BalanceCard(
                    label: 'Total balance',
                    value: '${_wallet.currency} ${_wallet.total.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceCard(
                          label: 'Reserved',
                          value: '${_wallet.currency} ${_wallet.reserved.toStringAsFixed(0)}',
                          icon: Icons.lock_rounded,
                          color: AppColors.warn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BalanceCard(
                          label: 'Available',
                          value: '${_wallet.currency} ${_wallet.available.toStringAsFixed(0)}',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Subscription plans ──
                  Text('Subscription plans', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...List.generate(_plans.length, (i) {
                    final plan = _plans[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: plan.isCurrent ? AppColors.primary : t.dividerColor,
                          width: plan.isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    if (plan.isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(plan.features.join(' · '), style: TextStyle(fontSize: 11, color: subtext), maxLines: 2),
                              ],
                            ),
                          ),
                          Text('KES ${plan.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 15)),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // ── Transaction history ──
                  Text('Transactions', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip('All', 'all'),
                      _chip('Top-ups', 'topups'),
                      _chip('Debits', 'debits'),
                      _chip('Payouts', 'payouts'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message: 'Your transaction history will appear here.',
                    )
                  else
                    ..._filtered.map((tx) => _TxRow(
                          tx: tx,
                          money: money,
                          subtext: subtext,
                          statusColor: _statusColor(tx.status),
                        )),

                  const SizedBox(height: 28),

                  // ── Subscription plans ──
                  const SectionHeader(title: 'Subscription plans'),
                  const SizedBox(height: 12),
                  ..._plans.map((plan) => _PlanCard(
                        plan: plan,
                        money: money,
                        subtext: subtext,
                      )),

                  const SizedBox(height: 28),

                  // ── Auto-recharge settings ──
                  const SectionHeader(title: 'Auto-recharge'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Enable auto-recharge',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Automatically top up when balance is low',
                                    style: TextStyle(
                                        color: subtext, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoRecharge,
                              activeTrackColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              activeThumbColor: AppColors.primary,
                              onChanged: (v) =>
                                  setState(() => _autoRecharge = v),
                            ),
                          ],
                        ),
                        if (_autoRecharge) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: WsTextField(
                                  controller: _autoThresholdCtrl,
                                  label: 'When below',
                                  hint: '500',
                                  icon: Icons.trending_down_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: WsTextField(
                                  controller: _autoAmountCtrl,
                                  label: 'Top up amount',
                                  hint: '2000',
                                  icon: Icons.payments_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saveAutoRecharge,
                              child: const Text('Save settings'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final active = _txFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      onSelected: (_) => setState(() => _txFilter = value),
    );
  }
}

// ─── Balance Card ───────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: subtext, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Transaction Row ────────────────────────────────────────────────────────

class _TxRow extends StatelessWidget {
  final _BillingTx tx;
  final NumberFormat money;
  final Color subtext;
  final Color statusColor;

  const _TxRow({
    required this.tx,
    required this.money,
    required this.subtext,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final amtColor = tx.isCredit ? AppColors.success : AppColors.danger;
    final sign = tx.isCredit ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              color: amtColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: amtColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(tx.createdAt),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(
                      label: tx.type,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (tx.description != null)
                  Text(
                    tx.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
                if (tx.reference != null)
                  Text(
                    'Ref: ${tx.reference}',
                    style: TextStyle(color: subtext, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${money.format(tx.amount)}',
                style: TextStyle(
                    color: amtColor, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 3),
              StatusPill(label: tx.status, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Plan Card ──────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final NumberFormat money;
  final Color subtext;

  const _PlanCard({
    required this.plan,
    required this.money,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isCurrent
              ? AppColors.primary.withValues(alpha: 0.6)
              : t.dividerColor,
          width: plan.isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (plan.isCurrent) ...[
                      const SizedBox(width: 8),
                      const StatusPill(
                          label: 'Current', color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.price == 0
                      ? 'Free'
                      : '${money.format(plan.price)}/mo',
                  style: TextStyle(
                      color: subtext,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: plan.features
                      .map((f) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded,
                                  size: 14, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(f,
                                  style: TextStyle(
                                      fontSize: 12, color: subtext)),
                            ],
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          if (!plan.isCurrent)
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switching to ${plan.name} plan...'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('Select',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─── Top Up Bottom Sheet (3-step flow) ──────────────────────────────────────

enum _TopUpStep { form, awaiting, success }

class _TopUpSheet extends StatefulWidget {
  final String currency;
  final VoidCallback onComplete;
  const _TopUpSheet({required this.currency, required this.onComplete});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  _TopUpStep _step = _TopUpStep.form;
  String _method = 'mpesa'; // mpesa | card
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+254 ');
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();
  bool _busy = false;
  Timer? _pollTimer;
  String? _topUpRef;

  static const _quickAmounts = [500, 1000, 2500, 5000, 10000];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_method == 'mpesa' && _phoneCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final resp = await ApiService.instance.post('/wallet/topup', body: {
        'amountCents': (amount * 100).round(),
        'phone': _phoneCtrl.text.trim(),
        'method': _method.toUpperCase(),
      });
      final data = unwrap<dynamic>(resp);
      _topUpRef = (data is Map ? data['reference']?.toString() : null) ??
          'TU${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _step = _TopUpStep.awaiting;
        _busy = false;
      });
      _startPolling();
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${cleanError(e)}')),
        );
      }
    }
  }

  void _startPolling() {
    if (_topUpRef == null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final resp = await ApiService.instance
            .get('/wallet/topup/$_topUpRef/status');
        final data = unwrap<dynamic>(resp);
        final status =
            (data is Map ? data['status']?.toString() : null) ?? '';
        if (status.toUpperCase() == 'COMPLETED' ||
            status.toUpperCase() == 'SUCCESS') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _step = _TopUpStep.success);
          }
        }
      } catch (_) {
        // keep polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            Text(
              _step == _TopUpStep.success ? 'Payment received' : 'Top up wallet',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (_step == _TopUpStep.form) _buildForm(t, subtext),
            if (_step == _TopUpStep.awaiting) _buildAwaiting(t, subtext),
            if (_step == _TopUpStep.success) _buildSuccess(t),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payment method toggle
        const Text('Payment method',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _method = 'mpesa'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _method == 'mpesa'
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : t.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _method == 'mpesa'
                          ? AppColors.primary
                          : t.dividerColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.phone_android_rounded,
                          color: _method == 'mpesa'
                              ? AppColors.primary
                              : subtext),
                      const SizedBox(height: 4),
                      Text(
                        'M-Pesa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _method == 'mpesa'
                              ? AppColors.primary
                              : subtext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _method = 'card'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _method == 'card'
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : t.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _method == 'card'
                          ? AppColors.primary
                          : t.dividerColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_rounded,
                          color: _method == 'card'
                              ? AppColors.primary
                              : subtext),
                      const SizedBox(height: 4),
                      Text(
                        'Card',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _method == 'card'
                              ? AppColors.primary
                              : subtext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick amount buttons
        const Text('Quick amount',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickAmounts.map((a) {
            return GestureDetector(
              onTap: () => setState(() => _amountCtrl.text = '$a'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _amountCtrl.text == '$a'
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : t.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _amountCtrl.text == '$a'
                        ? AppColors.primary
                        : t.dividerColor,
                  ),
                ),
                child: Text(
                  '${widget.currency} ${NumberFormat('#,###').format(a)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _amountCtrl.text == '$a'
                        ? AppColors.primary
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        WsTextField(
          controller: _amountCtrl,
          label: 'Custom amount',
          hint: 'e.g. 3000',
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),

        if (_method == 'mpesa')
          WsTextField(
            controller: _phoneCtrl,
            label: 'M-Pesa phone number',
            hint: '+254 7XX XXX XXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

        if (_method == 'card') ...[
          WsTextField(
            controller: _cardNumberCtrl,
            label: 'Card number',
            hint: '4242 4242 4242 4242',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: WsTextField(
                  controller: _cardExpiryCtrl,
                  label: 'Expiry',
                  hint: 'MM/YY',
                  icon: Icons.date_range_rounded,
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WsTextField(
                  controller: _cardCvvCtrl,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(_method == 'mpesa' ? 'Top up via M-Pesa' : 'Pay with card'),
          ),
        ),
      ],
    );
  }

  Widget _buildAwaiting(ThemeData t, Color subtext) {
    return Column(
      children: [
        const SizedBox(height: 24),
        const CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 3),
        const SizedBox(height: 20),
        const Text(
          'Waiting for M-Pesa confirmation...',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your phone and enter your M-Pesa PIN to complete the payment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtext, fontSize: 13),
        ),
        if (_topUpRef != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ref: $_topUpRef',
            style: TextStyle(color: subtext, fontSize: 11),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildSuccess(ThemeData t) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Payment received!',
          style:
              t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your wallet balance has been updated.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.onComplete();
            Navigator.pop(context);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
