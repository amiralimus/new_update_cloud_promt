import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;

/// کارت «کد یکبارمصرف دانلود» که مربی به ورزشکار می‌دهد.
///
/// چرا کارت مستقل و نه یک دیالوگ ساده: این کد یک‌بارمصرف است و مربی باید
/// بتواند بدون بستن کارت آن را ببیند، مخفی کند، کپی کند یا کد تازه بگیرد.
/// هر کدام از این‌ها اگر یک دیالوگ جدا می‌شد، مربی وسط کار کد قبلی را گم
/// می‌کرد.
Future<void> showShareCodeCard({
  required BuildContext context,
  required int programId,
  required String programName,
  required bool hasWorkout,
  required bool hasMealPlan,
  required String initialSection,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: scrimColor,
    builder: (_) => _ShareCodeCard(
      programId: programId,
      programName: programName,
      hasWorkout: hasWorkout,
      hasMealPlan: hasMealPlan,
      initialSection: initialSection,
    ),
  );
}

class _ShareCodeCard extends StatefulWidget {
  const _ShareCodeCard({
    required this.programId,
    required this.programName,
    required this.hasWorkout,
    required this.hasMealPlan,
    required this.initialSection,
  });

  final int programId;
  final String programName;
  final bool hasWorkout;
  final bool hasMealPlan;
  final String initialSection;

  @override
  State<_ShareCodeCard> createState() => _ShareCodeCardState();
}

class _ShareCodeCardState extends State<_ShareCodeCard> {
  final ApiService _apiService = ApiService();

  late String _section = widget.initialSection;
  String? _code;
  bool _isLoading = true;
  bool _isHidden = false;
  String? _error;

  /// فقط وقتی برنامه هر دو بخش را دارد، انتخاب بخش معنا دارد.
  bool get _sectionChoiceMatters => widget.hasWorkout && widget.hasMealPlan;

  @override
  void initState() {
    super.initState();
    _fetchCode();
  }

  Future<void> _fetchCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.post(
      endpoint: ServerEndpoints.programShareCode(widget.programId),
      body: {'section': _section},
    );

    if (!mounted) return;

    if (!response.success || response.data is! Map) {
      setState(() {
        _isLoading = false;
        _error = response.error ?? 'ساخت کد ناموفق بود.';
      });
      return;
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final code = (data['code'] ?? '').toString();

    setState(() {
      _isLoading = false;
      _code = code.isEmpty ? null : code;
      _error = code.isEmpty ? 'کد از سرور دریافت نشد.' : null;
      _isHidden = false;
    });
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('کد کپی شد'),
          backgroundColor: okFgColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _changeSection(String next) {
    if (next == _section) return;
    setState(() => _section = next);
    // کد قبلی به بخش قبلی گره خورده است و با تغییر بخش دیگر همان چیزی را
    // نمی‌دهد که مربی انتظار دارد؛ پس کد تازه گرفته می‌شود.
    _fetchCode();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 400
                ? constraints.maxWidth
                : 380.0;
            return Center(
              child: SingleChildScrollView(
                child: Container(
                  width: width,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 34,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      if (_sectionChoiceMatters) ...[
                        _sectionPicker(),
                        const SizedBox(height: 14),
                      ],
                      _codeBox(),
                      const SizedBox(height: 14),
                      _actions(),
                      const SizedBox(height: 14),
                      _note(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            backgroundColor: surfaceMutedColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'بستن',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.shield_outlined, color: primeColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'کد یکبارمصرف دانلود',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.programName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: textMutedColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionPicker() {
    const options = <String, String>{
      'both': 'هر دو',
      'workout': 'ورزشی',
      'meal': 'غذایی',
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceMutedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : () => _changeSection(entry.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _section == entry.key
                        ? primeColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _section == entry.key
                          ? onPrimaryColor
                          : textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _codeBox() {
    return Container(
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primeColor.withValues(alpha: 0.28)),
      ),
      child: _buildCodeContent(),
    );
  }

  Widget _buildCodeContent() {
    if (_isLoading) {
      return SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(primeColor),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: dangerFgColor),
        ),
      );
    }

    final code = _code ?? '';
    // نقطه‌چین به همان تعداد رقم کد ساخته می‌شود تا طول کادر با مخفی‌شدن
    // کد نپرد.
    final shown = _isHidden ? '•' * code.length : code;

    return Text(
      shown,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: 10,
        color: primeColor,
      ),
    );
  }

  Widget _actions() {
    final bool ready = !_isLoading && _code != null;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: _isHidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            label: _isHidden ? 'نمایش' : 'مخفی',
            onTap: ready ? () => setState(() => _isHidden = !_isHidden) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_rounded,
            label: 'کپی',
            onTap: ready ? _copy : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.autorenew_rounded,
            label: 'کد جدید',
            onTap: _isLoading ? null : _fetchCode,
          ),
        ),
      ],
    );
  }

  Widget _note() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warnBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: warnFgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'این کد فقط برای دانلود همین برنامه توسط ورزشکار است و یک‌بار '
              'مصرف می‌شود؛ به‌محض استفاده منقضی و نامعتبر می‌شود.',
              style: TextStyle(
                fontSize: 11.8,
                height: 1.6,
                color: warnFgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color fg = enabled ? textSecondaryColor : textFaintColor;

    return Material(
      color: surfaceMutedColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
