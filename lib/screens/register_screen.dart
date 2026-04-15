import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'login_screen.dart';
import 'otp_verify_screen.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

const _industries = [
  'Customer Support / BPO',
  'Sales & Lead Generation',
  'Data Entry & Processing',
  'KYC & Compliance',
  'Back-Office Operations',
  'Social Media & Content',
  'Voice & Call Centre',
  'Finance & Accounts',
  'Healthcare Administration',
  'Logistics & Fulfilment',
  'Other',
];

const _teamSizes = ['1–10', '11–50', '51–200', '201–500', '500+'];

const _countries = [
  'Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'Ethiopia',
  'Nigeria', 'Ghana', 'South Africa', 'Other',
];

class _Plan {
  final String id, name, price, period;
  final List<String> features;
  final bool popular;
  const _Plan(this.id, this.name, this.price, this.period, this.features,
      {this.popular = false});
}

const _plans = [
  _Plan('free',   'Free',       'KES 0',      '/ month',
      ['Up to 2 agents', '25 tasks/month', 'Basic task tracking', 'Community support']),
  _Plan('starter','Starter',    'KES 2,999',  '/ month',
      ['Up to 5 agents', '100 tasks/month', 'Basic SLA tracking', 'Email support']),
  _Plan('growth', 'Growth',     'KES 7,999',  '/ month',
      ['Up to 25 agents', 'Unlimited tasks', 'Advanced SLA + QA', 'Live chat support', 'Wallet payouts', 'Analytics'],
      popular: true),
  _Plan('enterprise','Enterprise','KES 24,999','/ month',
      ['Unlimited agents', 'Unlimited tasks', 'Custom SLA rules', 'Dedicated manager', 'API access', 'White-label option']),
];

const _stepLabels = ['Your account', 'Your business', 'Choose plan', 'Review & launch'];

enum _AccountType { agent, business }

// ─── Root screen ──────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _AccountType _type = _AccountType.agent;
  int _step = 1; // 1–4 for business, always 1 for agent

  // Shared
  final _first = TextEditingController();
  final _last  = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw    = TextEditingController();
  final _conf  = TextEditingController();
  bool _obscure = true;
  bool _terms   = false;

  // Business only
  final _bizName    = TextEditingController();
  final _bizDesc    = TextEditingController();
  final _bizEmail   = TextEditingController();
  final _bizPhone   = TextEditingController();
  final _bizWebsite = TextEditingController();
  String _industry  = _industries.first;
  String _teamSize  = _teamSizes.first;
  String _hiringModel = 'FREELANCE';
  String _country   = 'Kenya';
  String _plan      = 'growth';

  Map<String, String> _errors = {};
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _pw, _conf,
      _bizName, _bizDesc, _bizEmail, _bizPhone, _bizWebsite]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validateStep1() {
    final e = <String, String>{};
    if (_first.text.trim().isEmpty) e['firstName'] = 'Required';
    if (_last.text.trim().isEmpty)  e['lastName']  = 'Required';
    if (_email.text.trim().isEmpty) {
      e['email'] = 'Required';
    } else if (!_email.text.contains('@')) {
      e['email'] = 'Invalid email';
    }
    if (_phone.text.trim().isEmpty) e['phone'] = 'Required';
    if (_pw.text.isEmpty) {
      e['password'] = 'Required';
    } else if (_pw.text.length < 8) {
      e['password'] = 'At least 8 characters';
    }
    if (_pw.text != _conf.text) e['confirm'] = "Passwords don't match";
    setState(() => _errors = e);
    return e.isEmpty;
  }

  bool _validateStep2() {
    final e = <String, String>{};
    if (_bizName.text.trim().isEmpty) e['bizName'] = 'Required';
    if (_bizDesc.text.trim().isEmpty) e['bizDesc'] = 'Required';
    if (_bizEmail.text.trim().isEmpty) {
      e['bizEmail'] = 'Required';
    } else if (!_bizEmail.text.contains('@')) {
      e['bizEmail'] = 'Invalid email';
    }
    if (_bizPhone.text.trim().isEmpty) e['bizPhone'] = 'Required';
    setState(() => _errors = e);
    return e.isEmpty;
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _switchType(_AccountType v) {
    setState(() { _type = v; _step = 1; _errors = {}; });
  }

  void _next() {
    setState(() => _serverError = null);
    if (_step == 1 && !_validateStep1()) return;
    if (_step == 2 && !_validateStep2()) return;
    if (_step < 4) setState(() => _step++);
  }

  void _back() {
    if (_step > 1) setState(() { _step--; _errors = {}; });
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final isBiz = _type == _AccountType.business;
    if (!isBiz) {
      if (!_validateStep1()) return;
      if (!_terms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the Terms & Conditions')));
        return;
      }
    }

    setState(() { _loading = true; _serverError = null; });
    try {
      final auth = context.read<AuthController>();
      final ok = await auth.register(
        firstName: _first.text.trim(),
        lastName:  _last.text.trim(),
        email:     _email.text.trim(),
        phone:     _phone.text.trim(),
        password:  _pw.text,
        role:      isBiz ? 'BUSINESS' : 'AGENT',
        businessName: isBiz ? _bizName.text.trim() : null,
      );

      if (!mounted) return;

      if (ok && isBiz) {
        // Best-effort: create business profile
        try {
          await ApiService.instance.post('/businesses', body: {
            'name':             _bizName.text.trim(),
            'industry':         _industry,
            'description':      _bizDesc.text.trim(),
            'website':          _bizWebsite.text.trim().isEmpty ? null : _bizWebsite.text.trim(),
            'contactEmail':     _bizEmail.text.trim(),
            'contactPhone':     _bizPhone.text.trim(),
            'country':          _country,
            'teamSize':         _teamSize,
            'agentHiringModel': _hiringModel,
            'plan':             _plan,
          });
        } catch (_) {}
      }

      if (!mounted) return;
      if (ok || auth.status == AuthStatus.authenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => OtpVerifyScreen(
              identifier: _email.text.trim(),
              purpose: OtpPurpose.register,
            ),
          ),
          (_) => false,
        );
      } else {
        setState(() => _serverError = auth.error ?? 'Registration failed');
      }
    } catch (e) {
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t   = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final isBiz  = _type == _AccountType.business;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Back / close
                  if (_step > 1 && isBiz)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _back,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 4),
                  Text('WorkStream',
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (isBiz)
                    Text('Step $_step of 4',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
                ],
              ),
            ),

            // ── Step indicator (business only) ────────────────
            if (isBiz) ...[
              const SizedBox(height: 16),
              _StepIndicator(current: _step),
            ],

            // ── Body ──────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey('${_type.name}-$_step'),
                  child: isBiz ? _buildBizStep(t, isDark) : _buildAgentForm(t, isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Agent form (single step) ─────────────────────────────────────────────────

  Widget _buildAgentForm(ThemeData t, bool isDark) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text('Create your account',
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Register as a freelance agent and start earning.',
            style: t.textTheme.bodyMedium?.copyWith(color: sub)),
        const SizedBox(height: 20),
        _AccountTypeToggle(
          value: _type,
          onChanged: _switchType,
        ),
        const SizedBox(height: 20),
        ..._step1Fields(isDark),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              activeColor: AppColors.accent,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _terms = !_terms),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(fontSize: 12, color: sub),
                    children: const [
                      TextSpan(text: 'Terms & Conditions',
                          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                      TextSpan(text: ' and '),
                      TextSpan(text: 'Privacy Policy',
                          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  )),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_serverError != null) _ErrorBanner(_serverError!),
        if (_serverError != null) const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Create agent account'),
        ),
        const SizedBox(height: 16),
        _SignInLink(),
      ],
    );
  }

  // ── Business step router ─────────────────────────────────────────────────────

  Widget _buildBizStep(ThemeData t, bool isDark) {
    switch (_step) {
      case 1: return _BizStep1(t: t, isDark: isDark, builder: this);
      case 2: return _BizStep2(t: t, isDark: isDark, builder: this);
      case 3: return _BizStep3(isDark: isDark, selected: _plan, onSelect: (v) => setState(() => _plan = v));
      case 4: return _BizStep4(builder: this);
      default: return const SizedBox.shrink();
    }
  }

  // ── Shared step-1 fields ─────────────────────────────────────────────────────

  List<Widget> _step1Fields(bool isDark) => [
    Row(children: [
      Expanded(child: WsTextField(
        controller: _first, label: 'First name', icon: Icons.person_outline,
        errorText: _errors['firstName'],
        validator: (_) => _errors['firstName'],
      )),
      const SizedBox(width: 12),
      Expanded(child: WsTextField(
        controller: _last, label: 'Last name',
        errorText: _errors['lastName'],
        validator: (_) => _errors['lastName'],
      )),
    ]),
    const SizedBox(height: 14),
    WsTextField(
      controller: _email, label: 'Work email', hint: 'you@company.com',
      icon: Icons.alternate_email_outlined,
      keyboardType: TextInputType.emailAddress,
      errorText: _errors['email'],
      validator: (_) => _errors['email'],
    ),
    const SizedBox(height: 14),
    WsTextField(
      controller: _phone, label: 'Phone number', hint: '+254 700 000 000',
      icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
      errorText: _errors['phone'],
      validator: (_) => _errors['phone'],
    ),
    const SizedBox(height: 14),
    WsTextField(
      controller: _pw, label: 'Password', hint: 'Min. 8 characters',
      icon: Icons.lock_outline, obscure: _obscure,
      errorText: _errors['password'],
      validator: (_) => _errors['password'],
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
    const SizedBox(height: 14),
    WsTextField(
      controller: _conf, label: 'Confirm password',
      icon: Icons.lock_outline, obscure: _obscure,
      errorText: _errors['confirm'],
      validator: (_) => _errors['confirm'],
    ),
  ];
}

// ─── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final leftStep = i ~/ 2 + 1;
            final done = current > leftStep;
            return Expanded(child: Container(
              height: 2,
              color: done ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ));
          }
          final step = i ~/ 2 + 1;
          final active = current == step;
          final done   = current > step;
          return _StepDot(step: step, active: active, done: done, isDark: isDark);
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final bool active, done, isDark;
  const _StepDot({required this.step, required this.active, required this.done, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (done) { bg = AppColors.accent; fg = Colors.white; }
    else if (active) { bg = AppColors.accent.withValues(alpha: 0.15); fg = AppColors.accent; }
    else { bg = isDark ? AppColors.darkCard : AppColors.lightBorder; fg = isDark ? AppColors.darkSubtext : AppColors.lightSubtext; }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: bg, shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Text('$step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ),
        const SizedBox(height: 4),
        Text(_stepLabels[step - 1],
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.accent : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
            )),
      ],
    );
  }
}

// ─── Account type toggle ──────────────────────────────────────────────────────

class _AccountTypeToggle extends StatelessWidget {
  final _AccountType value;
  final ValueChanged<_AccountType> onChanged;
  const _AccountTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('I am joining as…',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _TypeCard(
            icon: Icons.person_rounded, title: 'Agent', subtitle: 'Find work & earn',
            selected: value == _AccountType.agent, isDark: isDark,
            onTap: () => onChanged(_AccountType.agent),
          )),
          const SizedBox(width: 12),
          Expanded(child: _TypeCard(
            icon: Icons.business_rounded, title: 'Business', subtitle: 'Post tasks & hire',
            selected: value == _AccountType.business, isDark: isDark,
            onTap: () => onChanged(_AccountType.business),
          )),
        ]),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _TypeCard({required this.icon, required this.title, required this.subtitle,
      required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          border: Border.all(
            color: selected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 22,
                color: selected ? AppColors.accent : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: selected ? AppColors.accent : (isDark ? AppColors.darkText : AppColors.lightText))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
        ]),
      ),
    );
  }
}

// ─── Business Step 1 — Account ────────────────────────────────────────────────

class _BizStep1 extends StatelessWidget {
  final ThemeData t;
  final bool isDark;
  final _RegisterScreenState builder;
  const _BizStep1({required this.t, required this.isDark, required this.builder});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _StepHeading(label: _stepLabels[0], sub: sub),
        const SizedBox(height: 16),
        _AccountTypeToggle(
          value: _AccountType.business,
          onChanged: (v) {
            if (v == _AccountType.agent) {
              builder._switchType(v);
            }
          },
        ),
        const SizedBox(height: 20),
        ...builder._step1Fields(isDark),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: builder._next,
          child: const Text('Continue'),
        ),
        const SizedBox(height: 16),
        _SignInLink(),
      ],
    );
  }
}

// ─── Business Step 2 — Business details ──────────────────────────────────────

class _BizStep2 extends StatefulWidget {
  final ThemeData t;
  final bool isDark;
  final _RegisterScreenState builder;
  const _BizStep2({required this.t, required this.isDark, required this.builder});
  @override
  State<_BizStep2> createState() => _BizStep2State();
}

class _BizStep2State extends State<_BizStep2> {
  @override
  Widget build(BuildContext context) {
    final b = widget.builder;
    final isDark = widget.isDark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _StepHeading(label: _stepLabels[1], sub: sub),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'You\'re setting up your remote operations workspace. Post jobs, assign tasks with SLA timers, run QA reviews, track live performance, and pay out earnings — all from one dashboard.',
            style: TextStyle(fontSize: 12, color: AppColors.accent.withValues(alpha: 0.9)),
          ),
        ),
        const SizedBox(height: 16),
        WsTextField(
          controller: b._bizName, label: 'Company name',
          hint: 'Acme BPO Kenya Ltd', icon: Icons.business_outlined,
          errorText: b._errors['bizName'], validator: (_) => b._errors['bizName'],
        ),
        const SizedBox(height: 14),
        _DropdownField(
          label: 'Industry', value: b._industry, items: _industries,
          isDark: isDark, onChanged: (v) => b.setState(() => b._industry = v!),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _DropdownField(
            label: 'Team size', value: b._teamSize, items: _teamSizes,
            isDark: isDark, onChanged: (v) => b.setState(() => b._teamSize = v!),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DropdownField(
            label: 'Country', value: b._country, items: _countries,
            isDark: isDark, onChanged: (v) => b.setState(() => b._country = v!),
          )),
        ]),
        const SizedBox(height: 14),
        _DropdownField(
          label: 'Agent hiring model',
          value: b._hiringModel,
          items: const ['FREELANCE', 'EMPLOYED', 'HYBRID'],
          labels: const ['Freelance agents (on-demand)', 'Employed staff', 'Hybrid (mix of both)'],
          isDark: isDark,
          onChanged: (v) => b.setState(() => b._hiringModel = v!),
        ),
        const SizedBox(height: 14),
        _TextAreaField(
          controller: b._bizDesc, label: 'Business description',
          hint: 'Brief description of what your business does and what tasks agents will handle…',
          isDark: isDark, error: b._errors['bizDesc'],
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: WsTextField(
            controller: b._bizEmail, label: 'Operations email', hint: 'ops@company.com',
            icon: Icons.alternate_email_outlined, keyboardType: TextInputType.emailAddress,
            errorText: b._errors['bizEmail'], validator: (_) => b._errors['bizEmail'],
          )),
          const SizedBox(width: 12),
          Expanded(child: WsTextField(
            controller: b._bizPhone, label: 'Ops phone', hint: '+254…',
            icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
            errorText: b._errors['bizPhone'], validator: (_) => b._errors['bizPhone'],
          )),
        ]),
        const SizedBox(height: 14),
        WsTextField(
          controller: b._bizWebsite, label: 'Website (optional)',
          hint: 'https://company.com', icon: Icons.language_outlined,
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: b._next, child: const Text('Continue')),
      ],
    );
  }
}

// ─── Business Step 3 — Choose plan ───────────────────────────────────────────

class _BizStep3 extends StatelessWidget {
  final bool isDark;
  final String selected;
  final ValueChanged<String> onSelect;
  const _BizStep3({required this.isDark, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final b = context.findAncestorStateOfType<_RegisterScreenState>()!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _StepHeading(label: _stepLabels[2], sub: sub),
        const SizedBox(height: 16),
        ..._plans.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PlanCard(
            plan: p, selected: selected == p.id, isDark: isDark,
            onTap: () => onSelect(p.id),
          ),
        )),
        const SizedBox(height: 16),
        FilledButton(onPressed: b._next, child: const Text('Continue')),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          border: Border.all(
            color: selected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(plan.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 8),
                  if (plan.popular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Most popular',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 2),
                RichText(text: TextSpan(children: [
                  TextSpan(text: plan.price,
                      style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w800)),
                  TextSpan(text: '  ${plan.period}',
                      style: TextStyle(fontSize: 12,
                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
                ])),
                const SizedBox(height: 8),
                ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f,
                        style: TextStyle(fontSize: 12,
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext))),
                  ]),
                )),
              ]),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Business Step 4 — Review & launch ───────────────────────────────────────

class _BizStep4 extends StatelessWidget {
  final _RegisterScreenState builder;
  const _BizStep4({required this.builder});

  @override
  Widget build(BuildContext context) {
    final b = builder;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final plan = _plans.firstWhere((p) => p.id == b._plan, orElse: () => _plans[2]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _StepHeading(label: _stepLabels[3], sub: sub),
        const SizedBox(height: 16),

        // Account card
        _ReviewCard(
          label: 'Account',
          isDark: isDark,
          children: [
            Text('${b._first.text.trim()} ${b._last.text.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(b._email.text.trim(), style: TextStyle(fontSize: 13, color: sub)),
            Text(b._phone.text.trim(), style: TextStyle(fontSize: 13, color: sub)),
          ],
        ),
        const SizedBox(height: 12),

        // Business card
        _ReviewCard(
          label: 'Business',
          isDark: isDark,
          children: [
            Text(b._bizName.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('${b._industry} · ${b._teamSize} team · ${b._hiringModel}',
                style: TextStyle(fontSize: 11, color: sub)),
            const SizedBox(height: 4),
            Text(b._bizDesc.text.trim(),
                style: TextStyle(fontSize: 13, color: sub), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
        const SizedBox(height: 12),

        // Plan card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PLAN', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.2, color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${plan.price} ${plan.period}',
                style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),

        if (b._serverError != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(b._serverError!),
        ],

        const SizedBox(height: 28),
        FilledButton(
          onPressed: b._loading ? null : b._submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: b._loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.rocket_launch_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Launch my workspace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
        ),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _StepHeading extends StatelessWidget {
  final String label;
  final Color sub;
  const _StepHeading({required this.label, required this.sub});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
    ],
  );
}

class _ReviewCard extends StatelessWidget {
  final String label;
  final bool isDark;
  final List<Widget> children;
  const _ReviewCard({required this.label, required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
      const SizedBox(height: 8),
      ...children,
    ]),
  );
}

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final List<String>? labels;
  final bool isDark;
  final ValueChanged<String?> onChanged;
  const _DropdownField({required this.label, required this.value, required this.items,
      this.labels, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bg     = isDark ? AppColors.darkCard : AppColors.lightCard;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg, border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true,
            items: items.asMap().entries.map((e) => DropdownMenuItem(
              value: e.value,
              child: Text(labels != null ? labels![e.key] : e.value, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }
}

class _TextAreaField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final bool isDark;
  final String? error;
  const _TextAreaField({required this.controller, required this.label,
      required this.hint, required this.isDark, this.error});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bg     = isDark ? AppColors.darkCard : AppColors.lightCard;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: bg, border: Border.all(color: error != null ? AppColors.danger : border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller, minLines: 3, maxLines: 5,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint, border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      if (error != null) Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 11)),
      ),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
    ]),
  );
}

class _SignInLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
      child: Text.rich(TextSpan(
        text: 'Already have an account? ',
        style: const TextStyle(fontSize: 13),
        children: const [
          TextSpan(text: 'Sign in',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
        ],
      )),
    ),
  );
}
