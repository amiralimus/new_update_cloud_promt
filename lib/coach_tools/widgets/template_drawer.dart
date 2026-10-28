import 'package:flutter/material.dart';

import '../../colors.dart';
import '../data/coach_tools_api.dart';
import '../models/coach_template.dart';
import 'coach_tools_common.dart';

class TemplateDrawer extends StatefulWidget {
  const TemplateDrawer({
    super.key,
    required this.onApply,
    required this.onOpenSettings,
  });

  final ValueChanged<CoachTemplate> onApply;
  final VoidCallback onOpenSettings;

  @override
  State<TemplateDrawer> createState() => _TemplateDrawerState();
}

class _TemplateDrawerState extends State<TemplateDrawer> {
  final CoachToolsApi _api = CoachToolsApi();
  bool _loading = true;
  TemplateCatalogResult? _result;
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
      final result = await _api.fetchTemplates();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
              decoration: BoxDecoration(
                color: primeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: primeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_outlined,
                      color: onPrimaryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تمپلیت‌ها',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'یک الگو را برای برنامه انتخاب کنید',
                          style: TextStyle(color: textMutedColor, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'به‌روزرسانی',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 21),
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 21),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('مدیریت تمپلیت‌ها'),
                  style: TextButton.styleFrom(
                    foregroundColor: primeColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const CoachLoadingState(label: 'دریافت تمپلیت‌ها...');
    if (_error != null) {
      return CoachErrorState(message: _error!, onRetry: _load);
    }
    final result = _result;
    if (result == null || result.templates.isEmpty) {
      return CoachEmptyState(
        title: result?.available == false
            ? 'سرویس تمپلیت متصل نیست'
            : 'تمپلیتی وجود ندارد',
        message: result?.message ?? 'از تنظیمات تمپلیت، اولین مورد را بسازید.',
        icon: Icons.dashboard_customize_outlined,
      );
    }

    final root = _TemplateTreeNode('root');
    for (final template in result.templates) {
      var current = root;
      final path = template.categoryPath.isEmpty
          ? <String>['بدون دسته‌بندی']
          : template.categoryPath;
      for (final segment in path) {
        current = current.children.putIfAbsent(
          segment,
          () => _TemplateTreeNode(segment),
        );
      }
      current.templates.add(template);
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: root.children.values
          .map((node) => _TemplateTreeTile(node: node, onApply: widget.onApply))
          .toList(),
    );
  }
}

class _TemplateTreeNode {
  _TemplateTreeNode(this.title);

  final String title;
  final Map<String, _TemplateTreeNode> children = {};
  final List<CoachTemplate> templates = [];
}

class _TemplateTreeTile extends StatelessWidget {
  const _TemplateTreeTile({required this.node, required this.onApply});

  final _TemplateTreeNode node;
  final ValueChanged<CoachTemplate> onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: surfaceAltColor,
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 13),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder_outlined,
              color: primeColor,
              size: 18,
            ),
          ),
          title: Text(
            node.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          children: [
            ...node.children.values.map(
              (child) => _TemplateTreeTile(node: child, onApply: onApply),
            ),
            ...node.templates.map(
              (template) => Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  leading: Icon(
                    template.serverOwned
                        ? Icons.verified_outlined
                        : Icons.person_outline_rounded,
                    color: template.serverOwned ? infoFgColor : primeColor,
                  ),
                  title: Text(
                    template.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    template.applyMode.label,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: TextButton(
                    onPressed: () => onApply(template),
                    style: TextButton.styleFrom(
                      foregroundColor: primeColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                    ),
                    child: const Text('اعمال'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
