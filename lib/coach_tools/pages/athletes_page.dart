import 'dart:async';

import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../core/platform/pdf_saver.dart';
import '../data/coach_tools_api.dart';
import '../models/athlete_model.dart';
import '../widgets/coach_tools_common.dart';

class AthletesPage extends StatefulWidget {
  const AthletesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AthletesPage> createState() => _AthletesPageState();
}

class _AthletesPageState extends State<AthletesPage> {
  final CoachToolsApi _api = CoachToolsApi();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<AthleteWithPrograms> _athletes = const [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final athletes = await _api.fetchAthletesWithPrograms();
      if (!mounted) return;
      setState(() => _athletes = athletes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<AthleteWithPrograms> get _filtered {
    if (_query.isEmpty) return _athletes;
    return _athletes
        .where(
          (item) => item.athlete.displayName.toLowerCase().contains(_query),
        )
        .toList();
  }

  Future<void> _openAthlete(AthleteWithPrograms item) async {
    final width = MediaQuery.sizeOf(context).width;
    final updated = width >= 700
        ? await showDialog<CoachAthlete>(
            context: context,
            barrierColor: scrimColor,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 920,
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: AthleteDetailPanel(item: item),
              ),
            ),
          )
        : await showModalBottomSheet<CoachAthlete>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.94,
              child: AthleteDetailPanel(item: item),
            ),
          );
    if (updated == null || !mounted) return;
    final index = _athletes.indexWhere(
      (entry) => entry.athlete.id == updated.id,
    );
    if (index >= 0) {
      setState(() {
        _athletes[index] = _athletes[index].copyWith(athlete: updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CoachPageFrame(
      title: 'پروفایل ورزشکارها',
      subtitle: 'مشخصات و برنامه‌های هر ورزشکار را یک‌جا ببینید.',
      onBack: widget.onBack,
      actions: [
        IconButton.filledTonal(
          tooltip: 'به‌روزرسانی',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: coachInputDecoration(
              hintText: 'جست‌وجوی نام ورزشکار',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _athletes.isEmpty) {
      return const CoachLoadingState(
        label: 'در حال دریافت ورزشکارها و برنامه‌ها...',
      );
    }
    if (_error != null && _athletes.isEmpty) {
      return CoachErrorState(message: _error!, onRetry: _load);
    }
    final items = _filtered;
    if (items.isEmpty) {
      return CoachEmptyState(
        title: _query.isEmpty ? 'ورزشکاری ثبت نشده است' : 'نتیجه‌ای پیدا نشد',
        message: _query.isEmpty
            ? 'ورزشکارها پس از ایجاد کد دسترسی یا ثبت در باشگاه اینجا ظاهر می‌شوند.'
            : 'نام دیگری را جست‌وجو کنید.',
        icon: _query.isEmpty
            ? Icons.people_outline_rounded
            : Icons.search_off_rounded,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 2 : 1;
        return GridView.builder(
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _AthleteCard(item: item, onTap: () => _openAthlete(item));
          },
        );
      },
    );
  }
}

class _AthleteCard extends StatelessWidget {
  const _AthleteCard({required this.item, required this.onTap});

  final AthleteWithPrograms item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            color: surfaceAltColor,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: infoBgColor,
                child: Text(
                  item.athlete.displayName.trim().isEmpty
                      ? '؟'
                      : item.athlete.displayName.characters.first,
                  style: const TextStyle(
                    color: infoFgColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.athlete.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${item.programCount} برنامه • آخرین: ${formatCoachDate(item.lastProgramDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.athlete.isActivated
                          ? 'حساب فعال'
                          : 'در انتظار فعال‌سازی',
                      style: TextStyle(
                        color: item.athlete.isActivated
                            ? okFgColor
                            : warnFgColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: textFaintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AthleteDetailPanel extends StatefulWidget {
  const AthleteDetailPanel({super.key, required this.item});

  final AthleteWithPrograms item;

  @override
  State<AthleteDetailPanel> createState() => _AthleteDetailPanelState();
}

class _AthleteDetailPanelState extends State<AthleteDetailPanel> {
  final CoachToolsApi _api = CoachToolsApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  String? _gender;
  bool _saving = false;
  final Set<int> _downloading = <int>{};

  @override
  void initState() {
    super.initState();
    final athlete = widget.item.athlete;
    _gender = athlete.gender;
    _controllers = {
      'name': TextEditingController(text: athlete.name),
      'age': TextEditingController(text: athlete.age?.toString() ?? ''),
      'height': TextEditingController(text: athlete.height?.toString() ?? ''),
      'weight': TextEditingController(text: athlete.weight?.toString() ?? ''),
      'goal': TextEditingController(text: athlete.goal),
      'injuries': TextEditingController(text: athlete.injuries),
      'food_allergies': TextEditingController(text: athlete.foodAllergies),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _controllers['name']!.text.trim(),
        if (_controllers['age']!.text.trim().isNotEmpty)
          'age': int.parse(_controllers['age']!.text.trim()),
        if (_gender?.isNotEmpty == true) 'gender': _gender,
        if (_controllers['height']!.text.trim().isNotEmpty)
          'height': double.parse(_controllers['height']!.text.trim()),
        if (_controllers['weight']!.text.trim().isNotEmpty)
          'weight': double.parse(_controllers['weight']!.text.trim()),
        'goal': _controllers['goal']!.text.trim(),
        'injuries': _controllers['injuries']!.text.trim(),
        'food_allergies': _controllers['food_allergies']!.text.trim(),
      };
      final updated = await _api.updateAthlete(widget.item.athlete.id, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مشخصات ورزشکار ذخیره شد.'),
          backgroundColor: okFgColor,
        ),
      );
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: dangerFgColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _viewProgram(AthleteProgramSummary program) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder<AthleteProgramDetail>(
        future: _api.fetchProgramDetail(program.id),
        builder: (context, snapshot) {
          return AlertDialog(
            title: Text(program.name),
            content: SizedBox(
              width: 660,
              child: snapshot.connectionState != ConnectionState.done
                  ? const SizedBox(height: 180, child: CoachLoadingState())
                  : snapshot.hasError
                  ? CoachErrorState(
                      message: snapshot.error.toString(),
                      onRetry: () => Navigator.of(context).pop(),
                    )
                  : _ProgramTextDetail(detail: snapshot.data!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('بستن'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _download(
    AthleteProgramSummary program, {
    required String type,
  }) async {
    if (_downloading.contains(program.id)) return;
    setState(() => _downloading.add(program.id));
    try {
      final bytes = await _api.downloadProgramPdf(
        programId: program.id,
        programType: type,
      );
      await savePdf(bytes, 'program_${program.id}_$type.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF دانلود شد.'),
            backgroundColor: okFgColor,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: dangerFgColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(program.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.athlete.displayName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'بستن',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildProfileForm(),
                const SizedBox(height: 18),
                _buildPrograms(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return CoachSurface(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اطلاعات شخصی',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 13),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final fields = [
                  _field('name', 'نام و نام خانوادگی', required: true),
                  _field('age', 'سن', number: true),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: coachInputDecoration(labelText: 'جنسیت'),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('مرد')),
                      DropdownMenuItem(value: 'F', child: Text('زن')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  _field('height', 'قد (سانتی‌متر)', decimal: true),
                  _field('weight', 'وزن (کیلوگرم)', decimal: true),
                  _field('goal', 'هدف'),
                  _field('injuries', 'آسیب‌ها'),
                  _field('food_allergies', 'حساسیت‌های غذایی'),
                ];
                if (!twoColumns) {
                  return Column(
                    children: fields
                        .map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: field,
                          ),
                        )
                        .toList(),
                  );
                }
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width: (constraints.maxWidth - 10) / 2,
                          child: field,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onPrimaryColor,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره تغییرات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    bool decimal = false,
  }) {
    return TextFormField(
      controller: _controllers[key],
      keyboardType: number || decimal
          ? TextInputType.numberWithOptions(decimal: decimal)
          : TextInputType.text,
      decoration: coachInputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return '$label لازم است.';
        if (number && text.isNotEmpty && int.tryParse(text) == null) {
          return 'عدد صحیح وارد کنید.';
        }
        if (decimal && text.isNotEmpty && double.tryParse(text) == null) {
          return 'عدد معتبر وارد کنید.';
        }
        return null;
      },
    );
  }

  Widget _buildPrograms() {
    final programs = widget.item.programs;
    return CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'برنامه‌ها (${programs.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (widget.item.programsError != null)
            CoachErrorState(message: widget.item.programsError!, onRetry: () {})
          else if (programs.isEmpty)
            const CoachEmptyState(
              title: 'برنامه‌ای ثبت نشده است',
              message:
                  'بعد از ساخت اولین برنامه، امکان مشاهده و دانلود آن اینجا فعال می‌شود.',
              icon: Icons.description_outlined,
            )
          else
            ...programs.map(
              (program) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: surfaceMutedColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: dangerFgColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            program.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${program.typeLabel} • ${program.dateLabel}',
                            style: const TextStyle(
                              color: textMutedColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'مشاهده',
                      onPressed: () => _viewProgram(program),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    if (_downloading.contains(program.id))
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      PopupMenuButton<String>(
                        tooltip: 'دانلود PDF',
                        icon: const Icon(Icons.download_rounded),
                        onSelected: (type) => _download(program, type: type),
                        itemBuilder: (context) => [
                          if (program.hasWorkout)
                            const PopupMenuItem(
                              value: 'workout',
                              child: Text('PDF ورزشی'),
                            ),
                          if (program.hasMeal)
                            const PopupMenuItem(
                              value: 'meal',
                              child: Text('PDF غذایی'),
                            ),
                          if (program.hasWorkout && program.hasMeal)
                            const PopupMenuItem(
                              value: 'both',
                              child: Text('PDF کامل'),
                            ),
                        ],
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

class _ProgramTextDetail extends StatelessWidget {
  const _ProgramTextDetail({required this.detail});

  final AthleteProgramDetail detail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.generatedWorkout.trim().isNotEmpty) ...[
            const Text(
              'برنامه ورزشی',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            SelectableText(
              detail.generatedWorkout,
              style: const TextStyle(height: 1.8),
            ),
          ],
          if (detail.generatedMealPlan.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'برنامه غذایی',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            SelectableText(
              detail.generatedMealPlan,
              style: const TextStyle(height: 1.8),
            ),
          ],
        ],
      ),
    );
  }
}
