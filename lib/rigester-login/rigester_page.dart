import 'package:flutter/foundation.dart';
import 'package:chegher_1/rigester-login/token_manegment.dart'
    hide LoggerService;
import 'package:flutter/material.dart';
import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../dashboard/dashboard.dart';
import '../loging_system/loging_system.dart';

enum AuthMode { login, register, forgotPassword }

const String _logoAsset = 'assets/logo.webp';
const String _sideImageAsset = 'assets/mon.webp';

const List<String> _firstFieldKeys = ['phone_number'];
const List<String> _codeFieldKeys = ['code', 'verification_code'];
const List<String> _secondFieldKeys = [
  'password',
  'new_password',
  'password_confirm',
  'new_password_confirm',
];

const Map<String, String> _fieldLabels = {
  'gym_name': 'نام باشگاه',
  'non_field_errors': '',
  'detail': '',
};

/// طول کد پیامکی (ثبت‌نام و بازیابی رمز).
const int _smsCodeLength = 4;

class _ParsedError {
  const _ParsedError({
    this.firstFieldError,
    this.secondFieldError,
    this.codeFieldError,
    this.generalMessage,
  });

  final String? firstFieldError;
  final String? secondFieldError;
  final String? codeFieldError;
  final String? generalMessage;

  bool get isEmpty =>
      firstFieldError == null &&
          secondFieldError == null &&
          codeFieldError == null &&
          generalMessage == null;
}

String _friendlyStatusMessage(int statusCode) {
  switch (statusCode) {
    case 400:
      return 'اطلاعات ارسالی معتبر نیست';
    case 401:
      return 'شماره موبایل یا رمز عبور اشتباه است';
    case 403:
      return 'اجازه‌ی انجام این عملیات را ندارید';
    case 404:
      return 'سرویس مورد نظر پیدا نشد';
    case 409:
      return 'این شماره موبایل قبلاً ثبت شده است';
    case 422:
      return 'اطلاعات ارسالی معتبر نیست';
    case 429:
      return 'تعداد درخواست‌ها زیاد شده، کمی بعد دوباره امتحان کنید';
    default:
      if (statusCode >= 500) {
        return 'مشکلی در سرور پیش آمده، لطفاً بعداً دوباره تلاش کنید';
      }
      return 'خطا در ارتباط با سرور (کد $statusCode)';
  }
}

class AuthFormData {
  const AuthFormData({required this.firstValue, required this.secondValue});

  final String firstValue;
  final String secondValue;
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.mode,
    this.onSubmit,
    this.onSwitchMode,
  });

  final AuthMode mode;
  final ValueChanged<AuthFormData>? onSubmit;
  final VoidCallback? onSwitchMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _secondController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  /// آیا کد پیامکی ارسال شده و منتظر ورود آن هستیم؟
  ///
  /// در دو حالت ثبت‌نام و بازیابی رمز، فرم دو مرحله‌ای است:
  /// مرحله ۱ فقط شماره موبایل، مرحله ۲ رمز عبور + کد پیامکی.
  final ValueNotifier<bool> _codeSent = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _codeFieldError = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _firstFieldError = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _secondFieldError = ValueNotifier<String?>(null);

  late final ApiService _apiService;
  late final AuthTokenService _authTokenService;

  bool get _isTwoStepMode =>
      widget.mode == AuthMode.register ||
          widget.mode == AuthMode.forgotPassword;

  String get _firstHint => 'شماره موبایل';

  String get _secondHint {
    switch (widget.mode) {
      case AuthMode.login:
        return 'رمزعبور';
      case AuthMode.register:
      case AuthMode.forgotPassword:
        return 'رمز عبور جدید';
    }
  }

  String get _submitText {
    switch (widget.mode) {
      case AuthMode.login:
        return 'تایید';
      case AuthMode.register:
        return _codeSent.value ? 'تایید و ساخت اکانت' : 'ارسال پیامک';
      case AuthMode.forgotPassword:
        return _codeSent.value ? 'تغییر رمز عبور' : 'ارسال کد تایید';
    }
  }

  String get _switchButtonText {
    switch (widget.mode) {
      case AuthMode.login:
        return 'ساخت اکانت جدید';
      case AuthMode.register:
        return 'از قبل حساب داشتم';
      case AuthMode.forgotPassword:
        return 'بازگشت به ورود';
    }
  }

  AuthMode get _switchMode {
    switch (widget.mode) {
      case AuthMode.login:
        return AuthMode.register;
      case AuthMode.register:
        return AuthMode.login;
      case AuthMode.forgotPassword:
        return AuthMode.login;
    }
  }

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authTokenService = AuthTokenService();

    LoggerService.logEvent(
      title: 'AUTH_PAGE_INIT',
      message: 'صفحه احراز - Mode: ${widget.mode.toString().split('.').last}',
    );
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    _codeController.dispose();
    _isSubmitting.dispose();
    _firstFieldError.dispose();
    _secondFieldError.dispose();
    _codeSent.dispose();
    _codeFieldError.dispose();
    super.dispose();
  }

  void _handleSwitchMode() {
    if (widget.onSwitchMode != null) {
      widget.onSwitchMode!();
      return;
    }

    // صفحه‌ی جدید عمداً هیچ کال‌بکی از صفحه‌ی قبلی به ارث نمی‌برد.
    // هر دو حالت ورود و ثبت‌نام در پایان به داشبورد می‌روند، پس این صفحه
    // به هیچ کال‌بک بیرونی نیاز ندارد.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(mode: _switchMode),
      ),
    );
  }

  void _openForgotPassword() {
    LoggerService.logEvent(
      title: 'FORGOT_PASSWORD',
      message: 'صفحه فراموشی رمز عبور باز شد',
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(
          mode: AuthMode.forgotPassword,
          onSwitchMode: () {
            Navigator.of(context).pop();
          },
          onSubmit: (data) {
            Navigator.of(context).pop();
            _showMessage('رمز عبور با موفقیت تغییر کرد، دوباره وارد شوید');
          },
        ),
      ),
    );
  }

  /// اعتبارسنجی شماره موبایل: فقط رقم و دقیقاً ۱۱ رقم (مثل 09123456789).
  bool _isValidPhone(String phone) {
    if (phone.length != 11) return false;
    return RegExp(r'^\d{11}$').hasMatch(phone);
  }

  Future<void> _submit() async {
    if (_isSubmitting.value) return;

    final phone = _firstController.text.trim();
    final password = _secondController.text.trim();
    final code = _codeController.text.trim();

    LoggerService.logAuth(
      action: 'SUBMIT_START',
      message: '$phone - ${widget.mode.toString().split('.').last}',
    );

    _isSubmitting.value = true;
    _firstFieldError.value = null;
    _secondFieldError.value = null;
    _codeFieldError.value = null;

    try {
      switch (widget.mode) {
        case AuthMode.login:
          await _submitLogin(phone, password);
          return;
        case AuthMode.register:
          if (_codeSent.value) {
            await _submitRegister(phone, password, code);
          } else {
            await _requestRegisterCode(phone);
          }
          return;
        case AuthMode.forgotPassword:
          if (_codeSent.value) {
            await _confirmPasswordReset(phone, password, code);
          } else {
            await _requestPasswordResetCode(phone);
          }
          return;
      }
    } catch (e) {
      LoggerService.logApiError(
        method: '_submit',
        url: widget.mode.toString(),
        error: e.toString(),
      );
      if (!mounted) return;
      _showMessage(
        'اتصال به سرور برقرار نشد، اینترنت خود را بررسی کنید',
        isError: true,
      );
    } finally {
      if (mounted) {
        _isSubmitting.value = false;
      }
    }
  }

  // ==========================================================================
  //  ورود
  // ==========================================================================

  Future<void> _submitLogin(String phone, String password) async {
    final response = await _apiService.post(
      endpoint: ServerEndpoints.authLogin,
      body: {'phone_number': phone, 'password': password},
      requiresAuth: false,
    );

    if (!mounted) return;

    if (!response.success) {
      _applyServerErrors(response);
      LoggerService.logAuth(
        action: 'LOGIN_FAILED',
        message: 'خطا (${response.statusCode}): ${response.error}',
        isSuccess: false,
      );
      return;
    }

    final token = response.data?['token'] ?? response.data?['auth_token'];

    if (token == null) {
      LoggerService.logApiError(
        method: '_submitLogin',
        url: ServerEndpoints.authLogin,
        error: 'توکن در پاسخ موجود نیست',
      );
      _showMessage(
        'خطایی در سرور رخ داد، لطفاً دوباره تلاش کنید',
        isError: true,
      );
      return;
    }

    await _authTokenService.saveToken(token: token, phone: phone);

    LoggerService.logAuth(
      action: 'LOGIN_SUCCESS',
      message: 'احراز موفق: $phone',
    );

    // کال‌بک بیرونی در try/catch جداگانه تا خطایش به «قطع ارتباط» ترجمه نشود.
    try {
      widget.onSubmit?.call(
        AuthFormData(firstValue: phone, secondValue: password),
      );
    } catch (callbackError) {
      LoggerService.logApiError(
        method: '_submitLogin/onSubmit',
        url: ServerEndpoints.authLogin,
        error: callbackError.toString(),
      );
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    }
  }

  // ==========================================================================
  //  ثبت‌نام — مرحله ۱: درخواست کد پیامکی
  // ==========================================================================

  Future<void> _requestRegisterCode(String phone) async {
    if (!_isValidPhone(phone)) {
      _firstFieldError.value =
      'شماره موبایل باید ۱۱ رقمی و فقط شامل عدد باشد';
      return;
    }

    final response = await _apiService.post(
      endpoint: ServerEndpoints.authSendRegisterCode,
      body: {'phone_number': phone},
      requiresAuth: false,
    );

    if (!mounted) return;

    if (response.success) {
      _codeSent.value = true;
      _showMessage('کد تایید پیامک شد، آن را وارد کنید.');
    } else {
      _applyServerErrors(response);
    }
  }

  // ==========================================================================
  //  ثبت‌نام — مرحله ۲: ارسال اطلاعات + کد
  // ==========================================================================

  Future<void> _submitRegister(
      String phone,
      String password,
      String code,
      ) async {
    if (password.isEmpty) {
      _secondFieldError.value = 'رمز عبور را وارد کنید';
      return;
    }

    if (code.isEmpty) {
      _codeFieldError.value = 'کد تایید را وارد کنید';
      return;
    }

    if (code.length != _smsCodeLength) {
      _codeFieldError.value = 'کد تایید باید $_smsCodeLength رقم باشد';
      return;
    }

    final response = await _apiService.post(
      endpoint: ServerEndpoints.authRegister,
      body: {
        'phone_number': phone,
        'password': password,
        'password_confirm': password,
        'gym_name': 'باشگاه من',
        'verification_code': code,
      },
      requiresAuth: false,
    );

    if (!mounted) return;

    if (!response.success) {
      _applyServerErrors(response);
      return;
    }

    final token = response.data?['token'] ?? response.data?['auth_token'];

    if (token == null) {
      LoggerService.logApiError(
        method: '_submitRegister',
        url: ServerEndpoints.authRegister,
        error: 'توکن در پاسخ موجود نیست',
      );
      _showMessage(
        'خطایی در سرور رخ داد، لطفاً دوباره تلاش کنید',
        isError: true,
      );
      return;
    }

    await _authTokenService.saveToken(token: token, phone: phone);

    LoggerService.logAuth(
      action: 'REGISTER_SUCCESS',
      message: 'ثبت‌نام موفق: $phone',
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    }
  }

  // ==========================================================================
  //  بازیابی رمز — مرحله ۱: درخواست کد
  // ==========================================================================

  Future<void> _requestPasswordResetCode(String phone) async {
    if (!_isValidPhone(phone)) {
      _firstFieldError.value =
      'شماره موبایل باید ۱۱ رقمی و فقط شامل عدد باشد';
      return;
    }

    final response = await _apiService.post(
      endpoint: ServerEndpoints.authPasswordReset,
      body: {'phone_number': phone},
      requiresAuth: false,
    );

    if (!mounted) return;

    if (response.success) {
      _codeSent.value = true;
      _showMessage(
        'اگر این شماره ثبت شده باشد، کد تایید پیامک می‌شود. '
            'کد را همراه رمز جدید وارد کنید.',
      );
    } else {
      _applyServerErrors(response);
    }
  }

  // ==========================================================================
  //  بازیابی رمز — مرحله ۲: تایید کد + رمز جدید
  // ==========================================================================

  Future<void> _confirmPasswordReset(
      String phone,
      String password,
      String code,
      ) async {
    if (password.isEmpty) {
      _secondFieldError.value = 'رمز عبور جدید را وارد کنید';
      return;
    }

    if (code.isEmpty) {
      _codeFieldError.value = 'کد تایید را وارد کنید';
      return;
    }

    if (code.length != _smsCodeLength) {
      _codeFieldError.value = 'کد تایید باید $_smsCodeLength رقم باشد';
      return;
    }

    final response = await _apiService.post(
      endpoint: ServerEndpoints.authPasswordResetConfirm,
      body: {
        'phone_number': phone,
        'code': code,
        'new_password': password,
        'new_password_confirm': password,
      },
      requiresAuth: false,
    );

    if (!mounted) return;

    if (!response.success) {
      _applyServerErrors(response);
      return;
    }

    LoggerService.logAuth(
      action: 'PASSWORD_RESET',
      message: 'رمز عبور برای $phone تغییر کرد',
    );

    try {
      widget.onSubmit?.call(
        AuthFormData(firstValue: phone, secondValue: password),
      );
    } catch (callbackError) {
      LoggerService.logApiError(
        method: '_confirmPasswordReset/onSubmit',
        url: ServerEndpoints.authPasswordResetConfirm,
        error: callbackError.toString(),
      );
    }

    if (mounted && widget.onSubmit == null) {
      _showMessage('رمز عبور تغییر کرد. اکنون با رمز جدید وارد شوید.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AuthPage(mode: AuthMode.login),
        ),
      );
    }
  }

  // ==========================================================================
  //  خطاها
  // ==========================================================================

  /// خطاهای اعتبارسنجی سرور را روی فیلد مربوطه می‌نشاند.
  void _applyServerErrors(ApiResponse response) {
    final parsed = _parseError(response);
    _firstFieldError.value = parsed.firstFieldError;
    _secondFieldError.value = parsed.secondFieldError;
    _codeFieldError.value = parsed.codeFieldError;

    if (parsed.generalMessage != null) {
      _showMessage(parsed.generalMessage!, isError: true);
    } else if (parsed.isEmpty) {
      _showMessage(
        response.error ?? _friendlyStatusMessage(response.statusCode),
        isError: true,
      );
    }
  }

  _ParsedError _parseError(ApiResponse response) {
    try {
      final decoded = response.data;
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        return const _ParsedError();
      }

      String? firstError;
      String? secondError;
      String? codeError;
      final generalMessages = <String>[];

      String flatten(dynamic value) {
        if (value is List) return value.map((e) => e.toString()).join('\n');
        return value.toString();
      }

      decoded.forEach((key, value) {
        final message = flatten(value);
        if (message.isEmpty) return;

        if (_firstFieldKeys.contains(key)) {
          firstError = firstError == null ? message : '$firstError\n$message';
        } else if (_codeFieldKeys.contains(key)) {
          codeError = codeError == null ? message : '$codeError\n$message';
        } else if (_secondFieldKeys.contains(key)) {
          secondError = secondError == null
              ? message
              : '$secondError\n$message';
        } else {
          final label = _fieldLabels[key];
          generalMessages.add(
            (label != null && label.isNotEmpty) ? '$label: $message' : message,
          );
        }
      });

      return _ParsedError(
        firstFieldError: firstError,
        secondFieldError: secondError,
        codeFieldError: codeError,
        generalMessage: generalMessages.isEmpty
            ? null
            : generalMessages.join('\n'),
      );
    } catch (_) {
      return const _ParsedError();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? dangerFgColor : null,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              if (isError) ...[
                const Icon(Icons.error_outline,
                    color: onPrimaryColor, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          cursorColor: primeColor,
          selectionColor: primeColor,
          selectionHandleColor: primeColor,
        ),
        child: Scaffold(
          backgroundColor: surfaceColor,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = _AuthLayoutMetrics.fromWidth(
                  constraints.maxWidth,
                );

                // کل چیدمان داخل ValueListenableBuilder است تا وقتی
                // مرحله‌ی دوم فعال/غیرفعال می‌شود، فیلدها و دکمه هم‌زمان
                // به‌روز شوند.
                return ValueListenableBuilder<bool>(
                  valueListenable: _codeSent,
                  builder: (context, codeSent, _) {
                    final isTwoStep = _isTwoStepMode;
                    final showSecondStage = !isTwoStep || codeSent;

                    final fields = _AuthFields(
                      metrics: metrics,
                      firstHint: _firstHint,
                      secondHint: _secondHint,
                      helperText: _helperForState(codeSent),
                      onHelperTap: widget.mode == AuthMode.login
                          ? _openForgotPassword
                          : null,
                      firstController: _firstController,
                      secondController: _secondController,
                      firstFieldError: _firstFieldError,
                      secondFieldError: _secondFieldError,
                      codeController:
                      isTwoStep ? _codeController : null,
                      codeFieldError:
                      isTwoStep ? _codeFieldError : null,
                      showSecondStage: showSecondStage,
                    );

                    final button = ValueListenableBuilder<bool>(
                      valueListenable: _isSubmitting,
                      builder: (context, isSubmitting, _) =>
                          _AuthSubmitButton(
                            metrics: metrics,
                            submitText: _submitText,
                            switchText: _switchButtonText,
                            isLoading: isSubmitting,
                            onSubmit: _submit,
                            onSwitch: _handleSwitchMode,
                          ),
                    );

                    if (metrics.deviceType == _AuthDeviceType.desktop) {
                      return Row(
                        textDirection: TextDirection.ltr,
                        children: [
                          Expanded(
                            child: Center(
                              child: _DesktopAuthForm(
                                metrics: metrics,
                                fields: fields,
                                button: button,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth * 0.42,
                            height: double.infinity,
                            child: Image.asset(
                              _sideImageAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                            ),
                          ),
                        ],
                      );
                    }

                    if (metrics.deviceType == _AuthDeviceType.tablet) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: metrics.pageHorizontalPadding,
                            vertical: 44,
                          ),
                          child: _DesktopAuthForm(
                            metrics: metrics,
                            fields: fields,
                            button: button,
                          ),
                        ),
                      );
                    }

                    return _MobileAuthLayout(
                      metrics: metrics,
                      fields: fields,
                      button: button,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// متن راهنمای زیر فیلدها؛ در حالت ثبت‌نام فقط وقتی رمز عبور ظاهر شده
  /// معنا دارد، پس تا قبل از ارسال کد نمایش داده نمی‌شود.
  String? _helperForState(bool codeSent) {
    switch (widget.mode) {
      case AuthMode.login:
        return 'فراموشی رمز عبور';
      case AuthMode.register:
        return codeSent
            ? 'یک رمز عبور 8 رقمی جدید برای خود انتخاب کنید'
            : null;
      case AuthMode.forgotPassword:
        return null;
    }
  }
}

// ============================================================================
// کلاس‌های کمکی
// ============================================================================

class _DesktopAuthForm extends StatelessWidget {
  const _DesktopAuthForm({
    required this.metrics,
    required this.fields,
    required this.button,
  });

  final _AuthLayoutMetrics metrics;
  final Widget fields;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: metrics.formWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _logoAsset,
            width: metrics.logoWidth,
            cacheWidth: (metrics.logoWidth * 2).round(),
            fit: BoxFit.contain,
          ),
          SizedBox(height: metrics.logoBottomSpace),
          fields,
          SizedBox(height: metrics.buttonTopSpace),
          button,
        ],
      ),
    );
  }
}

class _MobileAuthLayout extends StatelessWidget {
  const _MobileAuthLayout({
    required this.metrics,
    required this.fields,
    required this.button,
  });

  final _AuthLayoutMetrics metrics;
  final Widget fields;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.pageHorizontalPadding),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 28,
            child: Image.asset(
              _logoAsset,
              width: metrics.logoWidth,
              cacheWidth: (metrics.logoWidth * 2).round(),
              fit: BoxFit.contain,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.formWidth),
              child: fields,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.formWidth),
                child: button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFields extends StatelessWidget {
  const _AuthFields({
    required this.metrics,
    required this.firstHint,
    required this.secondHint,
    required this.helperText,
    required this.firstController,
    required this.secondController,
    required this.firstFieldError,
    required this.secondFieldError,
    required this.showSecondStage,
    this.onHelperTap,
    this.codeController,
    this.codeFieldError,
  });

  final _AuthLayoutMetrics metrics;
  final String firstHint;
  final String secondHint;
  final String? helperText;
  final TextEditingController firstController;
  final TextEditingController secondController;
  final ValueNotifier<String?> firstFieldError;
  final ValueNotifier<String?> secondFieldError;

  /// آیا فیلدهای مرحله‌ی دوم (رمز عبور + کد پیامکی) نمایش داده شوند؟
  ///
  /// در حالت ورود، همیشه `true` است (فقط رمز عبور، بدون کد).
  /// در حالت‌های ثبت‌نام و بازیابی رمز، فقط پس از ارسال موفق کد `true`
  /// می‌شود.
  final bool showSecondStage;

  final VoidCallback? onHelperTap;

  /// فیلد کد پیامکی فقط در حالت‌های دو مرحله‌ای مقدار دارد.
  final TextEditingController? codeController;
  final ValueNotifier<String?>? codeFieldError;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: firstFieldError,
          builder: (context, errorText, _) => _AuthTextField(
            controller: firstController,
            hintText: firstHint,
            metrics: metrics,
            keyboardType: TextInputType.phone,
            errorText: errorText,
            onChanged: (_) => firstFieldError.value = null,
          ),
        ),
        if (showSecondStage) ...[
          SizedBox(height: metrics.fieldGap),
          ValueListenableBuilder<String?>(
            valueListenable: secondFieldError,
            builder: (context, errorText, _) => _AuthTextField(
              controller: secondController,
              hintText: secondHint,
              metrics: metrics,
              isPassword: true,
              errorText: errorText,
              onChanged: (_) => secondFieldError.value = null,
            ),
          ),
          if (codeController != null && codeFieldError != null) ...[
            SizedBox(height: metrics.fieldGap),
            ValueListenableBuilder<String?>(
              valueListenable: codeFieldError!,
              builder: (context, errorText, _) => _AuthTextField(
                controller: codeController!,
                hintText: 'کد تایید $_smsCodeLength رقمی',
                metrics: metrics,
                keyboardType: TextInputType.number,
                maxLength: _smsCodeLength,
                errorText: errorText,
                onChanged: (_) => codeFieldError!.value = null,
              ),
            ),
          ],
        ],
        if (helperText != null) ...[
          SizedBox(height: metrics.helperTopSpace),
          GestureDetector(
            onTap: onHelperTap,
            child: Text(
              helperText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: metrics.helperFontSize,
                decoration: TextDecoration.underline,
                decorationColor: textPrimaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthSubmitButton extends StatelessWidget {
  const _AuthSubmitButton({
    required this.metrics,
    required this.submitText,
    required this.switchText,
    required this.onSubmit,
    required this.onSwitch,
    this.isLoading = false,
  });

  final _AuthLayoutMetrics metrics;
  final String submitText;
  final String switchText;
  final VoidCallback onSubmit;
  final VoidCallback onSwitch;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: metrics.buttonHeight,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primeColor,
              foregroundColor: onPrimaryColor,
              disabledBackgroundColor: primeColor.withOpacity(0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(metrics.borderRadius),
              ),
            ),
            child: isLoading
                ? SizedBox(
              width: metrics.buttonFontSize,
              height: metrics.buttonFontSize,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: onPrimaryColor,
              ),
            )
                : Text(
              submitText,
              style: TextStyle(
                fontSize: metrics.buttonFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: metrics.buttonHeight * 0.8,
          child: TextButton(
            onPressed: isLoading ? null : onSwitch,
            style: TextButton.styleFrom(
              foregroundColor: primeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(metrics.borderRadius),
              ),
            ),
            child: Text(
              switchText,
              style: TextStyle(
                fontSize: metrics.buttonFontSize * 0.85,
                fontWeight: FontWeight.w500,
                color: primeColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.metrics,
    this.isPassword = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final _AuthLayoutMetrics metrics;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.fieldHeight),
      child: TextField(
        controller: controller,
        cursorColor: primeColor,
        textAlign: TextAlign.right,
        textAlignVertical: TextAlignVertical.center,
        textDirection: TextDirection.rtl,
        obscureText: isPassword,
        enableSuggestions: !isPassword,
        autocorrect: !isPassword,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        style: TextStyle(
          color: textPrimaryColor,
          fontSize: metrics.fieldFontSize,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: textfildColor,
          hintText: hintText,
          errorText: errorText,
          errorMaxLines: 3,
          counterText: '',
          isDense: false,
          hintStyle: TextStyle(
            color: textFaintColor,
            fontSize: metrics.fieldFontSize,
            fontWeight: FontWeight.w400,
          ),
          errorStyle: TextStyle(
            color: dangerFgColor,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: metrics.fieldHorizontalPadding,
            vertical: metrics.fieldVerticalPadding,
          ),
          border: _inputBorder(metrics.borderRadius),
          enabledBorder: _inputBorder(metrics.borderRadius),
          focusedBorder: _inputBorder(metrics.borderRadius),
          errorBorder: _inputBorder(
            metrics.borderRadius,
            color: dangerFgColor,
          ),
          focusedErrorBorder: _inputBorder(
            metrics.borderRadius,
            color: dangerFgColor,
            width: 1.6,
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder(
      double radius, {
        Color? color,
        double width = 1.2,
      }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }
}

enum _AuthDeviceType { mobile, tablet, desktop }

class _AuthLayoutMetrics {
  const _AuthLayoutMetrics({
    required this.deviceType,
    required this.formWidth,
    required this.logoWidth,
    required this.logoBottomSpace,
    required this.fieldHeight,
    required this.fieldGap,
    required this.fieldFontSize,
    required this.fieldHorizontalPadding,
    required this.fieldVerticalPadding,
    required this.helperTopSpace,
    required this.helperFontSize,
    required this.buttonTopSpace,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.borderRadius,
    required this.pageHorizontalPadding,
  });

  final _AuthDeviceType deviceType;
  final double formWidth;
  final double logoWidth;
  final double logoBottomSpace;
  final double fieldHeight;
  final double fieldGap;
  final double fieldFontSize;
  final double fieldHorizontalPadding;
  final double fieldVerticalPadding;
  final double helperTopSpace;
  final double helperFontSize;
  final double buttonTopSpace;
  final double buttonHeight;
  final double buttonFontSize;
  final double borderRadius;
  final double pageHorizontalPadding;

  factory _AuthLayoutMetrics.fromWidth(double width) {
    if (width >= 1100) {
      return const _AuthLayoutMetrics(
        deviceType: _AuthDeviceType.desktop,
        formWidth: 400,
        logoWidth: 213,
        logoBottomSpace: 0,
        fieldHeight: 57,
        fieldGap: 19,
        fieldFontSize: 16,
        fieldHorizontalPadding: 16,
        fieldVerticalPadding: 13,
        helperTopSpace: 12,
        helperFontSize: 13,
        buttonTopSpace: 31,
        buttonHeight: 43,
        buttonFontSize: 16,
        borderRadius: 11,
        pageHorizontalPadding: 48,
      );
    }

    if (width >= 600) {
      final formWidth = (width * 0.62).clamp(500.0, 620.0);

      return _AuthLayoutMetrics(
        deviceType: _AuthDeviceType.tablet,
        formWidth: formWidth,
        logoWidth: (width * 0.28).clamp(230.0, 300.0),
        logoBottomSpace: 14,
        fieldHeight: (width * 0.075).clamp(64.0, 76.0),
        fieldGap: (width * 0.024).clamp(18.0, 24.0),
        fieldFontSize: (width * 0.022).clamp(18.0, 22.0),
        fieldHorizontalPadding: 22,
        fieldVerticalPadding: 18,
        helperTopSpace: 14,
        helperFontSize: (width * 0.019).clamp(16.0, 19.0),
        buttonTopSpace: (width * 0.042).clamp(30.0, 42.0),
        buttonHeight: (width * 0.063).clamp(54.0, 64.0),
        buttonFontSize: (width * 0.021).clamp(18.0, 22.0),
        borderRadius: 14,
        pageHorizontalPadding: (width * 0.07).clamp(40.0, 72.0),
      );
    }

    final formWidth = (width - 48).clamp(280.0, 360.0);

    return _AuthLayoutMetrics(
      deviceType: _AuthDeviceType.mobile,
      formWidth: formWidth,
      logoWidth: (width * 0.52).clamp(168.0, 220.0),
      logoBottomSpace: 16,
      fieldHeight: 56,
      fieldGap: 16,
      fieldFontSize: 16,
      fieldHorizontalPadding: 16,
      fieldVerticalPadding: 14,
      helperTopSpace: 12,
      helperFontSize: 15,
      buttonTopSpace: 0,
      buttonHeight: 50,
      buttonFontSize: 18,
      borderRadius: 12,
      pageHorizontalPadding: 24,
    );
  }
}