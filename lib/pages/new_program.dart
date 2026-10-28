import 'package:flutter/material.dart';

import '../colors.dart';
import '../core/network/api_config.dart';
import '../core/network/server_endpoints.dart';
import '../core/platform/pdf_saver.dart';
import '../responsive.dart';
import '../rigester-login/token_manegment.dart';

String _formatToday() {
  final now = DateTime.now();
  return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
}

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

AppDeviceType _resolveDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppBreakpoints.mobile) return AppDeviceType.mobile;
  if (width < AppBreakpoints.tablet) return AppDeviceType.tablet;
  return AppDeviceType.desktop;
}

/// مسیر PDF بر اساس بخش درخواستی — تنها منبع آدرس‌ها `ServerEndpoints` است.
String _getPdfPath(int programId, String kind) {
  switch (kind) {
    case 'both':
      return ServerEndpoints.programPdf(programId);
    case 'meal':
      return ServerEndpoints.programPdfMeal(programId);
    case 'workout':
    default:
      return ServerEndpoints.programPdfWorkout(programId);
  }
}

class NewProgram extends StatefulWidget {
  const NewProgram({super.key});

  @override
  State<NewProgram> createState() => _NewProgramState();
}

class _NewProgramState extends State<NewProgram>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  final TextEditingController _injuryController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _bodyIssuesController = TextEditingController();
  String? _trainingHistory;

  final TextEditingController _foodSensitivityController =
  TextEditingController();
  final TextEditingController _additionalNotesController =
  TextEditingController();

  String _gender = 'مرد';
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

  bool _isSubmitting = false;
  String? _submitErrorMessage;
  int? _programId;
  String _programType = 'both';
  String _customerName = '';

  // عمداً اینجا repeat() صدا زده نمی‌شود. این صفحه، صفحه پیش‌فرض داشبورد است
  // و تا پایان نشست زنده می‌ماند؛ یک تیکر همیشه‌درحال‌چرخش یعنی رندر پیوسته
  // ۶۰ فریم بر ثانیه و مصرف دائمی CPU/GPU، حتی وقتی اسپینر اصلاً دیده نمی‌شود.
  // چرخش فقط در بازه‌ی ساخت برنامه روشن می‌شود (_setSubmitting).
  late final AnimationController _loadingController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  /// وضعیت ارسال را تغییر می‌دهد و انیمیشن لودینگ را دقیقاً هم‌زمان با آن
  /// روشن/خاموش می‌کند تا هیچ تیکری بیرون از زمان نمایش اسپینر نچرخد.
  void _setSubmitting(bool value) {
    if (value) {
      if (!_loadingController.isAnimating) _loadingController.repeat();
    } else {
      _loadingController.stop();
    }
    _isSubmitting = value;
  }

  final AuthTokenService _authTokenService = AuthTokenService();
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _injuryController.dispose();
    _ageController.dispose();
    _bodyIssuesController.dispose();
    _foodSensitivityController.dispose();
    _additionalNotesController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _toggleGender() {
    setState(() {
      _gender = _gender == 'مرد' ? 'زن' : 'مرد';
    });
  }

  void _changeDays(int delta) {
    setState(() {
      _days = (_days + delta).clamp(1, 6);
    });
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
    if (_currentPage == 0) {
      if (!_validatePageOne()) return;
    }

    if (_currentPage == _totalPages - 1) {
      if (_isSubmitting) return;
      _submitProgram();
      return;
    }

    setState(() => _currentPage++);
  }

  void _onPrevPressed() {
    if (_currentPage == 0) return;
    setState(() => _currentPage--);
  }

  void _resetForm() {
    setState(() {
      _currentPage = 0;
      _isCompleted = false;
      _programId = null;
      _programType = 'both';
      _customerName = '';
      _nameController.clear();
      _weightController.clear();
      _heightController.clear();
      _injuryController.clear();
      _ageController.clear();
      _bodyIssuesController.clear();
      _foodSensitivityController.clear();
      _additionalNotesController.clear();
      _trainingHistory = null;
      _gender = 'مرد';
      _days = 3;
      _hasExercisePlan = true;
      _hasFoodPlan = false;
    });
  }

  Future<void> _submitProgram() async {
    setState(() {
      _setSubmitting(true);
      _submitErrorMessage = null;
    });

    try {
      final isLoggedIn = await _authTokenService.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('ابتدا وارد حساب کاربری خود شوید.');
      }

      String programType;
      if (_hasExercisePlan && _hasFoodPlan) {
        programType = 'both';
      } else if (_hasExercisePlan) {
        programType = 'workout';
      } else {
        programType = 'meal';
      }

      final extraNotesParts = <String>[];
      if (_bodyIssuesController.text.trim().isNotEmpty) {
        extraNotesParts
            .add('ایرادات بدنی: ${_bodyIssuesController.text.trim()}');
      }
      if (_foodSensitivityController.text.trim().isNotEmpty) {
        extraNotesParts
            .add('حساسیت غذایی: ${_foodSensitivityController.text.trim()}');
      }
      if (_additionalNotesController.text.trim().isNotEmpty) {
        extraNotesParts
            .add('توضیحات تکمیلی: ${_additionalNotesController.text.trim()}');
      }

      final ageText = _ageController.text.trim();

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'gender': _gender == 'مرد' ? 'M' : 'F',
        'age': ageText.isNotEmpty ? int.tryParse(ageText) : null,
        'height': double.parse(_heightController.text.trim()),
        'weight': double.parse(_weightController.text.trim()),
        'program_days': _days,
        'exercise_history': _trainingHistory ?? '',
        'injuries': _injuryController.text.trim(),
        'extra_notes': extraNotesParts.join(' | '),
        'program_type': programType,
        'training_place': 'gym_equipment',
      };

      // ساخت برنامه ممکن است چند ده ثانیه طول بکشد (تولید با هوش مصنوعی)،
      // پس از تایم‌اوت بلند استفاده می‌شود.
      final response = await _apiService.post(
        endpoint: ServerEndpoints.programsGenerate,
        body: payload,
        requiresAuth: true,
        timeout: ApiConfig.programGenerationTimeout,
      );

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 401) {
        await _authTokenService.clearToken();
        throw Exception('نشست شما منقضی شده است. لطفاً دوباره وارد شوید.');
      }

      if (response.statusCode == 402) {
        throw Exception(
          'توکن کافی نیست. لازم: ${data['required_tokens']} | موجودی: ${data['current_balance']}',
        );
      }

      if (!response.success) {
        throw Exception(response.error ?? 'ساخت برنامه ناموفق بود.');
      }

      final program = data['program'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _programId = program['id'] as int;
        _programType = programType;
        _customerName = _nameController.text.trim();
        _setSubmitting(false);
        _isCompleted = true;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _setSubmitting(false);
        _submitErrorMessage = message;
      });
      context.showSafeSnackBar('خطا در ساخت برنامه: $message',
          color: Colors.red, seconds: 4);
    }
  }

  List<_ResultCardSpec> _resultCardSpecs() {
    final id = _programId;
    if (id == null) return const [];

    late String title;
    if (_programType == 'both') {
      title = 'برنامه ورزشی و غذایی';
    } else if (_programType == 'workout') {
      title = 'برنامه ورزشی';
    } else {
      title = 'برنامه غذایی';
    }

    return [
      _ResultCardSpec(
        title: title,
        pdfKind: _programType,
        programId: id,
        userName: _customerName,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = _resolveDeviceType(context);

    if (deviceType == AppDeviceType.desktop) {
      return _buildDesktop();
    }

    final sizes = _ResponsiveSizes.of(deviceType);
    if (deviceType == AppDeviceType.mobile) {
      return _buildMobileLayout(sizes);
    }
    return _buildTabletLayout(sizes);
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '${_currentPage + 1}/$_totalPages',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: textMutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPageOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicator(),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _FormTextField(
                controller: _nameController,
                hintText: 'اسم',
                hasError: _nameError,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChipButton(text: _gender, onTap: _toggleGender),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _DaysStepper(days: _days, onChange: _changeDays),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FormTextField(
                controller: _weightController,
                hintText: 'وزن',
                keyboardType: TextInputType.number,
                hasError: _weightError,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FormTextField(
                controller: _heightController,
                hintText: 'قد',
                keyboardType: TextInputType.number,
                hasError: _heightError,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _CheckboxOption(
                label: 'برنامه ورزشی',
                value: _hasExercisePlan,
                hasError: _checkboxError,
                onChanged: (value) => setState(() => _hasExercisePlan = value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CheckboxOption(
                label: 'برنامه غذایی',
                value: _hasFoodPlan,
                hasError: _checkboxError,
                onChanged: (value) => setState(() => _hasFoodPlan = value),
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
        Row(
          children: [
            const Text(
              'سابقه تمرینی:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const Spacer(),
            for (final option in options) ...[
              _TrainingOption(
                label: option,
                selected: _trainingHistory == option,
                onTap: () => setState(() {
                  _trainingHistory =
                  _trainingHistory == option ? null : option;
                }),
              ),
              if (option != options.last) const SizedBox(width: 14),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _OptionalTextField(
                controller: _injuryController,
                hintText: 'مصدومیت',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OptionalTextField(
                controller: _ageController,
                hintText: 'سن',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _OptionalTextField(
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
        _OptionalTextField(
          controller: _foodSensitivityController,
          hintText: 'حساسیت غذایی',
        ),
        const SizedBox(height: 12),
        _OptionalTextField(
          controller: _additionalNotesController,
          hintText: 'توضیحات تکمیلی',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildLoadingContent({
    double titleFontSize = 20,
    double subtitleFontSize = 14,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _loadingController,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  primeColor.withValues(alpha: 0.08),
                  primeColor,
                  primeColor.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surfaceColor,
                ),
                child: Icon(Icons.fitness_center, color: primeColor, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'در حال ساخت برنامه اختصاصی شما...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
            color: logoColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'هوش مصنوعی در حال طراحی برنامه بر اساس اطلاعات شماست، کمی صبر کنید.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: subtitleFontSize,
            color: textMutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    final specs = _resultCardSpecs();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: okBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: okFgColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'برنامه با موفقیت ساخته شد',
                  style: TextStyle(
                    color: okFgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _CompletedResultsRow(
            cards: specs,
            cardWidth: 300,
            stacked: false,
            spacing: 28,
          ),
          const SizedBox(height: 36),
          Material(
            color: primeColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _resetForm,
              child: Container(
                height: 48,
                width: 200,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, color: onPrimaryColor, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'برنامه جدید',
                      style: TextStyle(
                        fontSize: 18,
                        color: onPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _totalPages - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isCompleted
            ? LayoutBuilder(
          builder: (context, constraints) {
            // برای اینکه ارتفاع صفحه دقیقاً مثل قبل (پر کردن کل فضای
            // موجود) بماند، حداقل ارتفاع محتوا را برابر ارتفاع در
            // دسترس می‌گذاریم؛ اگر پنل ویرایش باعث بلندتر شدن محتوا شد،
            // به‌جای بریدن، اسکرول فعال می‌شود.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildCompletedView(),
              ),
            );
          },
        )
            : Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                Text(
                  'ساخت برنامه جدید',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: logoColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'توضیحات دقیق تر و کامل تر باعث خروجی بهتر میشود!',
                  style: TextStyle(fontSize: 20, color: textPrimaryColor),
                ),
                const SizedBox(height: 95),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Container(
                    width: 650,
                    height: 300,
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderStrongColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: _isSubmitting
                          ? _buildLoadingContent()
                          : _buildPageContent(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: primeColor,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _isSubmitting ? null : _onNextPressed,
                        child: Container(
                          height: 45,
                          width: 130,
                          alignment: Alignment.center,
                          child: (isLastPage && _isSubmitting)
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onPrimaryColor,
                            ),
                          )
                              : Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              if (!isLastPage) ...[
                                const Icon(Icons.arrow_back,
                                    color: onPrimaryColor, size: 26),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                isLastPage ? 'تایید' : 'بعدی',
                                style: const TextStyle(
                                    fontSize: 22,
                                    color: onPrimaryColor),
                              ),
                              if (isLastPage) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check,
                                    color: onPrimaryColor, size: 26),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Opacity(
                      opacity: isFirstPage ? 0.4 : 1,
                      child: Material(
                        color: primeColor,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: (isFirstPage || _isSubmitting)
                              ? null
                              : _onPrevPressed,
                          child: Container(
                            height: 45,
                            width: 130,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                              CrossAxisAlignment.center,
                              children: const [
                                Text(
                                  'قبلی',
                                  style: TextStyle(
                                      fontSize: 22, color: onPrimaryColor),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward,
                                  color: onPrimaryColor,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                Text(
                  'هوش مصنوعی ممکن است اشتباه کند!',
                  style: TextStyle(
                      color: textMutedColor, fontSize: 16),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageIndicatorR(double fontSize) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '${_currentPage + 1}/$_totalPages',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
            color: textMutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPageOneR(_ResponsiveSizes sizes) {
    final nameField = _FormTextField(
      controller: _nameController,
      hintText: 'اسم',
      hasError: _nameError,
    );
    final genderChip = _ChipButton(text: _gender, onTap: _toggleGender);
    final daysStepper = _DaysStepper(days: _days, onChange: _changeDays);
    final weightField = _FormTextField(
      controller: _weightController,
      hintText: 'وزن',
      keyboardType: TextInputType.number,
      hasError: _weightError,
    );
    final heightField = _FormTextField(
      controller: _heightController,
      hintText: 'قد',
      keyboardType: TextInputType.number,
      hasError: _heightError,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicatorR(sizes.pageIndicatorFontSize),
        if (sizes.stackFormRows) ...[
          nameField,
          const SizedBox(height: 12),
          genderChip,
          const SizedBox(height: 12),
          daysStepper,
          const SizedBox(height: 12),
          weightField,
          const SizedBox(height: 12),
          heightField,
        ] else ...[
          Row(
            children: [
              Expanded(flex: 2, child: nameField),
              const SizedBox(width: 14),
              Expanded(child: genderChip),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: daysStepper),
              const SizedBox(width: 14),
              Expanded(child: weightField),
              const SizedBox(width: 14),
              Expanded(child: heightField),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CheckboxOption(
                label: 'برنامه ورزشی',
                value: _hasExercisePlan,
                hasError: _checkboxError,
                compact: sizes.compactCheckbox,
                onChanged: (value) => setState(() => _hasExercisePlan = value),
              ),
            ),
            SizedBox(width: sizes.checkboxRowGap),
            Expanded(
              child: _CheckboxOption(
                label: 'برنامه غذایی',
                value: _hasFoodPlan,
                hasError: _checkboxError,
                compact: sizes.compactCheckbox,
                onChanged: (value) => setState(() => _hasFoodPlan = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageTwoR(_ResponsiveSizes sizes) {
    const options = ['کم', 'متوسط', 'زیاد'];

    final trainingOptions = [
      for (final option in options)
        _TrainingOption(
          label: option,
          selected: _trainingHistory == option,
          onTap: () => setState(() {
            _trainingHistory = _trainingHistory == option ? null : option;
          }),
        ),
    ];

    final historySection = sizes.stackFormRows
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'سابقه تمرینی:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: trainingOptions,
        ),
      ],
    )
        : Row(
      children: [
        const Text(
          'سابقه تمرینی:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const Spacer(),
        for (var i = 0; i < trainingOptions.length; i++) ...[
          trainingOptions[i],
          if (i != trainingOptions.length - 1)
            const SizedBox(width: 14),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicatorR(sizes.pageIndicatorFontSize),
        historySection,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _OptionalTextField(
                controller: _injuryController,
                hintText: 'مصدومیت',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OptionalTextField(
                controller: _ageController,
                hintText: 'سن',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _OptionalTextField(
          controller: _bodyIssuesController,
          hintText: 'ایرادات بدنی',
        ),
      ],
    );
  }

  Widget _buildPageThreeR(_ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageIndicatorR(sizes.pageIndicatorFontSize),
        _OptionalTextField(
          controller: _foodSensitivityController,
          hintText: 'حساسیت غذایی',
        ),
        const SizedBox(height: 12),
        _OptionalTextField(
          controller: _additionalNotesController,
          hintText: 'توضیحات تکمیلی',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildPageContentR(_ResponsiveSizes sizes) {
    switch (_currentPage) {
      case 0:
        return _buildPageOneR(sizes);
      case 1:
        return _buildPageTwoR(sizes);
      case 2:
        return _buildPageThreeR(sizes);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavButtonsR(
      _ResponsiveSizes sizes,
      bool isFirstPage,
      bool isLastPage,
      ) {
    final nextButton = Material(
      color: primeColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _isSubmitting ? null : _onNextPressed,
        child: Container(
          height: sizes.navButtonHeight,
          width: sizes.navButtonWidth,
          alignment: Alignment.center,
          child: (isLastPage && _isSubmitting)
              ? SizedBox(
            width: sizes.navButtonFontSize,
            height: sizes.navButtonFontSize,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: onPrimaryColor,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isLastPage) ...[
                Icon(Icons.arrow_back,
                    color: onPrimaryColor,
                    size: sizes.navButtonFontSize + 4),
                const SizedBox(width: 6),
              ],
              Text(
                isLastPage ? 'تایید' : 'بعدی',
                style: TextStyle(
                    fontSize: sizes.navButtonFontSize,
                    color: onPrimaryColor),
              ),
              if (isLastPage) ...[
                const SizedBox(width: 6),
                Icon(Icons.check,
                    color: onPrimaryColor,
                    size: sizes.navButtonFontSize + 4),
              ],
            ],
          ),
        ),
      ),
    );

    final prevButton = Opacity(
      opacity: isFirstPage ? 0.4 : 1,
      child: Material(
        color: primeColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (isFirstPage || _isSubmitting) ? null : _onPrevPressed,
          child: Container(
            height: sizes.navButtonHeight,
            width: sizes.navButtonWidth,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'قبلی',
                  style: TextStyle(
                      fontSize: sizes.navButtonFontSize, color: onPrimaryColor),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward,
                    color: onPrimaryColor,
                    size: sizes.navButtonFontSize + 4),
              ],
            ),
          ),
        ),
      ),
    );

    if (sizes.navButtonWidth != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [nextButton, SizedBox(width: sizes.navGap), prevButton],
      );
    }

    return Row(
      children: [
        Expanded(child: nextButton),
        SizedBox(width: sizes.navGap),
        Expanded(child: prevButton),
      ],
    );
  }

  Widget _questionCard(_ResponsiveSizes sizes) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sizes.cardHorizontalPadding),
      child: Container(
        width: sizes.cardWidth,
        constraints: BoxConstraints(minHeight: sizes.cardMinHeight),
        padding: EdgeInsets.all(sizes.cardPadding),
        decoration: BoxDecoration(
          border: Border.all(color: borderStrongColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _isSubmitting
            ? _buildLoadingContent(
          titleFontSize: sizes.pageIndicatorFontSize + 4,
          subtitleFontSize: sizes.footerFontSize + 1,
        )
            : _buildPageContentR(sizes),
      ),
    );
  }

  Widget _buildCompletedViewR(_ResponsiveSizes sizes) {
    final specs = _resultCardSpecs();
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: sizes.topSpacing),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: okBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: okFgColor, size: 16),
              const SizedBox(width: 6),
              Text(
                'برنامه با موفقیت ساخته شد',
                style: TextStyle(
                  color: okFgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sizes.spacingAfterSubtitle * 0.7),
        _CompletedResultsRow(
          cards: specs,
          cardWidth: sizes.resultCardWidth,
          stacked: sizes.stackResultCards,
          spacing: sizes.stackResultCards ? 18 : 24,
        ),
        const SizedBox(height: 24),
        Material(
          color: primeColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _resetForm,
            child: Container(
              height: 44,
              width: sizes.resultCardWidth == double.infinity ? double.infinity : 160,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, color: onPrimaryColor, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'برنامه جدید',
                    style: TextStyle(
                      fontSize: 16,
                      color: onPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(_ResponsiveSizes sizes) {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _totalPages - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.all(sizes.outerMargin),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: sizes.containerPaddingH),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: sizes.verticalPadding),
            child: _isCompleted
                ? _buildCompletedViewR(sizes)
                : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: sizes.topSpacing),
                Text(
                  'ساخت برنامه جدید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: sizes.titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: logoColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'توضیحات دقیق تر و کامل تر باعث خروجی بهتر میشود!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: sizes.subtitleFontSize,
                    color: textPrimaryColor,
                  ),
                ),
                SizedBox(height: sizes.spacingAfterSubtitle),
                _questionCard(sizes),
                const SizedBox(height: 22),
                _buildNavButtonsR(sizes, isFirstPage, isLastPage),
                SizedBox(height: sizes.footerSpacing),
                Text(
                  'هوش مصنوعی ممکن است اشتباه کند!',
                  style: TextStyle(
                    color: textMutedColor,
                    fontSize: sizes.footerFontSize,
                  ),
                ),
                SizedBox(height: sizes.footerBottomGap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(_ResponsiveSizes sizes) {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _totalPages - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.all(sizes.outerMargin),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: sizes.containerPaddingH),
        child: SafeArea(
          top: false,
          bottom: false,
          child: _isCompleted
              ? LayoutBuilder(
            builder: (context, constraints) {
              // مثل دسکتاپ: ارتفاع قبلی حفظ می‌شود و فقط اگر پنل
              // ویرایش جا نشد، اسکرول فعال می‌شود.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: _buildCompletedViewR(sizes)),
                ),
              );
            },
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: sizes.topSpacing),
                        Text(
                          'ساخت برنامه جدید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: sizes.titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: logoColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'توضیحات دقیق تر و کامل تر باعث خروجی بهتر میشود!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: sizes.subtitleFontSize,
                            color: textPrimaryColor,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _questionCard(sizes),
                                const SizedBox(height: 18),
                                _buildNavButtonsR(sizes, isFirstPage,
                                    isLastPage),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'هوش مصنوعی ممکن است اشتباه کند!',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: sizes.footerFontSize,
                          ),
                        ),
                        SizedBox(height: sizes.footerBottomGap),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResultCardSpec {
  const _ResultCardSpec({
    required this.title,
    required this.pdfKind,
    required this.programId,
    required this.userName,
  });

  final String title;
  final String pdfKind;
  final int programId;
  final String userName;
}

class _CompletedResultsRow extends StatelessWidget {
  const _CompletedResultsRow({
    required this.cards,
    required this.cardWidth,
    required this.stacked,
    required this.spacing,
  });

  final List<_ResultCardSpec> cards;
  final double cardWidth;
  final bool stacked;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardWidgets = [
      for (final spec in cards)
        _ResultCard(
          width: cardWidth,
          title: spec.title,
          fileSize: 'PDF',
          date: _formatToday(),
          userName: spec.userName,
          programId: spec.programId,
          pdfKind: spec.pdfKind,
        ),
    ];

    if (stacked) {
      return Column(
        children: [
          for (var i = 0; i < cardWidgets.length; i++) ...[
            cardWidgets[i],
            if (i != cardWidgets.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cardWidgets.length; i++) ...[
          cardWidgets[i],
          if (i != cardWidgets.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

class _ResponsiveSizes {
  const _ResponsiveSizes({
    required this.outerMargin,
    required this.containerPaddingH,
    required this.verticalPadding,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.topSpacing,
    required this.spacingAfterSubtitle,
    required this.cardHorizontalPadding,
    required this.cardPadding,
    required this.cardWidth,
    required this.cardMinHeight,
    required this.navButtonHeight,
    required this.navButtonFontSize,
    required this.navButtonWidth,
    required this.navGap,
    required this.resultCardWidth,
    required this.stackFormRows,
    required this.stackResultCards,
    required this.pageIndicatorFontSize,
    required this.footerFontSize,
    required this.footerSpacing,
    required this.footerBottomGap,
    required this.checkboxRowGap,
    required this.compactCheckbox,
  });

  final double outerMargin;
  final double containerPaddingH;
  final double verticalPadding;
  final double titleFontSize;
  final double subtitleFontSize;
  final double topSpacing;
  final double spacingAfterSubtitle;
  final double cardHorizontalPadding;
  final double cardPadding;
  final double cardWidth;
  final double cardMinHeight;
  final double navButtonHeight;
  final double navButtonFontSize;
  final double? navButtonWidth;
  final double navGap;
  final double resultCardWidth;
  final bool stackFormRows;
  final bool stackResultCards;
  final double pageIndicatorFontSize;
  final double footerFontSize;
  final double footerSpacing;
  final double footerBottomGap;
  final double checkboxRowGap;
  final bool compactCheckbox;

  factory _ResponsiveSizes.of(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.tablet:
        return const _ResponsiveSizes(
          outerMargin: 20,
          containerPaddingH: 24,
          verticalPadding: 28,
          titleFontSize: 30,
          subtitleFontSize: 16,
          topSpacing: 8,
          spacingAfterSubtitle: 36,
          cardHorizontalPadding: 20,
          cardPadding: 30,
          cardWidth: 540,
          cardMinHeight: 260,
          navButtonHeight: 42,
          navButtonFontSize: 18,
          navButtonWidth: 110,
          navGap: 16,
          resultCardWidth: 260,
          stackFormRows: false,
          stackResultCards: false,
          pageIndicatorFontSize: 14,
          footerFontSize: 14,
          footerSpacing: 24,
          footerBottomGap: 6,
          checkboxRowGap: 16,
          compactCheckbox: false,
        );
      case AppDeviceType.mobile:
        return const _ResponsiveSizes(
          outerMargin: 12,
          containerPaddingH: 16,
          verticalPadding: 20,
          titleFontSize: 22,
          subtitleFontSize: 12.5,
          topSpacing: 34,
          spacingAfterSubtitle: 0,
          cardHorizontalPadding: 0,
          cardPadding: 18,
          cardWidth: double.infinity,
          cardMinHeight: 0,
          navButtonHeight: 50,
          navButtonFontSize: 17,
          navButtonWidth: null,
          navGap: 12,
          resultCardWidth: double.infinity,
          stackFormRows: true,
          stackResultCards: true,
          pageIndicatorFontSize: 12,
          footerFontSize: 11,
          footerSpacing: 14,
          footerBottomGap: 14,
          checkboxRowGap: 10,
          compactCheckbox: true,
        );
      case AppDeviceType.desktop:
        return const _ResponsiveSizes(
          outerMargin: 20,
          containerPaddingH: 20,
          verticalPadding: 0,
          titleFontSize: 40,
          subtitleFontSize: 20,
          topSpacing: 80,
          spacingAfterSubtitle: 95,
          cardHorizontalPadding: 50,
          cardPadding: 48,
          cardWidth: 650,
          cardMinHeight: 300,
          navButtonHeight: 45,
          navButtonFontSize: 22,
          navButtonWidth: 130,
          navGap: 20,
          resultCardWidth: 300,
          stackFormRows: false,
          stackResultCards: false,
          pageIndicatorFontSize: 15,
          footerFontSize: 16,
          footerSpacing: 28,
          footerBottomGap: 10,
          checkboxRowGap: 16,
          compactCheckbox: false,
        );
    }
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    final OutlineInputBorder errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: dangerFgColor, width: 1.5),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        filled: true,
        fillColor: textfildColor,
        hintText: hintText,
        hintStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: normalBorder,
        enabledBorder: hasError ? errorBorder : normalBorder,
        focusedBorder: hasError ? errorBorder : normalBorder,
      ),
    );
  }
}

class _OptionalTextField extends StatelessWidget {
  const _OptionalTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        filled: true,
        fillColor: textfildColor,
        hintText: hintText,
        hintStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: textfildColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _DaysStepper extends StatelessWidget {
  const _DaysStepper({required this.days, required this.onChange});

  final int days;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: textfildColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'تعداد روز:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            IconButton(
              onPressed: () => onChange(1),
              icon: const Icon(Icons.add, size: 27),
            ),
            Text(
              '$days',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            IconButton(
              onPressed: () => onChange(-1),
              icon: const Icon(Icons.remove, size: 27),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxOption extends StatelessWidget {
  const _CheckboxOption({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hasError = false,
    this.compact = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasError;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double checkboxScale = compact ? 1.0 : 1.3;
    final double fontSize = compact ? 13.5 : 20;
    final double gap = compact ? 6 : 8;

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: checkboxScale,
              child: Checkbox(
                value: value,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                  side: hasError && !value
                      ? BorderSide(color: dangerFgColor, width: 1.5)
                      : BorderSide.none,
                ),
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: primeColor,
              ),
            ),
            SizedBox(width: gap),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingOption extends StatelessWidget {
  const _TrainingOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: selected ? primeColor : Colors.transparent,
              border: Border.all(
                color: selected ? primeColor : textFaintColor,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.title,
    required this.fileSize,
    required this.date,
    required this.userName,
    required this.width,
    required this.programId,
    required this.pdfKind,
  });

  final String title;
  final String fileSize;
  final String date;
  final String userName;
  final double width;
  final int programId;
  final String pdfKind;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
    with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  final AuthTokenService _authTokenService = AuthTokenService();
  final ApiService _apiService = ApiService();

  // ---- ویرایش برنامه با هوش مصنوعی ----
  final TextEditingController _editFeedbackController =
  TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  bool _isSubmittingEdit = false;
  bool _hasEditedOnce = false;
  String? _editErrorMessage;

  // انیمیشن ورود/به‌روزرسانی کارت: یک "پاپ" نرم و فنری هنگام آماده‌شدن
  // پی‌دی‌اف (اول یا بعد از هر ویرایش موفق).
  late final AnimationController _arrivalController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _arrivalScale = Tween<double>(
    begin: 0.8,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _arrivalController, curve: Curves.elasticOut),
  );

  @override
  void dispose() {
    _editFeedbackController.dispose();
    _editFocusNode.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final isLoggedIn = await _authTokenService.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('ابتدا وارد حساب کاربری خود شوید.');
      }

      final path = _getPdfPath(widget.programId, widget.pdfKind);
      final bytes = await _apiService.getBytes(endpoint: path);

      if (bytes == null || bytes.isEmpty) {
        throw Exception('دریافت فایل ناموفق بود. دوباره تلاش کنید.');
      }

      // دانلود از مسیر وابسته به پلتفرم (وب: دانلود مرورگر).
      // مستقیم dart:html صدا زده نمی‌شود تا این فایل روی بیلد غیروب هم
      // کامپایل شود.
      await savePdf(
        bytes,
        'program_${widget.programId}_${widget.pdfKind}.pdf',
      );

      if (mounted) {
        context.showSafeSnackBar('PDF با موفقیت دانلود شد',
            color: Colors.green, seconds: 3);
      }

    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        context.showSafeSnackBar('خطا در دانلود PDF: $message',
            color: Colors.red, seconds: 4);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// ارسال بازخورد متنی به هوش مصنوعی برای ویرایش همین برنامه. پس از موفقیت،
  /// دکمه‌ی «دانلود PDF» موجود در کارت، نسخه‌ی به‌روزشده را می‌گیرد؛ نیازی
  /// به دانلود جداگانه یا تغییر مسیر نیست.
  Future<void> _submitEdit() async {
    final feedback = _editFeedbackController.text.trim();
    if (feedback.isEmpty) {
      setState(() {
        _editErrorMessage = 'لطفاً تغییری که مدنظرتان است را بنویسید.';
      });
      return;
    }
    if (_isSubmittingEdit) return;

    setState(() {
      _isSubmittingEdit = true;
      _editErrorMessage = null;
    });

    try {
      final isLoggedIn = await _authTokenService.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('ابتدا وارد حساب کاربری خود شوید.');
      }

      final response = await _apiService.post(
        endpoint: ServerEndpoints.programEdit(widget.programId),
        body: {
          'feedback': feedback,
          'generate_pdf': false,
        },
        requiresAuth: true,
        timeout: ApiConfig.programGenerationTimeout,
      );

      if (response.statusCode == 401) {
        await _authTokenService.clearToken();
        throw Exception('نشست شما منقضی شده است. لطفاً دوباره وارد شوید.');
      }

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 402) {
        throw Exception(
          'توکن کافی نیست. لازم: ${data['required_tokens']} | موجودی: ${data['current_balance']}',
        );
      }

      if (!response.success) {
        throw Exception(response.error ?? 'ویرایش برنامه ناموفق بود.');
      }

      if (!mounted) return;
      setState(() {
        _isSubmittingEdit = false;
        _hasEditedOnce = true;
        _editFeedbackController.clear();
      });
      // یک تکون فنری کوچک روی کارت، تا کاربر حس کند نسخه‌ی جدید آماده شد.
      _arrivalController.forward(from: 0);
      context.showSafeSnackBar('برنامه با موفقیت ویرایش شد',
          color: Colors.green, seconds: 3);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSubmittingEdit = false;
        _editErrorMessage = message;
      });
      context.showSafeSnackBar('خطا در ویرایش برنامه: $message',
          color: Colors.red, seconds: 4);
    }
  }

  Widget _buildAnimatedCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _arrivalController,
      builder: (context, child) {
        final glow = (1 - _arrivalController.value).clamp(0.0, 1.0);
        return Transform.scale(
          scale: _arrivalScale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: glow > 0
                  ? [
                BoxShadow(
                  color: primeColor.withValues(alpha: glow * 0.35),
                  blurRadius: 30,
                  spreadRadius: glow * 3,
                ),
              ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: _buildCardContent(context),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Container(
      width: widget.width,
      height: 400,
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
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  Icon(Icons.check_circle,
                      color: okFgColor, size: 16),
                ],
              ),
            ),
          ),
          if (_hasEditedOnce) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: primeColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'نسخه ویرایش‌شده',
                      style: TextStyle(
                        color: primeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Image.asset('assets/pdf.webp', width: 84, height: 84, cacheWidth: 168),
          const SizedBox(height: 14),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'نوع فایل:',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fileSize,
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
                      'تاریخ ایجاد:',
                      style: TextStyle(
                        color: textMutedColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.date,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: Text(
              widget.userName,
              style: TextStyle(
                color: textSecondaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _downloadPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: primeColor,
                elevation: 0,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isDownloading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onPrimaryColor,
                ),
              )
                  : Row(
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // فقط بر اساس عرض واقعی صفحه تصمیم می‌گیریم (نه Constraints بالادستی)
    // چون این ویجت گاهی داخل یک Row با عرض نامحدود قرار می‌گیرد.
    final screenWidth = MediaQuery.sizeOf(context).width;
    const double editPanelWidth = 340;
    final bool canFitSideBySide = widget.width.isFinite &&
        screenWidth >= widget.width + editPanelWidth + 460;

    final card = _buildAnimatedCard(context);
    final editPanel = _EditProgramPanel(
      controller: _editFeedbackController,
      focusNode: _editFocusNode,
      isSubmitting: _isSubmittingEdit,
      errorMessage: _editErrorMessage,
      hasEditedOnce: _hasEditedOnce,
      onSubmit: _submitEdit,
      expandToFillHeight: canFitSideBySide,
    );

    if (canFitSideBySide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            card,
            const SizedBox(width: 28),
            SizedBox(width: editPanelWidth, child: editPanel),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 20),
        editPanel,
      ],
    );
  }
}

/// جایگاه ویرایش برنامه با هوش مصنوعی: کنار کارت دانلود (صفحه بزرگ) یا زیر
/// آن (موبایل/صفحه کوچک). کاربر متن تغییر را می‌نویسد، ارسال می‌کند و پس
/// از موفقیت، همان دکمه «دانلود PDF» در کارت، نسخه‌ی جدید را می‌گیرد.
class _EditProgramPanel extends StatelessWidget {
  const _EditProgramPanel({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.errorMessage,
    required this.hasEditedOnce,
    required this.onSubmit,
    this.expandToFillHeight = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final String? errorMessage;
  final bool hasEditedOnce;
  final VoidCallback onSubmit;
  final bool expandToFillHeight;

  @override
  Widget build(BuildContext context) {
    final textFieldBox = Container(
      constraints: expandToFillHeight
          ? null
          : const BoxConstraints(minHeight: 140, maxHeight: 240),
      decoration: BoxDecoration(
        color: textfildColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errorMessage != null ? dangerFgColor : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isSubmitting,
        maxLines: null,
        expands: expandToFillHeight,
        minLines: expandToFillHeight ? null : 6,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, height: 1.6),
        decoration: InputDecoration(
          hintText:
          'مثلاً: روزهای تمرین را ۴ روز کن و پروتئین بیشتری اضافه کن',
          hintStyle: TextStyle(color: textMutedColor, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderStrongColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: primeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasEditedOnce ? 'ویرایش دوباره برنامه' : 'ویرایش برنامه با هوش مصنوعی',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تغییری که مدنظرتان است را بنویسید؛ هوش مصنوعی برنامه و فایل PDF را به‌روزرسانی می‌کند.',
            style: TextStyle(fontSize: 13, color: textMutedColor, height: 1.6),
          ),
          const SizedBox(height: 16),
          expandToFillHeight ? Expanded(child: textFieldBox) : textFieldBox,
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, color: dangerFgColor, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: dangerFgColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primeColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'در حال اعمال ویرایش...',
                    style: TextStyle(
                      color: onPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.auto_fix_high, color: onPrimaryColor, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'اعمال ویرایش',
                    style: TextStyle(
                      color: onPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}