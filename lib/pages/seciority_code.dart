// lib/pages/one_time_code.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../responsive.dart';
import '../rigester-login/token_manegment.dart';

// ============================================================
// Extension برای نمایش SnackBar با بررسی mounted
// ============================================================
extension SafeSnackBar on BuildContext {
  void showSafeSnackBar(String message, {Color? color, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
      ),
    );
  }
}

// تابع تشخیص نوع دستگاه (همانند سایر صفحات)
AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

class OneTimeCode extends StatefulWidget {
  const OneTimeCode({super.key});

  @override
  State<OneTimeCode> createState() => _OneTimeCodeState();
}

class _OneTimeCodeState extends State<OneTimeCode> with WidgetsBindingObserver {
  // حذف const و تبدیل به متغیر معمولی
  int _initialTokenCredit = 110;

  final ApiService _api = ApiService();

  String? _code;
  int? _clientId;
  int _tokenBalance = 0;

  bool _isLoading = false;
  bool _isGenerating = false;
  String? _errorMessage;

  bool _isCodeVisible = true;
  bool _showConfigDialog = false;

  bool _showTokenRequests = false;
  bool _isLoadingTokenRequests = false;
  List<_TokenRequestItem> _tokenRequests = [];
  final Set<int> _respondingRequestIds = {};

  // نوع برنامه و تنظیمات
  final Set<String> _selectedPrograms = {'workout'}; // workout, nutrition
  bool _allowEditing = false;
  int? _selectedDuration; // دقیقه، یا null برای نامحدود

  // تایمر
  bool _timerActive = false;

  // ثانیه‌های باقی‌مانده عمداً داخل ValueNotifier است، نه state صفحه.
  //
  // قبلاً هر ثانیه setState صدا زده می‌شد و کل درخت این صفحه (یک صفحه‌ی
  // بسیار بزرگ) از نو ساخته می‌شد — فقط برای اینکه دو رقم ساعت عوض شود.
  // حالا تنها همان بنر شمارنده با ValueListenableBuilder بازسازی می‌شود.
  final ValueNotifier<int> _remaining = ValueNotifier<int>(0);
  Timer? _countdownTimer;

  // ========== تابع محاسبه توکن ==========
  int _calculateTokenCredit() {
    int tokenCount = 0;

    // محاسبه بر اساس نوع برنامه
    if (_selectedPrograms.contains('workout')) {
      tokenCount += 25;
    }
    if (_selectedPrograms.contains('nutrition')) {
      tokenCount += 25;
    }

    // اگر توانایی ویرایش انتخاب شده باشد، 25 توکن اضافه کن
    if (_allowEditing) {
      tokenCount += 25;
    }

    // اگر هیچ برنامه‌ای انتخاب نشده، حداقل 25 توکن
    if (tokenCount == 0) {
      tokenCount = 25;
    }

    return tokenCount;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTokenRequests();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _remaining.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ========== API CALLS ==========

  Future<void> _generateNewCode() async {
    if (_isGenerating) return;

    // محاسبه توکن قبل از شروع
    _initialTokenCredit = _calculateTokenCredit();

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final payload = {
      'name': '',
      'age': null,
      'height': null,
      'weight': null,
      'goal': '',
      'injuries': '',
      'food_allergies': '',
      'program_types': _selectedPrograms.toList(),
      'allow_editing': _allowEditing,
    };

    // اگر محدودیت زمانی انتخاب شده باشد
    if (_selectedDuration != null && _selectedDuration! > 0) {
      payload['access_code_validity_days'] = _selectedDuration;
    }

    final createResponse = await _api.post(
      endpoint: ServerEndpoints.gymClients,
      body: payload,
    );

    if (!mounted) return;

    if (!createResponse.success || createResponse.data is! Map) {
      setState(() => _isGenerating = false);
      context.showSafeSnackBar(
        createResponse.error ?? 'خطا در ساخت کد جدید',
        color: Colors.red,
      );
      return;
    }

    final data = createResponse.data as Map<String, dynamic>;
    final newId = _asInt(data['id']);
    final newCode = data['access_code']?.toString();

    if (newId == null || newCode == null) {
      setState(() => _isGenerating = false);
      context.showSafeSnackBar('پاسخ سرور نامعتبر است', color: Colors.red);
      return;
    }

    final tokenResponse = await _api.post(
      endpoint: ServerEndpoints.gymClientAdjustTokens(newId),
      body: {'amount': _initialTokenCredit},
    );

    if (!mounted) return;

    if (!tokenResponse.success) {
      setState(() {
        _code = newCode;
        _clientId = newId;
        _tokenBalance = 0;
        _isGenerating = false;
        _isCodeVisible = true;
        _showConfigDialog = false;
      });
      context.showSafeSnackBar(
        'کد ساخته شد اما ثبت اعتبار اولیه با خطا مواجه شد: ${tokenResponse.error}',
        color: Colors.red,
      );
      return;
    }

    setState(() {
      _code = newCode;
      _clientId = newId;
      _tokenBalance = _initialTokenCredit;
      _isGenerating = false;
      _isCodeVisible = true;
      _showConfigDialog = false;
      _timerActive = _selectedDuration != null && _selectedDuration! > 0;
      _remaining.value = _timerActive ? (_selectedDuration! * 60) : 0;

      // ریست کردن تنظیمات برای بار بعد
      _selectedPrograms.clear();
      _allowEditing = false;
      _selectedDuration = null;
      // بازگذاری انتخاب پیش‌فرض
      _selectedPrograms.add('workout');
    });

    context.showSafeSnackBar(
      'کد جدید با $_initialTokenCredit توکن اعتبار ساخته شد',
    );

    if (_timerActive) {
      _startTimer();
    }
  }

  /// شمارش معکوس اعتبار کد.
  ///
  /// پیاده‌سازی قبلی یک حلقه‌ی Future.doWhile بود که اگر صفحه dispose می‌شد،
  /// چون دیگر setState اجرا نمی‌شد، شمارنده هرگز کم نمی‌شد و شرط پایان هم
  /// هیچ‌وقت برقرار نمی‌شد — یعنی حلقه تا آخر عمر برنامه هر ثانیه بیدار
  /// می‌ماند. حالا یک Timer معمولی است که در dispose قطع می‌شود.
  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_timerActive || _remaining.value <= 1) {
        timer.cancel();
        setState(() {
          _timerActive = false;
          _code = null;
          _clientId = null;
        });
        _remaining.value = 0;
        context.showSafeSnackBar('کد منقضی شد', color: Colors.orange);
        return;
      }

      // فقط بنر شمارنده بازسازی می‌شود، نه کل صفحه
      _remaining.value = _remaining.value - 1;
    });
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!)).then((_) {
      context.showSafeSnackBar('کد کپی شد!');
    });
  }

  void _toggleCodeVisibility() {
    setState(() {
      _isCodeVisible = !_isCodeVisible;
    });
  }

  void _openConfigDialog() {
    setState(() {
      _showConfigDialog = true;
      _showTokenRequests = false;
    });
  }

  void _hideConfigDialog() {
    setState(() {
      _showConfigDialog = false;
    });
  }

  /// ✅ دریافت درخواست‌های توکن از سرور
  Future<void> _loadTokenRequests() async {
    setState(() => _isLoadingTokenRequests = true);

    final response = await _api.get(
      endpoint: ServerEndpoints.tokenRequests,
    );

    if (!mounted) return;

    if (response.success && response.data is List) {
      setState(() {
        _tokenRequests = (response.data as List)
            .map((item) => _TokenRequestItem.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } else {
      setState(() => _tokenRequests = []);
    }

    setState(() => _isLoadingTokenRequests = false);
  }

  /// ✅ پاسخ دادن به درخواست توکن
  Future<void> _respondToTokenRequest(int requestId, String action) async {
    setState(() => _respondingRequestIds.add(requestId));

    final response = await _api.post(
      endpoint: ServerEndpoints.tokenRequestRespond(requestId),
      body: {
        'action': action,
        'response_message': action == 'approve' ? 'تایید شد.' : 'رد شد.',
      },
    );

    if (!mounted) return;

    setState(() => _respondingRequestIds.remove(requestId));

    if (response.success) {
      context.showSafeSnackBar(
        action == 'approve' ? 'درخواست تایید شد ✅' : 'درخواست رد شد',
      );
      _loadTokenRequests();
    } else {
      context.showSafeSnackBar(
        response.error ?? 'خطا در ثبت پاسخ',
        color: Colors.red,
      );
    }
  }

  void _openTokenRequests() {
    setState(() {
      _showTokenRequests = true;
      _showConfigDialog = false;
    });
    _loadTokenRequests();
  }

  void _closeTokenRequests() {
    setState(() => _showTokenRequests = false);
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final isDesktop = deviceType == AppDeviceType.desktop;

    final sizes = _ResponsiveSizes.of(deviceType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.all(sizes.outerMargin),
        padding: EdgeInsets.symmetric(
          horizontal: sizes.horizontalPadding,
          vertical: sizes.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(sizes.containerRadius),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: SizedBox(
              width: isDesktop ? 1000 : double.infinity,
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {},
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: sizes.verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(sizes),
                          const SizedBox(height: 28),
                          if (_timerActive) ...[
                            _buildTimerBanner(sizes),
                            const SizedBox(height: 16),
                          ],
                          Container(
                            padding: EdgeInsets.all(sizes.cardPadding),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(sizes.cardRadius),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (_errorMessage != null) ...[
                                  _buildErrorBanner(_errorMessage!),
                                  const SizedBox(height: 14),
                                ],
                                _buildCodeBox(sizes),
                                if (_clientId != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'اعتبار این کد: $_tokenBalance توکن',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: sizes.bannerTextSize,
                                      color: textSecondaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                _buildSecurityBanner(sizes),
                                const SizedBox(height: 24),
                                _buildFeatureCards(sizes),
                                const SizedBox(height: 24),
                                _buildGenerateButton(sizes),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showConfigDialog)
                    _buildConfigDialog(sizes),
                  if (_showTokenRequests)
                    _buildTokenRequestsOverlay(sizes),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildTimerBanner(_ResponsiveSizes sizes) {
    // تنها بخشی از صفحه که هر ثانیه بازسازی می‌شود
    return ValueListenableBuilder<int>(
      valueListenable: _remaining,
      builder: (context, remaining, _) {
        if (remaining <= 0) return const SizedBox.shrink();
        return _timerBannerBody(sizes, remaining);
      },
    );
  }

  Widget _timerBannerBody(_ResponsiveSizes sizes, int remaining) {
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final timerText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: infoFgColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: sizes.bannerTextSize + 4,
            color: infoFgColor,
          ),
          const SizedBox(width: 8),
          Text(
            'کد در $timerText منقضی می‌شود',
            style: TextStyle(
              fontSize: sizes.bannerTextSize,
              fontWeight: FontWeight.w600,
              color: infoFgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: dangerBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dangerBorderColor),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: dangerFgColor, fontSize: 13),
      ),
    );
  }

  Widget _buildHeader(_ResponsiveSizes sizes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: sizes.headerIconSize,
          height: sizes.headerIconSize,
          decoration: BoxDecoration(
            color: primeColor,
            borderRadius: BorderRadius.circular(sizes.headerIconRadius),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: sizes.headerIconSize * 0.55,
            color: onPrimaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'کد محرمانه یک بار مصرف',
                style: TextStyle(
                  fontSize: sizes.headerTitleSize,
                  fontWeight: FontWeight.bold,
                  color: logoColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تنظیم برنامه، محدودیت زمانی و نوع برنامه را مشخص کنید',
                style: TextStyle(
                  fontSize: sizes.headerSubtitleSize,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildTokenRequestsButton(sizes),
      ],
    );
  }

  Widget _buildTokenRequestsButton(_ResponsiveSizes sizes) {
    final pendingCount =
        _tokenRequests.where((r) => r.status == 'pending').length;

    return Material(
      color: infoBgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openTokenRequests,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sizes.isMobile ? 10 : 14,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mail_outline,
                size: sizes.headerSubtitleSize + 6,
                color: primeColor,
              ),
              if (!sizes.isMobile) ...[
                const SizedBox(width: 6),
                Text(
                  'درخواست‌های توکن',
                  style: TextStyle(
                    fontSize: sizes.bannerTextSize,
                    fontWeight: FontWeight.w600,
                    color: primeColor,
                  ),
                ),
              ],
              if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  decoration: BoxDecoration(
                    color: dangerSolidColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$pendingCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: onPrimaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCodeBox(_ResponsiveSizes sizes) {
    return Container(
      height: sizes.codeBoxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderStrongColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isLoading
          ? const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      )
          : Row(
        children: [
          _buildCopyButton(sizes),
          Expanded(child: Center(child: _buildCodeDisplay(sizes))),
          _buildVisibilityButton(sizes),
        ],
      ),
    );
  }

  Widget _buildCopyButton(_ResponsiveSizes sizes) {
    final enabled = _code != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primeColor.withValues(alpha: enabled ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: enabled ? _copyCode : null,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy,
              size: sizes.copyIconSize,
              color: enabled ? primeColor : textFaintColor,
            ),
            const SizedBox(width: 4),
            Text(
              'کپی',
              style: TextStyle(
                fontSize: sizes.copyTextSize,
                fontWeight: FontWeight.w600,
                color: enabled ? primeColor : textFaintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeDisplay(_ResponsiveSizes sizes) {
    if (_code == null) {
      return Text(
        'کد فعالی وجود ندارد',
        style: TextStyle(
          fontSize: sizes.codeDigitSize * 0.5,
          color: textFaintColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: _isCodeVisible
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _code!.split('').map((digit) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              digit,
              style: TextStyle(
                fontSize: sizes.codeDigitSize,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
                letterSpacing: 2,
              ),
            ),
          );
        }).toList(),
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_code!.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: sizes.codeDotSize,
              height: sizes.codeDotSize,
              decoration: BoxDecoration(
                color: textPrimaryColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVisibilityButton(_ResponsiveSizes sizes) {
    final enabled = _code != null;
    return InkWell(
      onTap: enabled ? _toggleCodeVisibility : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          _isCodeVisible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: sizes.visibilityIconSize,
          color: enabled ? textSecondaryColor : borderStrongColor,
        ),
      ),
    );
  }

  Widget _buildSecurityBanner(_ResponsiveSizes sizes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: okBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: okFgColor),
      ),
      child: Text(
        'این کد محرمانه است آن را فقط با ورزشکار مورد نظر به اشتراک بگذارید',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: sizes.bannerTextSize,
          fontWeight: FontWeight.w500,
          color: okFgColor,
        ),
      ),
    );
  }

  Widget _buildFeatureCards(_ResponsiveSizes sizes) {
    final List<_FeatureItem> features = const [
      _FeatureItem(
        icon: Icons.lock_outline,
        title: 'چند بار مصرف',
        description: 'هر کد تا زمانی که تایم و توکن داشته باشد معنبر است',
      ),
      _FeatureItem(
        icon: Icons.edit_outlined,
        title: 'توانایی ویرایش',
        description: 'ورزشکار برنامه را بعد از ایجاد یک بار ویرایش کند',
      ),
      _FeatureItem(
        icon: Icons.schedule_outlined,
        title: 'محدودیت زمانی',
        description: 'اگر تا تا قبل از تمام شدن محدودیت زمانی کد اعتبار سنجی نشود منقضی میشود',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: sizes.isMobile
          ? _buildMobileFeatures(features, sizes)
          : _buildDesktopTabletFeatures(features, sizes),
    );
  }

  Widget _buildDesktopTabletFeatures(
      List<_FeatureItem> features,
      _ResponsiveSizes sizes,
      ) {
    return Row(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Expanded(
          child: _buildFeatureItem(
            item,
            sizes,
            withDivider: index < features.length - 1,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileFeatures(
      List<_FeatureItem> features,
      _ResponsiveSizes sizes,
      ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFeatureItem(features[0], sizes, withDivider: true),
            ),
            Expanded(
              child: _buildFeatureItem(features[1], sizes, withDivider: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.42,
            child: _buildFeatureItem(features[2], sizes, withDivider: false),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
      _FeatureItem item,
      _ResponsiveSizes sizes, {
        required bool withDivider,
      }) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: sizes.featureIconBgSize,
          height: sizes.featureIconBgSize,
          decoration: BoxDecoration(
            color: infoBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.icon,
            size: sizes.featureIconSize,
            color: primeColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sizes.featureTitleSize,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sizes.featureDescSize,
            color: textSecondaryColor,
          ),
        ),
      ],
    );

    if (withDivider) {
      return Row(
        children: [
          Expanded(child: child),
          Container(
            width: 1,
            height: 60,
            color: borderStrongColor,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ],
      );
    }
    return child;
  }

  Widget _buildGenerateButton(_ResponsiveSizes sizes) {
    return SizedBox(
      width: double.infinity,
      height: sizes.generateButtonHeight,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _openConfigDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: primeColor,
          foregroundColor: onPrimaryColor,
          disabledBackgroundColor: primeColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isGenerating
            ? SizedBox(
          width: sizes.generateButtonTextSize,
          height: sizes.generateButtonTextSize,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: onPrimaryColor,
          ),
        )
            : Text(
          'ساخت کد جدید',
          style: TextStyle(
            fontSize: sizes.generateButtonTextSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigDialog(_ResponsiveSizes sizes) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideConfigDialog,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: sizes.isMobile ? 320 : 420,
                constraints: const BoxConstraints(maxHeight: 600),
                padding: EdgeInsets.all(sizes.confirmationPadding),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(sizes.confirmationRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: infoBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.settings_outlined,
                              color: primeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'تنظیمات کد',
                              style: TextStyle(
                                fontSize: sizes.confirmationTitleSize,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _hideConfigDialog,
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // نوع برنامه
                      _buildConfigSection(
                        'نوع برنامه',
                        _buildProgramTypeSelector(sizes),
                        sizes,
                      ),
                      const SizedBox(height: 16),
                      // توانایی ویرایش
                      _buildEditingToggle(sizes),
                      const SizedBox(height: 16),
                      // محدودیت زمانی
                      _buildConfigSection(
                        'محدودیت زمانی',
                        _buildDurationSelector(sizes),
                        sizes,
                      ),
                      const SizedBox(height: 24),
                      // دکمه تایید
                      _buildConfigSubmitButton(sizes),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigSection(
      String title, Widget content, _ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: sizes.bannerTextSize + 1,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildProgramTypeSelector(_ResponsiveSizes sizes) {
    final options = [
      ('workout', 'ورزشی', 25),
      ('nutrition', 'غذایی', 25),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((option) {
        final (key, label, cost) = option;
        final isSelected = _selectedPrograms.contains(key);
        return Material(
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected && _selectedPrograms.length > 1) {
                  _selectedPrograms.remove(key);
                } else if (!isSelected) {
                  _selectedPrograms.add(key);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? primeColor.withValues(alpha: 0.08) : surfaceAltColor,
                border: Border.all(
                  color: isSelected ? primeColor : borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? primeColor : borderStrongColor,
                      ),
                      color: isSelected ? primeColor : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                      Icons.check,
                      size: 12,
                      color: onPrimaryColor,
                    )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: sizes.confirmationDescSize,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  Text(
                    '$cost توکن',
                    style: TextStyle(
                      fontSize: sizes.confirmationDescSize,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? primeColor : textMutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditingToggle(_ResponsiveSizes sizes) {
    return Material(
      child: InkWell(
        onTap: () => setState(() => _allowEditing = !_allowEditing),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: _allowEditing ? primeColor.withValues(alpha: 0.08) : surfaceAltColor,
            border: Border.all(
              color: _allowEditing ? primeColor : borderColor,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توانایی ویرایش برنامه',
                      style: TextStyle(
                        fontSize: sizes.confirmationDescSize,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ورزشکار بتواند برنامه را بعد از ایجاد تغییر دهد',
                      style: TextStyle(
                        fontSize: sizes.confirmationDescSize - 1,
                        color: textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: _allowEditing ? primeColor : borderStrongColor,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _allowEditing
                        ? Icons.check_outlined
                        : Icons.close_outlined,
                    size: 16,
                    color: onPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector(_ResponsiveSizes sizes) {
    final durations = [3, 5, 10, 15, 30];

    return Column(
      children: [
        // بدون محدودیت زمانی
        Material(
          child: InkWell(
            onTap: () => setState(() => _selectedDuration = null),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _selectedDuration == null
                    ? primeColor.withValues(alpha: 0.08)
                    : surfaceAltColor,
                border: Border.all(
                  color: _selectedDuration == null
                      ? primeColor
                      : borderColor,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedDuration == null
                            ? primeColor
                            : borderStrongColor,
                      ),
                      color: _selectedDuration == null
                          ? primeColor
                          : Colors.transparent,
                    ),
                    child: _selectedDuration == null
                        ? const Icon(Icons.check, size: 12, color: onPrimaryColor)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'بدون محدودیت',
                    style: TextStyle(
                      fontSize: sizes.confirmationDescSize,
                      fontWeight: FontWeight.w500,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // گزینه‌های زمانی
        ...durations.map((duration) {
          final isSelected = _selectedDuration == duration;
          return Material(
            child: InkWell(
              onTap: () => setState(() => _selectedDuration = duration),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primeColor.withValues(alpha: 0.08)
                      : surfaceAltColor,
                  border: Border.all(
                    color: isSelected ? primeColor : borderColor,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                          isSelected ? primeColor : borderStrongColor,
                        ),
                        color: isSelected ? primeColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                        Icons.check,
                        size: 12,
                        color: onPrimaryColor,
                      )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$duration دقیقه',
                      style: TextStyle(
                        fontSize: sizes.confirmationDescSize,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfigSubmitButton(_ResponsiveSizes sizes) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _hideConfigDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: textSecondaryColor,
              side: BorderSide(color: borderStrongColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: sizes.confirmationButtonPadding),
            ),
            child: Text(
              'لغو',
              style: TextStyle(
                fontSize: sizes.confirmationButtonSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isGenerating
                ? null
                : () {
              _hideConfigDialog();
              _generateNewCode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primeColor,
              foregroundColor: onPrimaryColor,
              disabledBackgroundColor: primeColor.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: sizes.confirmationButtonPadding),
              elevation: 0,
            ),
            child: Text(
              'تأیید و ساخت',
              style: TextStyle(
                fontSize: sizes.confirmationButtonSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenRequestsOverlay(_ResponsiveSizes sizes) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeTokenRequests,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: sizes.isMobile ? 320 : 460,
                constraints: const BoxConstraints(maxHeight: 520),
                padding: EdgeInsets.all(sizes.confirmationPadding),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(sizes.confirmationRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 36,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: infoBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mail_outline,
                            color: primeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'درخواست‌های توکن',
                            style: TextStyle(
                              fontSize: sizes.confirmationTitleSize,
                              fontWeight: FontWeight.bold,
                              color: textPrimaryColor,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _closeTokenRequests,
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: _isLoadingTokenRequests
                          ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : _tokenRequests.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'درخواستی وجود ندارد',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textMutedColor),
                        ),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _tokenRequests.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildTokenRequestRow(_tokenRequests[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenRequestRow(_TokenRequestItem request) {
    final isPending = request.status == 'pending';
    final isResponding = _respondingRequestIds.contains(request.id);

    Color statusColor;
    String statusLabel;
    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'تایید شده';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'رد شده';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'در انتظار';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.clientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${request.requestedTokens} توکن',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primeColor,
            ),
          ),
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.message,
              style: TextStyle(fontSize: 12, color: textSecondaryColor),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isResponding
                        ? null
                        : () => _respondToTokenRequest(request.id, 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dangerFgColor,
                      side: BorderSide(color: dangerBorderColor),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('رد', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isResponding
                        ? null
                        : () => _respondToTokenRequest(request.id, 'approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primeColor,
                      foregroundColor: onPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isResponding
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onPrimaryColor,
                      ),
                    )
                        : const Text('تایید', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// Models and Responsive Sizes
// ==========================================================
class _TokenRequestItem {
  final int id;
  final String clientName;
  final int requestedTokens;
  final String status;
  final String message;

  const _TokenRequestItem({
    required this.id,
    required this.clientName,
    required this.requestedTokens,
    required this.status,
    required this.message,
  });

  factory _TokenRequestItem.fromJson(Map<String, dynamic> json) {
    return _TokenRequestItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      clientName: json['client_name']?.toString() ?? 'مشتری',
      requestedTokens: json['requested_tokens'] is int
          ? json['requested_tokens'] as int
          : int.tryParse('${json['requested_tokens']}') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString() ?? '',
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _ResponsiveSizes {
  const _ResponsiveSizes({
    required this.outerMargin,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.containerRadius,
    required this.cardPadding,
    required this.cardRadius,
    required this.headerIconSize,
    required this.headerIconRadius,
    required this.headerTitleSize,
    required this.headerSubtitleSize,
    required this.codeBoxHeight,
    required this.copyIconSize,
    required this.copyTextSize,
    required this.codeDotSize,
    required this.codeDigitSize,
    required this.visibilityIconSize,
    required this.bannerTextSize,
    required this.featureIconBgSize,
    required this.featureIconSize,
    required this.featureTitleSize,
    required this.featureDescSize,
    required this.generateButtonHeight,
    required this.generateButtonTextSize,
    required this.isMobile,
    required this.confirmationWidth,
    required this.confirmationPadding,
    required this.confirmationRadius,
    required this.confirmationIconSize,
    required this.confirmationTitleSize,
    required this.confirmationDescSize,
    required this.confirmationButtonPadding,
    required this.confirmationButtonSize,
  });

  final double outerMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final double containerRadius;
  final double cardPadding;
  final double cardRadius;

  final double headerIconSize;
  final double headerIconRadius;
  final double headerTitleSize;
  final double headerSubtitleSize;

  final double codeBoxHeight;
  final double copyIconSize;
  final double copyTextSize;
  final double codeDotSize;
  final double codeDigitSize;
  final double visibilityIconSize;

  final double bannerTextSize;

  final double featureIconBgSize;
  final double featureIconSize;
  final double featureTitleSize;
  final double featureDescSize;

  final double generateButtonHeight;
  final double generateButtonTextSize;

  final bool isMobile;

  final double confirmationWidth;
  final double confirmationPadding;
  final double confirmationRadius;
  final double confirmationIconSize;
  final double confirmationTitleSize;
  final double confirmationDescSize;
  final double confirmationButtonPadding;
  final double confirmationButtonSize;

  factory _ResponsiveSizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.desktop:
        return const _ResponsiveSizes(
          outerMargin: 24,
          horizontalPadding: 32,
          verticalPadding: 32,
          containerRadius: 24,
          cardPadding: 32,
          cardRadius: 20,
          headerIconSize: 56,
          headerIconRadius: 16,
          headerTitleSize: 28,
          headerSubtitleSize: 16,
          codeBoxHeight: 80,
          copyIconSize: 22,
          copyTextSize: 16,
          codeDotSize: 16,
          codeDigitSize: 28,
          visibilityIconSize: 26,
          bannerTextSize: 15,
          featureIconBgSize: 52,
          featureIconSize: 26,
          featureTitleSize: 15,
          featureDescSize: 13,
          generateButtonHeight: 58,
          generateButtonTextSize: 18,
          isMobile: false,
          confirmationWidth: 400,
          confirmationPadding: 28,
          confirmationRadius: 24,
          confirmationIconSize: 60,
          confirmationTitleSize: 20,
          confirmationDescSize: 15,
          confirmationButtonPadding: 14,
          confirmationButtonSize: 16,
        );
      case AppDeviceType.tablet:
        return const _ResponsiveSizes(
          outerMargin: 20,
          horizontalPadding: 24,
          verticalPadding: 24,
          containerRadius: 20,
          cardPadding: 24,
          cardRadius: 16,
          headerIconSize: 48,
          headerIconRadius: 14,
          headerTitleSize: 24,
          headerSubtitleSize: 14,
          codeBoxHeight: 72,
          copyIconSize: 20,
          copyTextSize: 14,
          codeDotSize: 14,
          codeDigitSize: 24,
          visibilityIconSize: 22,
          bannerTextSize: 13,
          featureIconBgSize: 46,
          featureIconSize: 22,
          featureTitleSize: 14,
          featureDescSize: 12,
          generateButtonHeight: 52,
          generateButtonTextSize: 16,
          isMobile: false,
          confirmationWidth: 380,
          confirmationPadding: 24,
          confirmationRadius: 20,
          confirmationIconSize: 52,
          confirmationTitleSize: 18,
          confirmationDescSize: 14,
          confirmationButtonPadding: 12,
          confirmationButtonSize: 15,
        );
      case AppDeviceType.mobile:
        return const _ResponsiveSizes(
          outerMargin: 12,
          horizontalPadding: 16,
          verticalPadding: 12,
          containerRadius: 16,
          cardPadding: 16,
          cardRadius: 12,
          headerIconSize: 40,
          headerIconRadius: 12,
          headerTitleSize: 18,
          headerSubtitleSize: 12,
          codeBoxHeight: 60,
          copyIconSize: 18,
          copyTextSize: 13,
          codeDotSize: 12,
          codeDigitSize: 20,
          visibilityIconSize: 20,
          bannerTextSize: 12,
          featureIconBgSize: 40,
          featureIconSize: 20,
          featureTitleSize: 13,
          featureDescSize: 11,
          generateButtonHeight: 48,
          generateButtonTextSize: 15,
          isMobile: true,
          confirmationWidth: 320,
          confirmationPadding: 20,
          confirmationRadius: 18,
          confirmationIconSize: 48,
          confirmationTitleSize: 17,
          confirmationDescSize: 13,
          confirmationButtonPadding: 10,
          confirmationButtonSize: 14,
        );
    }
  }
}