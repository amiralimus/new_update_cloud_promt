import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../colors.dart';
import '../core/network/server_endpoints.dart';
import '../core/platform/url_opener.dart';
import '../loging_system/loging_system.dart';
import '../rigester-login/token_manegment.dart' hide LoggerService;

/// اطلاعات کارت مقصد که سرور برمی‌گرداند.
class CardAccount {
  const CardAccount({
    required this.cardNumber,
    required this.formattedCardNumber,
    required this.cardHolder,
    this.bankName,
    this.sheba,
    this.instructions,
  });

  final String cardNumber;
  final String formattedCardNumber;
  final String cardHolder;
  final String? bankName;
  final String? sheba;
  final String? instructions;

  factory CardAccount.fromJson(Map<String, dynamic> json) {
    return CardAccount(
      cardNumber: (json['card_number'] ?? '').toString(),
      formattedCardNumber:
          (json['formatted_card_number'] ?? json['card_number'] ?? '').toString(),
      cardHolder: (json['card_holder'] ?? '').toString(),
      bankName: json['bank_name'] as String?,
      sheba: json['sheba'] as String?,
      instructions: json['instructions'] as String?,
    );
  }
}

/// دیالوگ پرداخت کارت‌به‌کارت: نمایش شماره کارت + بارگذاری رسید.
///
/// توکن‌ها اینجا آزاد نمی‌شوند؛ بعد از بارگذاری رسید، سفارش به صف بررسی
/// مدیر می‌رود و تایید نهایی در پنل ادمین انجام می‌شود.
Future<bool?> showCardPaymentSheet({
  required BuildContext context,
  required int purchaseId,
  required CardAccount account,
  required double amount,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CardPaymentDialog(
      purchaseId: purchaseId,
      account: account,
      amount: amount,
    ),
  );
}

class _CardPaymentDialog extends StatefulWidget {
  const _CardPaymentDialog({
    required this.purchaseId,
    required this.account,
    required this.amount,
  });

  final int purchaseId;
  final CardAccount account;
  final double amount;

  @override
  State<_CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends State<_CardPaymentDialog> {
  final TextEditingController _referenceController = TextEditingController();
  final ApiService _apiService = ApiService();

  Uint8List? _receiptBytes;
  String? _receiptName;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  String get _amountLabel {
    final rounded = widget.amount.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Future<void> _pickReceipt() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _receiptBytes = bytes;
        _receiptName = picked.name;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'انتخاب تصویر ناموفق بود: $e');
    }
  }

  Future<void> _submitReceipt() async {
    if (_receiptBytes == null) {
      setState(() => _errorMessage = 'ابتدا تصویر رسید را انتخاب کنید.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.multipart(
        method: 'POST',
        endpoint: ServerEndpoints.purchaseReceipt(widget.purchaseId),
        fields: {
          if (_referenceController.text.trim().isNotEmpty)
            'receipt_reference': _referenceController.text.trim(),
        },
        fileFieldName: 'receipt_image',
        fileBytes: _receiptBytes,
        fileName: _receiptName ?? 'receipt.jpg',
        requiresAuth: true,
      );

      if (!mounted) return;

      if (response.success) {
        LoggerService.logProfile(
          action: 'RECEIPT_UPLOADED',
          message: 'رسید سفارش ${widget.purchaseId} بارگذاری شد',
        );
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _isUploading = false;
        _errorMessage = response.error ?? 'بارگذاری رسید ناموفق بود.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = 'خطا در بارگذاری رسید: $e';
      });
    }
  }

  Future<void> _copyCardNumber() async {
    await Clipboard.setData(ClipboardData(text: widget.account.cardNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('شماره کارت کپی شد'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, color: primeColor, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'پرداخت کارت به کارت',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'بستن',
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ---- مبلغ ----
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'مبلغ قابل پرداخت',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '$_amountLabel تومان',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: logoColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- شماره کارت ----
                _FieldRow(
                  label: 'شماره کارت',
                  value: widget.account.formattedCardNumber,
                  bold: true,
                  onCopy: _copyCardNumber,
                ),
                const SizedBox(height: 8),
                _FieldRow(label: 'به نام', value: widget.account.cardHolder),
                if ((widget.account.bankName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FieldRow(label: 'بانک', value: widget.account.bankName!),
                ],
                if ((widget.account.sheba ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FieldRow(label: 'شبا', value: widget.account.sheba!),
                ],

                if ((widget.account.instructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.account.instructions!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: textSecondaryColor,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                const Text(
                  'پس از واریز، تصویر رسید را بارگذاری کنید',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                // ---- انتخاب رسید ----
                InkWell(
                  onTap: _isUploading ? null : _pickReceipt,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _receiptBytes == null
                            ? borderStrongColor
                            : primeColor,
                        width: 1.2,
                      ),
                      color: _receiptBytes == null
                          ? surfaceAltColor
                          : backgroundColor,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _receiptBytes == null
                              ? Icons.upload_file_outlined
                              : Icons.check_circle,
                          size: 20,
                          color: _receiptBytes == null
                              ? textMutedColor
                              : primeColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _receiptBytes == null
                                ? 'انتخاب تصویر رسید'
                                : (_receiptName ?? 'رسید انتخاب شد'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_receiptBytes != null)
                          Text(
                            'تغییر',
                            style: TextStyle(
                              fontSize: 12,
                              color: primeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_receiptBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _receiptBytes!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  enabled: !_isUploading,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'شماره پیگیری واریز (اختیاری)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: textFaintColor,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: dangerFgColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitReceipt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primeColor,
                      foregroundColor: onPrimaryColor,
                      disabledBackgroundColor: primeColor.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onPrimaryColor,
                            ),
                          )
                        : const Text(
                            'ارسال رسید',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'توکن‌ها پس از تایید رسید توسط مدیر به حساب شما اضافه می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: textMutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool bold;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: textSecondaryColor),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: bold ? 1.1 : 0,
              color: bold ? logoColor : textPrimaryColor,
            ),
          ),
        ),
        if (onCopy != null)
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'کپی',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
