import 'package:flutter/material.dart';

import '../../colors.dart';
import '../models/manual_program_models.dart';
import 'coach_tools_common.dart';
import 'exercise_picker.dart';

class TrainingEditor extends StatefulWidget {
  const TrainingEditor({
    super.key,
    required this.sessions,
    required this.onChanged,
    this.onSessionAdded,
  });

  final List<TrainingSessionDraft> sessions;
  final VoidCallback onChanged;
  final ValueChanged<int>? onSessionAdded;

  @override
  State<TrainingEditor> createState() => _TrainingEditorState();
}

class _TrainingEditorState extends State<TrainingEditor> {
  Future<void> _pickExercises(TrainingSessionDraft session) async {
    final selected = await showExercisePicker(context);
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() {
      for (final exercise in selected) {
        session.exercises.add(ProgramExerciseDraft.fromExercise(exercise));
      }
    });
    widget.onChanged();
  }

  void _addManualExercise(TrainingSessionDraft session) {
    setState(() => session.exercises.add(ProgramExerciseDraft()));
    widget.onChanged();
  }

  void _addSession() {
    if (widget.sessions.length >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداکثر ۷ جلسه می‌توانید بسازید.')),
      );
      return;
    }
    setState(() => widget.sessions.add(TrainingSessionDraft()));
    widget.onSessionAdded?.call(widget.sessions.length - 1);
    widget.onChanged();
  }

  Future<void> _removeSession(int index) async {
    if (widget.sessions.length == 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جلسه'),
        content: const Text('این جلسه و حرکت‌های داخل آن حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => widget.sessions.removeAt(index));
    widget.onChanged();
  }

  Future<void> _createSuperset(TrainingSessionDraft session) async {
    if (session.exercises.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای ساخت سوپرست حداقل دو حرکت لازم است.'),
        ),
      );
      return;
    }
    final selectedIds = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _SupersetSelectionDialog(session: session),
    );
    if (selectedIds == null || selectedIds.length < 2 || !mounted) return;

    setState(() {
      for (final existing in session.supersets.toList()) {
        existing.exerciseLocalIds.removeWhere(selectedIds.contains);
        if (existing.exerciseLocalIds.length < 2) {
          for (final exercise in session.exercises) {
            if (exercise.supersetId == existing.id) exercise.supersetId = null;
          }
          session.supersets.remove(existing);
        }
      }

      final selectedExercises = session.exercises
          .where((exercise) => selectedIds.contains(exercise.localId))
          .toList();
      final firstIndex = session.exercises.indexWhere(
        (exercise) => selectedIds.contains(exercise.localId),
      );
      session.exercises.removeWhere(
        (exercise) => selectedIds.contains(exercise.localId),
      );
      session.exercises.insertAll(firstIndex, selectedExercises);

      final superset = SupersetDraft(
        exerciseLocalIds: selectedExercises
            .map((exercise) => exercise.localId)
            .toList(),
      );
      session.supersets.add(superset);
      for (final exercise in selectedExercises) {
        exercise.supersetId = superset.id;
      }
    });
    widget.onChanged();
  }

  void _removeSuperset(TrainingSessionDraft session, SupersetDraft superset) {
    setState(() {
      for (final exercise in session.exercises) {
        if (exercise.supersetId == superset.id) exercise.supersetId = null;
      }
      session.supersets.removeWhere((item) => item.id == superset.id);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: widget.sessions.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final session = widget.sessions.removeAt(oldIndex);
              widget.sessions.insert(newIndex, session);
            });
            widget.onChanged();
          },
          itemBuilder: (context, index) {
            final session = widget.sessions[index];
            return Padding(
              key: ValueKey(session.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _SessionEditorCard(
                index: index,
                session: session,
                canDelete: widget.sessions.length > 1,
                onDelete: () => _removeSession(index),
                onPickExercises: () => _pickExercises(session),
                onAddManualExercise: () => _addManualExercise(session),
                onCreateSuperset: () => _createSuperset(session),
                onRemoveSuperset: (superset) =>
                    _removeSuperset(session, superset),
                onChanged: () {
                  setState(() {});
                  widget.onChanged();
                },
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: widget.sessions.length >= 7 ? null : _addSession,
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن جلسه'),
          ),
        ),
      ],
    );
  }
}

class _SessionEditorCard extends StatelessWidget {
  const _SessionEditorCard({
    required this.index,
    required this.session,
    required this.canDelete,
    required this.onDelete,
    required this.onPickExercises,
    required this.onAddManualExercise,
    required this.onCreateSuperset,
    required this.onRemoveSuperset,
    required this.onChanged,
  });

  final int index;
  final TrainingSessionDraft session;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onPickExercises;
  final VoidCallback onAddManualExercise;
  final VoidCallback onCreateSuperset;
  final ValueChanged<SupersetDraft> onRemoveSuperset;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: ReorderableDragStartListener(
          index: index,
          child: const MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(Icons.drag_indicator_rounded, color: textFaintColor),
          ),
        ),
        title: Text(
          session.title.trim().isEmpty
              ? 'جلسه ${index + 1}'
              : 'جلسه ${index + 1} — ${session.title}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: canDelete
            ? IconButton(
                tooltip: 'حذف جلسه',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: dangerFgColor,
                ),
              )
            : null,
        children: [
          TextFormField(
            key: ValueKey('${session.id}-title'),
            initialValue: session.title,
            onChanged: (value) {
              session.title = value;
              onChanged();
            },
            decoration: coachInputDecoration(labelText: 'عنوان جلسه'),
          ),
          const SizedBox(height: 12),
          if (session.exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: CoachEmptyState(
                title: 'هنوز حرکتی اضافه نشده',
                message: 'از کتابخانه انتخاب کنید یا حرکت را دستی بنویسید.',
                icon: Icons.fitness_center_rounded,
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: session.exercises.length,
              onReorderItem: (oldIndex, newIndex) {
                final exercise = session.exercises.removeAt(oldIndex);
                session.exercises.insert(newIndex, exercise);
                onChanged();
              },
              itemBuilder: (context, exerciseIndex) {
                final exercise = session.exercises[exerciseIndex];
                final superset = session.supersetFor(exercise.supersetId);
                final firstInGroup =
                    superset != null &&
                    superset.exerciseLocalIds.isNotEmpty &&
                    superset.exerciseLocalIds.first == exercise.localId;
                return Padding(
                  key: ValueKey(exercise.localId),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExerciseEditorTile(
                    index: exerciseIndex,
                    exercise: exercise,
                    superset: superset,
                    firstInGroup: firstInGroup,
                    onRemoveSuperset: superset == null
                        ? null
                        : () => onRemoveSuperset(superset),
                    onDelete: () {
                      session.removeExerciseAt(exerciseIndex);
                      onChanged();
                    },
                    onChanged: onChanged,
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPickExercises,
                icon: const Icon(Icons.library_add_outlined),
                label: const Text('افزودن از کتابخانه حرکات'),
              ),
              OutlinedButton.icon(
                onPressed: onAddManualExercise,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('حرکت دستی'),
              ),
              OutlinedButton.icon(
                onPressed: session.exercises.length < 2
                    ? null
                    : onCreateSuperset,
                icon: const Icon(Icons.link_rounded),
                label: const Text('ساخت سوپرست'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseEditorTile extends StatelessWidget {
  const _ExerciseEditorTile({
    required this.index,
    required this.exercise,
    required this.superset,
    required this.firstInGroup,
    required this.onDelete,
    required this.onChanged,
    this.onRemoveSuperset,
  });

  final int index;
  final ProgramExerciseDraft exercise;
  final SupersetDraft? superset;
  final bool firstInGroup;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback? onRemoveSuperset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: superset == null ? surfaceAltColor : infoBgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: superset == null
              ? borderColor
              : infoFgColor.withValues(alpha: 0.34),
          width: superset == null ? 1 : 1.4,
        ),
      ),
      child: Column(
        children: [
          if (firstInGroup && superset != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 470;
                final label = const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, color: infoFgColor, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'گروه سوپرست',
                      style: TextStyle(
                        color: infoFgColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
                final rounds = SizedBox(
                  width: compact ? 125 : 105,
                  child: TextFormField(
                    key: ValueKey('${superset!.id}-rounds'),
                    initialValue: superset!.rounds,
                    onChanged: (value) {
                      superset!.rounds = value;
                      onChanged();
                    },
                    keyboardType: TextInputType.number,
                    decoration: coachInputDecoration(
                      labelText: 'تعداد دور',
                      dense: true,
                    ),
                  ),
                );
                final unlink = TextButton.icon(
                  onPressed: onRemoveSuperset,
                  icon: const Icon(Icons.link_off_rounded, size: 17),
                  label: const Text('جدا کردن'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label,
                      const SizedBox(height: 8),
                      Row(children: [rounds, const Spacer(), unlink]),
                    ],
                  );
                }
                return Row(
                  children: [
                    label,
                    const SizedBox(width: 10),
                    rounds,
                    const Spacer(),
                    unlink,
                  ],
                );
              },
            ),
            const Divider(height: 18),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: textFaintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 4,
                child: TextFormField(
                  key: ValueKey('${exercise.localId}-name'),
                  initialValue: exercise.name,
                  onChanged: (value) => exercise.name = value,
                  decoration: coachInputDecoration(
                    labelText: 'نام حرکت ${index + 1}',
                    hintText: 'نام حرکت را بنویسید',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'حذف حرکت',
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, color: dangerFgColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final fieldWidth = width < 560
                  ? (width - 8) / 2
                  : (width - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallField(exercise, 'sets', 'ست', fieldWidth),
                  _smallField(exercise, 'reps', 'تکرار', fieldWidth),
                  _smallField(exercise, 'rest', 'استراحت (ثانیه)', fieldWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _smallField(
    ProgramExerciseDraft exercise,
    String field,
    String label,
    double width,
  ) {
    String value() => switch (field) {
      'sets' => exercise.sets,
      'reps' => exercise.reps,
      'rest' => exercise.rest,
      _ => exercise.rest,
    };
    void update(String input) {
      switch (field) {
        case 'sets':
          exercise.sets = input;
        case 'reps':
          exercise.reps = input;
        case 'rest':
          exercise.rest = input;
        default:
          exercise.rest = input;
      }
    }

    return SizedBox(
      width: width,
      child: TextFormField(
        key: ValueKey('${exercise.localId}-$field'),
        initialValue: value(),
        onChanged: update,
        keyboardType: TextInputType.number,
        decoration: coachInputDecoration(labelText: label, dense: true),
      ),
    );
  }
}

class _SupersetSelectionDialog extends StatefulWidget {
  const _SupersetSelectionDialog({required this.session});

  final TrainingSessionDraft session;

  @override
  State<_SupersetSelectionDialog> createState() =>
      _SupersetSelectionDialogState();
}

class _SupersetSelectionDialogState extends State<_SupersetSelectionDialog> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ساخت سوپرست'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'دو یا چند حرکت را انتخاب کنید. ست و تکرار هر حرکت جدا می‌ماند.',
              style: TextStyle(color: textMutedColor, height: 1.5),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.session.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = widget.session.exercises[index];
                  final selected = _selected.contains(exercise.localId);
                  return CheckboxListTile(
                    value: selected,
                    title: Text(
                      exercise.name.trim().isEmpty
                          ? 'حرکت ${index + 1}'
                          : exercise.name,
                    ),
                    subtitle: Text(
                      [
                        if (exercise.sets.trim().isNotEmpty)
                          '${exercise.sets} ست',
                        if (exercise.reps.trim().isNotEmpty)
                          '${exercise.reps} تکرار',
                      ].join(' • '),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(exercise.localId);
                        } else {
                          _selected.remove(exercise.localId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _selected.length < 2
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('ساخت گروه'),
        ),
      ],
    );
  }
}
