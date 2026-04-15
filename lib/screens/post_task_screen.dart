import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/marketplace_service.dart';
import '../theme/app_theme.dart';

// ─── Category picker ──────────────────────────────────────────────────────────

const _kCategories = [
  'Development', 'Design', 'Marketing', 'Writing & Content',
  'Data & Analytics', 'Video & Audio', 'Finance & Accounting',
  'Customer Support', 'HR & Recruitment', 'Legal', 'Sales', 'Other',
];

const _kCommonSkills = [
  'Flutter', 'React', 'Node.js', 'Python', 'Java', 'Swift',
  'Figma', 'Photoshop', 'Illustrator', 'UI/UX',
  'SEO', 'Social Media', 'Copywriting', 'Excel', 'SQL',
  'Data Analysis', 'Machine Learning', 'AWS', 'Docker',
  'Project Management', 'Salesforce', 'HubSpot',
];

// ─── Step chip widget ─────────────────────────────────────────────────────────

class _StepChip extends StatelessWidget {
  final int step;
  final String label;
  final bool active;
  final bool done;

  const _StepChip({required this.step, required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done
                ? AppColors.success
                : active
                ? AppColors.accent
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: done ? AppColors.success : active ? AppColors.accent : subtext.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : subtext,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? (isDark ? AppColors.darkText : AppColors.lightText) : subtext,
          ),
        ),
      ],
    );
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class PostTaskScreen extends StatefulWidget {
  const PostTaskScreen({super.key});

  @override
  State<PostTaskScreen> createState() => _PostTaskScreenState();
}

class _PostTaskScreenState extends State<PostTaskScreen> {
  final _service = MarketplaceService();
  final _pageCtrl = PageController();
  int _page = 0; // 0=basics, 1=details, 2=settings

  // Step 1 — Basics
  final _titleCtrl = TextEditingController();
  String? _selectedCategory;

  // Step 2 — Details
  final _descCtrl = TextEditingController();
  final _skillInputCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime? _dueAt;
  final List<String> _skills = [];

  // Step 3 — Settings
  final _locationCtrl = TextEditingController();
  final _maxBidsCtrl = TextEditingController();
  DateTime? _expiresAt;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _skillInputCtrl.dispose();
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    _maxBidsCtrl.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      _titleCtrl.text.trim().length >= 10 && _selectedCategory != null;

  bool get _step2Valid =>
      _descCtrl.text.trim().length >= 20 &&
      _budgetCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_budgetCtrl.text.trim()) ?? 0) > 0 &&
      _dueAt != null;

  void _nextPage() {
    if (_page < 2) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _page++);
    }
  }

  void _prevPage() {
    if (_page > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _page--);
    }
  }

  void _addSkill(String s) {
    final skill = s.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() => _skills.add(skill));
    }
    _skillInputCtrl.clear();
  }

  Future<void> _pickDate({bool isExpiry = false}) async {
    final now = DateTime.now();
    final initial = isExpiry
        ? (_expiresAt ?? now.add(const Duration(days: 30)))
        : (_dueAt ?? now.add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) { _expiresAt = picked; } else { _dueAt = picked; }
      });
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final budget = double.parse(_budgetCtrl.text.trim());
      final budgetCents = (budget * 100).round();
      final maxBids = _maxBidsCtrl.text.trim().isNotEmpty
          ? int.tryParse(_maxBidsCtrl.text.trim())
          : null;

      await _service.createListing(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selectedCategory,
        skills: _skills,
        budgetCents: budgetCents,
        dueAt: _dueAt!,
        locationText: _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : null,
        maxBids: maxBids,
        expiresAt: _expiresAt,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Listing submitted for review. You\'ll be notified when it goes live.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post a task'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _StepChip(step: 1, label: 'Basics', active: _page == 0, done: _page > 0),
                Expanded(child: Container(height: 1, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 6))),
                _StepChip(step: 2, label: 'Details', active: _page == 1, done: _page > 1),
                Expanded(child: Container(height: 1, color: borderColor, margin: const EdgeInsets.symmetric(horizontal: 6))),
                _StepChip(step: 3, label: 'Settings', active: _page == 2, done: false),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ─── Step 1: Basics ───────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What task do you need done?', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Give it a clear, specific title so free agents can immediately understand the work.', style: TextStyle(fontSize: 13, color: subtext)),
                const SizedBox(height: 20),

                // Title
                _FieldLabel('Task title *', subtext: subtext),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Build a Next.js landing page for our SaaS product',
                    counterText: '',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_titleCtrl.text.length}/120',
                    style: TextStyle(fontSize: 11, color: _titleCtrl.text.length > 100 ? AppColors.warn : subtext),
                  ),
                ),
                if (_titleCtrl.text.trim().isNotEmpty && _titleCtrl.text.trim().length < 10) ...[
                  const SizedBox(height: 4),
                  Text('Title must be at least 10 characters', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
                const SizedBox(height: 20),

                // Category
                _FieldLabel('Category *', subtext: subtext),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kCategories.map((c) {
                    final active = _selectedCategory == c;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = active ? null : c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent : cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppColors.accent : borderColor),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ─── Step 2: Details ──────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Describe the task in detail', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('The more detail you provide, the better quality bids you\'ll receive.', style: TextStyle(fontSize: 13, color: subtext)),
                const SizedBox(height: 20),

                // Description
                _FieldLabel('Full description *', subtext: subtext),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 6,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Describe what needs to be done, the expected outcome, any specific requirements, and what you\'ll provide to the agent (assets, access, etc.)…',
                    counterText: '',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_descCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().length < 20)
                      Text('Min 20 characters', style: const TextStyle(fontSize: 12, color: AppColors.danger))
                    else
                      const SizedBox.shrink(),
                    Text('${_descCtrl.text.length}/2000', style: TextStyle(fontSize: 11, color: subtext)),
                  ],
                ),
                const SizedBox(height: 20),

                // Skills
                _FieldLabel('Required skills', subtext: subtext),
                const SizedBox(height: 8),
                // Quick-add chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _kCommonSkills
                      .where((s) => !_skills.contains(s))
                      .take(16)
                      .map((s) => GestureDetector(
                            onTap: () => setState(() => _skills.add(s)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(s, style: TextStyle(fontSize: 12, color: subtext)),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                // Custom skill input
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skillInputCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add custom skill…',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onFieldSubmitted: _addSkill,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _addSkill(_skillInputCtrl.text),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_skills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _skills.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s, style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _skills.remove(s)),
                            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.accent),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // Budget
                _FieldLabel('Budget (KES) *', subtext: subtext),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _budgetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    prefixText: 'KES ',
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 20),

                // Deadline
                _FieldLabel('Deadline *', subtext: subtext),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickDate(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: _dueAt != null ? AppColors.accent : borderColor),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: _dueAt != null ? AppColors.accent : subtext),
                        const SizedBox(width: 10),
                        Text(
                          _dueAt != null ? _fmtDate(_dueAt!) : 'Pick a deadline',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _dueAt != null ? FontWeight.w600 : FontWeight.normal,
                            color: _dueAt != null ? null : subtext,
                          ),
                        ),
                        const Spacer(),
                        if (_dueAt != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueAt = null),
                            child: Icon(Icons.close_rounded, size: 16, color: subtext),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Step 3: Settings ─────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advanced settings', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('All optional. Fine-tune how your listing works.', style: TextStyle(fontSize: 13, color: subtext)),
                const SizedBox(height: 24),

                // Location
                _FieldLabel('Location / remote preference', subtext: subtext),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Nairobi, Kenya or Remote',
                    prefixIcon: Icon(Icons.location_on_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 20),

                // Max bids
                _FieldLabel('Maximum number of bids', subtext: subtext),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _maxBidsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'e.g. 20 (leave blank for unlimited)',
                  ),
                ),
                const SizedBox(height: 6),
                Text('Limit the number of agents who can bid on your task.', style: TextStyle(fontSize: 12, color: subtext)),
                const SizedBox(height: 20),

                // Listing expiry
                _FieldLabel('Listing expiry date', subtext: subtext),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickDate(isExpiry: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: _expiresAt != null ? AppColors.accent : borderColor),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_available_rounded, size: 18, color: _expiresAt != null ? AppColors.accent : subtext),
                        const SizedBox(width: 10),
                        Text(
                          _expiresAt != null ? _fmtDate(_expiresAt!) : 'No expiry (stays open until closed)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _expiresAt != null ? null : subtext,
                          ),
                        ),
                        const Spacer(),
                        if (_expiresAt != null)
                          GestureDetector(
                            onTap: () => setState(() => _expiresAt = null),
                            child: Icon(Icons.close_rounded, size: 16, color: subtext),
                          ),
                      ],
                    ),
                  ),
                ),

                // Info box
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          const Text('What happens next?', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Your listing goes to admin review (usually < 24h).\n'
                        '2. Once approved, it\'s visible to all free agents.\n'
                        '3. Agents submit bids — you review and accept one.\n'
                        '4. The task is auto-assigned. Payment is released when you mark it complete.',
                        style: TextStyle(fontSize: 13, color: subtext, height: 1.5),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
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
              ],
            ),
          ),
        ],
      ),

      // ─── Bottom bar ─────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_page > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _prevPage,
                    child: const Text('Back'),
                  ),
                ),
              if (_page > 0) const SizedBox(width: 12),
              Expanded(
                flex: _page == 0 ? 1 : 2,
                child: _page < 2
                    ? FilledButton(
                        onPressed: (_page == 0 ? _step1Valid : _page == 1 ? _step2Valid : true)
                            ? _nextPage
                            : null,
                        child: Text(
                          'Continue',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
                    : FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Submit for review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color subtext;
  const _FieldLabel(this.text, {required this.subtext});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subtext),
    );
  }
}
