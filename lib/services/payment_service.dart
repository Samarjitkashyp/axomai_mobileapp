import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'storage_service.dart';

class PlanOption {
  final String key; // plan_monthly / plan_yearly: what the server sells
  final int amount; // rupees
  final int days;
  final int perMonth;
  PlanOption({required this.key, required this.amount, required this.days, this.perMonth = 0});
}

class PlanInfo {
  final String id, name, badge, desc, words;
  final bool popular;
  final List<String> features;
  final PlanOption monthly, yearly;
  PlanInfo({
    required this.id,
    required this.name,
    required this.badge,
    required this.desc,
    required this.words,
    required this.popular,
    required this.features,
    required this.monthly,
    required this.yearly,
  });

  static PlanOption _opt(Map<String, dynamic> j) => PlanOption(
        key: j['key'] as String,
        amount: (j['amount'] as num).toInt(),
        days: (j['days'] as num).toInt(),
        perMonth: (j['per_month'] as num?)?.toInt() ?? 0,
      );

  factory PlanInfo.fromJson(Map<String, dynamic> j) => PlanInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        badge: j['badge'] as String? ?? '',
        desc: j['desc'] as String? ?? '',
        words: j['words'] as String? ?? '',
        popular: j['popular'] == true,
        features: (j['features'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        monthly: _opt(j['monthly'] as Map<String, dynamic>),
        yearly: _opt(j['yearly'] as Map<String, dynamic>),
      );
}

class CurrentPlan {
  final bool active;
  final String? label;
  final int daysLeft;
  final String? expiresAt;
  CurrentPlan({required this.active, this.label, this.daysLeft = 0, this.expiresAt});
}

class RazorpayOrder {
  final String orderId, keyId, planLabel, userName, userEmail;
  final int amount; // paise
  RazorpayOrder({
    required this.orderId,
    required this.keyId,
    required this.planLabel,
    required this.userName,
    required this.userEmail,
    required this.amount,
  });
}

class PaymentException implements Exception {
  final String message;
  final bool loginRequired;
  PaymentException(this.message, {this.loginRequired = false});
  @override
  String toString() => message;
}

/// Plans, orders and the payment check against the Axom AI server (the same ones the website uses).
class PaymentService {
  static Future<Map<String, String>> _headers({bool json = false}) async {
    final cookie = await AuthService.getSessionCookie();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  static Future<Map<String, dynamic>> _call(String method, String path, {Map<String, dynamic>? body}) async {
    final base = await StorageService.loadApiBaseUrl();
    final uri = Uri.parse('$base$path');
    try {
      final r = method == 'GET'
          ? await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 20))
          : await http
              .post(uri, headers: await _headers(json: true), body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 30));
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
      if (r.statusCode == 401 || r.statusCode == 403) {
        throw PaymentException('Please log in to buy a plan.', loginRequired: true);
      }
      if (r.statusCode == 429) {
        throw PaymentException('Too many attempts. Please wait a minute and try again.');
      }
      if (r.statusCode >= 400) {
        throw PaymentException((data['error'] as String?) ?? 'Something went wrong (${r.statusCode}). Please try again.');
      }
      return data;
    } on PaymentException {
      rethrow;
    } catch (_) {
      throw PaymentException('No connection. Check your internet and try again.');
    }
  }

  static Future<List<PlanInfo>> fetchPlans() async {
    final d = await _call('GET', '/api/plans/');
    return (d['plans'] as List<dynamic>).map((e) => PlanInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<CurrentPlan> fetchCurrentPlan() async {
    try {
      final d = await _call('GET', '/api/plan/status/');
      if (d['active'] != true) return CurrentPlan(active: false);
      return CurrentPlan(
        active: true,
        label: d['plan_label'] as String?,
        daysLeft: (d['days_left'] as num?)?.toInt() ?? 0,
        expiresAt: d['expires_at'] as String?,
      );
    } on PaymentException {
      return CurrentPlan(active: false);
    }
  }

  static Future<RazorpayOrder> createOrder(String planKey) async {
    final d = await _call('POST', '/api/payment/app/create-order/', body: {'plan': planKey});
    return RazorpayOrder(
      orderId: d['order_id'] as String,
      keyId: d['key_id'] as String,
      amount: (d['amount'] as num).toInt(),
      planLabel: d['plan_label'] as String? ?? 'Axom AI plan',
      userName: d['user_name'] as String? ?? '',
      userEmail: d['user_email'] as String? ?? '',
    );
  }

  /// Asks the server to check the payment. Retries a few times, because the network may drop right after paying.
  static Future<void> verify({required String orderId, required String paymentId, required String signature}) async {
    PaymentException? last;
    for (var i = 0; i < 4; i++) {
      try {
        await _call('POST', '/api/payment/app/verify/', body: {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        });
        return;
      } on PaymentException catch (e) {
        last = e;
        if (e.loginRequired || !e.message.startsWith('No connection')) break;
        await Future<void>.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    throw last ?? PaymentException('Could not confirm the payment.');
  }
}
