import 'package:flutter/material.dart';
import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../loging_system/loging_system.dart';
import '../responsive.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;

// ============================================================
// تابع تشخیص نوع دستگاه
// ============================================================
AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

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

// ============================================================
// صفحه اصلی دستورالعمل ثابت مربی
// API واقعی: یک متن واحد program_instructions - GET / PATCH روی /coach-instructions/
// ============================================================
class CoachInstructionsPage extends StatefulWidget {
  const CoachInstructionsPage({super.key});

  @override
  State<CoachInstructionsPage> createState() => _CoachInstructionsPageState();
}

class _CoachInstructionsPageState extends State<CoachInstructionsPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController _instructionsController =
  TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // متنی که آخرین بار از سرور دریافت شده (برای نمایش وضعیت و تشخیص تغییر)
  String _lastSavedText = '';

  bool get _hasSavedInstructions => _lastSavedText.trim().isNotEmpty;
  bool get _hasUnsavedChanges =>
      _instructionsController.text.trim() != _lastSavedText.trim();

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  // ============================================================
  // دریافت دستورالعمل فعلی از سرور (GET)
  // ============================================================
  Future<void> _loadInstructions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      LoggerService.logEvent(
        title: 'COACH_INSTRUCTIONS',
        message: 'در حال بارگذاری دستورالعمل...',
      );

      final response = await _apiService.get(
        endpoint: ServerEndpoints.coachInstructions,
        requiresAuth: true,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final dataMap = response.data as Map<String, dynamic>;
        final text = (dataMap['program_instructions'] ?? '').toString();

        _instructionsController.text = text;
        _lastSavedText = text;

        setState(() {
          _isLoading = false;
        });

        LoggerService.logProfile(
          action: 'LOAD_SUCCESS',
          message: 'دستورالعمل بارگذاری شد',
        );
      } else {
        setState(() {
          _errorMessage = response.error ?? 'خطای نامشخصی رخ داد';
          _isLoading = false;
        });

        LoggerService.logApiError(
          method: 'GET',
          url: ServerEndpoints.coachInstructions,
          error: response.error ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'خطا: ${e.toString()}';
        _isLoading = false;
      });

      LoggerService.logApiError(
        method: 'GET',
        url: ServerEndpoints.coachInstructions,
        error: e.toString(),
      );
    }
  }

  // ============================================================
  // ذخیره دستورالعمل (PATCH)
  // ============================================================
  Future<void> _saveInstructions() async {
    setState(() {
      _isSaving = true;
    });

    try {
      LoggerService.logProfile(
        action: 'SAVE_INSTRUCTIONS',
        message: 'در حال ذخیره دستورالعمل...',
      );

      final response = await _apiService.put(
        endpoint: ServerEndpoints.coachInstructions,
        body: {
          'program_instructions': _instructionsController.text,
        },
        requiresAuth: true,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() {
          _lastSavedText = _instructionsController.text;
          _isSaving = false;
        });

        LoggerService.logProfile(
          action: 'SAVE_SUCCESS',
          message: 'دستورالعمل ذخیره شد',
        );

        context.showSafeSnackBar('✅ دستورالعمل با موفقیت ذخیره شد');
      } else {
        setState(() {
          _isSaving = false;
        });

        LoggerService.logApiError(
          method: 'PATCH',
          url: ServerEndpoints.coachInstructions,
          error: response.error ?? 'Unknown error',
        );

        context.showSafeSnackBar(
          '❌ خطا: ${response.error ?? 'خطای ناشناخته'}',
          color: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      LoggerService.logApiError(
        method: 'PATCH',
        url: ServerEndpoints.coachInstructions,
        error: e.toString(),
      );

      context.showSafeSnackBar('❌ خطا: ${e.toString()}', color: Colors.red);
    }
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);
    final sizes = _CoachInstructionsSizes.of(deviceType);

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
              width: deviceType == AppDeviceType.desktop
                  ? 1100
                  : double.infinity,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(sizes),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      _buildLoadingState(sizes)
                    else if (_errorMessage != null)
                      _buildErrorState(sizes)
                    else
                      _buildInstructionsCard(sizes),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Header
  // ============================================================
  Widget _buildHeader(_CoachInstructionsSizes sizes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دستورالعمل ثابت مربی',
                style: TextStyle(
                  fontSize: sizes.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'متنی که در تولید هر برنامه‌ی این باشگاه با اولویت بالا به هوش مصنوعی داده می‌شود. مثال: «روز اول هر هفته سبک باشد» یا «برای بانوان از پرس سرشانه بالای سر استفاده نشود».',
                style: TextStyle(
                  fontSize: sizes.descriptionFontSize,
                  color: textSecondaryColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _RefreshButton(
              onPressed: _loadInstructions,
              sizes: sizes,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // Loading State
  // ============================================================
  Widget _buildLoadingState(_CoachInstructionsSizes sizes) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: sizes.emptyStatePaddingV),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(primeColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'در حال بارگذاری...',
              style: TextStyle(
                fontSize: sizes.emptyTitleSize,
                color: textMutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Error State
  // ============================================================
  Widget _buildErrorState(_CoachInstructionsSizes sizes) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: sizes.emptyStatePaddingV),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: sizes.emptyIconSize,
            color: dangerFgColor,
          ),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری',
            style: TextStyle(
              fontSize: sizes.emptyTitleSize,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'خطای نامشخصی رخ داد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sizes.emptyDescSize,
              color: textMutedColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            onPressed: _loadInstructions,
            label: 'تلاش دوباره',
            icon: Icons.refresh_outlined,
            textSize: sizes.buttonTextSize,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // کارت اصلی دستورالعمل (شبیه استایل کارت‌های قبلی)
  // ============================================================
  Widget _buildInstructionsCard(_CoachInstructionsSizes sizes) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(sizes.cardPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(sizes.cardRadius),
        border: Border.all(
          color: _hasUnsavedChanges ? primeColor : borderColor,
          width: _hasUnsavedChanges ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _hasSavedInstructions
                      ? okBgColor
                      : borderColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasSavedInstructions
                        ? okFgColor
                        : textFaintColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasSavedInstructions
                          ? Icons.auto_awesome_outlined
                          : Icons.note_outlined,
                      size: sizes.badgeIconSize,
                      color: _hasSavedInstructions
                          ? okFgColor
                          : textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hasSavedInstructions ? 'ثبت شده' : 'هنوز ثبت نشده',
                      style: TextStyle(
                        fontSize: sizes.badgeTextSize,
                        fontWeight: FontWeight.w500,
                        color: _hasSavedInstructions
                            ? okFgColor
                            : textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasUnsavedChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: warnBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: warnFgColor),
                  ),
                  child: Text(
                    'تغییر ذخیره‌نشده',
                    style: TextStyle(
                      fontSize: sizes.badgeTextSize * 0.9,
                      fontWeight: FontWeight.w500,
                      color: warnFgColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'متن دستورالعمل',
            style: TextStyle(
              fontSize: sizes.cardTextSize * 0.9,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceAltColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderStrongColor, width: 1),
            ),
            child: TextField(
              controller: _instructionsController,
              maxLines: 6,
              minLines: 4,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'دستورالعمل خود را بنویسید...',
                hintStyle: TextStyle(
                  fontSize: sizes.cardTextSize,
                  color: textFaintColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(
                fontSize: sizes.cardTextSize,
                color: textPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  onPressed: (_isSaving || !_hasUnsavedChanges)
                      ? null
                      : _saveInstructions,
                  label: _isSaving ? 'در حال ذخیره...' : 'ذخیره',
                  textSize: sizes.buttonTextSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  onPressed: (_isSaving || !_hasUnsavedChanges)
                      ? null
                      : () {
                    setState(() {
                      _instructionsController.text = _lastSavedText;
                    });
                  },
                  label: 'لغو تغییرات',
                  textSize: sizes.buttonTextSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// دکمه بروزرسانی (رفرش)
// ============================================================
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed, required this.sizes});

  final VoidCallback onPressed;
  final _CoachInstructionsSizes sizes;

  @override
  Widget build(BuildContext context) {
    if (sizes.isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: primeColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primeColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh_outlined, color: onPrimaryColor),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          splashRadius: 22,
        ),
      );
    }

    return _SecondaryButton(
      onPressed: onPressed,
      label: 'دریافت دستورالعمل فعلی',
      textSize: sizes.buttonTextSize,
    );
  }
}

// ============================================================
// دکمه Primary
// ============================================================
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    required this.textSize,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? primeColor : borderStrongColor,
        foregroundColor: onPressed != null
            ? onPrimaryColor
            : textMutedColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(fontSize: textSize, fontWeight: FontWeight.w600),
        minimumSize: const Size(80, 44),
      ),
      child: icon != null
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      )
          : Text(label),
    );
  }
}

// ============================================================
// دکمه Secondary
// ============================================================
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.onPressed,
    required this.label,
    required this.textSize,
  });

  final VoidCallback? onPressed;
  final String label;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondaryColor,
        side: BorderSide(
          color: onPressed != null
              ? textFaintColor
              : borderStrongColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(fontSize: textSize, fontWeight: FontWeight.w500),
        minimumSize: const Size(80, 44),
      ),
      child: Text(label),
    );
  }
}

// ============================================================
// Sizes
// ============================================================
class _CoachInstructionsSizes {
  const _CoachInstructionsSizes({
    required this.isMobile,
    required this.outerMargin,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.containerRadius,
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.buttonTextSize,
    required this.cardPadding,
    required this.cardRadius,
    required this.cardTextSize,
    required this.badgeTextSize,
    required this.badgeIconSize,
    required this.emptyStatePaddingV,
    required this.emptyIconSize,
    required this.emptyTitleSize,
    required this.emptyDescSize,
  });

  final bool isMobile;
  final double outerMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final double containerRadius;
  final double titleFontSize;
  final double descriptionFontSize;
  final double buttonTextSize;
  final double cardPadding;
  final double cardRadius;
  final double cardTextSize;
  final double badgeTextSize;
  final double badgeIconSize;
  final double emptyStatePaddingV;
  final double emptyIconSize;
  final double emptyTitleSize;
  final double emptyDescSize;

  factory _CoachInstructionsSizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.desktop:
        return const _CoachInstructionsSizes(
          isMobile: false,
          outerMargin: 24,
          horizontalPadding: 32,
          verticalPadding: 28,
          containerRadius: 24,
          titleFontSize: 26,
          descriptionFontSize: 17,
          buttonTextSize: 15,
          cardPadding: 20,
          cardRadius: 16,
          cardTextSize: 16,
          badgeTextSize: 12,
          badgeIconSize: 16,
          emptyStatePaddingV: 48,
          emptyIconSize: 64,
          emptyTitleSize: 20,
          emptyDescSize: 16,
        );
      case AppDeviceType.tablet:
        return const _CoachInstructionsSizes(
          isMobile: false,
          outerMargin: 20,
          horizontalPadding: 24,
          verticalPadding: 24,
          containerRadius: 20,
          titleFontSize: 22,
          descriptionFontSize: 15,
          buttonTextSize: 14,
          cardPadding: 16,
          cardRadius: 14,
          cardTextSize: 15,
          badgeTextSize: 11,
          badgeIconSize: 14,
          emptyStatePaddingV: 40,
          emptyIconSize: 56,
          emptyTitleSize: 18,
          emptyDescSize: 14,
        );
      case AppDeviceType.mobile:
        return const _CoachInstructionsSizes(
          isMobile: true,
          outerMargin: 12,
          horizontalPadding: 16,
          verticalPadding: 16,
          containerRadius: 16,
          titleFontSize: 18,
          descriptionFontSize: 14,
          buttonTextSize: 14,
          cardPadding: 16,
          cardRadius: 12,
          cardTextSize: 14,
          badgeTextSize: 10,
          badgeIconSize: 12,
          emptyStatePaddingV: 32,
          emptyIconSize: 48,
          emptyTitleSize: 16,
          emptyDescSize: 14,
        );
    }
  }
}