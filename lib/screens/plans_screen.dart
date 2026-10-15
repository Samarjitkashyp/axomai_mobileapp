import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';

/// Plans and payment inside the app: pick a plan, pay with Razorpay, the plan starts at once.
class PlansScreen extends StatefulWidget {
  final bool signedIn;
  final VoidCallback onOpenLogin;

  const PlansScreen({super.key, required this.signedIn, required this.onOpenLogin});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final Razorpay _razorpay = Razorpay();
  List<PlanInfo> _plans = [];
  CurrentPlan _current = CurrentPlan(active: false);
  bool _loading = true;
  String? _loadError;
  bool _yearly = false;
  bool _paying = false;
  String? _expandedId = 'pro';
  PlanOption? _buying;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onFailed);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final plans = await PaymentService.fetchPlans();
      final current = widget.signedIn ? await PaymentService.fetchCurrentPlan() : CurrentPlan(active: false);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _current = current;
        _loading = false;
      });
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _buy(PlanInfo plan) async {
    if (!widget.signedIn) {
      _snack('Please log in first. Your plan stays safe with your account.');
      widget.onOpenLogin();
      return;
    }
    if (_paying) return;
    final option = _yearly ? plan.yearly : plan.monthly;
    setState(() {
      _paying = true;
      _buying = option;
    });
    try {
      final order = await PaymentService.createOrder(option.key);
      _razorpay.open({
        'key': order.keyId,
        'amount': order.amount,
        'currency': 'INR',
        'order_id': order.orderId,
        'name': 'Axom AI',
        'description': order.planLabel,
        'prefill': {'email': order.userEmail, 'name': order.userName},
        'theme': {'color': '#34D399'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } on PaymentException catch (e) {
      _snack(e.message);
      if (e.loginRequired) widget.onOpenLogin();
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    try {
      await PaymentService.verify(
        orderId: r.orderId ?? '',
        paymentId: r.paymentId ?? '',
        signature: r.signature ?? '',
      );
      await AuthService.syncUserStatus();
      final current = await PaymentService.fetchCurrentPlan();
      if (!mounted) return;
      setState(() {
        _current = current;
        _paying = false;
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Payment successful'),
          content: Text('${current.label ?? 'Your plan'} is now active'
              '${current.daysLeft > 0 ? ' for ${current.daysLeft} days' : ''}. Enjoy Axom AI!'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      // The money was taken. The server also learns about it from Razorpay, so the plan will start by itself.
      _snack('Payment received, but we could not confirm it yet (${e.message}). '
          'Your plan will start shortly. If it does not, contact support with payment id ${r.paymentId}.');
    }
  }

  void _onFailed(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() => _paying = false);
    final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
    _snack(cancelled ? 'Payment cancelled. You were not charged.' : 'Payment failed. You were not charged. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        title: const Text('Choose your plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentEmerald))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    if (_current.active) _currentBanner(),
                    _cycleToggle(),
                    const SizedBox(height: 12),
                    _freeCard(),
                    for (final p in _plans) _planCard(p),
                    const SizedBox(height: 8),
                    const Text(
                      'Payments are processed securely by Razorpay (UPI, cards, net banking). '
                      'A plan runs for the period you buy and does not renew by itself.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
    );
  }

  Widget _currentBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentEmerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppTheme.accentEmerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_current.label ?? 'Plan'} is active'
              '${_current.daysLeft > 0 && _current.daysLeft < 9000 ? ' · ${_current.daysLeft} days left' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cycleToggle() {
    Widget chip(String label, bool value) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _yearly = value),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _yearly == value ? AppTheme.accentEmerald : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _yearly == value ? Colors.black : AppTheme.textSecondary,
                  )),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.bgPill, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [chip('Monthly', false), chip('Yearly · save 20%', true)]),
    );
  }

  Widget _freeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppTheme.textSecondary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Free', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('5,000 words / month · basic AI · daily limits',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('₹0', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _planCard(PlanInfo p) {
    final opt = _yearly ? p.yearly : p.monthly;
    final open = _expandedId == p.id;
    final busy = _paying && _buying?.key == opt.key;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.popular ? AppTheme.accentEmerald : AppTheme.borderColor, width: p.popular ? 1.5 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expandedId = open ? null : p.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(width: 8),
                          if (p.badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(p.badge,
                                  style: const TextStyle(fontSize: 10.5, color: AppTheme.accentEmerald, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(p.words, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${_yearly ? opt.perMonth : opt.amount}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                      Text(_yearly ? '/ month, billed ₹${opt.amount}/yr' : '/ month',
                          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.desc, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  for (final f in p.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentEmerald),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _paying ? null : () => _buy(p),
                child: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text('Pay ₹${opt.amount} · ${p.name} ${_yearly ? 'Yearly' : 'Monthly'}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
