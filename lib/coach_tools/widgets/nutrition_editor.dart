import 'package:flutter/material.dart';

import '../../colors.dart';
import '../models/manual_program_models.dart';
import 'coach_tools_common.dart';

enum NutritionEditorMode { manual, ai }

class NutritionEditor extends StatefulWidget {
  const NutritionEditor({
    super.key,
    required this.days,
    required this.prompt,
    required this.onPromptChanged,
    required this.onChanged,
    this.mode = NutritionEditorMode.manual,
    this.onModeChanged,
    this.showModeSelector = true,
  });

  final List<MealDayDraft> days;
  final String prompt;
  final ValueChanged<String> onPromptChanged;
  final VoidCallback onChanged;
  final NutritionEditorMode mode;
  final ValueChanged<NutritionEditorMode>? onModeChanged;
  final bool showModeSelector;

  @override
  State<NutritionEditor> createState() => _NutritionEditorState();
}

class _NutritionEditorState extends State<NutritionEditor> {
  int _selectedDayIndex = 0;

  void _addMeal(MealDayDraft day) {
    setState(() {
      day.enabled = true;
      day.meals.add(MealDraft());
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showModeSelector) ...[
          _NutritionModeSelector(
            mode: widget.mode,
            onChanged: widget.onModeChanged ?? (_) {},
          ),
          const SizedBox(height: 16),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: widget.mode == NutritionEditorMode.ai
              ? _buildAiEditor()
              : _buildManualEditor(),
        ),
      ],
    );
  }

  Widget _buildAiEditor() {
    return TextFormField(
      key: const ValueKey('nutrition-ai-prompt'),
      initialValue: widget.prompt,
      onChanged: widget.onPromptChanged,
      minLines: 4,
      maxLines: 7,
      decoration: coachInputDecoration(
        labelText: 'برنامه غذایی موردنظر را بنویسید',
      ),
      validator: (value) {
        if (widget.mode == NutritionEditorMode.ai &&
            (value == null || value.trim().isEmpty)) {
          return 'درخواست برنامه غذایی را بنویسید.';
        }
        return null;
      },
    );
  }

  Widget _buildManualEditor() {
    if (widget.days.isEmpty) return const SizedBox.shrink();
    if (_selectedDayIndex >= widget.days.length) _selectedDayIndex = 0;
    final day = widget.days[_selectedDayIndex];
    return Column(
      key: const ValueKey('nutrition-manual'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final item = widget.days[index];
              final hasContent = item.meals.any(
                (meal) =>
                    meal.title.trim().isNotEmpty ||
                    meal.content.trim().isNotEmpty,
              );
              return ChoiceChip(
                selected: index == _selectedDayIndex,
                showCheckmark: false,
                avatar: hasContent
                    ? const Icon(Icons.check_rounded, size: 16)
                    : null,
                label: Text('روز ${item.dayNumber}'),
                onSelected: (_) => setState(() => _selectedDayIndex = index),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        CoachSurface(
          color: surfaceAltColor,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'روز ${day.dayNumber}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  FilterChip(
                    selected: day.calculateNutrition,
                    showCheckmark: false,
                    avatar: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: const Text('محاسبه هوشمند'),
                    onSelected: (value) {
                      setState(() => day.calculateNutrition = value);
                      widget.onChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: day.meals.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final meal = day.meals.removeAt(oldIndex);
                    day.meals.insert(newIndex, meal);
                  });
                  widget.onChanged();
                },
                itemBuilder: (context, index) => _MealEditor(
                  key: ValueKey(day.meals[index].id),
                  meal: day.meals[index],
                  index: index,
                  canDelete: day.meals.length > 1,
                  onChanged: () {
                    day.enabled = true;
                    widget.onChanged();
                  },
                  onDelete: () {
                    setState(() => day.meals.removeAt(index));
                    widget.onChanged();
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _addMeal(day),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن وعده'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NutritionModeSelector extends StatelessWidget {
  const _NutritionModeSelector({required this.mode, required this.onChanged});

  final NutritionEditorMode mode;
  final ValueChanged<NutritionEditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceMutedColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'دستی',
              icon: Icons.edit_outlined,
              selected: mode == NutritionEditorMode.manual,
              onTap: () => onChanged(NutritionEditorMode.manual),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeButton(
              label: 'با هوش مصنوعی',
              icon: Icons.auto_awesome_rounded,
              selected: mode == NutritionEditorMode.ai,
              onTap: () => onChanged(NutritionEditorMode.ai),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? surfaceColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? primeColor : textMutedColor),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? textPrimaryColor : textMutedColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealEditor extends StatelessWidget {
  const _MealEditor({
    super.key,
    required this.meal,
    required this.index,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final MealDraft meal;
  final int index;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 580;
          final handle = ReorderableDragStartListener(
            index: index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.drag_indicator_rounded, color: textFaintColor),
              ),
            ),
          );
          final title = TextFormField(
            key: ValueKey('${meal.id}-title'),
            initialValue: meal.title,
            onChanged: (value) {
              meal.title = value;
              onChanged();
            },
            decoration: coachInputDecoration(
              labelText: 'عنوان وعده',
              dense: true,
            ),
          );
          final content = TextFormField(
            key: ValueKey('${meal.id}-content'),
            initialValue: meal.content,
            onChanged: (value) {
              meal.content = value;
              onChanged();
            },
            minLines: 1,
            maxLines: 3,
            decoration: coachInputDecoration(
              labelText: 'مواد غذایی و مقدار',
              dense: true,
            ),
          );
          final delete = IconButton(
            tooltip: 'حذف وعده',
            onPressed: canDelete ? onDelete : null,
            icon: const Icon(Icons.delete_outline_rounded),
            color: dangerFgColor,
          );
          if (compact) {
            return Column(
              children: [
                Row(
                  children: [handle, const Spacer(), delete],
                ),
                title,
                const SizedBox(height: 8),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 5), child: handle),
              const SizedBox(width: 4),
              Expanded(flex: 2, child: title),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: content),
              Padding(padding: const EdgeInsets.only(top: 3), child: delete),
            ],
          );
        },
      ),
    );
  }
}
