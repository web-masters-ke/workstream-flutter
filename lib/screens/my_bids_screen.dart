import 'package:flutter/material.dart';

import '../models/marketplace.dart';
import '../services/marketplace_service.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';

class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({super.key});

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen>
    with SingleTickerProviderStateMixin {
  final _service = MarketplaceService();
  List<MyBid> _bids = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  static const _tabs = ['All', 'Pending', 'Accepted', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bids = await _service.myBids();
      if (mounted) setState(() { _bids = bids; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<MyBid> _filtered(String tab) {
    return switch (tab) {
      'Pending'  => _bids.where((b) => b.status == 'PENDING').toList(),
      'Accepted' => _bids.where((b) => b.status == 'ACCEPTED').toList(),
      'Rejected' => _bids.where((b) => b.status == 'REJECTED').toList(),
      _          => _bids,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final accepted = _bids.where((b) => b.status == 'ACCEPTED').length;
    final pending  = _bids.where((b) => b.status == 'PENDING').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bids'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs.map((tab) {
            final count = switch (tab) {
              'Pending'  => pending,
              'Accepted' => accepted,
              'Rejected' => _bids.where((b) => b.status == 'REJECTED').length,
              _          => _bids.length,
            };
            return Tab(text: count > 0 ? '$tab ($count)' : tab);
          }).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Accepted highlight
                    if (accepted > 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$accepted bid${accepted > 1 ? 's' : ''} accepted! Head to Tasks to get started.',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Win rate stats
                    if (_bids.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            _StatCard(label: 'Total', value: '${_bids.length}'),
                            const SizedBox(width: 8),
                            _StatCard(label: 'Pending', value: '$pending', color: AppColors.warn),
                            const SizedBox(width: 8),
                            _StatCard(label: 'Won', value: '$accepted', color: AppColors.success),
                            const SizedBox(width: 8),
                            _StatCard(
                              label: 'Win rate',
                              value: _bids.isNotEmpty ? '${(accepted / _bids.length * 100).round()}%' : '—',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: _tabs.map((tab) {
                          final bids = _filtered(tab);
                          if (bids.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_rounded, size: 48, color: subtext.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  Text(
                                    tab == 'All' ? 'No bids placed yet' : 'No $tab bids',
                                    style: t.textTheme.titleSmall?.copyWith(color: subtext),
                                  ),
                                  if (tab == 'All') ...[
                                    const SizedBox(height: 6),
                                    Text('Browse the marketplace and start bidding.', style: TextStyle(fontSize: 13, color: subtext)),
                                  ],
                                ],
                              ),
                            );
                          }
                          return RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: bids.length,
                              itemBuilder: (ctx, i) => _BidCard(
                                bid: bids[i],
                                onWithdraw: _load,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListingDetailScreen(listingId: bids[i].taskId),
                                  ),
                                ).then((_) => _load()),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
          ],
        ),
      ),
    );
  }
}

// ─── Bid card ─────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final MyBid bid;
  final VoidCallback onWithdraw;
  final VoidCallback onTap;

  const _BidCard({required this.bid, required this.onWithdraw, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (bid.status) {
      case 'ACCEPTED':
        statusColor = AppColors.success; statusIcon = Icons.check_circle_rounded; statusLabel = 'Accepted!';
        break;
      case 'REJECTED':
        statusColor = AppColors.danger; statusIcon = Icons.cancel_rounded; statusLabel = 'Not selected';
        break;
      case 'WITHDRAWN':
        statusColor = subtext; statusIcon = Icons.remove_circle_outline_rounded; statusLabel = 'Withdrawn';
        break;
      default:
        statusColor = AppColors.warn; statusIcon = Icons.hourglass_top_rounded; statusLabel = 'Pending review';
    }

    final budgetDiff = bid.proposedCents - bid.listing.budgetCents;
    final pct = bid.listing.budgetCents > 0
        ? (budgetDiff / bid.listing.budgetCents * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: bid.status == 'ACCEPTED' ? AppColors.success : borderColor,
            width: bid.status == 'ACCEPTED' ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 6),
                  Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                  const Spacer(),
                  Text(
                    'KES ${(bid.proposedCents ~/ 100).toStringAsFixed(0)}',
                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                bid.listing.title,
                style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(bid.listing.businessName, style: TextStyle(fontSize: 12, color: subtext)),
                  if (bid.listing.category != null) ...[
                    Text(' · ', style: TextStyle(color: subtext)),
                    Text(bid.listing.category!, style: TextStyle(fontSize: 12, color: subtext)),
                  ],
                  const Spacer(),
                  if (budgetDiff != 0)
                    Text(
                      '${budgetDiff < 0 ? '' : '+'}$pct% vs budget',
                      style: TextStyle(
                        fontSize: 11,
                        color: budgetDiff < 0 ? AppColors.success : AppColors.warn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),

              // Rejection note
              if (bid.status == 'REJECTED' && bid.rejectionNote != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.feedback_outlined, size: 13, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bid.rejectionNote!,
                          style: const TextStyle(fontSize: 12, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Withdraw button
              if (bid.status == 'PENDING') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Withdraw bid?'),
                          content: const Text('This removes your bid. You can bid again if the listing is still open.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Withdraw'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await MarketplaceService().withdrawBid(bid.id);
                          onWithdraw();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Withdraw bid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
              ],

              // Go to task (accepted)
              if (bid.status == 'ACCEPTED') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.success),
                      ],
                    ),
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
