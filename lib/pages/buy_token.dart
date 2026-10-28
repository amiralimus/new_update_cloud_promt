import 'package:flutter/material.dart';

import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../core/platform/url_opener.dart';
import '../loging_system/loging_system.dart';
import '../responsive.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;
import 'card_payment_sheet.dart';

/// رنگ زمینه‌ی باکس‌های آبی‌رنگ (اطلاعیه‌ها و باکس‌های نرخ) — دقیقاً مطابق طرح.
/// زمینه‌ی باکس‌های آبی‌رنگ (اطلاعیه و نرخ) — در تم تاریک نسخه‌ی کم‌اشباع.
Color get _highlightBg => infoBgColor;

AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

// ============================================================
// مدل بسته‌ی توکن — نگاشت از /api/token-packages/
// ============================================================
class TokenPackage {
  final int id;
  final String name;
  final int tokenAmount;
  final num pricePer50Tokens;
  final num calculatedPrice;

  TokenPackage({
    required this.id,
    required this.name,
    required this.tokenAmount,
    required this.pricePer50Tokens,
    required this.calculatedPrice,
  });

  factory TokenPackage.fromJson(Map<String, dynamic> json) {
    num numFrom(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return TokenPackage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? 'بسته',
      tokenAmount: numFrom(json['token_amount']).toInt(),
      pricePer50Tokens: numFrom(json['price_per_50_tokens']),
      calculatedPrice: numFrom(json['calculated_price']),
    );
  }
}

class BuyToken extends StatefulWidget {
  const BuyToken({super.key});

  @override
  State<BuyToken> createState() => _BuyTokenState();
}

class _BuyTokenState extends State<BuyToken> {
  final ApiService _apiService = ApiService();

  // مضرب ۵۰ چون بک‌اند فقط همین مقدارها رو قبول می‌کنه (input[step="50"] در HTML مرجع)
  static const int _minTokens = 50;
  static const int _tokenStep = 50;
  static const int _maxTokens = 100000;

  int _tokenCount = _minTokens;
  final TextEditingController _discountController = TextEditingController();

  // ---- داده‌های واقعی از سرور ----
  TokenPackage? _selectedPackage; // انتخاب خودکار و مخفی از کاربر
  int _currentBalance = 0;

  bool _isLoadingPackages = true;
  bool _isLoadingBalance = true;
  String? _packagesError;
  String? _balanceError;

  bool _isValidatingDiscount = false;
  String? _discountStatusMessage;
  bool? _discountValid;
  String? _appliedDiscountCode;

  bool _isPurchasing = false;

  // ---- روش‌های پرداخت ----
  //
  // هیچ‌کدام از این دو روش در کلاینت روشن یا خاموش نمی‌شود؛ سرور در
  // `/payment-methods/` می‌گوید همین حالا کدام‌یک واقعاً کار می‌کند. پس
  // «فعلاً فقط کارت‌به‌کارت» یک تنظیم است، نه یک تصمیم دوخته‌شده در کد:
  // روزی که درگاه واقعی در پنل ادمین فعال شود، گزینه‌اش خودبه‌خود ظاهر
  // می‌شود و این فایل دست نمی‌خورد.
  static const String _methodCard = 'card';
  static const String _methodGateway = 'gateway';

  String _paymentMethod = _methodCard;
  CardAccount? _cardAccount;

  /// کارت‌به‌کارت: مدیر یک کارت فعال ثبت کرده است.
  bool _cardEnabled = false;

  /// درگاه آنلاین: یک درگاه **واقعی** فعال است.
  ///
  /// درگاه تستی اینجا false است — شبیه‌ساز نباید به کاربر نهایی فروخته شود.
  bool _gatewayEnabled = false;

  /// درگاه فعال از نوع تستی است (فقط برای پیام توسعه‌دهنده).
  bool _gatewayIsMock = false;

  /// نام نمایشی درگاه فعال، برای برچسب دکمه.
  String? _gatewayName;

  /// کاربر خودش روش پرداخت را انتخاب کرده است.
  bool _paymentMethodPickedByUser = false;

  /// آیا پاسخ `/payment-methods/` رسیده است؟
  ///
  /// تا پیش از رسیدنش نه می‌شود گفت پرداخت فعال است نه غیرفعال، پس دکمه
  /// در حالت انتظار می‌ماند به‌جای اینکه پیام غلط نشان بدهد.
  bool _methodsLoaded = false;

  /// آیا اصلاً راهی برای پرداخت وجود دارد؟
  bool get _anyMethodAvailable => _cardEnabled || _gatewayEnabled;

  /// انتخاب روش فقط وقتی معنا دارد که هر دو در دسترس باشند.
  bool get _methodChoiceMatters => _cardEnabled && _gatewayEnabled;

  @override
  void initState() {
    super.initState();
    _loadPackages(showLoading: false);
    _loadBalance(showLoading: false);
    _loadPaymentMethods();
  }

  /// روش‌های پرداخت فعال را از سرور می‌گیرد.
  ///
  /// شکست این درخواست نباید صفحه‌ی خرید را خراب کند؛ در بدترین حالت هیچ
  /// روشی در دسترس نشان داده نمی‌شود و کاربر پیام روشنی می‌بیند.
  Future<void> _loadPaymentMethods() async {
    try {
      final response = await _apiService.get(
        endpoint: ServerEndpoints.paymentMethods,
        requiresAuth: true,
      );
      if (!mounted) return;

      if (response.success && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final card = data['card'] is Map
            ? Map<String, dynamic>.from(data['card'] as Map)
            : const <String, dynamic>{};
        final gateway = data['gateway'] is Map
            ? Map<String, dynamic>.from(data['gateway'] as Map)
            : const <String, dynamic>{};

        final account = card['account'];
        setState(() {
          _cardEnabled = card['available'] == true && account is Map;
          _cardAccount = account is Map
              ? CardAccount.fromJson(Map<String, dynamic>.from(account))
              : null;
          _gatewayEnabled = gateway['available'] == true;
          _gatewayIsMock = gateway['is_mock'] == true;
          _gatewayName = gateway['name'] as String?;
          _methodsLoaded = true;

          // پیش‌فرض روی روشی می‌نشیند که واقعاً کار می‌کند. کارت‌به‌کارت
          // اولویت دارد چون تاییدش دست خودمان است.
          if (!_paymentMethodPickedByUser) {
            if (_cardEnabled) {
              _paymentMethod = _methodCard;
            } else if (_gatewayEnabled) {
              _paymentMethod = _methodGateway;
            }
          }
        });
      } else {
        setState(() => _methodsLoaded = true);
      }
    } catch (e) {
      if (mounted) setState(() => _methodsLoaded = true);
      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.paymentMethods,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  // ==========================================================
  // بارگذاری بسته‌ها -> GET /api/token-packages/
  // (بدون requiresAuth، دقیقاً مثل HTML مرجع که بدون هدر Authorization بود)
  // ==========================================================
  Future<void> _loadPackages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingPackages = true;
        _packagesError = null;
      });
    }

    try {
      LoggerService.logEvent(
        title: 'BUY_TOKEN',
        message: 'در حال دریافت بسته‌های توکن...',
      );

      final response = await _apiService.get(
        endpoint: ServerEndpoints.tokenPackages,
        requiresAuth: false,
      );

      if (response.success && response.data != null) {
        final List<dynamic> rawList = response.data as List<dynamic>;
        final packages = rawList
            .map((e) => TokenPackage.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _selectedPackage = packages.isNotEmpty ? packages.first : null;
          _isLoadingPackages = false;
        });

        LoggerService.logProfile(
          action: 'LOAD_SUCCESS',
          message: 'بسته‌های توکن بارگذاری شدند (${packages.length} بسته)',
        );
      } else {
        setState(() {
          _packagesError = response.error ?? 'دریافت بسته‌ها ناموفق بود';
          _isLoadingPackages = false;
        });

        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.tokenPackages,
          error: response.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      setState(() {
        _packagesError = 'خطا: ${e.toString()}';
        _isLoadingPackages = false;
      });

      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.tokenPackages,
        error: e.toString(),
      );
    }
  }

  // ==========================================================
  // بارگذاری موجودی -> GET /api/user/profile/
  // ==========================================================
  Future<void> _loadBalance({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingBalance = true;
        _balanceError = null;
      });
    }

    try {
      final response = await _apiService.get(
        endpoint: ServerEndpoints.userProfile,
        requiresAuth: true,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final balance = data['token_balance'];
        setState(() {
          _currentBalance = balance is int
              ? balance
              : (num.tryParse('$balance') ?? 0).toInt();
          _isLoadingBalance = false;
        });

        LoggerService.logProfile(
          action: 'LOAD_SUCCESS',
          message: 'موجودی توکن دریافت شد: $_currentBalance',
        );
      } else {
        setState(() {
          _balanceError = response.error ?? 'دریافت موجودی ناموفق بود';
          _isLoadingBalance = false;
        });

        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.userProfile,
          error: response.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      setState(() {
        _balanceError = 'خطا: ${e.toString()}';
        _isLoadingBalance = false;
      });

      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.userProfile,
        error: e.toString(),
      );
    }
  }

  void _changeTokens(int deltaSteps) {
    setState(() {
      // حداقل ۵۰ توکن، بدون محدودیت حداکثر
      // سقف عمداً یک عدد بزرگ و واقعی است: `double.infinity as int` که
      // اینجا بود روی وب یک TypeError زمان اجرا می‌داد و دکمه‌های + و −
      // را می‌شکست.
      _tokenCount = (_tokenCount + deltaSteps * _tokenStep).clamp(
        _minTokens,
        _maxTokens,
      );
      // با تغییر تعداد، تاییدیه‌ی قبلیِ کد تخفیف دیگه معتبر نیست
      _discountStatusMessage = null;
      _discountValid = null;
    });
  }

  // قیمت واقعی بر اساس بسته‌ی انتخاب‌شده (نه مقدار هاردکد قبلی)
  num get _pricePer50 => _selectedPackage?.pricePer50Tokens ?? 0;

  num get _pricePerToken => _pricePer50 / 50;

  num get _finalPrice => (_tokenCount / 50) * _pricePer50;

  /// جداکننده‌ی هزارگان با ویرگول
  String _formatPrice(num value) {
    final str = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i != 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // ==========================================================
  // اعتبارسنجی کد تخفیف -> POST /api/validate-discount-code/
  // ساختار پاسخ سرور مشخص نیست (در HTML مرجع هم فقط JSON خام نمایش داده می‌شد)
  // پس فقط پیام/وضعیت رو نشون می‌دیم؛ تخفیف واقعی موقع خرید توسط سرور اعمال میشه.
  // ==========================================================
  Future<void> _validateDiscount() async {
    final code = _discountController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('کد تخفیف را وارد کنید.')));
      return;
    }
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بسته‌ها هنوز بارگذاری نشده‌اند، کمی صبر کنید.'),
        ),
      );
      return;
    }

    setState(() {
      _isValidatingDiscount = true;
      _discountStatusMessage = null;
      _discountValid = null;
    });

    try {
      LoggerService.logProfile(
        action: 'VALIDATE_DISCOUNT',
        message: 'در حال بررسی کد تخفیف: $code',
      );

      final response = await _apiService.post(
        endpoint: ServerEndpoints.validateDiscountCode,
        body: {'code': code, 'purchase_amount': _finalPrice.toStringAsFixed(2)},
        requiresAuth: true,
      );

      if (response.success && response.data != null) {
        final data = response.data;
        String message = 'کد تخفیف معتبر است';
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        setState(() {
          _discountValid = true;
          _discountStatusMessage = message;
          _appliedDiscountCode = code;
          _isValidatingDiscount = false;
        });

        LoggerService.logProfile(
          action: 'VALIDATE_DISCOUNT_SUCCESS',
          message: 'کد تخفیف معتبر است: $code',
        );
      } else {
        setState(() {
          _discountValid = false;
          _discountStatusMessage = response.error ?? 'کد تخفیف نامعتبر است';
          _appliedDiscountCode = null;
          _isValidatingDiscount = false;
        });

        LoggerService.logApiError(
          method: 'POST',
          url: ServerEndpoints.validateDiscountCode,
          error: response.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      setState(() {
        _discountValid = false;
        _discountStatusMessage = 'خطا: ${e.toString()}';
        _appliedDiscountCode = null;
        _isValidatingDiscount = false;
      });

      LoggerService.logApiError(
        method: 'POST',
        url: ServerEndpoints.validateDiscountCode,
        error: e.toString(),
      );
    }
  }

  // ==========================================================
  // خرید تستی (چون درگاه واقعی وجود نداره):
  // ۱) POST /api/purchase-token/  -> سفارش pending می‌سازه
  // ۲) POST /api/payment-callback/ -> شبیه‌سازی پرداخت موفق (بدون auth، طبق HTML مرجع)
  // ۳) رفرش موجودی
  // ==========================================================
  Future<void> _purchaseTokens() async {
    if (!_anyMethodAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پرداخت در حال حاضر فعال نیست. لطفاً با پشتیبانی تماس بگیرید.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بسته‌ای برای خرید موجود نیست، صفحه را رفرش کنید.'),
        ),
      );
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      // ---- مرحله ۱: ثبت سفارش ----
      LoggerService.logProfile(
        action: 'PURCHASE_START',
        message: 'ثبت سفارش خرید $_tokenCount توکن',
      );

      final Map<String, dynamic> purchasePayload = {
        'token_amount': _tokenCount,
        'package_id': _selectedPackage!.id,
        'payment_method': _paymentMethod,
      };
      if (_appliedDiscountCode != null && _appliedDiscountCode!.isNotEmpty) {
        purchasePayload['discount_code'] = _appliedDiscountCode;
      }

      final purchaseResponse = await _apiService.post(
        endpoint: ServerEndpoints.purchaseToken,
        body: purchasePayload,
        requiresAuth: true,
      );

      if (!purchaseResponse.success || purchaseResponse.data == null) {
        setState(() => _isPurchasing = false);
        LoggerService.logApiError(
          method: 'POST',
          url: ServerEndpoints.purchaseToken,
          error: purchaseResponse.error ?? 'Unknown error',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطا در ثبت سفارش: ${purchaseResponse.error ?? "نامشخص"}',
              ),
            ),
          );
        }
        return;
      }

      final purchaseData = purchaseResponse.data as Map<String, dynamic>;
      final purchaseId = purchaseData['purchase_id'];

      if (purchaseId == null) {
        setState(() => _isPurchasing = false);
        LoggerService.logApiError(
          method: 'POST',
          url: ServerEndpoints.purchaseToken,
          error: 'purchase_id در پاسخ سرور یافت نشد',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('سفارش ثبت شد ولی شناسه‌ی آن دریافت نشد.'),
            ),
          );
        }
        return;
      }

      LoggerService.logProfile(
        action: 'PURCHASE_ORDER_CREATED',
        message: 'سفارش با شناسه $purchaseId ثبت شد',
      );

      // ---- مرحله ۲ ----
      //
      // قبلاً اینجا یک کال‌بک ساختگی با ref_id جعلی به سرور زده می‌شد و
      // توکن بدون هیچ پرداخت واقعی آزاد می‌شد. توکن حالا فقط با تایید
      // رسید توسط مدیر آزاد می‌شود.

      // تخفیف ۱۰۰٪: سرور خودش سفارش را تکمیل کرده و کارتی در کار نیست
      if (purchaseData['status'] == 'paid') {
        await _loadBalance();
        if (!mounted) return;
        setState(() {
          _isPurchasing = false;
          _tokenCount = _minTokens;
          _discountController.clear();
          _discountStatusMessage = null;
          _discountValid = null;
          _appliedDiscountCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ خرید انجام شد و موجودی به‌روزرسانی شد.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // مسیر درگاه آنلاین: هدایت کاربر به صفحه‌ی پرداخت.
      //
      // درگاه تستی هرگز باز نمی‌شود؛ یک شبیه‌ساز است و کاربر نهایی را به
      // یک پرداخت جعلی می‌برد. سرور هم آن را available اعلام نمی‌کند، این
      // شرط لایه‌ی دوم محافظت است.
      if (_paymentMethod == _methodGateway) {
        final paymentUrl = purchaseData['payment_url'];
        final bool isMock = purchaseData['is_mock_gateway'] == true;

        if (!mounted) return;
        setState(() => _isPurchasing = false);

        if (!isMock && paymentUrl is String && paymentUrl.isNotEmpty) {
          LoggerService.logProfile(
            action: 'PURCHASE_REDIRECT',
            message: 'هدایت به درگاه پرداخت',
          );
          openExternalUrl(paymentUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'به درگاه پرداخت هدایت شدید. پس از پرداخت، موجودی '
                    'به‌روزرسانی می‌شود.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        LoggerService.logProfile(
          action: 'PURCHASE_GATEWAY_UNAVAILABLE',
          message: isMock
              ? 'درگاه فعال از نوع تستی است؛ هدایت انجام نشد.'
              : 'درگاه لینک پرداخت برنگرداند.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cardEnabled
                  ? 'اتصال به درگاه ممکن نشد. می‌توانید با روش کارت به کارت '
                  'ادامه دهید.'
                  : 'اتصال به درگاه ممکن نشد. لطفاً بعداً دوباره تلاش کنید.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // مسیر کارت‌به‌کارت — نمایش شماره کارت و گرفتن رسید
          {
        final accountJson = purchaseData['card_account'];
        final account = accountJson is Map
            ? CardAccount.fromJson(Map<String, dynamic>.from(accountJson))
            : _cardAccount;

        if (!mounted) return;
        setState(() => _isPurchasing = false);

        if (account == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اطلاعات کارت مقصد دریافت نشد. دوباره تلاش کنید.'),
            ),
          );
          return;
        }

        final uploaded = await showCardPaymentSheet(
          context: context,
          purchaseId: purchaseId is int
              ? purchaseId
              : int.parse(purchaseId.toString()),
          account: account,
          amount: (purchaseData['final_price'] as num?)?.toDouble() ?? 0.0,
        );

        if (!mounted) return;
        if (uploaded == true) {
          setState(() {
            _tokenCount = _minTokens;
            _discountController.clear();
            _discountStatusMessage = null;
            _discountValid = null;
            _appliedDiscountCode = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'رسید شما ثبت شد. پس از تایید مدیر، توکن‌ها به حساب شما اضافه می‌شود.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'سفارش ثبت شد. هر زمان رسید را بارگذاری کنید، بررسی می‌شود.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

    } catch (e) {
      setState(() => _isPurchasing = false);
      LoggerService.logApiError(
        method: 'POST',
        url: ServerEndpoints.purchaseToken,
        error: e.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final bool isDesktop = deviceType == AppDeviceType.desktop;
    final bool isTablet = deviceType == AppDeviceType.tablet;

    final double outerMargin = isDesktop ? 20 : (isTablet ? 20 : 12);
    final double containerPaddingH = isDesktop ? 20 : (isTablet ? 24 : 16);
    final double verticalPadding = isDesktop ? 20 : (isTablet ? 28 : 20);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.all(outerMargin),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: containerPaddingH),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: isDesktop
                ? _buildWideLayout()
                : _buildNarrowLayout(deviceType),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 6,
              child: _headerBlock(titleFontSize: 34, iconBoxSize: 88),
            ),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: _balanceCard()),
          ],
        ),
        const SizedBox(height: 20),
        if (_packagesError != null)
          _packagesErrorBanner()
        else
          _combinedCard(isWide: true),
        const SizedBox(height: 16),
        _secureNoteBar(),
      ],
    );
  }

  Widget _buildNarrowLayout(AppDeviceType deviceType) {
    final bool isMobile = deviceType == AppDeviceType.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _headerBlock(
          titleFontSize: isMobile ? 24 : 27,
          iconBoxSize: isMobile ? 8 : 0,
        ),
        const SizedBox(height: 16),
        _balanceCard(),
        const SizedBox(height: 16),
        if (_packagesError != null)
          _packagesErrorBanner()
        else
          _combinedCard(isWide: false),
        const SizedBox(height: 16),
        _secureNoteBar(),
      ],
    );
  }

  Widget _packagesErrorBanner() {
    return _Card(
      child: Column(
        children: [
          Icon(Icons.error_outline, color: dangerFgColor, size: 32),
          const SizedBox(height: 10),
          Text(
            _packagesError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadPackages,
            child: const Text('تلاش دوباره'),
          ),
        ],
      ),
    );
  }

  Widget _headerBlock({
    required double titleFontSize,
    required double iconBoxSize,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: onPrimaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'خرید توکن',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: logoColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'برای ساخت برنامه، توکن، نیاز است.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: titleFontSize * 0.44,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceCard() {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'موجودی فعلی شما:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 10),
              if (_isLoadingBalance)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (_balanceError != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'خطا در دریافت موجودی',
                      style: TextStyle(
                        fontSize: 13,
                        color: dangerFgColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _loadBalance,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_currentBalance',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'توکن',
                      style: TextStyle(
                        fontSize: 16,
                        color: textMutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Image.asset(
            'assets/coin.webp',
            width: 120,
            height: 120,
            cacheWidth: 240,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _combinedCard({required bool isWide}) {
    if (_isLoadingPackages) {
      return const _Card(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final tokenContent = _tokenCountContent();
    final priceContent = _priceSummaryContent();

    if (isWide) {
      return _Card(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: priceContent,
                ),
              ),
              const _VerticalHalfDivider(),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: tokenContent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(24), child: tokenContent),
          const _HorizontalHalfDivider(),
          Padding(padding: const EdgeInsets.all(24), child: priceContent),
        ],
      ),
    );
  }

  Widget _tokenCountContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'تعیین تعداد توکن',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _tokenStepper(),
        const SizedBox(height: 18),
        const _InfoNote(
          text: 'حداقل تعداد توکن قابل خرید ۵۰ عدد و مضرب ۵۰ است',
        ),
        const SizedBox(height: 5),
        const _InfoNote(
          text: 'برای تعداد بیشتر یا شرایط ویژه، از کد تخفیف استفاده کنید',
        ),
        const SizedBox(height: 22),
        const Text(
          'کد تخفیف',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _discountRow(),
        if (_discountStatusMessage != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _discountValid == true ? Icons.check_circle : Icons.error,
                size: 16,
                color: _discountValid == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _discountStatusMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _discountValid == true
                        ? okFgColor
                        : dangerFgColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tokenStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: _tokenCount > _minTokens,
            onTap: () => _changeTokens(-1),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 18),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$_tokenCount',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: logoColor,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: true, // همیشه فعال چون محدودیت بالایی نداریم
            onTap: () => _changeTokens(1),
          ),
        ],
      ),
    );
  }

  Widget _discountRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: TextField(
              controller: _discountController,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: surfaceColor,
                hintText: 'کد تخفیف خود را وارد کنید',
                hintStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.sell_outlined,
                  color: textPrimaryColor,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 21,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: surfaceAltColor,
                    width: 4,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: textFaintColor,
                    width: 2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: textFaintColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 120,
          height: 54,
          child: Material(
            color: primeColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isValidatingDiscount ? null : _validateDiscount,
              child: Center(
                child: _isValidatingDiscount
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: onPrimaryColor,
                  ),
                )
                    : const Text(
                  'بررسی',
                  style: TextStyle(
                    color: onPrimaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceSummaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'نرخ هر توکن',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _RateBox(text: 'هر توکن ${_formatPrice(_pricePerToken)} تومان'),
        const SizedBox(height: 20),
        const Text(
          'نرخ خرید عمده',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _RateBox(text: 'هر ۵۰ توکن ${_formatPrice(_pricePer50)} تومان'),
        const SizedBox(height: 18),
        const _DashedDivider(),
        const SizedBox(height: 18),
        const Text(
          'مبلغ نهایی',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatPrice(_finalPrice),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              'تومان',
              style: TextStyle(
                fontSize: 15,
                color: textMutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (_appliedDiscountCode != null) ...[
          const SizedBox(height: 6),
          Text(
            'تخفیف «$_appliedDiscountCode» در لحظه‌ی پرداخت اعمال می‌شود',
            style: TextStyle(fontSize: 12, color: textMutedColor),
          ),
        ],
        const SizedBox(height: 18),
        _paymentNotice(),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: Material(
            color: (_anyMethodAvailable && _methodsLoaded)
                ? primeColor
                : borderStrongColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: (_isPurchasing || !_methodsLoaded || !_anyMethodAvailable)
                  ? null
                  : _purchaseTokens,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPurchasing)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: onPrimaryColor,
                      ),
                    )
                  else ...[
                    const Text(
                      'پرداخت',
                      style: TextStyle(
                        color: onPrimaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: onPrimaryColor,
                      size: 22,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بخش روش پرداخت.
  ///
  /// وقتی فقط یک روش در دسترس است، انتخابی در کار نیست و فقط توضیح داده
  /// می‌شود چه اتفاقی می‌افتد. به‌محض اینکه سرور دو روش را فعال اعلام کند،
  /// همین ویجت خودش دکمه‌های انتخاب را نشان می‌دهد.
  Widget _paymentNotice() {
    if (!_methodsLoaded) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (!_anyMethodAvailable) {
      return _noticeBox(
        icon: Icons.info_outline,
        background: warnBgColor,
        foreground: warnFgColor,
        text: 'پرداخت در حال حاضر فعال نیست. لطفاً با پشتیبانی تماس بگیرید.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_methodChoiceMatters) ...[
          Text(
            'روش پرداخت',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _methodOption(
                  value: _methodCard,
                  label: 'کارت به کارت',
                  icon: Icons.credit_card_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _methodOption(
                  value: _methodGateway,
                  label: _gatewayName ?? 'درگاه آنلاین',
                  icon: Icons.language_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_paymentMethod == _methodCard)
          _noticeBox(
            icon: Icons.credit_card_rounded,
            background: _highlightBg,
            foreground: logoColor,
            textColor: textSecondaryColor,
            text: 'پس از ثبت سفارش، شماره کارت نمایش داده می‌شود. مبلغ را '
                'واریز کنید و تصویر رسید را بارگذاری کنید؛ توکن‌ها با تایید '
                'مدیر به حساب شما اضافه می‌شوند.',
          )
        else
          _noticeBox(
            icon: Icons.language_rounded,
            background: _highlightBg,
            foreground: logoColor,
            textColor: textSecondaryColor,
            text: 'پس از ثبت سفارش به صفحه‌ی پرداخت هدایت می‌شوید. توکن‌ها '
                'بلافاصله پس از تایید پرداخت توسط درگاه اضافه می‌شوند.',
          ),
      ],
    );
  }

  Widget _noticeBox({
    required IconData icon,
    required Color background,
    required Color foreground,
    required String text,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.8,
                color: textColor ?? foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _paymentMethod == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isPurchasing
          ? null
          : () => setState(() {
        _paymentMethod = value;
        _paymentMethodPickedByUser = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? primeColor.withValues(alpha: 0.10) : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primeColor : borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? primeColor : textMutedColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? primeColor : textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secureNoteBar() {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: textMutedColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _paymentMethod == _methodCard && _cardEnabled
                  ? 'رسید شما توسط مدیر بررسی می‌شود؛ توکن‌ها بلافاصله پس از تایید به حساب شما اضافه می‌شوند'
                  : 'توکن‌ها فقط پس از تایید قطعی پرداخت به حساب شما اضافه می‌شوند',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ویجت‌های کوچیک کمکی (بدون تغییر)
// ==========================================================

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(24)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceAltColor, width: 4),
      ),
      child: child,
    );
  }
}

class _VerticalHalfDivider extends StatelessWidget {
  const _VerticalHalfDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: Center(
        child: FractionallySizedBox(
          heightFactor: 0.62,
          child: Container(width: 1, color: borderColor),
        ),
      ),
    );
  }
}

class _HorizontalHalfDivider extends StatelessWidget {
  const _HorizontalHalfDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.7,
        child: Container(height: 1, color: borderColor),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _highlightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 19, color: primeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateBox extends StatelessWidget {
  const _RateBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _highlightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  static const double _dashWidth = 6;
  static const double _dashSpace = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = borderStrongColor
      ..strokeWidth = 1;
    final double y = size.height / 2;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset((startX + _dashWidth).clamp(0, size.width), y),
        paint,
      );
      startX += _dashWidth + _dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}