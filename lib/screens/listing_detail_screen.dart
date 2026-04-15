import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/marketplace.dart';
import '../services/marketplace_service.dart';
import '../theme/app_theme.dart';

// ─── Bid form bottom sheet ────────────────────────────────────────────────────

class _BidFormSheet extends StatefulWidget {
  final MarketplaceListing listing;
  final MyBidOnListing? existingBid;
  final VoidCallback onSuccess;

  const _BidFormSheet({
    required this.listing,
    this.existingBid,
    required this.onSuccess,
  });

  @override
  State<_BidFormSheet> createState() => _BidFormSheetState();
}

class _BidFormSheetState extends State<_BidFormSheet> {
  final _service = MarketplaceService();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill with budget as suggested amount
    _amountCtrl.text = (widget.listing.budgetCents ~/ 100).toString();
    if (widget.existingBid != null) {
      _amountCtrl.text = (widget.existingBid!.proposedCents ~/ 100).toString();
      _noteCtrl.text = widget.existingBid!.coverNote ?? '';
      _daysCtrl.text = widget.existingBid!.estimatedDays?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
      final proposedCents = (amount * 100).round();
      final days = _daysCtrl.text.isNotEmpty ? int.tryParse(_daysCtrl.text) : null;

      await _service.placeBid(
        listingId: widget.listing.id,
        proposedCents: proposedCents,
        coverNote: _noteCtrl.text.trim(),
        estimatedDays: days,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bid placed! The org will be notified.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(
                  color: t.dividerColor, borderRadius: BorderRadius.circular(2),
                )),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingBid != null ? 'Update your bid' : 'Place a bid',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          widget.listing.title,
                          style: TextStyle(fontSize: 13, color: subtext),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Budget reference
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('Budget', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
                        Text(
                          'KES ${(widget.listing.budgetCents ~/ 100).toString()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount
              Text('Your bid amount (KES) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtext)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  prefixText: 'KES ',
                  hintText: '0',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final val = double.tryParse(v.replaceAll(',', ''));
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cover note
              Text('Cover note * (min 20 characters)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtext)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Introduce yourself, explain why you\'re the best fit for this task, describe your approach…',
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 20) return 'Cover note must be at least 20 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Estimated days
              Text('Estimated completion (days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtext)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'e.g. 3',
                  suffixText: 'days',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be realistic — orgs prefer accurate estimates over optimistic ones.',
                style: TextStyle(fontSize: 12, color: subtext, fontStyle: FontStyle.italic),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.existingBid != null ? 'Update bid' : 'Submit bid',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your bid will be visible to the org owner only.',
                  style: TextStyle(fontSize: 12, color: subtext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reject bid modal ─────────────────────────────────────────────────────────

class _RejectBidSheet extends StatefulWidget {
  final BidItem bid;
  final String listingId;
  final VoidCallback onSuccess;

  const _RejectBidSheet({required this.bid, required this.listingId, required this.onSuccess});

  @override
  State<_RejectBidSheet> createState() => _RejectBidSheetState();
}

class _RejectBidSheetState extends State<_RejectBidSheet> {
  final _service = MarketplaceService();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _service.rejectBid(widget.listingId, widget.bid.id, note: _noteCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid declined.'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: t.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Decline bid from ${widget.bid.agentName}', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('KES ${(widget.bid.proposedCents ~/ 100).toStringAsFixed(0)} · ${widget.bid.estimatedDays != null ? '${widget.bid.estimatedDays}d' : 'no ETA'}',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 16),
          Text('Feedback for the agent (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subtext)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'e.g. We went with a more experienced candidate…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: _loading ? null : _reject,
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bid tile (for org owner) ─────────────────────────────────────────────────

class _BidTile extends StatelessWidget {
  final BidItem bid;
  final String listingId;
  final int listingBudgetCents;
  final VoidCallback onRefresh;

  const _BidTile({
    required this.bid,
    required this.listingId,
    required this.listingBudgetCents,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final service = MarketplaceService();
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    Color statusColor;
    String statusLabel;
    switch (bid.status) {
      case 'ACCEPTED':  statusColor = AppColors.success; statusLabel = 'Accepted'; break;
      case 'REJECTED':  statusColor = AppColors.danger;  statusLabel = 'Declined'; break;
      case 'WITHDRAWN': statusColor = subtext;            statusLabel = 'Withdrawn'; break;
      default:          statusColor = AppColors.warn;     statusLabel = 'Pending';
    }

    final isPending = bid.status == 'PENDING';
    final budgetDiff = bid.proposedCents - listingBudgetCents;
    final pctLabel = listingBudgetCents > 0
        ? '${budgetDiff >= 0 ? '+' : ''}${(budgetDiff / listingBudgetCents * 100).round()}%'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bid.status == 'ACCEPTED' ? AppColors.success : borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: name + amount + status
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: Text(
                    bid.agentName.isNotEmpty ? bid.agentName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bid.agentName, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (bid.agentEmail != null)
                        Text(bid.agentEmail!, style: TextStyle(fontSize: 12, color: subtext)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES ${(bid.proposedCents ~/ 100).toStringAsFixed(0)}',
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (pctLabel != null)
                      Text(
                        pctLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: budgetDiff <= 0 ? AppColors.success : AppColors.warn,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Meta: ETA + skills + task count
            Wrap(
              spacing: 12,
              children: [
                if (bid.estimatedDays != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 13, color: subtext),
                    const SizedBox(width: 4),
                    Text('${bid.estimatedDays}d', style: TextStyle(fontSize: 12, color: subtext)),
                  ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.task_alt_rounded, size: 13, color: subtext),
                  const SizedBox(width: 4),
                  Text('${bid.completedTaskCount} tasks done', style: TextStyle(fontSize: 12, color: subtext)),
                ]),
              ],
            ),

            // Skills
            if (bid.agentSkills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: bid.agentSkills.take(4).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 11, color: subtext)),
                )).toList(),
              ),
            ],

            // Cover note
            if (bid.coverNote != null && bid.coverNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${bid.coverNote}"',
                  style: TextStyle(fontSize: 13, color: subtext, fontStyle: FontStyle.italic, height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Action buttons (pending only)
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (_) => _RejectBidSheet(
                          bid: bid,
                          listingId: listingId,
                          onSuccess: onRefresh,
                        ),
                      ),
                      child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          await service.acceptBid(listingId, bid.id);
                          onRefresh();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bid accepted! Task assigned to ${bid.agentName}.'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                      child: const Text('Accept bid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Main detail screen ───────────────────────────────────────────────────────

class ListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = MarketplaceService();
  MarketplaceListing? _listing;
  List<BidItem> _bids = [];
  bool _loading = true;
  bool _loadingBids = false;
  String? _error;
  late TabController _tabCtrl;
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
      final listing = await _service.getListing(widget.listingId);
      setState(() { _listing = listing; _loading = false; });
      // Load bids for org owner
      _loadBids();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _loadBids() async {
    setState(() => _loadingBids = true);
    try {
      final bids = await _service.getListingBids(widget.listingId);
      if (mounted) setState(() { _bids = bids; _loadingBids = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBids = false);
    }
  }

  Future<void> _withdrawBid() async {
    final bid = _listing?.myBid;
    if (bid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw your bid?'),
        content: const Text('This will remove your bid from this listing. You can bid again if the listing is still open.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _withdrawing = true);
    try {
      await _service.withdrawBid(bid.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bid withdrawn.'), behavior: SnackBarBehavior.floating),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  void _openBidForm() {
    if (_listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BidFormSheet(
        listing: _listing!,
        existingBid: _listing!.myBid,
        onSuccess: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
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
        ),
      );
    }
    final listing = _listing!;
    final myBid = listing.myBid;
    final hasAccepted = _bids.any((b) => b.status == 'ACCEPTED');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          listing.businessName,
          style: t.appBarTheme.titleTextStyle?.copyWith(fontSize: 15),
        ),
        actions: [
          if (listing.bidCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${listing.bidCount} bids',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Bids'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Tab 1: Details ─────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + budget hero
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.12),
                        AppColors.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (listing.category != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(listing.category!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                      Text(listing.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.business_rounded, size: 14, color: subtext),
                          const SizedBox(width: 4),
                          Text(listing.businessName, style: TextStyle(fontSize: 13, color: subtext, fontWeight: FontWeight.w600)),
                          if (listing.businessCity != null) ...[
                            Text(' · ', style: TextStyle(color: subtext)),
                            Text(listing.businessCity!, style: TextStyle(fontSize: 13, color: subtext)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _DetailStat(
                            icon: Icons.attach_money_rounded,
                            label: 'Budget',
                            value: 'KES ${(listing.budgetCents ~/ 100).toStringAsFixed(0)}',
                            valueColor: AppColors.accent,
                          ),
                          _DetailStat(
                            icon: Icons.schedule_rounded,
                            label: 'Deadline',
                            value: listing.deadlineLabel,
                            valueColor: listing.isDeadlineUrgent ? AppColors.danger : null,
                          ),
                          if (listing.locationText != null)
                            _DetailStat(
                              icon: Icons.location_on_rounded,
                              label: 'Location',
                              value: listing.locationText!,
                            ),
                          _DetailStat(
                            icon: Icons.gavel_rounded,
                            label: 'Bids',
                            value: '${listing.bidCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Description
                Text('Task description', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(listing.description, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? AppColors.darkText : AppColors.lightText)),

                // Skills
                if (listing.requiredSkills.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Required skills', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: listing.requiredSkills.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                ],

                // My bid status (agent view)
                if (myBid != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (myBid.status == 'ACCEPTED' ? AppColors.success : myBid.status == 'REJECTED' ? AppColors.danger : AppColors.warn).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (myBid.status == 'ACCEPTED' ? AppColors.success : myBid.status == 'REJECTED' ? AppColors.danger : AppColors.warn).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              myBid.status == 'ACCEPTED'
                                  ? Icons.check_circle_rounded
                                  : myBid.status == 'REJECTED'
                                  ? Icons.cancel_rounded
                                  : Icons.hourglass_top_rounded,
                              color: myBid.status == 'ACCEPTED' ? AppColors.success : myBid.status == 'REJECTED' ? AppColors.danger : AppColors.warn,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              myBid.status == 'ACCEPTED' ? 'Your bid was accepted!' : myBid.status == 'REJECTED' ? 'Not selected' : 'Your bid is under review',
                              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Proposed: KES ${(myBid.proposedCents ~/ 100).toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: subtext)),
                        if (myBid.estimatedDays != null)
                          Text('Estimated: ${myBid.estimatedDays} days', style: TextStyle(fontSize: 13, color: subtext)),
                        if (myBid.rejectionNote != null) ...[
                          const SizedBox(height: 8),
                          Text('Feedback: ${myBid.rejectionNote}', style: TextStyle(fontSize: 13, color: subtext)),
                        ],
                        if (myBid.status == 'PENDING') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _withdrawing ? null : _withdrawBid,
                                  child: const Text('Withdraw bid', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: _openBidForm,
                                  child: const Text('Edit bid', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Tab 2: Bids ────────────────────────────────────
          _loadingBids
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _bids.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: subtext.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No bids yet', style: t.textTheme.titleSmall?.copyWith(color: subtext)),
                          const SizedBox(height: 4),
                          Text('Bids from free agents will appear here.', style: TextStyle(fontSize: 13, color: subtext)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: _loadBids,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          if (hasAccepted)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  const Text('A bid has been accepted and the task is assigned.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                                ],
                              ),
                            ),
                          ..._bids.map((bid) => _BidTile(
                            bid: bid,
                            listingId: listing.id,
                            listingBudgetCents: listing.budgetCents,
                            onRefresh: () { _load(); _loadBids(); },
                          )),
                        ],
                      ),
                    ),
        ],
      ),

      // ── FAB: place bid (agent, no existing bid) ──────────
      floatingActionButton: myBid == null && !hasAccepted
          ? FloatingActionButton.extended(
              onPressed: _openBidForm,
              backgroundColor: AppColors.accent,
              icon: const Icon(Icons.gavel_rounded, color: Colors.white),
              label: const Text('Place bid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailStat({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: subtext),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: subtext)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}
