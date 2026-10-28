import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../core/network/api_config.dart';
import '../../core/network/server_endpoints.dart';
import '../../core/platform/pdf_saver.dart';
import '../../rigester-login/token_manegment.dart';
import 'coach_tools_common.dart';

class ProgramResultCard extends StatefulWidget {
  const ProgramResultCard({
    super.key,
    required this.programId,
    required this.programType,
    required this.athleteName,
    required this.onClose,
    this.title = 'برنامه آماده است',
  });

  final int programId;
  final String programType;
  final String athleteName;
  final String title;
  final VoidCallback onClose;

  @override
  State<ProgramResultCard> createState() => _ProgramResultCardState();
}

class _ProgramResultCardState extends State<ProgramResultCard>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AuthTokenService _authTokenService = AuthTokenService();
  final TextEditingController _feedbackController = TextEditingController();
  final FocusNode _feedbackFocus = FocusNode();

  bool _downloading = false;
  bool _editing = false;
  bool _edited = false;
  String? _error;

  late final AnimationController _arrivalController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1)
      .animate(
        CurvedAnimation(parent: _arrivalController, curve: Curves.elasticOut),
      );

  @override
  void dispose() {
    _feedbackController.dispose();
    _feedbackFocus.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  String get _pdfEndpoint {
    switch (widget.programType) {
      case 'workout':
        return ServerEndpoints.programPdfWorkout(widget.programId);
      case 'meal':
        return ServerEndpoints.programPdfMeal(widget.programId);
      default:
        return ServerEndpoints.programPdf(widget.programId);
    }
  }

  String get _typeLabel {
    switch (widget.programType) {
      case 'workout':
        return 'برنامه ورزشی';
      case 'meal':
        return 'برنامه غذایی';
      default:
        return 'برنامه ورزشی و غذایی';
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      if (!await _authTokenService.isLoggedIn()) {
        throw Exception('ابتدا وارد حساب کاربری شوید.');
      }
      final bytes = await _apiService.getBytes(endpoint: _pdfEndpoint);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('دریافت فایل ناموفق بود. دوباره تلاش کنید.');
      }
      await savePdf(
        bytes,
        'program_${widget.programId}_${widget.programType}.pdf',
      );
      if (mounted) _showMessage('PDF با موفقیت دانلود شد.', ok: true);
    } catch (error) {
      if (mounted) {
        _showMessage('خطا در دانلود: ${_cleanError(error)}', ok: false);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _submitEdit() async {
    final feedback = _feedbackController.text.trim();
    if (feedback.isEmpty) {
      setState(() => _error = 'تغییر موردنظرتان را بنویسید.');
      _feedbackFocus.requestFocus();
      return;
    }
    if (_editing) return;
    setState(() {
      _editing = true;
      _error = null;
    });
    try {
      final response = await _apiService.post(
        endpoint: ServerEndpoints.programEdit(widget.programId),
        body: {
          'feedback': feedback,
          'generate_pdf': false,
          'pdf_type': widget.programType,
        },
        timeout: ApiConfig.programGenerationTimeout,
      );
      if (!response.success) {
        throw Exception(response.error ?? 'ویرایش برنامه ناموفق بود.');
      }
      if (!mounted) return;
      setState(() {
        _editing = false;
        _edited = true;
        _feedbackController.clear();
      });
      _arrivalController.forward(from: 0);
      _showMessage('برنامه با موفقیت ویرایش شد.', ok: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _editing = false;
        _error = _cleanError(error);
      });
      _showMessage('ویرایش انجام نشد: ${_cleanError(error)}', ok: false);
    }
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

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 850;
        final fileCard = ScaleTransition(
          scale: _scale,
          child: _buildFileCard(),
        );
        final editPanel = _buildEditPanel();
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: fileCard),
              const SizedBox(width: 20),
              Expanded(child: editPanel),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [fileCard, const SizedBox(height: 16), editPanel],
          ),
        );
      },
    );
  }

  Widget _buildFileCard() {
    final now = DateTime.now();
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: shadowColor, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: okBgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: okFgColor, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _edited ? 'نسخه ویرایش‌شده' : 'آماده',
                      style: TextStyle(
                        color: okFgColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'بستن و ساخت برنامه تازه',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Image.asset(
            'assets/pdf.webp',
            width: 88,
            height: 88,
            cacheWidth: 176,
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            widget.athleteName,
            style: const TextStyle(
              color: textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _meta('نوع فایل', _typeLabel)),
              Container(width: 1, height: 34, color: borderColor),
              Expanded(child: _meta('تاریخ ایجاد', date)),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onPrimaryColor,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(_downloading ? 'در حال دریافت...' : 'دانلود PDF'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: textMutedColor, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildEditPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderStrongColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: primeColor),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ویرایش برنامه با هوش مصنوعی',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'اگر نیاز به تغییر هست، اینجا بنویسید تا هوش مصنوعی تغییر بدهد.',
            style: TextStyle(color: textMutedColor, height: 1.6, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _feedbackController,
            focusNode: _feedbackFocus,
            enabled: !_editing,
            minLines: 6,
            maxLines: 10,
            textDirection: TextDirection.rtl,
            decoration: coachInputDecoration(
              hintText: 'مثلاً: جلسه سوم سبک‌تر شود و استراحت‌ها بیشتر شوند',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _editing ? null : _submitEdit,
              icon: _editing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onPrimaryColor,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_editing ? 'در حال اعمال...' : 'اعمال تغییرات'),
            ),
          ),
        ],
      ),
    );
  }
}
