import 'package:flutter/material.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/coach_template.dart';
import '../models/manual_program_models.dart';
import '../widgets/coach_tools_common.dart';
import '../widgets/nutrition_editor.dart';
import '../widgets/optional_plan_editor.dart';
import '../widgets/training_editor.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  final CoachToolsApi _api = CoachToolsApi();
  TemplateCatalogResult? _catalog;
  CoachTemplate? _editing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _api.fetchTemplates();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CoachTemplate _freshTemplate() {
    return CoachTemplate(
      id: '',
      title: '',
      sessions: [TrainingSessionDraft()],
      mealDays: List.generate(7, (index) => MealDayDraft(dayNumber: index + 1)),
      supplements: [OptionalPlanItemDraft()],
      medications: [OptionalPlanItemDraft()],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editing != null) {
      return TemplateEditorView(
        template: _editing!,
        onCancel: () => setState(() => _editing = null),
        onSaved: () {
          setState(() => _editing = null);
          _load();
        },
      );
    }

    return CoachPageFrame(
      title: 'مدیریت تمپلیت‌ها',
      onBack: widget.onBack,
      actions: [
        FilledButton.icon(
          onPressed: () => setState(() => _editing = _freshTemplate()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('ساخت تمپلیت جدید'),
        ),
      ],
      body: _buildCatalog(),
    );
  }

  Widget _buildCatalog() {
    if (_loading) {
      return const CoachLoadingState(label: 'در حال دریافت تمپلیت‌ها...');
    }
    if (_error != null) {
      return CoachErrorState(message: _error!, onRetry: _load);
    }
    final catalog = _catalog;
    if (catalog == null || catalog.templates.isEmpty) {
      return CoachSurface(
        child: CoachEmptyState(
          title: catalog?.available == false
              ? 'بخش فرانت آماده است'
              : 'هنوز تمپلیتی وجود ندارد',
          message:
              catalog?.message ?? 'برای شروع، تمپلیت اختصاصی خود را بسازید.',
          icon: Icons.dashboard_customize_outlined,
          action: FilledButton.tonalIcon(
            onPressed: () => setState(() => _editing = _freshTemplate()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ساخت اولین تمپلیت'),
          ),
        ),
      );
    }

    final root = _TemplateNode('root');
    for (final template in catalog.templates) {
      var current = root;
      final path = template.categoryPath.isEmpty
          ? <String>['بدون دسته‌بندی']
          : template.categoryPath;
      for (final segment in path) {
        current = current.children.putIfAbsent(
          segment,
          () => _TemplateNode(segment),
        );
      }
      current.templates.add(template);
    }

    return ListView(
      children: root.children.values
          .map(
            (node) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TemplateCatalogNode(
                node: node,
                onOpen: _showTemplateDetails,
                onEdit: (template) => setState(() => _editing = template),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showTemplateDetails(CoachTemplate template) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.title),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(template.categoryLabel)),
                    Chip(label: Text(template.applyMode.label)),
                    Chip(
                      label: Text(
                        template.serverOwned ? 'سیستمی' : 'اختصاصی مربی',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (template.sessions.isEmpty)
                  const Text(
                    'جلسه تمرینی ثبت نشده است.',
                    style: TextStyle(color: textMutedColor),
                  )
                else
                  ...template.sessions.asMap().entries.map((entry) {
                    final session = entry.value;
                    return ExpansionTile(
                      title: Text(
                        session.title.trim().isEmpty
                            ? 'جلسه ${entry.key + 1}'
                            : session.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      children: session.exercises
                          .map(
                            (exercise) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.fitness_center_rounded,
                                size: 18,
                              ),
                              title: Text(exercise.name),
                              subtitle: Text(
                                [
                                  if (exercise.sets.isNotEmpty)
                                    '${exercise.sets} ست',
                                  if (exercise.reps.isNotEmpty)
                                    '${exercise.reps} تکرار',
                                  if (exercise.rest.isNotEmpty)
                                    '${exercise.rest} ثانیه استراحت',
                                ].join(' • '),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
}

class _TemplateNode {
  _TemplateNode(this.title);

  final String title;
  final Map<String, _TemplateNode> children = {};
  final List<CoachTemplate> templates = [];
}

class _TemplateCatalogNode extends StatelessWidget {
  const _TemplateCatalogNode({
    required this.node,
    required this.onOpen,
    required this.onEdit,
  });

  final _TemplateNode node;
  final ValueChanged<CoachTemplate> onOpen;
  final ValueChanged<CoachTemplate> onEdit;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          node.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: [
          ...node.children.values.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TemplateCatalogNode(
                node: child,
                onOpen: onOpen,
                onEdit: onEdit,
              ),
            ),
          ),
          ...node.templates.map(
            (template) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: surfaceMutedColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => onOpen(template),
                leading: Icon(
                  template.serverOwned
                      ? Icons.verified_outlined
                      : Icons.person_outline_rounded,
                  color: template.serverOwned ? infoFgColor : primeColor,
                ),
                title: Text(
                  template.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${template.applyMode.label} • ${template.sessions.length} جلسه',
                ),
                trailing: template.serverOwned
                    ? const Icon(Icons.visibility_outlined)
                    : IconButton(
                        tooltip: 'ویرایش',
                        onPressed: () => onEdit(template),
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TemplateEditorView extends StatefulWidget {
  const TemplateEditorView({
    super.key,
    required this.template,
    required this.onCancel,
    required this.onSaved,
  });

  final CoachTemplate template;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<TemplateEditorView> createState() => _TemplateEditorViewState();
}

enum _TemplateEditorSection { workout, nutrition, supplements, medications }

class _TemplateEditorViewState extends State<TemplateEditorView> {
  final CoachToolsApi _api = CoachToolsApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  bool _saving = false;
  _TemplateEditorSection _activeSection = _TemplateEditorSection.workout;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.template.title);
    _categoryController = TextEditingController(
      text: widget.template.categoryPath.join(' / '),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    widget.template
      ..title = _titleController.text.trim()
      ..categoryPath = _categoryController.text
          .split(RegExp(r'[/،>]'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    try {
      final result = await _api.saveTemplate(widget.template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? okFgColor : warnFgColor,
        ),
      );
      if (result.success) widget.onSaved();
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

  @override
  Widget build(BuildContext context) {
    return CoachPageFrame(
      title: widget.template.title.trim().isEmpty
          ? 'ساخت تمپلیت جدید'
          : 'ویرایش تمپلیت',
      onBack: widget.onCancel,
      actions: [
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onPrimaryColor,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره تمپلیت'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            CoachSurface(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 700;
                  final fields = [
                    TextFormField(
                      controller: _titleController,
                      decoration: coachInputDecoration(
                        labelText: 'عنوان تمپلیت',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'عنوان تمپلیت لازم است.'
                          : null,
                    ),
                    TextFormField(
                      controller: _categoryController,
                      decoration: coachInputDecoration(
                        labelText: 'دسته‌بندی',
                        hintText: 'مثلاً گرم‌کردن / سطح متوسط',
                      ),
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      children: [
                        ...fields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: field,
                          ),
                        ),
                        _ApplyModeSelector(
                          value: widget.template.applyMode,
                          onChanged: (mode) =>
                              setState(() => widget.template.applyMode = mode),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 10),
                          Expanded(child: fields[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ApplyModeSelector(
                        value: widget.template.applyMode,
                        onChanged: (mode) =>
                            setState(() => widget.template.applyMode = mode),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTabs(),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_activeSection),
                child: _buildActiveSection(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
    final tabs =
        <
          ({
            _TemplateEditorSection section,
            String label,
            IconData icon,
          })
        >[
          (
            section: _TemplateEditorSection.workout,
            label: 'تمرین',
            icon: Icons.fitness_center_rounded,
          ),
          (
            section: _TemplateEditorSection.nutrition,
            label: 'تغذیه',
            icon: Icons.restaurant_menu_rounded,
          ),
          (
            section: _TemplateEditorSection.supplements,
            label: 'مکمل',
            icon: Icons.medication_liquid_outlined,
          ),
          (
            section: _TemplateEditorSection.medications,
            label: 'دارو',
            icon: Icons.medication_outlined,
          ),
        ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tabs.map((tab) {
        final selected = _activeSection == tab.section;
        return ChoiceChip(
          selected: selected,
          showCheckmark: false,
          avatar: Icon(
            tab.icon,
            size: 18,
            color: selected ? onPrimaryColor : primeColor,
          ),
          label: Text(tab.label),
          selectedColor: primeColor,
          labelStyle: TextStyle(
            color: selected ? onPrimaryColor : textPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
          onSelected: (_) => setState(() => _activeSection = tab.section),
        );
      }).toList(),
    );
  }

  Widget _buildActiveSection() {
    switch (_activeSection) {
      case _TemplateEditorSection.workout:
        return _TemplateSection(
          title: 'جلسه‌های تمرینی',
          child: TrainingEditor(
            sessions: widget.template.sessions,
            onChanged: () => setState(() {}),
          ),
        );
      case _TemplateEditorSection.nutrition:
        return _TemplateSection(
          title: 'برنامه غذایی',
          child: NutritionEditor(
            days: widget.template.mealDays,
            prompt: '',
            showModeSelector: false,
            onPromptChanged: (_) {},
            onChanged: () => setState(() {}),
          ),
        );
      case _TemplateEditorSection.supplements:
        return _TemplateSection(
          title: 'مکمل‌ها',
          child: OptionalPlanEditor(
            title: 'مکمل',
            items: widget.template.supplements,
            onChanged: () => setState(() {}),
          ),
        );
      case _TemplateEditorSection.medications:
        return _TemplateSection(
          title: 'داروها',
          child: OptionalPlanEditor(
            title: 'دارو',
            items: widget.template.medications,
            onChanged: () => setState(() {}),
          ),
        );
    }
  }
}

class _ApplyModeSelector extends StatelessWidget {
  const _ApplyModeSelector({required this.value, required this.onChanged});

  final TemplateApplyMode value;
  final ValueChanged<TemplateApplyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        mode: TemplateApplyMode.replace,
        label: 'جایگزینی',
        icon: Icons.swap_horiz_rounded,
      ),
      (
        mode: TemplateApplyMode.prepend,
        label: 'ابتدای جلسه',
        icon: Icons.vertical_align_top_rounded,
      ),
      (
        mode: TemplateApplyMode.append,
        label: 'انتهای جلسه',
        icon: Icons.vertical_align_bottom_rounded,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: Material(
              color: value == items[index].mode
                  ? primeColor.withValues(alpha: 0.10)
                  : surfaceAltColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: value == items[index].mode ? primeColor : borderColor,
                ),
              ),
              child: InkWell(
                onTap: () => onChanged(items[index].mode),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        items[index].icon,
                        size: 20,
                        color: value == items[index].mode
                            ? primeColor
                            : textMutedColor,
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[index].label,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (index != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TemplateSection extends StatelessWidget {
  const _TemplateSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
