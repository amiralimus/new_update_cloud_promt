import 'dart:async';

import 'package:flutter/material.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/athlete_model.dart';
import '../models/coach_template.dart';
import '../models/exercise_model.dart';
import '../models/manual_program_models.dart';
import '../widgets/coach_tools_common.dart';
import '../widgets/nutrition_editor.dart';
import '../widgets/optional_plan_editor.dart';
import '../widgets/program_result_card.dart';
import '../widgets/template_drawer.dart';
import '../widgets/training_editor.dart';

enum _EditorSection { workout, nutrition, extras }

class ManualProgramEditorPage extends StatefulWidget {
  const ManualProgramEditorPage({
    super.key,
    required this.onBack,
    required this.onOpenTemplates,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenTemplates;

  @override
  State<ManualProgramEditorPage> createState() =>
      ManualProgramEditorPageState();
}

class ManualProgramEditorPageState extends State<ManualProgramEditorPage> {
  final CoachToolsApi _api = CoachToolsApi();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _athleteNameController = TextEditingController();
  Timer? _quotaDebounce;

  ManualProgramDraft _draft = ManualProgramDraft.fresh();
  List<CoachAthlete> _athletes = const [];
  final List<CoachTemplate> _appliedTemplates = [];
  bool _loadingAthletes = true;
  bool _loadingQuota = false;
  bool _submitting = false;
  String? _athletesError;
  String? _submitError;
  ManualProgramQuota? _quota;
  ManualProgramResult? _result;
  _EditorSection _activeSection = _EditorSection.workout;

  @override
  void initState() {
    super.initState();
    _athleteNameController.addListener(_onAthleteNameChanged);
    _loadAthletes();
  }

  @override
  void dispose() {
    _quotaDebounce?.cancel();
    _athleteNameController
      ..removeListener(_onAthleteNameChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void addExerciseFromLibrary(CoachExercise exercise) {
    setState(() {
      _draft.workoutEnabled = true;
      _draft.addExerciseToFirstSession(exercise);
      _result = null;
      _activeSection = _EditorSection.workout;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
    _showMessage('«${exercise.name}» به جلسه اول اضافه شد.', ok: true);
  }

  void startNewWithExercise(CoachExercise exercise) {
    setState(() {
      _draft = ManualProgramDraft.fresh();
      _result = null;
      _quota = null;
      _submitError = null;
      _appliedTemplates.clear();
      _activeSection = _EditorSection.workout;
      _athleteNameController.clear();
      _draft.addExerciseToFirstSession(exercise);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
    _showMessage('برنامه تازه با «${exercise.name}» ساخته شد.', ok: true);
  }

  void startNewForAthlete(CoachAthlete athlete) {
    setState(() {
      if (!_athletes.any((item) => item.id == athlete.id)) {
        _athletes = [athlete, ..._athletes];
      }
      _draft = ManualProgramDraft.fresh();
      _result = null;
      _quota = null;
      _submitError = null;
      _appliedTemplates.clear();
      _activeSection = _EditorSection.workout;
      _draft.athleteId = athlete.id;
      _draft.athleteName = athlete.displayName;
      _athleteNameController.text = athlete.displayName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
    _loadQuota();
  }

  Future<void> _loadAthletes() async {
    setState(() {
      _loadingAthletes = true;
      _athletesError = null;
    });
    try {
      final athletes = await _api.fetchAthletes();
      if (!mounted) return;
      setState(() => _athletes = athletes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _athletesError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingAthletes = false);
    }
  }

  void _onAthleteNameChanged() {
    _draft.athleteName = _athleteNameController.text;
    _quotaDebounce?.cancel();
    if (_draft.athleteName.trim().isEmpty) {
      setState(() => _quota = null);
      return;
    }
    _quotaDebounce = Timer(const Duration(milliseconds: 500), _loadQuota);
  }

  Future<void> _loadQuota() async {
    if (_draft.athleteName.trim().isEmpty) return;
    setState(() => _loadingQuota = true);
    try {
      final quota = await _api.fetchManualQuota(
        athleteName: _draft.athleteName,
        athleteId: _draft.athleteId,
      );
      if (!mounted) return;
      setState(() => _quota = quota);
    } catch (_) {
      if (mounted) setState(() => _quota = null);
    } finally {
      if (mounted) setState(() => _loadingQuota = false);
    }
  }

  void _selectAthlete(int? athleteId) {
    setState(() {
      _draft.athleteId = athleteId;
      if (athleteId != null) {
        final athlete = _athletes.firstWhere((item) => item.id == athleteId);
        _athleteNameController.text = athlete.displayName;
      }
    });
    _loadQuota();
  }

  Future<void> _applyTemplate(CoachTemplate template) async {
    if (template.applyMode == TemplateApplyMode.replace &&
        _draft.sessions.any((session) => session.exercises.isNotEmpty)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('جایگزینی برنامه'),
          content: const Text(
            'این تمپلیت محتوای تمرینی فعلی را جایگزین می‌کند. ادامه می‌دهید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('جایگزینی'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      template.applyTo(_draft);
      _activeSection = _EditorSection.workout;
      if (!_appliedTemplates.any((item) => item.id == template.id)) {
        _appliedTemplates.add(template);
      }
    });
    _showMessage('تمپلیت «${template.title}» اعمال شد.', ok: true);
  }

  void _onSessionAdded(int sessionIndex) {
    final target = _draft.sessions[sessionIndex];
    for (final template in _appliedTemplates) {
      if (template.applyMode == TemplateApplyMode.replace ||
          sessionIndex >= template.sessions.length) {
        continue;
      }
      final additions = template.exercisesForSession(sessionIndex);
      if (template.applyMode == TemplateApplyMode.prepend) {
        target.exercises.insertAll(0, additions);
      } else {
        target.exercises.addAll(additions);
      }
    }
    setState(() {});
  }

  String? _validateDraft() {
    if (_draft.athleteName.trim().isEmpty) return 'نام ورزشکار لازم است.';
    if (_draft.nutritionAiMode) {
      return _draft.nutritionPrompt.trim().isEmpty
          ? 'درخواست برنامه غذایی را بنویسید.'
          : null;
    }
    final hasWorkout = _draft.sessions.any((session) => session.hasContent);
    final hasMeal = _draft.mealDays.expand((day) => day.meals).any(
      (meal) =>
          meal.title.trim().isNotEmpty || meal.content.trim().isNotEmpty,
    );
    final hasSupplement = _draft.supplements.any(
      (item) =>
          item.title.trim().isNotEmpty || item.content.trim().isNotEmpty,
    );
    final hasMedication = _draft.medications.any(
      (item) =>
          item.title.trim().isNotEmpty || item.content.trim().isNotEmpty,
    );
    if (!hasWorkout && !hasMeal && !hasSupplement) {
      return hasMedication
          ? 'ذخیره دارو هنوز در سرور فعال نیست.'
          : 'حداقل یک حرکت، وعده یا مکمل وارد کنید.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    final validationError = _validateDraft();
    if (!formValid || validationError != null) {
      setState(
        () =>
            _submitError = validationError ?? 'فیلدهای مشخص‌شده را بررسی کنید.',
      );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_quota?.blocked == true) {
      setState(() {
        _submitError = _quota!.blockedMessage.isEmpty
            ? 'ساخت برنامه دستی در حال حاضر در دسترس نیست.'
            : _quota!.blockedMessage;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      CoachAthlete? athlete;
      if (_draft.athleteId != null) {
        for (final item in _athletes) {
          if (item.id == _draft.athleteId) {
            athlete = item;
            break;
          }
        }
      }
      final result = _draft.nutritionAiMode
          ? await _api.createAiNutritionProgram(_draft, athlete: athlete)
          : await _api.createManualProgram(_draft);
      if (!mounted) return;
      setState(() => _result = result);
      _showMessage(
        result.wasFree
            ? 'برنامه با موفقیت ساخته شد.'
            : '${result.chargedTokens} توکن کسر شد و برنامه ساخته شد.',
        ok: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
      _showMessage(error.toString(), ok: false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetAfterResult() {
    setState(() {
      _draft = ManualProgramDraft.fresh();
      _athleteNameController.clear();
      _quota = null;
      _result = null;
      _submitError = null;
      _appliedTemplates.clear();
      _activeSection = _EditorSection.workout;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _openTemplateSettings() {
    Navigator.of(context).maybePop();
    widget.onOpenTemplates();
  }

  void _showMessage(String message, {required bool ok}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? okFgColor : dangerFgColor,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      endDrawer: Drawer(
        width: MediaQuery.sizeOf(context).width < 600
            ? MediaQuery.sizeOf(context).width * 0.94
            : 390,
        child: TemplateDrawer(
          onApply: _applyTemplate,
          onOpenSettings: _openTemplateSettings,
        ),
      ),
      body: CoachPageFrame(
        title: _result == null ? 'ساخت برنامه جدید' : 'خروجی برنامه',
        onBack: widget.onBack,
        actions: _result == null
            ? [
                TextButton.icon(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  label: const Text('تمپلیت‌ها'),
                  style: TextButton.styleFrom(
                    foregroundColor: primeColor,
                    backgroundColor: primeColor.withValues(alpha: 0.09),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ]
            : const [],
        body: _result == null ? _buildEditor() : _buildResult(),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return ProgramResultCard(
      programId: result.programId,
      programType: result.programType,
      athleteName: result.athleteName,
      onClose: _resetAfterResult,
    );
  }

  Widget _buildEditor() {
    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        children: [
          _buildAthleteSection(),
          const SizedBox(height: 18),
          _buildSectionNavigation(),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_activeSection),
              child: _buildActiveSection(),
            ),
          ),
          const SizedBox(height: 16),
          _buildValidityBar(),
          const SizedBox(height: 14),
          if (_submitError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dangerBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dangerBorderColor),
              ),
              child: Text(
                _submitError!,
                style: const TextStyle(color: dangerFgColor),
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onPrimaryColor,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_submitting ? 'در حال ساخت برنامه...' : 'ساخت PDF'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionNavigation() {
    final items = <_EditorSectionItem>[
      const _EditorSectionItem(
        section: _EditorSection.workout,
        label: 'تمرین',
        icon: Icons.fitness_center_rounded,
      ),
      const _EditorSectionItem(
        section: _EditorSection.nutrition,
        label: 'تغذیه',
        icon: Icons.restaurant_menu_rounded,
      ),
      const _EditorSectionItem(
        section: _EditorSection.extras,
        label: 'مکمل و دارو',
        icon: Icons.medication_liquid_outlined,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: _SectionTab(
              item: items[index],
              selected: _activeSection == items[index].section,
              onTap: () => _selectSection(items[index].section),
            ),
          ),
          if (index != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  void _selectSection(_EditorSection section) {
    setState(() {
      _activeSection = section;
      if (section == _EditorSection.nutrition) {
        _draft.nutritionEnabled = true;
      } else if (_draft.nutritionAiMode) {
        _draft.nutritionAiMode = false;
        _draft.workoutEnabled = true;
      }
    });
  }

  Widget _buildActiveSection() {
    switch (_activeSection) {
      case _EditorSection.workout:
        return _ProgramSection(
          title: 'برنامه ورزشی',
          icon: Icons.fitness_center_rounded,
          child: TrainingEditor(
            sessions: _draft.sessions,
            onChanged: () => setState(() {}),
            onSessionAdded: _onSessionAdded,
          ),
        );
      case _EditorSection.nutrition:
        return _ProgramSection(
          title: 'برنامه غذایی',
          icon: Icons.restaurant_menu_rounded,
          child: NutritionEditor(
            days: _draft.mealDays,
            prompt: _draft.nutritionPrompt,
            mode: _draft.nutritionAiMode
                ? NutritionEditorMode.ai
                : NutritionEditorMode.manual,
            onModeChanged: (mode) {
              setState(() {
                _draft.nutritionAiMode = mode == NutritionEditorMode.ai;
                _draft.nutritionEnabled = true;
                _draft.workoutEnabled = !_draft.nutritionAiMode;
              });
            },
            onPromptChanged: (value) => _draft.nutritionPrompt = value,
            onChanged: () => setState(() {}),
          ),
        );
      case _EditorSection.extras:
        return _ProgramSection(
          title: 'مکمل و دارو',
          icon: Icons.medication_liquid_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'مکمل‌ها',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              OptionalPlanEditor(
                title: 'مکمل',
                items: _draft.supplements,
                onChanged: () => setState(() {}),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              const Text(
                'داروها',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              OptionalPlanEditor(
                title: 'دارو',
                items: _draft.medications,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildAthleteSection() {
    return CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final selector = DropdownButtonFormField<int>(
                key: ValueKey(_draft.athleteId),
                initialValue: _draft.athleteId,
                isExpanded: true,
                decoration: coachInputDecoration(
                  labelText: 'پروفایل ورزشکار (اختیاری)',
                  suffixIcon: _loadingAthletes
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                hint: Text(
                  _athletesError == null
                      ? 'انتخاب ورزشکار'
                      : 'دریافت فهرست ناموفق بود',
                ),
                items: _athletes
                    .map(
                      (athlete) => DropdownMenuItem(
                        value: athlete.id,
                        child: Text(
                          athlete.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingAthletes ? null : _selectAthlete,
              );
              final name = TextFormField(
                controller: _athleteNameController,
                decoration: coachInputDecoration(labelText: 'نام ورزشکار'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'نام ورزشکار لازم است.'
                    : null,
              );
              if (stacked) {
                return Column(
                  children: [selector, const SizedBox(height: 9), name],
                );
              }
              return Row(
                children: [
                  Expanded(child: selector),
                  const SizedBox(width: 10),
                  Expanded(child: name),
                ],
              );
            },
          ),
          if (_quota != null || _loadingQuota) ...[
            const SizedBox(height: 10),
            _QuotaBanner(quota: _quota, loading: _loadingQuota),
          ],
        ],
      ),
    );
  }

  Widget _buildValidityBar() {
    const quickOptions = <MapEntry<String, int>>[
      MapEntry('۷ روز', 7),
      MapEntry('۱۴ روز', 14),
      MapEntry('۳۰ روز', 30),
      MapEntry('۲ ماه', 60),
    ];
    return CoachSurface(
      color: surfaceAltColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Text(
            'اعتبار:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ...quickOptions.map(
            (option) => ChoiceChip(
              label: Text(option.key),
              selected: _draft.validityDays == option.value,
              onSelected: (_) =>
                  setState(() => _draft.validityDays = option.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSectionItem {
  const _EditorSectionItem({
    required this.section,
    required this.label,
    required this.icon,
  });

  final _EditorSection section;
  final String label;
  final IconData icon;
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _EditorSectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? primeColor.withValues(alpha: 0.09) : surfaceAltColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? primeColor : borderColor,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? primeColor : surfaceMutedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: selected ? onPrimaryColor : textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? primeColor : textPrimaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramSection extends StatelessWidget {
  const _ProgramSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primeColor.withValues(alpha: 0.16),
                      primeColor.withValues(alpha: 0.06),
                    ],
                  ),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Icon(icon, color: primeColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({required this.quota, required this.loading});

  final ManualProgramQuota? quota;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && quota == null) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final current = quota!;
    final blocked = current.blocked;
    final free = current.nextIsFree;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: blocked
            ? dangerBgColor
            : free
            ? okBgColor
            : warnBgColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            blocked
                ? Icons.block_rounded
                : free
                ? Icons.check_circle_outline_rounded
                : Icons.toll_outlined,
            color: blocked
                ? dangerFgColor
                : free
                ? okFgColor
                : warnFgColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              blocked
                  ? (current.blockedMessage.isEmpty
                        ? 'ساخت برنامه برای این ورزشکار موقتاً مسدود است.'
                        : current.blockedMessage)
                  : free
                  ? 'رایگان • ${current.freeRemaining} سهم باقی‌مانده'
                  : '${current.nextCost} توکن • موجودی ${current.balance}',
              style: TextStyle(
                color: blocked
                    ? dangerFgColor
                    : free
                    ? okFgColor
                    : warnFgColor,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
