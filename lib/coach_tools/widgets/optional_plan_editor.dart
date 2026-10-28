import 'package:flutter/material.dart';

import '../../colors.dart';
import '../models/manual_program_models.dart';
import 'coach_tools_common.dart';

class OptionalPlanEditor extends StatefulWidget {
  const OptionalPlanEditor({
    super.key,
    required this.title,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final List<OptionalPlanItemDraft> items;
  final VoidCallback onChanged;

  @override
  State<OptionalPlanEditor> createState() => _OptionalPlanEditorState();
}

class _OptionalPlanEditorState extends State<OptionalPlanEditor> {
  void _addItem() {
    setState(() => widget.items.add(OptionalPlanItemDraft()));
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
          itemCount: widget.items.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final item = widget.items.removeAt(oldIndex);
              widget.items.insert(newIndex, item);
            });
            widget.onChanged();
          },
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return Container(
              key: ValueKey(item.id),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceAltColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final handle = ReorderableDragStartListener(
                    index: index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: textFaintColor,
                        ),
                      ),
                    ),
                  );
                  final title = TextFormField(
                    key: ValueKey('${item.id}-title'),
                    initialValue: item.title,
                    onChanged: (value) => item.title = value,
                    decoration: coachInputDecoration(
                      labelText: 'نام ${widget.title}',
                      dense: true,
                    ),
                  );
                  final amount = TextFormField(
                    key: ValueKey('${item.id}-content'),
                    initialValue: item.content,
                    onChanged: (value) => item.content = value,
                    decoration: coachInputDecoration(
                      labelText: 'مقدار و زمان مصرف',
                      dense: true,
                    ),
                  );
                  final delete = IconButton(
                    tooltip: 'حذف',
                    onPressed: widget.items.length == 1
                        ? null
                        : () {
                            setState(() => widget.items.removeAt(index));
                            widget.onChanged();
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: dangerFgColor,
                  );
                  if (compact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            handle,
                            const Spacer(),
                            delete,
                          ],
                        ),
                        title,
                        const SizedBox(height: 8),
                        amount,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: handle,
                      ),
                      const SizedBox(width: 4),
                      Expanded(flex: 2, child: title),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: amount),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: delete,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: Text('افزودن ${widget.title}'),
          ),
        ),
      ],
    );
  }
}
