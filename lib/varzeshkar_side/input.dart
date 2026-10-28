import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../colors.dart';
import '../core/network/athlete_api.dart';
import '../core/session/session_resolver.dart';
import '../core/session/session_store.dart';
import '../rigester-login/which_one.dart' show AuthChoicePage;

// پالت اختصاصی پنل ورزشکار.
//
// این سه نام عمداً همین‌جا تعریف شده‌اند و نسخه‌ی `colors.dart` را سایه
// می‌زنند: پنل ورزشکار هویت رنگی آبی خودش را دارد و نباید با فیروزه‌ای
// پنل مربی یکی شود.

enum AppDeviceType { mobile, tablet, desktop }

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

/// برچسب و آیکون نوع PDF — بخش نمایشی.
extension ProgramPdfTypeX on ProgramPdfType {
  String get label {
    switch (this) {
      case ProgramPdfType.workout:
        return 'ورزشی';
      case ProgramPdfType.meal:
        return 'غذایی';
      case ProgramPdfType.both:
        return 'کامل';
    }
  }

  IconData get icon {
    switch (this) {
      case ProgramPdfType.workout:
        return Icons.fitness_center;
      case ProgramPdfType.meal:
        return Icons.restaurant;
      case ProgramPdfType.both:
        return Icons.menu_book;
    }
  }
}

/// بخش نمایشی درخواست توکن — رنگ و برچسب فارسی وضعیت.
///
/// خود مدل در `core/network/athlete_api.dart` است؛ اینها تصمیم رابط
/// کاربری‌اند و نباید در لایه‌ی شبکه بنشینند.
extension TokenRequestView on TokenRequest {
  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return textMutedColor;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'در انتظار';
      case 'approved':
        return 'تایید شده';
      case 'rejected':
        return 'رد شده';
      default:
        return '-';
    }
  }
}

// ==================== لودینگ داخل کارت (جایگزین فرم) ====================
class _LoadingInsideCard extends StatelessWidget {
  const _LoadingInsideCard({this.message = 'در حال ساخت برنامه...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        border: Border.all(color: borderStrongColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // حلقه‌های بارگذاری
          Stack(
            alignment: Alignment.center,
            children: [
              // حلقه بیرونی
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0, end: 1),
                curve: Curves.linear,
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 6.2832,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          primeColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // حلقه داخلی
              TweenAnimationBuilder(
                duration: const Duration(seconds: 1),
                tween: Tween<double>(begin: 0, end: -1),
                curve: Curves.linear,
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 6.2832,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          backgroundColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // نقطه مرکزی با پالس
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0.6, end: 1),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Container(
                    width: 14 * value,
                    height: 14 * value,
                    decoration: BoxDecoration(
                      color: primeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primeColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          // متن
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 0, end: 1),
            curve: Curves.easeIn,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Column(
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textSecondaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // نقطه‌های متحرک
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                            (index) => TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween<double>(begin: 0, end: 1),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            final delay = index * 0.2;
                            final progress = ((value - delay) % 1);
                            final opacity = progress < 0.5
                                ? progress * 2
                                : (1 - progress) * 2;
                            return Opacity(
                              opacity: opacity,
                              child: Container(
                                margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: primeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لطفاً صبر کنید...',
                      style: TextStyle(
                        fontSize: 13,
                        color: textFaintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==================== کارت آماده‌بودن برنامه (الگو گرفته از کارت NewProgram) ====================
class _ProgramReadyCard extends StatelessWidget {
  const _ProgramReadyCard({
    required this.days,
    required this.typeLabel,
    required this.child,
    this.width = 300,
  });

  final int days;
  final String typeLabel;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
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
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: okBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'آماده',
                    style: TextStyle(
                      color: okFgColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle, color: okFgColor, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Image.asset('assets/pdf.webp',
              width: 84, height: 84, cacheWidth: 168),
          const SizedBox(height: 14),
          const Text(
            'برنامه شما',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'روزهای برنامه:',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$days روز',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: borderColor),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'نوع برنامه:',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ==================== کلاس کمکی برای ذخیره و باز کردن PDF ====================
// ==================== ApiService ====================
// ==================== دکمه دانلود PDF ====================
class PdfDownloadButton extends StatefulWidget {
  final int programId;
  final ProgramPdfType type;
  final bool showAllTypes;

  const PdfDownloadButton({
    super.key,
    required this.programId,
    this.type = ProgramPdfType.both,
    this.showAllTypes = false,
  });

  @override
  State<PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

enum _DownloadState { idle, loading, success, error }

class _PdfDownloadButtonState extends State<PdfDownloadButton> {
  _DownloadState _state = _DownloadState.idle;
  List<ProgramPdfType> _typesToDownload = [];
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _initTypes();
  }

  void _initTypes() {
    if (widget.showAllTypes) {
      _typesToDownload = [
        ProgramPdfType.both,
        ProgramPdfType.workout,
        ProgramPdfType.meal
      ];
    } else {
      _typesToDownload = [widget.type];
    }
  }

  Future<void> _download() async {
    setState(() {
      _state = _DownloadState.loading;
      _downloadProgress = 0;
    });

    try {
      final results = await AthleteApi.downloadMultipleProgramPdfs(
        programId: widget.programId,
        types: _typesToDownload,
      );

      for (int i = 0; i < results.length; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _downloadProgress = (i + 1) / results.length;
        });
      }

      await PdfFileHelper.saveMultipleAndOpen(results);

      if (!mounted) return;
      setState(() => _state = _DownloadState.success);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${results.length} فایل PDF با موفقیت دانلود شد'),
          backgroundColor: okFgColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _DownloadState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: dangerFgColor,
        ),
      );
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _state != _DownloadState.loading) {
          setState(() => _state = _DownloadState.idle);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _state == _DownloadState.loading;
    final isSuccess = _state == _DownloadState.success;
    final isError = _state == _DownloadState.error;

    final Color bg =
    isSuccess ? okFgColor : isError ? dangerFgColor : primeColor;

    String getButtonText() {
      if (isSuccess) return 'دانلود شد';
      if (isError) return 'دوباره تلاش';
      if (widget.showAllTypes) {
        return 'دانلود همه (${_typesToDownload.length})';
      }
      return 'دانلود ${widget.type.label}';
    }

    return ElevatedButton(
      onPressed: isLoading ? null : _download,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: isLoading
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _downloadProgress,
              valueColor:
              const AlwaysStoppedAnimation(onPrimaryColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(_downloadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: onPrimaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.showAllTypes)
            Icon(widget.type.icon, color: onPrimaryColor, size: 16),
          if (!widget.showAllTypes) const SizedBox(width: 6),
          Text(
            getButtonText(),
            style: const TextStyle(
              color: onPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== دکمه دانلود گروهی ====================
class PdfBatchDownloadButton extends StatelessWidget {
  final int programId;
  final bool hasExercisePlan;
  final bool hasFoodPlan;

  const PdfBatchDownloadButton({
    super.key,
    required this.programId,
    required this.hasExercisePlan,
    required this.hasFoodPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PdfDownloadButton(
          programId: programId,
          showAllTypes: true,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            PdfDownloadButton(
              programId: programId,
              type: ProgramPdfType.both,
            ),
            if (hasExercisePlan)
              PdfDownloadButton(
                programId: programId,
                type: ProgramPdfType.workout,
              ),
            if (hasFoodPlan)
              PdfDownloadButton(
                programId: programId,
                type: ProgramPdfType.meal,
              ),
          ],
        ),
      ],
    );
  }
}

// ==================== صفحه اصلی ====================
class VarzeshkarSide extends StatefulWidget {
  const VarzeshkarSide({super.key});

  @override
  State<VarzeshkarSide> createState() => _VarzeshkarSideState();
}

class _VarzeshkarSideState extends State<VarzeshkarSide> {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _gymBrand;
  int _tokenBalance = 0;
  String _errorMessage = '';
  bool _isLoading = false;
  bool _isRefreshing = false;

  final TextEditingController _accessCodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _injuryController = TextEditingController();
  final TextEditingController _bodyIssuesController = TextEditingController();
  final TextEditingController _foodSensitivityController =
  TextEditingController();
  final TextEditingController _additionalNotesController =
  TextEditingController();
  final TextEditingController _tokenMessageController =
  TextEditingController();

  int _tokenRequestAmount = 50;
  String _gender = 'مرد';
  String? _trainingHistory;
  int _days = 3;
  bool _hasExercisePlan = true;
  bool _hasFoodPlan = false;

  int _currentPage = 0;
  static const int _totalPages = 3;

  bool _nameError = false;
  bool _weightError = false;
  bool _heightError = false;
  bool _checkboxError = false;

  bool _isCompleted = false;
  bool _showTokenRequestDialog = false;
  List<TokenRequest> _previousRequests = [];
  bool _isLoadingRequests = false;

  int? _lastProgramId;
  Uint8List? _lastProgramPdf;
  String _lastProgramPdfType = 'both';

  /// برنامه‌ای که با کد یکبارمصرف گرفته شده و منتظر کلیک کاربر است.
  Uint8List? _redeemedPdf;
  String? _redeemedPdfName;
  bool _isSavingRedeemedPdf = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  @override
  void dispose() {
    _accessCodeController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _injuryController.dispose();
    _bodyIssuesController.dispose();
    _foodSensitivityController.dispose();
    _additionalNotesController.dispose();
    _tokenMessageController.dispose();
    super.dispose();
  }

  /// آیا نشست ذخیره‌شده متعلق به همین پنل است؟
  Future<void> _checkExistingLogin() async {
    final token = await SecureStorage.getString(tokenKey);
    if (token == null || token.isEmpty) return;

    final kind = await SessionResolver.resolveKindOrStored();

    if (kind == AppSessionKind.none) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _errorMessage =
        'نشست شما منقضی شده است. دوباره کد دسترسی را وارد کنید.';
      });
      return;
    }

    if (kind == AppSessionKind.coach) {
      if (!mounted) return;
      setState(() => _isLoggedIn = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoggedIn = true);
    await _loadUserData();
    await _loadTokenRequests();
  }

  Future<void> _login() async {
    if (_accessCodeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'کد دسترسی را وارد کنید');
      return;
    }

    final code = _accessCodeController.text.trim();

    setState(() => _isLoading = true);
    try {
      await AthleteApi.clientLogin(code);
      setState(() {
        _isLoggedIn = true;
        _errorMessage = '';
      });
      await _loadUserData();
      await _loadTokenRequests();
    } on ProgramDownloadCodeException {
      await _redeemProgramCode(code);
    } catch (e) {
      setState(() => _errorMessage = 'خطا: ${e.toString()}');
      Logger.log('Login error', error: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// گرفتن برنامه‌ای که مربی از قبل ساخته است، با کد یکبارمصرف.
  Future<void> _redeemProgramCode(String code) async {
    try {
      final bytes = await AthleteApi.redeemProgramCode(code);

      if (!mounted) return;
      setState(() {
        _errorMessage = '';
        _redeemedPdf = bytes;
        _redeemedPdfName = 'program_$code.pdf';
        _accessCodeController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(
              () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      Logger.log('Redeem error', error: e.toString());
    }
  }

  /// ذخیره‌ی فایلی که با کد یکبارمصرف گرفته شده — با کلیک خود ورزشکار.
  Future<void> _saveRedeemedPdf() async {
    final bytes = _redeemedPdf;
    final name = _redeemedPdfName;
    if (bytes == null || name == null) return;

    setState(() => _isSavingRedeemedPdf = true);
    try {
      await PdfFileHelper.saveAndOpen(bytes, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          content: Text('برنامه شما دانلود شد. فایل را نگه دارید.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: dangerFgColor,
          content: Text('ذخیره‌ی فایل ناموفق بود: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingRedeemedPdf = false);
    }
  }

  /// بازگشت از کارت دانلود به فرم ورود کد.
  void _clearRedeemedPdf() {
    setState(() {
      _redeemedPdf = null;
      _redeemedPdfName = null;
      _errorMessage = '';
    });
  }

  Future<void> _refreshTokenBalance() async {
    setState(() => _isRefreshing = true);
    try {
      final balance = await AthleteApi.getTokenBalance();
      if (mounted) {
        setState(() => _tokenBalance = balance);
      }
      Logger.log('Token balance updated: $balance');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('موجودی به‌روزرسانی شد'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      Logger.log('Refresh token balance error', error: e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: dangerFgColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    Map<String, dynamic> profile = {};
    Map<String, dynamic> brand = {};
    Map<String, dynamic> user = {};

    try {
      profile = await AthleteApi.getClientProfile();
    } catch (e) {
      Logger.log('Load client profile error', error: e.toString());
    }

    try {
      brand = await AthleteApi.getGymBrand();
    } catch (e) {
      Logger.log('Load gym brand error', error: e.toString());
    }

    try {
      user = await AthleteApi.getUserProfile();
    } catch (e) {
      Logger.log('Load user profile error', error: e.toString());
    }

    if (!mounted) return;

    setState(() {
      if (profile.isNotEmpty) {
        _userProfile = profile;
        _nameController.text = profile['name'] ?? '';
        _ageController.text = (profile['age'] ?? '').toString();
        _heightController.text = (profile['height'] ?? '').toString();
        _weightController.text = (profile['weight'] ?? '').toString();
        _injuryController.text = profile['injuries'] ?? '';
        _bodyIssuesController.text = (profile['body_issues'] ?? '') as String;
        _foodSensitivityController.text = profile['food_allergies'] ?? '';

        if (profile['gender'] != null) _gender = profile['gender'];
      }

      if (brand.isNotEmpty) {
        _gymBrand = brand;
      }

      if (user.containsKey('token_balance')) {
        _tokenBalance = user['token_balance'] ?? 0;
      }
    });

    Logger.log('User data loaded');
  }

  Future<void> _loadTokenRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final requests = await AthleteApi.getTokenRequests();
      if (!mounted) return;
      setState(() {
        _previousRequests = requests;
      });
    } catch (e) {
      Logger.log('Load requests error', error: e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _requestTokens() async {
    final amount = _tokenRequestAmount;
    final message = _tokenMessageController.text.trim();

    setState(() => _isLoading = true);
    try {
      await AthleteApi.requestTokens(
        amount: amount,
        message: message,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست ارسال شد'),
          backgroundColor: Colors.green,
        ),
      );

      _tokenMessageController.clear();
      setState(() {
        _showTokenRequestDialog = false;
        _tokenRequestAmount = 50;
      });

      await _loadTokenRequests();
      await _refreshTokenBalance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: dangerFgColor,
          ),
        );
      }
      Logger.log('Request tokens error', error: e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validatePageOne() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty;
      _weightError = _weightController.text.trim().isEmpty ||
          double.tryParse(_weightController.text.trim()) == null;
      _heightError = _heightController.text.trim().isEmpty ||
          double.tryParse(_heightController.text.trim()) == null;
      _checkboxError = !_hasExercisePlan && !_hasFoodPlan;
    });
    return !_nameError && !_weightError && !_heightError && !_checkboxError;
  }

  void _onNextPressed() {
    if (_currentPage == 0 && !_validatePageOne()) return;

    if (_currentPage == _totalPages - 1) {
      setState(() => _isCompleted = true);
      _generateProgram();
      return;
    }

    setState(() => _currentPage++);
  }

  void _onPrevPressed() {
    if (_currentPage == 0) return;
    setState(() => _currentPage--);
  }

  /// نگه داشته شده برای زمانی که نوع PDF از پاسخ سرور خوانده شود.
  // ignore: unused_element
  ProgramPdfType _getPdfTypeFromString(String type) {
    switch (type) {
      case 'workout':
        return ProgramPdfType.workout;
      case 'meal':
        return ProgramPdfType.meal;
      default:
        return ProgramPdfType.both;
    }
  }

  Future<void> _generateProgram() async {
    setState(() {
      _isLoading = true;
      _lastProgramPdf = null;
      _lastProgramId = null;
      _errorMessage = '';
    });

    try {
      String pdfType = 'both';
      if (_hasExercisePlan && !_hasFoodPlan) {
        pdfType = 'workout';
      } else if (!_hasExercisePlan && _hasFoodPlan) {
        pdfType = 'meal';
      }

      Logger.log('Starting program generation with pdfType: $pdfType');

      final (isPdf, pdfBytes, data) = await AthleteApi.generateProgram(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _gender == 'زن' ? 'F' : 'M',
        height: double.tryParse(_heightController.text.trim()),
        weight: double.tryParse(_weightController.text.trim()),
        injuries: _injuryController.text.trim(),
        foodAllergies: _foodSensitivityController.text.trim(),
        bodyIssues: _bodyIssuesController.text.trim(),
        chronicDiseases: '',
        exerciseHistory: _trainingHistory ?? '',
        extraNotes: _additionalNotesController.text.trim(),
        programDays: _days,
        programType: _hasExercisePlan && _hasFoodPlan
            ? 'both'
            : _hasExercisePlan
            ? 'workout'
            : 'meal',
        pdfType: pdfType,
      );

      if (!mounted) return;

      if (isPdf && pdfBytes != null && pdfBytes.isNotEmpty) {
        Logger.log('PDF received from API: ${pdfBytes.length} bytes');

        setState(() {
          _lastProgramPdf = pdfBytes;
          _lastProgramPdfType = pdfType;
          _isLoading = false;
          _isCompleted = true;
        });

        setState(() {
          _errorMessage = '';
        });
        return;
      }

      if (data.isNotEmpty) {
        Logger.log('JSON response received');

        int? programId;
        if (data['program'] is Map) {
          programId = data['program']['id'];
        } else if (data['id'] != null) {
          programId = data['id'] is int
              ? data['id'] as int
              : int.tryParse(data['id'].toString());
        }

        if (data.containsKey('remaining_tokens')) {
          setState(() => _tokenBalance = data['remaining_tokens'] ?? 0);
        }

        if (programId != null) {
          setState(() {
            _lastProgramId = programId;
            _lastProgramPdfType = pdfType;
          });
        }

        setState(() {
          _isLoading = false;
          _isCompleted = true;
        });
      } else {
        throw Exception('دریافت داده از سرور ناموفق بود');
      }

      await _refreshTokenBalance();
    } catch (e) {
      Logger.log('Program generation error', error: e.toString());
      if (!mounted) return;
      setState(() {
        _isCompleted = false;
        _errorMessage = 'خطا: ${e.toString()}';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: dangerFgColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _logout() async {
    await AthleteApi.logout();
    if (!mounted) return;

    setState(() {
      _isLoggedIn = false;
      _redeemedPdf = null;
      _redeemedPdfName = null;
      _isSavingRedeemedPdf = false;
      _userProfile = null;
      _gymBrand = null;
      _accessCodeController.clear();
      _errorMessage = '';
      _currentPage = 0;
      _isCompleted = false;
      _previousRequests = [];
      _lastProgramId = null;
      _lastProgramPdf = null;
      _tokenBalance = 0;
      _showTokenRequestDialog = false;
      _isLoading = false;
      _isLoadingRequests = false;

      _nameController.clear();
      _ageController.clear();
      _heightController.clear();
      _weightController.clear();
      _injuryController.clear();
      _bodyIssuesController.clear();
      _foodSensitivityController.clear();
      _additionalNotesController.clear();
      _tokenMessageController.clear();
      _trainingHistory = null;
      _days = 3;
      _hasExercisePlan = true;
      _hasFoodPlan = false;
      _gender = 'مرد';
      _tokenRequestAmount = 50;
    });

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ==================== ویجت لوگو ====================
  Widget _buildLogo({double? width}) {
    return Image.asset(
      'assets/logo.webp',
      width: width ?? 200,
      cacheWidth: ((width ?? 200) * 2).round(),
      fit: BoxFit.fill,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showTokenRequestDialog) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              _buildMainWidget(context),
              _buildTokenRequestDialog(),
            ],
          ),
        ),
      );
    }
    return _buildMainWidget(context);
  }

  Widget _buildMainWidget(BuildContext context) {
    final deviceType = _resolveDeviceType(context);

    if (_redeemedPdf != null) {
      return _buildProgramDownloadScreen();
    }

    if (!_isLoggedIn) {
      return _buildLoginScreen();
    }

    if (deviceType == AppDeviceType.desktop) {
      return _buildDesktopLayout();
    } else if (deviceType == AppDeviceType.tablet) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  /// صفحه‌ی «برنامه‌ات آماده است» — پس از وارد کردن کد یکبارمصرف دانلود.
  Widget _buildProgramDownloadScreen() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ برچسب «آماده» به تنهایی (دکمه‌ی تم حذف شد)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: okBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'آماده',
                                style: TextStyle(
                                  color: okFgColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle,
                                color: okFgColor,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Image.asset(
                          'assets/pdf.webp',
                          width: 78,
                          height: 78,
                          cacheWidth: 156,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'برنامه شما آماده است',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'مربی شما این برنامه را از قبل ساخته است. برای ذخیره '
                            'روی دستگاه خودتان، دکمه‌ی زیر را بزنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: textMutedColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                          _isSavingRedeemedPdf ? null : _saveRedeemedPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primeColor,
                            foregroundColor: onPrimaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSavingRedeemedPdf
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Icon(Icons.download_rounded, size: 20),
                          label: const Text(
                            'دانلود برنامه (PDF)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: warnBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 17,
                              color: warnFgColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'کدی که وارد کردید یکبارمصرف بود و دیگر کار '
                                    'نمی‌کند. فایل را نگه دارید.',
                                style: TextStyle(
                                  fontSize: 11.8,
                                  height: 1.6,
                                  fontWeight: FontWeight.w600,
                                  color: warnFgColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _clearRedeemedPdf,
                        child: Text(
                          'وارد کردن کد دیگر',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: textMutedColor,
                          ),
                        ),
                      ),
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

  Widget _buildLoginScreen() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ دکمه‌ی تم حذف شد
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildLogo(width: 150),
                ),
                const SizedBox(height: 8),
                Text(
                  'پنل مشتری',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: logoColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'کد خود را وارد کنید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _accessCodeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    hintText: 'کد ۴ رقمی',
                    hintStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: textfildColor,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dangerBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dangerBorderColor),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: dangerFgColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (_errorMessage.isNotEmpty) const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: textFaintColor,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(onPrimaryColor),
                    ),
                  )
                      : const Text(
                    'ورود',
                    style: TextStyle(
                      color: onPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.popUntil((route) => route.isFirst);
                    } else {
                      navigator.pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthChoicePage(),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'بازگشت',
                    style: TextStyle(
                      fontSize: 15,
                      color: textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 5, right: 20, top: 20, bottom: 20),
              child: SizedBox(width: 280, child: _buildSidebar()),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: _buildMainContent(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 1,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'چغر',
                style: TextStyle(
                  color: logoColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'خروج',
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(
              width: 240,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildSidebar(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: _buildMainContent(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 27),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Text(
            'چغر',
            style: TextStyle(
              color: logoColor,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        drawer: _buildMobileDrawer(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _buildMainContent(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      width: 300,
      child: Container(
        color: surfaceColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // ✅ دکمه‌ی تم حذف شد
                  _buildLogo(width: 130),
                  const SizedBox(height: 10),
                  if (_gymBrand?['gym_name'] != null)
                    Text(
                      _gymBrand!['gym_name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: logoColor,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [infoBgColor, infoBgColor],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: infoFgColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 22,
                              color: primeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'موجودی',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimaryColor,
                              ),
                            ),
                          ),
                          Text(
                            '$_tokenBalance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _refreshTokenBalance,
                            child: _isRefreshing
                                ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primeColor,
                              ),
                            )
                                : Icon(Icons.refresh_rounded,
                                size: 20, color: primeColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: warnBgColor,
                        border: Border.all(color: warnFgColor),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 18, color: warnFgColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'درخواست‌های توکن',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: warnFgColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: warnFgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_previousRequests.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: warnFgColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(
                            height: 14,
                            color: warnFgColor,
                            thickness: 1,
                          ),
                          Expanded(
                            child: _isLoadingRequests
                                ? const Center(
                                child: CircularProgressIndicator())
                                : _previousRequests.isEmpty
                                ? Center(
                              child: Text(
                                'درخواستی ثبت نشده',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: textMutedColor),
                              ),
                            )
                                : ListView.separated(
                              itemCount: _previousRequests.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 8,
                                color: warnFgColor,
                                thickness: 0.6,
                              ),
                              itemBuilder: (context, index) {
                                final req =
                                _previousRequests[index];
                                return Padding(
                                  padding: const EdgeInsets
                                      .symmetric(vertical: 5),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      Text(
                                        '${req.requestedTokens} توکن',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: req.statusColor
                                              .withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                          BorderRadius.circular(
                                              6),
                                        ),
                                        child: Text(
                                          req.statusLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.w600,
                                            color: req.statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _showTokenRequestDialog = true;
                      _tokenRequestAmount = 50;
                    }),
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 22),
                    label: const Text(
                      'درخواست توکن',
                      style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: warnFgColor,
                      foregroundColor: onPrimaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 58),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        size: 22, color: onPrimaryColor),
                    label: const Text(
                      'خروج',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onPrimaryColor,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerFgColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 58),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ دکمه‌ی تم حذف شد
          Center(child: _buildLogo(width: 64)),
          const SizedBox(height: 10),

          if (_gymBrand?['gym_name'] != null) ...[
            Text(
              _gymBrand!['gym_name'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: logoColor,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [infoBgColor, infoBgColor],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: infoFgColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: primeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'موجودی',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor),
                  ),
                ),
                Text(
                  '$_tokenBalance',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primeColor,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _refreshTokenBalance,
                  child: _isRefreshing
                      ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primeColor,
                    ),
                  )
                      : Icon(Icons.refresh_rounded,
                      size: 18, color: primeColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            height: 240,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: warnBgColor,
              border: Border.all(color: warnFgColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 18, color: warnFgColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'درخواست‌های توکن',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: warnFgColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: warnFgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_previousRequests.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: warnFgColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 14,
                  color: warnFgColor,
                  thickness: 1,
                ),
                Expanded(
                  child: _isLoadingRequests
                      ? const Center(child: CircularProgressIndicator())
                      : _previousRequests.isEmpty
                      ? Center(
                    child: Text(
                      'درخواستی ثبت نشده',
                      style: TextStyle(
                          fontSize: 14, color: textMutedColor),
                    ),
                  )
                      : ListView.separated(
                    itemCount: _previousRequests.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 10,
                      color: warnFgColor,
                      thickness: 0.6,
                    ),
                    itemBuilder: (context, index) {
                      final req = _previousRequests[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${req.requestedTokens} توکن',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: req.statusColor
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: Text(
                                req.statusLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: req.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          ElevatedButton.icon(
            onPressed: () => setState(() {
              _showTokenRequestDialog = true;
              _tokenRequestAmount = 50;
            }),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text(
              'درخواست توکن',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: warnFgColor,
              foregroundColor: onPrimaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded,
                size: 20, color: onPrimaryColor),
            label: const Text(
              'خروج',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: onPrimaryColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerFgColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Text(
            'ساخت برنامه جدید',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: logoColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اطلاعات دقیق نتیجه بهتری می‌دهد',
            style: TextStyle(fontSize: 13, color: textPrimaryColor),
          ),
          const SizedBox(height: 32),
          const _LoadingInsideCard(),
          const SizedBox(height: 20),
        ],
      );
    }

    if (_isCompleted) {
      return _buildCompletedView();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),
        Text(
          'ساخت برنامه جدید',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: logoColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اطلاعات دقیق نتیجه بهتری می‌دهد',
          style: TextStyle(fontSize: 13, color: textPrimaryColor),
        ),
        const SizedBox(height: 32),
        _buildFormContainer(),
        const SizedBox(height: 18),
        _buildNavigationButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormContainer() {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: borderStrongColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(child: _buildPageContent()),
    );
  }

  Widget _buildPageContent() {
    switch (_currentPage) {
      case 0:
        return _buildPageOne();
      case 1:
        return _buildPageTwo();
      case 2:
        return _buildPageThree();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pageIndicator() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '${_currentPage + 1}/$_totalPages',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: textMutedColor,
        ),
      ),
    );
  }

  Widget _buildPageOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicator(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _formTextField(
                controller: _nameController,
                hintText: 'اسم',
                hasError: _nameError,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _chipButton(
                text: _gender,
                onTap: () =>
                    setState(() => _gender = _gender == 'مرد' ? 'زن' : 'مرد'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _daysStepper(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _formTextField(
                controller: _weightController,
                hintText: 'وزن',
                keyboardType: TextInputType.number,
                hasError: _weightError,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _formTextField(
                controller: _heightController,
                hintText: 'قد',
                keyboardType: TextInputType.number,
                hasError: _heightError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _checkboxOption(
                label: 'برنامه ورزشی',
                value: _hasExercisePlan,
                hasError: _checkboxError,
                onChanged: (v) => setState(() => _hasExercisePlan = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _checkboxOption(
                label: 'برنامه غذایی',
                value: _hasFoodPlan,
                hasError: _checkboxError,
                onChanged: (v) => setState(() => _hasFoodPlan = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageTwo() {
    const options = ['کم', 'متوسط', 'زیاد'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicator(),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'سابقه تمرینی:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            for (final option in options) ...[
              _trainingOption(
                label: option,
                selected: _trainingHistory == option,
                onTap: () => setState(() {
                  _trainingHistory =
                  _trainingHistory == option ? null : option;
                }),
              ),
              if (option != options.last) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _optionalTextField(
            controller: _injuryController, hintText: 'مصدومیت'),
        const SizedBox(height: 12),
        _optionalTextField(
          controller: _bodyIssuesController,
          hintText: 'ایرادات بدنی',
        ),
      ],
    );
  }

  Widget _buildPageThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicator(),
        const SizedBox(height: 12),
        _optionalTextField(
          controller: _foodSensitivityController,
          hintText: 'حساسیت غذایی',
        ),
        const SizedBox(height: 12),
        _optionalTextField(
          controller: _additionalNotesController,
          hintText: 'توضیحات تکمیلی',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _totalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: (_isLoading || _isCompleted) ? null : _onNextPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primeColor,
            padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            children: [
              if (!isLastPage) ...[
                const Icon(Icons.arrow_back, color: onPrimaryColor, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                isLastPage ? 'تایید' : 'بعدی',
                style: const TextStyle(
                  fontSize: 15,
                  color: onPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLastPage) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, color: onPrimaryColor, size: 18),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Opacity(
          opacity: isFirstPage ? 0.4 : 1,
          child: ElevatedButton(
            onPressed: (isFirstPage || _isCompleted) ? null : _onPrevPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primeColor,
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              children: const [
                Text(
                  'قبلی',
                  style: TextStyle(
                    fontSize: 15,
                    color: onPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: onPrimaryColor, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: okBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 50,
                color: okFgColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'برنامه ساخته شد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primeColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'موجودی: $_tokenBalance توکن',
              style: TextStyle(fontSize: 14, color: textSecondaryColor),
            ),
            const SizedBox(height: 28),
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: dangerBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dangerBorderColor),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: dangerFgColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            if (_lastProgramPdf != null || _lastProgramId != null)
              _ProgramReadyCard(
                days: _days,
                typeLabel: _hasExercisePlan && _hasFoodPlan
                    ? 'کامل'
                    : _hasExercisePlan
                    ? 'ورزشی'
                    : 'غذایی',
                child: _lastProgramPdf != null
                    ? SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await PdfFileHelper.saveAndOpen(
                          _lastProgramPdf!,
                          'program_${DateTime.now().millisecondsSinceEpoch}.pdf',
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطا: $e'),
                            backgroundColor: dangerFgColor,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primeColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'دانلود PDF',
                          style: TextStyle(
                            color: onPrimaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.file_download_outlined,
                            color: onPrimaryColor, size: 20),
                      ],
                    ),
                  ),
                )
                    : PdfBatchDownloadButton(
                  programId: _lastProgramId!,
                  hasExercisePlan: _hasExercisePlan,
                  hasFoodPlan: _hasFoodPlan,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isCompleted = false;
                  _currentPage = 0;
                  _errorMessage = '';
                  _nameController.clear();
                  _ageController.clear();
                  _heightController.clear();
                  _weightController.clear();
                  _injuryController.clear();
                  _bodyIssuesController.clear();
                  _foodSensitivityController.clear();
                  _additionalNotesController.clear();
                  _trainingHistory = null;
                  _days = 3;
                  _lastProgramId = null;
                  _lastProgramPdf = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primeColor,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'برنامه جدید',
                style: TextStyle(
                  fontSize: 15,
                  color: onPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenRequestDialog() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
                        Icons.add_circle,
                        color: primeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'درخواست توکن',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'توکن اضافی درخواست کنید',
                            style: TextStyle(
                              fontSize: 12,
                              color: textMutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          setState(() => _showTokenRequestDialog = false),
                      child: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: infoBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: infoFgColor),
                  ),
                  child: Text(
                    'حداقل: 50 توکن (مضرب 50)',
                    style: TextStyle(
                      fontSize: 12,
                      color: infoFgColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعداد توکن',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _tokenAmountStepper(),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پیام (اختیاری)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _tokenMessageController,
                      maxLines: 3,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: surfaceMutedColor,
                        hintText: 'پیام خود را بنویسید',
                        hintStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _showTokenRequestDialog = false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child:
                        const Text('لغو', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestTokens,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primeColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation(onPrimaryColor),
                          ),
                        )
                            : const Text(
                          'ارسال',
                          style: TextStyle(
                            color: onPrimaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool hasError = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: textfildColor,
        hintText: hintText,
        hintStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hasError
              ? BorderSide(color: dangerFgColor, width: 1.5)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hasError
              ? BorderSide(color: dangerFgColor, width: 1.5)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _optionalTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: textfildColor,
        hintText: hintText,
        hintStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _chipButton({required String text, required VoidCallback onTap}) {
    return Material(
      color: textfildColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              text,
              style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _daysStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: textfildColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'روزهای برنامه:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          IconButton(
            onPressed: () => setState(() => _days = (_days + 1).clamp(1, 7)),
            icon: const Icon(Icons.add),
            iconSize: 20,
          ),
          Text(
            '$_days',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          IconButton(
            onPressed: () => setState(() => _days = (_days - 1).clamp(1, 7)),
            icon: const Icon(Icons.remove),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _tokenAmountStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceMutedColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => _tokenRequestAmount += 50),
            icon: const Icon(Icons.add),
            iconSize: 20,
          ),
          Text(
            '$_tokenRequestAmount',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          IconButton(
            onPressed: _tokenRequestAmount > 50
                ? () => setState(() => _tokenRequestAmount -= 50)
                : null,
            icon: const Icon(Icons.remove),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _checkboxOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: primeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: selected ? primeColor : Colors.transparent,
              border: Border.all(
                color: selected ? primeColor : textFaintColor,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}