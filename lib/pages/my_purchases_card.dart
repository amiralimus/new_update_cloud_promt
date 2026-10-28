import 'package:flutter/material.dart';

import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;
import 'card_payment_sheet.dart';

/// یک سفارش خرید توکن، آن‌طور که `/my-purchases/` برمی‌گرداند.
class TokenPurchaseStatus {
  const TokenPurchaseStatus({
    required this.id,
    required this.tokenAmount,
    required this.finalPrice,
    required this.status,
    required this.statusDisplay,
    required this.hasReceipt,
    required this.createdAt,
    this.reviewNote,
    this.cardAccount,
  });

  final int id;
  final int tokenAmount;
  final double finalPrice;
  final String status;
  final String statusDisplay;
  final bool hasReceipt;
  final String createdAt;
  final String? reviewNote;
  final CardAccount? cardAccount;

  /// سفارشی که هنوز رسیدش بالا نرفته — تنها حالتی که کاربر باید کاری بکند.
  bool get needsReceipt => status == 'awaiting_receipt' && !hasReceipt;

  /// سفارشی که رسید دارد و منتظر نظر مدیر است.
  bool get isUnderReview =>
      status == 'under_review' || (status == 'awaiting_receipt' && hasReceipt);

  bool get isPaid => status == 'paid';

  bool get isRejected => status == 'rejected';

  factory TokenPurchaseStatus.fromJson(Map<String, dynamic> json) {
    final account = json['card_account'];
    return TokenPurchaseStatus(
      id: (json['id'] as num).toInt(),
      tokenAmount: (json['token_amount'] as num?)?.toInt() ?? 0,
      finalPrice: (json['final_price'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? '').toString(),
      statusDisplay: (json['status_display'] ?? '').toString(),
      hasReceipt: json['has_receipt'] == true,
      createdAt: (json['created_at'] ?? '').toString(),
      reviewNote: json['review_note'] as String?,
      cardAccount: account is Map
          ? CardAccount.fromJson(Map<String, dynamic>.from(account))
          : null,
    );
  }
}

/// فهرست سفارش‌های کاربر با امکان بارگذاری رسید برای سفارش‌های نیمه‌کاره.
///
/// چرا لازم است: پیش از این اگر کاربر پنجره‌ی پرداخت را بدون بارگذاری رسید
/// می‌بست، سفارش در حالت «منتظر رسید» می‌ماند و هیچ راهی در برنامه برای
/// برگشتن و بارگذاری آن وجود نداشت — پیام «هر زمان رسید را بارگذاری کنید»
/// عملاً بی‌معنا بود.
class MyPurchasesCard extends StatefulWidget {
  const MyPurchasesCard({super.key, this.onChanged});

  /// وقتی وضعیت سفارشی عوض شد (مثلاً رسید بالا رفت) صدا زده می‌شود تا
  /// صفحه‌ی خرید موجودی را تازه کند.
  final VoidCallback? onChanged;

  @override
  State<MyPurchasesCard> createState() => MyPurchasesCardState();
}

class MyPurchasesCardState extends State<MyPurchasesCard> {
  final ApiService _apiService = ApiService();

  List<TokenPurchaseStatus> _purchases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.get(endpoint: ServerEndpoints.myPurchases);
    if (!mounted) return;

    if (!response.success || response.data is! Map) {
      setState(() {
        _isLoading = false;
        _error = response.error ?? 'دریافت سفارش‌ها ناموفق بود.';
      });
      return;
    }

    final raw = (response.data as Map)['purchases'];
    setState(() {
      _isLoading = false;
      _purchases = raw is List
          ? raw
                .map((e) =>
                    TokenPurchaseStatus.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
          : <TokenPurchaseStatus>[];
    });
  }

  Future<void> _uploadReceipt(TokenPurchaseStatus purchase) async {
    final account = purchase.cardAccount;
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اطلاعات کارت این سفارش در دسترس نیست.'),
        ),
      );
      return;
    }

    final uploaded = await showCardPaymentSheet(
      context: context,
      purchaseId: purchase.id,
      account: account,
      amount: purchase.finalPrice,
    );

    if (!mounted) return;
    if (uploaded == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رسید ثبت شد. پس از تایید مدیر، توکن‌ها اضافه می‌شود.'),
          duration: Duration(seconds: 4),
        ),
      );
      widget.onChanged?.call();
    }
    await reload();
  }

  /// تاریخ کوتاه از رشته‌ی ISO سرور.
  static String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _price(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // تا وقتی هیچ سفارشی نیست، این بخش اصلاً جا نمی‌گیرد.
    if (!_isLoading && _error == null && _purchases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 19, color: primeColor),
              const SizedBox(width: 8),
              Text(
                'سفارش‌های من',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimaryColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : reload,
                tooltip: 'به‌روزرسانی',
                icon: Icon(Icons.refresh_rounded, size: 19, color: textMutedColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13, color: dangerFgColor),
              ),
            )
          else
            for (final purchase in _purchases) _row(purchase),
        ],
      ),
    );
  }

  Widget _row(TokenPurchaseStatus purchase) {
    final Color badgeBg;
    final Color badgeFg;
    if (purchase.isPaid) {
      badgeBg = okBgColor;
      badgeFg = okFgColor;
    } else if (purchase.isRejected) {
      badgeBg = dangerBgColor;
      badgeFg = dangerFgColor;
    } else {
      badgeBg = warnBgColor;
      badgeFg = warnFgColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  purchase.statusDisplay,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${purchase.tokenAmount} توکن — '
                  '${_price(purchase.finalPrice)} تومان',
                  style: TextStyle(fontSize: 13, color: textPrimaryColor),
                ),
              ),
              Text(
                _shortDate(purchase.createdAt),
                style: TextStyle(fontSize: 11.5, color: textFaintColor),
              ),
            ],
          ),
          if (purchase.needsReceipt) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _uploadReceipt(purchase),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primeColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.upload_file_rounded, size: 17, color: primeColor),
                label: Text(
                  'بارگذاری رسید',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: primeColor,
                  ),
                ),
              ),
            ),
          ],
          if (purchase.isRejected &&
              (purchase.reviewNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              purchase.reviewNote!,
              style: TextStyle(fontSize: 11.8, color: dangerFgColor, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}
