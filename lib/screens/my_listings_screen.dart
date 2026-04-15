import 'package:flutter/material.dart';

import '../models/marketplace.dart';
import '../services/marketplace_service.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';
import 'post_task_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = MarketplaceService();
  List<MyListing> _listings = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  static const _tabs = ['All', 'Review', 'Active', 'Closed'];

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
      final listings = await _service.myListings();
      if (mounted) setState(() { _listings = listings; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<MyListing> _filtered(String tab) => switch (tab) {
    'Review' => _listings.where((l) => l.marketplaceStatus == 'PENDING_REVIEW').toList(),
    'Active' => _listings.where((l) => l.marketplaceStatus == 'APPROVED' || l.marketplaceStatus == 'ACTIVE').toList(),
    'Closed' => _listings.where((l) => l.marketplaceStatus == 'CLOSED' || l.marketplaceStatus == 'EXPIRED' || l.marketplaceStatus == 'REJECTED').toList(),
    _        => _listings,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final pendingCount = _listings.where((l) => l.marketplaceStatus == 'PENDING_REVIEW').length;
    final totalBids    = _listings.fold(0, (s, l) => s + l.totalBids);
    final activeCount  = _listings.where((l) => l.marketplaceStatus == 'APPROVED' || l.marketplaceStatus == 'ACTIVE').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Post new task',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostTaskScreen()),
            ).then((_) => _load()),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: _tabs.map((tab) {
            final count = switch (tab) {
              'Review' => pendingCount,
              'Active' => activeCount,
              'Closed' => _listings.where((l) => ['CLOSED','EXPIRED','REJECTED'].contains(l.marketplaceStatus)).length,
              _        => _listings.length,
            };
            return Tab(text: count > 0 ? '$tab ($count)' : tab);
          }).toList(),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                    // Stats row
                    if (_listings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            _StatCard(label: 'Listings', value: '${_listings.length}'),
                            const SizedBox(width: 8),
                            _StatCard(label: 'Active', value: '$activeCount', color: AppColors.success),
                            const SizedBox(width: 8),
                            _StatCard(label: 'In review', value: '$pendingCount', color: AppColors.warn),
                            const SizedBox(width: 8),
                            _StatCard(label: 'Total bids', value: '$totalBids', color: AppColors.accent),
                          ],
                        ),
                      ),

                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: _tabs.map((tab) {
                          final items = _filtered(tab);
                          if (items.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.storefront_outlined, size: 56, color: subtext.withValues(alpha: 0.35)),
                                  const SizedBox(height: 14),
                                  Text(
                                    tab == 'All' ? 'No listings yet' : 'No $tab listings',
                                    style: t.textTheme.titleSmall?.copyWith(color: subtext),
                                  ),
                                  if (tab == 'All') ...[
                                    const SizedBox(height: 6),
                                    Text('Post your first task to the marketplace.', style: TextStyle(fontSize: 13, color: subtext)),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const PostTaskScreen()),
                                      ).then((_) => _load()),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Post a task'),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                          return RefreshIndicator(
                            color: AppColors.accent,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) => _ListingCard(
                                listing: items[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListingDetailScreen(listingId: items[i].id),
                                  ),
                                ).then((_) => _load()),
                                onClose: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Close listing?'),
                                      content: Text(
                                        'This will stop new bids on "${items[i].title}". You can\'t reopen it.',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Close it'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      await _service.closeListing(items[i].id);
                                      _load();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostTaskScreen()),
        ).then((_) => _load()),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
          ],
        ),
      ),
    );
  }
}

// ─── Listing card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final MyListing listing;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const _ListingCard({required this.listing, required this.onTap, required this.onClose});

  static const _statusLabel = {
    'DRAFT':          'Draft',
    'PENDING_REVIEW': 'Under Review',
    'APPROVED':       'Approved',
    'REJECTED':       'Rejected',
    'ACTIVE':         'Active',
    'CLOSED':         'Closed',
    'EXPIRED':        'Expired',
  };

  static Color _statusColor(String s) => switch (s) {
    'ACTIVE' || 'APPROVED' => AppColors.success,
    'PENDING_REVIEW'       => AppColors.warn,
    'REJECTED' || 'EXPIRED'=> AppColors.danger,
    _                      => AppColors.lightSubtext,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final sColor = _statusColor(listing.marketplaceStatus);
    final label = _statusLabel[listing.marketplaceStatus] ?? listing.marketplaceStatus;
    final canClose = listing.marketplaceStatus == 'APPROVED' || listing.marketplaceStatus == 'ACTIVE';
    final hasAccepted = listing.acceptedBids > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasAccepted ? AppColors.success : borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status + budget
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: sColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sColor)),
                      ],
                    ),
                  ),
                  if (listing.category != null) ...[
                    const SizedBox(width: 8),
                    Text(listing.category!, style: TextStyle(fontSize: 11, color: subtext)),
                  ],
                  const Spacer(),
                  Text(
                    'KES ${(listing.budgetCents ~/ 100).toStringAsFixed(0)}',
                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                listing.title,
                style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Rejection note
              if (listing.marketplaceStatus == 'REJECTED' && listing.adminRejectNote != null) ...[
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
                        child: Text(listing.adminRejectNote!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Bid stats + actions
              Row(
                children: [
                  // Bids
                  Row(children: [
                    Icon(Icons.gavel_rounded, size: 14, color: listing.totalBids > 0 ? AppColors.accent : subtext),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.totalBids} bid${listing.totalBids != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: listing.totalBids > 0 ? AppColors.accent : subtext),
                    ),
                  ]),
                  if (listing.pendingBids > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warn.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${listing.pendingBids} pending', style: const TextStyle(fontSize: 11, color: AppColors.warn, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (hasAccepted) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Accepted ✓', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (canClose && !hasAccepted)
                    GestureDetector(
                      onTap: onClose,
                      child: Text(
                        'Close',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
